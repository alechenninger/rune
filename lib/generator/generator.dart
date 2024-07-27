/// Generates assembly from model.
///
/// There are two general types of state
/// which needs to be managed while generating code:
///
/// 1. Non-volatile (code state, see [Program]):
/// the state of the code that we can see in a text editor.
/// Related to this state is the known state of volatile memory
/// which must be true at the moment of generating certain instructions
/// (e.g. whether we are in an event loop or dialog loop).
/// See [SceneAsmGenerator]
/// This is not considered the second category
/// because it is only needed to contextualize code being generated.
/// 2. Volatile (event state, see [Memory]):
/// the state of registers and RAM.
/// This can be looked at in two different views:
/// abstract (state of the model, [EventState]) and
/// system (values in RAM and CPU registers, [SystemState]).
library generator.dart;

import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:logging/logging.dart';
import 'package:quiver/check.dart';
import 'package:quiver/collection.dart';
import 'package:quiver/iterables.dart' show concat;
import 'package:rune/generator/guild.dart';
import 'package:rune/src/logging.dart';

import '../asm/asm.dart';
import '../asm/dialog.dart';
import '../asm/dialog.dart' as dialog_asm;
import '../asm/events.dart';
import '../asm/events.dart' as events_asm;
import '../asm/text.dart';
import '../model/model.dart';
import '../src/iterables.dart';
import '../src/null.dart';
import 'conditional.dart';
import 'cutscenes.dart';
import 'debug.dart' as debug;
import 'dialog.dart';
import 'event.dart';
import 'map.dart';
import 'memory.dart';
import 'movement.dart';
import 'objects.dart';
import 'scene.dart';
import 'text.dart' as text_model;

export '../asm/asm.dart' show Asm;
export 'deprecated.dart';
export 'map.dart';
export 'scene.dart';
export 'objects.dart';

typedef DebugOptions = ({
  List<EventFlag> eventFlags,
  List<Character> party,
  LoadMap loadMap,
});

final _log = Logger('generator');

// tracks global state about the program code
// e.g. event pointers
// could also use to save generation as it is done, relative to the state
// updates
// i.e. once a map is generated which adds event pointers, add the map here as
// well.
// this is the state of what we would look at in a text editor.
class Program {
  final _scenes = <SceneId, SceneAsm>{};
  Map<SceneId, SceneAsm> get scenes => UnmodifiableMapView(_scenes);

  final _maps = <MapId, MapAsm>{};
  Map<MapId, MapAsm> get maps => UnmodifiableMapView(_maps);

  final _AsmProgramConfiguration _config;

  DialogTrees get dialogTrees => _config.dialogTrees;
  Asm get additionalEventPointers => _config.additionalEvents.toAsm();
  Asm get eventPointers => _config.events.toAsm();
  Word get peekNextEventIndex => _config.events.nextIndex;
  Asm get cutscenesPointers => _config.cutscenes.toAsm();

  EventFlags get _eventFlags => _config.eventFlags;
  Constants get _constants => _config.constants;
  Asm get runEventsJumpTable => _config.runEvents.toAsm();

  FieldRoutineRepository get _fieldRoutines => _config.fieldRoutines;

  Program({
    EventPointers? eventPointers,
    EventPointers? cutscenePointers,
    JumpTable<Byte>? runEvents,
    Map<MapId, Word>? vramTileOffsets,
    Map<MapId, List<SpriteVramMapping>>? builtInSprites,
    FieldRoutineRepository? fieldRoutines,
  }) : _config = _AsmProgramConfiguration(
            events: eventPointers ?? eventPtrs(),
            cutscenes:
                cutscenePointers?.withOffset(Word(0x8000)) ?? cutscenePtrs(),
            runEvents: runEvents ?? runEventsJmpTbl(),
            fieldRoutines: fieldRoutines ?? defaultFieldRoutines,
            eventFlags: EventFlags(),
            constants: Constants.wrap({}),
            dialogTrees: DialogTrees(),
            spriteVramOffsets: vramTileOffsets ?? _defaultSpriteVramOffsets,
            builtInSprites: builtInSprites ?? _defaultBuiltInSprites);

  /// Returns event index by which [routine] can be referenced.
  ///
  /// The event code must be added separate with the exact label of [routine].
  @Deprecated('use ProgramConfiguration instead')
  Word _addEventPointer(Label routine) {
    return _config.events.add(routine);
  }

  /// Returns event index by which [routine] can be referenced.
  ///
  /// The event code must be added separate with the exact label of [routine].
  @Deprecated('use ProgramConfiguration instead')
  Word _addCutscenePointer(Label routine) {
    return _config.cutscenes.add(routine);
  }

  EventAsm debugStart(DebugOptions debugOptions) {
    var asm = debug.debugStart(
        party: debugOptions.party,
        flagsSet: debugOptions.eventFlags,
        eventFlags: _eventFlags,
        loadMap: debugOptions.loadMap);

    _scenes[SceneId('gamestart')] = SceneAsm(event: asm);
    return asm;
  }

  SceneAsm addScene(SceneId id, Scene scene, {GameMap? startingMap}) {
    var eventAsm = EventAsm.empty();
    var eventType = sceneEventType(scene.events);

    switch (eventType) {
      case EventType.cutscene:
        _addCutscenePointer(Label('Cutscene_$id'));
        break;
      case _:
        _addEventPointer(Label('Event_$id'));
        break;
    }

    try {
      var generator = SceneAsmGenerator.forEvent(id, dialogTrees, eventAsm,
          startingMap: startingMap,
          eventFlags: _eventFlags,
          eventType: eventType,
          fieldRoutines: _fieldRoutines);

      for (var event in scene.events) {
        event.visit(generator);
      }

      generator.finish();
    } catch (err, s) {
      _log.e(
          e('add_scene', {
            'scene_id': id.toString(),
          }),
          err,
          s);
      rethrow;
    }

    return _scenes[id] = SceneAsm(event: eventAsm);
  }

  MapAsm addMap(GameMap map) {
    // trees are already written to, and we don't know which ones, and which
    // branches
    if (_maps.containsKey(map.id)) {
      throw ArgumentError.value(
          map.id.name, 'map', 'map with same id already added');
    }

    return _maps[map.id] = compileMap(map, _config);
  }

  HuntersGuildAsm configureHuntersGuild(HuntersGuild guild,
      {required GameMap inMap}) {
    return compileHuntersGuild(
        guild: guild,
        map: inMap,
        constants: _constants,
        dialogTrees: dialogTrees,
        eventFlags: _eventFlags,
        eventRoutines: _ProgramEventRoutines(this));
  }

  /// DialogTrees for maps which are not added to the game.
  Map<MapId?, DialogTree> extraDialogTrees() {
    var extras = dialogTrees.toMap();
    extras.removeWhere((key, _) => _maps.containsKey(key));
    return extras;
  }

  Asm extraConstants() {
    var asm = _eventFlags
        .customEventFlags()
        .entries
        .sortedBy<num>((e) => e.key.value)
        .map((e) => Asm.fromRaw('${e.value} = ${e.key}'))
        .reduceOr((a1, a2) => Asm([a1, a2]), ifEmpty: Asm.empty());

    asm.add(_constants
        .map((e) => Asm.fromRaw('${e.key} = ${e.value}'))
        .reduceOr((a1, a2) => Asm([a1, a2]), ifEmpty: Asm.empty()));

    return asm;
  }
}

abstract class EventRoutines {
  Word addEvent(Label name);
  Word addCutscene(Label name);
}

abstract class ProgramConfiguration implements EventRoutines {
  Byte addRunEvent(Label name);
  FieldRoutineRepository get fieldRoutines;
  EventFlags get eventFlags;
  Constants get constants;
  DialogTrees get dialogTrees;
  Word? spriteVramOffsetForMap(MapId map);
  List<SpriteVramMapping> builtInSpritesForMap(MapId map);

  ProgramConfiguration._();

  factory ProgramConfiguration.empty(
      {EventPointers? events,
      EventPointers? cutscenes,
      JumpTable<Byte>? runEvents,
      FieldRoutineRepository? fieldRoutines,
      EventFlags? eventFlags,
      Constants? constants,
      DialogTrees? dialogTrees,
      Map<MapId, Word>? spriteVramOffsets,
      Map<MapId, List<SpriteVramMapping>>? builtInSprites}) {
    return _AsmProgramConfiguration(
        events: events ?? EventPointers([]),
        cutscenes: cutscenes?.withOffset(Word(0x8000)) ??
            EventPointers([], offset: Word(0x8000)),
        runEvents: runEvents ??
            JumpTable.sparse(
              jump: withNoop(Label.known('RunEvent_NoEvent'), bra.w),
              newIndex: (i) => Byte(i),
            ),
        fieldRoutines: fieldRoutines ?? defaultFieldRoutines,
        eventFlags: eventFlags ?? EventFlags(),
        constants: constants ?? Constants.wrap({}),
        dialogTrees: dialogTrees ?? DialogTrees(),
        spriteVramOffsets: spriteVramOffsets ?? _defaultSpriteVramOffsets,
        builtInSprites: builtInSprites ?? _defaultBuiltInSprites);
  }

  factory ProgramConfiguration.grandCross() {
    return _AsmProgramConfiguration(
        events: eventPtrs(),
        cutscenes: cutscenePtrs(),
        runEvents: runEventsJmpTbl(),
        fieldRoutines: defaultFieldRoutines,
        eventFlags: EventFlags(),
        constants: Constants.wrap({}),
        dialogTrees: DialogTrees(),
        spriteVramOffsets: _defaultSpriteVramOffsets,
        builtInSprites: _defaultBuiltInSprites);
  }
}

class _AsmProgramConfiguration extends ProgramConfiguration {
  final int _startEventCount;
  final EventPointers events;
  EventPointers get additionalEvents => events.skip(_startEventCount);
  final EventPointers cutscenes;
  final JumpTable<Byte> runEvents;

  @override
  final FieldRoutineRepository fieldRoutines;
  @override
  final EventFlags eventFlags;
  @override
  final Constants constants;
  @override
  final DialogTrees dialogTrees;

  final Map<MapId, Word> _spriteVramOffsets;
  final Map<MapId, List<SpriteVramMapping>> _builtInSprites;

  _AsmProgramConfiguration(
      {required this.events,
      required this.cutscenes,
      required this.runEvents,
      required this.fieldRoutines,
      required this.eventFlags,
      required this.constants,
      required this.dialogTrees,
      required Map<MapId, Word> spriteVramOffsets,
      required Map<MapId, List<SpriteVramMapping>> builtInSprites})
      : _spriteVramOffsets = Map.of(spriteVramOffsets),
        _builtInSprites = Map.of(builtInSprites),
        _startEventCount = events.length,
        super._();

  @override
  Word addCutscene(Label name) {
    return cutscenes.add(name);
  }

  @override
  Word addEvent(Label name) {
    return events.add(name);
  }

  @override
  Byte addRunEvent(Label name) {
    return runEvents.add(name);
  }

  @override
  Word? spriteVramOffsetForMap(MapId map) => _spriteVramOffsets[map];

  @override
  List<SpriteVramMapping> builtInSpritesForMap(MapId map) =>
      _builtInSprites[map] ?? const [];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AsmProgramConfiguration &&
          runtimeType == other.runtimeType &&
          events == other.events &&
          cutscenes == other.cutscenes &&
          runEvents == other.runEvents &&
          fieldRoutines == other.fieldRoutines &&
          eventFlags == other.eventFlags &&
          constants == other.constants &&
          dialogTrees == other.dialogTrees &&
          const MapEquality()
              .equals(_spriteVramOffsets, other._spriteVramOffsets) &&
          const MapEquality().equals(_builtInSprites, other._builtInSprites);

  @override
  int get hashCode =>
      events.hashCode ^
      cutscenes.hashCode ^
      runEvents.hashCode ^
      fieldRoutines.hashCode ^
      eventFlags.hashCode ^
      constants.hashCode ^
      dialogTrees.hashCode ^
      const MapEquality().hash(_spriteVramOffsets) ^
      const MapEquality().hash(_builtInSprites);

  @override
  String toString() {
    return '_ProgramConfiguration{events: $events, '
        'cutscenes: $cutscenes, '
        'runEvents: $runEvents, '
        'fieldRoutines: $fieldRoutines, '
        'eventFlags: $eventFlags, '
        'constants: $constants, '
        'dialogTrees: $dialogTrees, '
        '_spriteVramOffsets: $_spriteVramOffsets, '
        '_builtInSprites: $_builtInSprites}';
  }
}

class _EventRoutinesWrappingConfiguration extends ProgramConfiguration {
  final EventRoutines _eventRoutines;
  final JumpTable<Byte> _runEvents;

  @override
  final Constants constants;

  @override
  final DialogTrees dialogTrees;

  @override
  final EventFlags eventFlags;

  @override
  final FieldRoutineRepository fieldRoutines;

  final Map<MapId, Word> _spriteVramOffsets;
  final Map<MapId, List<SpriteVramMapping>> _builtInSprites;

  _EventRoutinesWrappingConfiguration(
      {required EventRoutines eventRoutines,
      JumpTable<Byte>? runEvents,
      required this.constants,
      required this.dialogTrees,
      required this.eventFlags,
      required this.fieldRoutines,
      Map<MapId, Word> spriteVramOffsets = const {},
      Map<MapId, List<SpriteVramMapping>> builtInSprites = const {}})
      : _spriteVramOffsets = Map.of(spriteVramOffsets),
        _builtInSprites = Map.of(builtInSprites),
        _eventRoutines = eventRoutines,
        _runEvents = runEvents ?? runEventsJmpTbl(),
        super._();

  @override
  Word addCutscene(Label name) => _eventRoutines.addCutscene(name);

  @override
  Word addEvent(Label name) => _eventRoutines.addEvent(name);

  @override
  Byte addRunEvent(Label name) => _runEvents.add(name);

  @override
  Word? spriteVramOffsetForMap(MapId map) => _spriteVramOffsets[map];

  @override
  List<SpriteVramMapping> builtInSpritesForMap(MapId map) =>
      _builtInSprites[map] ?? const [];
}

class EventFlags {
  Word? _eventFlagOffset;
  final BiMap<Word, Constant> _customEventFlags = BiMap();
  Word? get peekNextEventFlag => _eventFlagOffset;
  Map<Word, Constant> customEventFlags() =>
      _customEventFlags.toIMap().unlockLazy;

  final _freeEventFlags = freeEventFlags();

  EventFlags() {
    _setNextFreeEventFlag();
  }

  Word toId(EventFlag flag) {
    var c = Constant('EventFlag_${flag.name}');
    return _addEventFlag(c);
  }

  KnownConstantValue toConstantValue(EventFlag flag) {
    var c = Constant('EventFlag_${flag.name}');
    return KnownConstantValue(c, _addEventFlag(c));
  }

  Constant toConstant(EventFlag flag) {
    var c = Constant('EventFlag_${flag.name}');
    _addEventFlag(c);
    return c;
  }

  Word _addEventFlag(Constant flag) {
    var existing =
        eventFlags[flag]?.value.toWord ?? _customEventFlags.inverse[flag];
    if (existing != null) return existing;

    var index = _eventFlagOffset;
    if (index == null) {
      throw StateError('cannot add event flag; too many event flags');
    }
    _customEventFlags[index] = flag;
    _setNextFreeEventFlag();
    return index;
  }

  void _setNextFreeEventFlag() {
    _eventFlagOffset =
        _freeEventFlags.isEmpty ? null : _freeEventFlags.removeFirst();
  }
}

class _ProgramEventRoutines extends EventRoutines {
  final Program _program;

  _ProgramEventRoutines(this._program);

  @override
  Word addEvent(Label routine) => _program._config.events.add(routine);

  @override
  Word addCutscene(Label routine) => _program._config.cutscenes.add(routine);
}

/// Returns true if an event routine is needed in code generated for [events].
///
/// Reproduces logic in Interaction_ProcessDialogueTree to see if the events
/// can be processed soley through dialog loop.
///
/// Returns `null` if events occur in the following order:
/// - A single [IfFlag] (i.e. `$FA` control code) event
/// and nothing else.
/// This is because if there are other events,
/// they are common to both branches,
/// and therefore must be added to both dialog trees
/// OR resulting events
/// if the individual branches end up running events themselves.
/// To avoid this complexity we resort to event code
/// which already deals with subsequent unconditional events.
///
/// OR
///
/// - Zero or one [FacePlayer] where `object` is [obj]
/// (i.e. `$F3` control code)
/// - Zero or more [Dialog]
///
/// See also: [SceneAsmGenerator.runEvent]
/*
todo: can also support all of this action control code stuff as events:
$F2 = Determines actions during dialogues. The byte after this has the following values:
  0 = Loads Panel; the word after this is the Panel index
  1 = Destroys panel loaded last
  2 = Destroys all panels
  3 = Loads sound; the byte after this is the Sound index
  4 = Loads sound; the byte after this is the Sound index
  6 = Updates palettes
  7 = Zio's eyes turn red in one of his panels (before the battle)
  8 = Pauses music
  9 = Resumes music
  $A = For the spaceship sabotage, plays alarm sound and turns the screen red
  $B = Sets event flag
  $C = After the Profound Darkness battle, it updates stuff when Elsydeon breaks
  */
EventType? sceneEventType(List<Event> events,
    {FieldObject? interactingWith, bool checkBranches = false}) {
  // SetContext is not a perceivable event, so ignore
  events = events.whereNot((e) => e is SetContext).toList(growable: false);

  // In interactions, each branch will be evaluated separately
  // so it doesn't matter what's in each branch.
  // FIXME(cutscenes): if there is an inline if,
  //  I think we still need to check branches.
  if (events.length == 1 && events[0] is IfFlag) return null;

  bool isLast(int i) => i == events.length - 1;
  bool hasDialogAfter(int i) => events.skip(i + 1).any((e) => e is Dialog);

  // One of dialog checks must pass for each event.
  // If check does not pass, the next check is used for all remaining events.
  // If there are no more checks, it must require an event.
  var dialogCheck = 0;
  var dialogChecks = <bool Function(Event, int, bool)>[
    (event, i, _) =>
        event is FacePlayer &&
        (event.object == interactingWith ||
            event.object == const InteractionObject()),
    (event, i, hasDialogAfter) =>
        // Events need dialog after, otherwise their order
        // creates unwanted dialog windows.
        (event is Dialog && !event.hidePanelsOnClose) ||
        (event is IndividualMoves &&
            switch (event.justFacing()) {
              var f? => _canFaceInDialog(f),
              null => false
            } &&
            hasDialogAfter) ||
        (event is PlaySound && hasDialogAfter) ||
        (event is PlayMusic && hasDialogAfter) ||
        (event is ShowPanel && event.showDialogBox && hasDialogAfter) ||
        (event is SetFlag && hasDialogAfter) ||
        (event is HideTopPanels && hasDialogAfter) ||
        (event is HideAllPanels && hasDialogAfter) ||
        (event is Pause &&
            (event.duringDialog == true ||
                event.duringDialog == null && hasDialogAfter)) ||
        // Choices must NOT have any events after in order to fit in dialog
        (event is YesOrNoChoice &&
            isLast(i) &&
            sceneEventType(event.ifNo) == null &&
            sceneEventType(event.ifYes) == null),
    (event, i, _) => event is Dialog && event.hidePanelsOnClose && isLast(i),
  ];

  var faded = false;
  var needsEvent = false;

  event:
  for (int i = 0; i < events.length; i++) {
    var event = events[i];
    for (var cIdx = dialogCheck;
        cIdx < dialogChecks.length && !needsEvent;
        cIdx++) {
      var dialogAfter = hasDialogAfter(i);
      if (dialogChecks[cIdx](event, i, dialogAfter)) {
        dialogCheck = cIdx;
        continue event;
      }
    }

    needsEvent = true;

    if (event is FadeOut) {
      faded = true;
    } else if (event is FadeInField || (event is LoadMap && event.showField)) {
      faded = false;
    } else if (event is Dialog && faded) {
      return EventType.cutscene;
    }
  }

  if (needsEvent) return EventType.event;

  return null;
}

class GenerationContext {
  GenerationContext(this.config,
      {required this.eventAsm, required this.runEventAsm});

  // Non-volatile state (state of the code being generated)
  final ProgramConfiguration config;
  DialogTrees get dialogTrees => config.dialogTrees;
  EventFlags get eventFlags => config.eventFlags;
  final EventAsm eventAsm;
  final Asm runEventAsm;

  /// Additional assembly segments, labelled, which are added after generation.
  ///
  /// Can be used for data tables or additional, top-level subroutines.
  final postEvents = <Asm>[];

  // required if processing interaction (see todo on ctor)
  EventRoutines get eventRoutines => config;
  FieldRoutineRepository get fieldRoutines => config.fieldRoutines;

  var _eventCounter = 1;
  int get eventCounter => _eventCounter;

  int getAndIncrementEventCount() {
    return _eventCounter++;
  }

  /// For currently generating branch, what is the known state of event flags
  // note: empty is currently used to understand "root" condition
  // if we allow starting scenes with other conditions,
  // we'll need to store the starting point.
  Condition currentCondition = Condition.empty();

  /// mem state which exactly matches current flags; other states may need
  /// updates
  Memory memory = Memory(); // todo: ctor initialization
  /// should also contain root state
  final stateGraph = <Condition, Memory>{};

  //AsmGeneratingEventVisitor mode;
}

class SceneAsmGenerator implements EventVisitor {
  final SceneId id;

  // Non-volatile state (state of the code being generated)
  final GenerationContext _context;

  ProgramConfiguration get _config => _context.config;
  DialogTrees get _dialogTrees => _config.dialogTrees;
  EventFlags get _eventFlags => _config.eventFlags;
  EventAsm get _eventAsm => _context.eventAsm;

  /// Additional assembly segments, labelled, which are added after generation.
  ///
  /// Can be used for data tables or additional, top-level subroutines.
  List<Asm> get _postAsm => _context.postEvents;

  // required if processing interaction (see todo on ctor)
  EventRoutines get _eventRoutines => _config;
  FieldRoutineRepository get _fieldRoutines => _config.fieldRoutines;

  int get _eventCounter => _context.eventCounter;

  // conditional runtime state

  /// For currently generating branch, what is the known state of event flags
  // note: empty is currently used to understand "root" condition
  // if we allow starting scenes with other conditions,
  // we'll need to store the starting point.
  Condition get _currentCondition => _context.currentCondition;
  set _currentCondition(Condition value) {
    _context.currentCondition = value;
  }

  /// mem state which exactly matches current flags; other states may need
  /// updates
  Memory get _memory => _context.memory;
  // TODO: probably move this to method on context
  set _memory(Memory value) {
    _context.memory = value;
  }

  /// should also contain root state
  Map<Condition, Memory> get _stateGraph => _context.stateGraph;

  final _finishedStates = <Condition>{};

  bool get _isFinished => _finishedStates.contains(_currentCondition);

  void _setCurrentStateFinished() => _finishedStates.add(_currentCondition);

  // Current dialog generation state:

  DialogTree? _dialogTree;
  Byte? _currentDialogId;
  DialogAsm? _currentDialog;
  var _lastEventBreak = -1;

  GameMode _gameMode;
  bool get inDialogLoop => switch (_gameMode) {
        DialogCapableMode mode => mode.isInDialogLoop,
        _ => false
      };

  // i think this should always be true if mode == event?
  /// Whether or not we are generating in the context of an existing event.
  ///
  /// This is necessary to understand whether, when in dialog mode, we can pop
  /// back to an event or have to trigger a new one.
  bool get _inEvent => switch (_gameMode) { EventMode() => true, _ => false };

  FieldObject? get _interactingWith => switch (_gameMode) {
        InteractionMode m => m.withObject,
        DialogCapableMode(priorMode: InteractionMode m) => m.withObject,
        _ => null,
      };

  bool get _isInteractingWithObject => _interactingWith != null;

  /// Events processed in current dialog, last event first.
  final _queuedGeneration = Queue<_QueuedGeneration>();
  Event? _lastEventInCurrentDialog;

  Function([int? dialogRoutine])? _replaceDialogRoutine;

  // todo: This might be a subclass really
  SceneAsmGenerator.forInteraction(GameMap map, this.id,
      DialogTrees dialogTrees, EventAsm eventAsm, EventRoutines eventRoutines,
      {EventFlags? eventFlags,
      FieldObject? withObject = const InteractionObject(),
      FieldRoutineRepository? fieldRoutines})
      : //_dialogIdOffset = _dialogTree.nextDialogId!,
        _gameMode = InteractionMode(withObject: withObject),
        _context = GenerationContext(
            _EventRoutinesWrappingConfiguration(
                eventRoutines: eventRoutines,
                constants: Constants.wrap({}),
                dialogTrees: dialogTrees,
                eventFlags: eventFlags ?? EventFlags(),
                fieldRoutines: fieldRoutines ?? defaultFieldRoutines),
            eventAsm: eventAsm,
            runEventAsm: Asm.empty()) {
    if (withObject != null) {
      _memory.putInAddress(a3, const InteractionObject());
    }
    _memory.hasSavedDialogPosition = false;
    _memory.currentMap = map;
    _memory.loadedDialogTree = _dialogTrees.forMap(map.id);
    _stateGraph[Condition.empty()] = _memory;

    // Since we start in dialog mode, there must be at least one dialog.
    _currentDialogIdOrStart();
  }

  SceneAsmGenerator.forEvent(
      this.id, DialogTrees dialogTrees, EventAsm eventAsm,
      {GameMap? startingMap,
      EventFlags? eventFlags,
      EventType? eventType,
      FieldRoutineRepository? fieldRoutines})
      : //_dialogIdOffset = _dialogTree.nextDialogId!,
        _gameMode = EventMode(type: eventType ?? EventType.event),
        _context = GenerationContext(
            _AsmProgramConfiguration(
                events: eventPtrs(),
                cutscenes: cutscenePtrs(),
                runEvents: runEventsJmpTbl(),
                fieldRoutines: fieldRoutines ?? defaultFieldRoutines,
                eventFlags: eventFlags ?? EventFlags(),
                constants: Constants.wrap({}),
                dialogTrees: dialogTrees,
                spriteVramOffsets: _defaultSpriteVramOffsets,
                builtInSprites: _defaultBuiltInSprites),
            eventAsm: eventAsm,
            runEventAsm: Asm.empty()) {
    _memory.currentMap = startingMap;
    if (startingMap != null) {
      _memory.loadedDialogTree = _dialogTrees.forMap(startingMap.id);
    }
    _stateGraph[Condition.empty()] = _memory;
  }

  SceneAsmGenerator.forRunEvent(this.id,
      {required GameMap inMap,
      required EventAsm eventAsm,
      required Asm runEventAsm,
      required ProgramConfiguration config})
      : _gameMode = RunEventMode(),
        _context = GenerationContext(config,
            eventAsm: eventAsm, runEventAsm: runEventAsm) {
    _memory.currentMap = inMap;
    _memory.loadedDialogTree = _dialogTrees.forMap(inMap.id);
    _stateGraph[Condition.empty()] = _memory;
  }

  void scene(Scene scene) {
    for (var event in scene.events) {
      event.visit(this);
    }
  }

  /// See [sceneEventType].
  EventType? needsEventMode(List<Event> events) {
    return sceneEventType(events, interactingWith: _interactingWith);
  }

  void runEventIfNeeded(List<Event> events,
      {Word? eventIndex, String? nameSuffix}) {
    // Check if we're already in an event
    if (_gameMode is EventMode) return;

    // We're not so see if the events require one.
    var type = needsEventMode(events);

    switch ((type, _gameMode)) {
      case (EventType.cutscene, _):
        // Cutscenes always require special handling.
        runEvent(
            type: EventType.cutscene,
            eventIndex: eventIndex,
            nameSuffix: nameSuffix);
        break;
      case (EventType.event, InteractionMode()):
        // Interactions require special handling for any event.
        runEvent(
            type: EventType.event,
            eventIndex: eventIndex,
            nameSuffix: nameSuffix);
        break;
      default:
        // Other modes (event, run event) support events.
        break;
    }
  }

  /// If in interaction and not yet in an event, run an event from dialog.
  ///
  /// If [eventIndex] is not provided, a new event will be added with optional
  /// [nameSuffix].
  EventMode runEvent(
      {Word? eventIndex,
      String? nameSuffix,
      EventType type = EventType.event}) {
    _checkNotFinished();

    Word addEventIfNeeded(String nameSuffix) {
      if (eventIndex != null) return eventIndex!;

      // only include event counter if we're in a branch condition
      // todo: we might not always start with an empty condition so this should
      // maybe be something about root or starting condition
      // var eventName = nameSuffix == null
      //     ? '$id${_currentCondition == Condition.empty() ? '' : _eventCounter}'
      //     : '$id$nameSuffix';
      var eventRoutine = Label('Event_GrandCross_$id$nameSuffix');
      eventIndex = type.addRoutine(_eventRoutines, eventRoutine);
      _eventAsm.add(setLabel(eventRoutine.name));

      return eventIndex!;
    }

    EventMode newMode;

    switch (_gameMode) {
      case InteractionMode m:
        if (_lastEventInCurrentDialog != null &&
            _lastEventInCurrentDialog is! IfFlag) {
          // This is because this is the implementation of this ctrl code:
          // TextCtrlCode_Event:
          //   lea	$1(a0), a0
          //   bra.w	RunText_CharacterLoop
          // i.e. a no-op.
          throw StateError('can only run events first or after IfFlag events '
              'but last event was $_lastEventInCurrentDialog');
        }

        var suffix = nameSuffix ??
            (_currentCondition == Condition.empty()
                ? ''
                : _eventCounter.toString());
        var eventIndex = addEventIfNeeded(suffix);
        _addToDialog(dialog_asm.runEvent(eventIndex));
        _terminateDialog();
        _gameMode = newMode = m.toEventMode(type);

        break;
      case RunEventMode m:
        var eventIndex = addEventIfNeeded(_eventCounter.toString());

        _context.runEventAsm.add(Asm([
          move.w(eventIndex.i, Event_Index.w),
          moveq(1.i, d7),
          rts,
        ]));

        _gameMode = newMode = m.toEventMode(type);

        break;
      default:
        throw StateError('cannot run event; already in event');
    }

    return newMode;
  }

  @override
  void asm(AsmEvent asm) {
    if (asm.requireEvent) {
      _addToEvent(asm, (i) {
        _memory.unknownAddressRegisters();
        return asm.asm;
      });
    } else {
      _addToEventOrRunEvent(asm, (i, _) {
        _memory.unknownAddressRegisters();
        return asm.asm;
      });
    }
  }

  @override
  void dialogCodes(DialogCodes codes) {
    _checkNotFinished();
    _generateQueueInCurrentMode();
    _runOrContinueDialog(codes);
    _addToDialog(dc.b(codes.codes));
  }

  @override
  void dialog(Dialog dialog) {
    _checkNotFinished();
    _generateQueueInCurrentMode();
    _runOrContinueDialog(dialog);
    _addToDialog(dialog.toAsm(_memory));
  }

  @override
  void displayText(DisplayText display) {
    _addToEvent(display, (i) {
      _terminateDialog();
      var asm = text_model.displayTextToAsm(display, _currentDialogTree());
      return asm.event;
    });
  }

  @override
  void facePlayer(FacePlayer face) {
    _checkNotFinished();

    if (!_inEvent &&
        _isInteractingWithObject &&
        _lastEventInCurrentDialog == null &&
        face.object == const InteractionObject()) {
      // this already will happen by default if the first event
      _lastEventInCurrentDialog = face;
      return;
    }

    _addToEvent(face, (i) {
      var asm = EventAsm.empty();

      // TODO: since we try to track withObject now,
      // maybe InteractionObject should point to that?
      // It's not exactly the same in case there are multiple objects
      // which share the same interaction scene.

      if (_memory.inAddress(a3) == AddressOf(face.object) &&
          face.object == const InteractionObject()) {
        asm.add(jsr(Label('Interaction_UpdateObj').l));
      } else {
        asm.add(face
            .toMoves()
            .toAsm(_memory, eventIndex: i, fieldRoutines: _fieldRoutines));
      }

      return asm;
    });
  }

  @override
  void overlapCharacters(OverlapCharacters overlap) {
    _checkNotFinished();
    _addToEvent(overlap, (_) => jsr(Label('Event_OverlapCharacters').l));
  }

  @override
  void individualMoves(IndividualMoves moves) {
    var facing = moves.justFacing();
    Asm? dialogAsm;

    if (facing != null &&
        (dialogAsm = _faceInDialog(facing, memory: _memory)) != null) {
      _addToEventOrDialog(moves,
          inDialog: () {
            _addToDialog(dialogAsm!);

            for (var MapEntry(key: obj, value: dir) in facing.entries) {
              switch (dir.known(_memory)) {
                case null:
                  _memory.clearFacing(obj);
                  break;
                case var dir:
                  _memory.setFacing(obj, dir);
                  break;
              }
            }
          },
          inEvent: (i) => moves.toAsm(_memory,
              eventIndex: i, fieldRoutines: _fieldRoutines));
    } else {
      _addToEvent(
          moves,
          (i) => moves.toAsm(_memory,
              eventIndex: i, fieldRoutines: _fieldRoutines));
    }
  }

  @override
  void absoluteMoves(AbsoluteMoves moves) {
    _addToEvent(moves, (i) => absoluteMovesToAsm(moves, _memory));
  }

  @override
  void instantMoves(InstantMoves moves) {
    _addToEvent(moves, (i) => instantMovesToAsm(moves, _memory, eventIndex: i));
  }

  @override
  void stepObject(StepObject step) {
    _addToEvent(step, (i) {
      /// Current x and y positions in memory are stored
      /// as a longword with fractional component.
      /// The higher order word is the position,
      /// but the lower order word can be used as a fractional part.
      /// This allows moving a pixel to take longer than one frame
      /// in the step objects loop,
      /// since the pixel is only read from the higher order word.
      /// This converts the double x and y positions
      /// to their longword counterparts.
      var x = (step.stepPerFrame.x * (1 << 4 * 4)).truncate();
      var y = (step.stepPerFrame.y * (1 << 4 * 4)).truncate();

      var current = _memory.positions[step.object];
      if (current != null) {
        var totalSteps = (step.stepPerFrame * step.frames).truncate();
        _memory.positions[step.object] =
            current + Position.fromPoint(totalSteps);
      }

      // Step will always execute at least once.
      var additionalFrames = step.frames - 1;

      return Asm([
        step.object.toA4(_memory),
        if (step.onTop) move.b(1.i, 5(a4)),
        if (Size.b.fitsSigned(x))
          moveq(x.toSignedByte.i, d0)
        else
          move.l(x.toSignedLongword.i, d0),
        if (Size.b.fitsSigned(y))
          moveq(y.toSignedByte.i, d1)
        else
          move.l(y.toSignedLongword.i, d1),
        if (additionalFrames <= 127)
          moveq(additionalFrames.toByte.i, d2)
        else
          move.w(additionalFrames.toWord.i, d2),
        if (step.animate)
          jsr(Label('Event_StepObject').l)
        else
          jsr(Label('Event_StepObjectNoAnimate').l),
        if (step.onTop) clr.b(5(a4)),
        move.w(curr_x_pos(a4), dest_x_pos(a4)),
        move.w(curr_y_pos(a4), dest_y_pos(a4)),
      ]);
    });
  }

  @override
  void stepObjects(StepObjects step) {
    if (step.objects.length == 1) {
      return stepObject(StepObject(step.objects.single,
          stepPerFrame: step.stepPerFrame,
          frames: step.frames,
          onTop: step.onTop,
          animate: step.animate));
    }

    _addToEvent(step, (eventIndex) {
      var x = (step.stepPerFrame.x * (1 << 4 * 4)).truncate();
      var y = (step.stepPerFrame.y * (1 << 4 * 4)).truncate();

      // Step will always execute at least once.
      var additionalFrames = step.frames - 1;

      var loop = Label('.stepObjectsLoop_$eventIndex');
      _eventAsm.add(Asm([
        if (additionalFrames <= 127)
          moveq(additionalFrames.toByte.i, d2)
        else
          move.w(additionalFrames.toWord.i, d2),
        label(loop)
      ]));

      // Adjust each object for each loop iteration (frame)
      for (var obj in step.objects) {
        _eventAsm.add(Asm([
          obj.toA4(_memory),
          if (step.onTop) move.b(1.i, 5(a4)),
          if (Size.b.fitsSigned(x))
            moveq(x.toSignedByte.i, d0)
          else
            move.l(x.toSignedLongword.i, d0),
          if (Size.b.fitsSigned(y))
            moveq(y.toSignedByte.i, d1)
          else
            move.l(y.toSignedLongword.i, d1),
          if (step.animate)
            jsr(Label('Event_StepObjectNoWait'))
          else
            jsr(Label('Event_StepObjectNoWaitNoAnimate').l),
        ]));
      }

      // Now update sprites, wait for vint, and loop
      _eventAsm.add(Asm([
        movem.l(d2 / a4, -(sp)),
        jsr(Label('Field_LoadSprites').l),
        jsr(Label('Field_BuildSprites').l),
        jsr(Label('AnimateTiles').l),
        jsr(Label('RunMapUpdates').l),
        jsr(Label('VInt_Prepare').l),
        movem.l(sp.postIncrement(), d2 / a4),
        dbf(d2, loop),
      ]));

      // Now reset all step constants and update memory
      for (var obj in step.objects.reversed) {
        _eventAsm.add(Asm([
          obj.toA4(_memory),
          moveq(0.i, d0),
          if (x != 0) move.l(d0, x_step_constant(a4)),
          if (y != 0) move.l(d0, y_step_constant(a4)),
          // Set destination to current position.
          // This is needed if routine will move to destination.
          // If not set in that case, the object will move the next time
          // the field object routine is run.
          setDestination(x: curr_x_pos(a4), y: curr_y_pos(a4)),
        ]));

        if (_memory.positions[obj] case var current?) {
          var totalSteps = (step.stepPerFrame * step.frames).truncate();
          _memory.positions[obj] = current + Position.fromPoint(totalSteps);
        }
      }
    });
  }

  @override
  void lockCamera(LockCamera lock) {
    _addToEvent(lock, (i) {
      if (_memory.cameraLock == true) {
        return EventAsm.empty();
      }
      return EventAsm.of(events_asm.lockCamera(_memory.cameraLock = true));
    });
  }

  @override
  void unlockCamera(UnlockCamera unlock) {
    _addToEvent(unlock, (i) {
      if (_memory.cameraLock == false) {
        return EventAsm.empty();
      }
      return EventAsm.of(events_asm.lockCamera(_memory.cameraLock = false));
    });
  }

  @override
  void moveCamera(MoveCamera move) {
    _addToEvent(move, (i) {
      _memory.unknownAddressRegisters();

      var panels = _memory.panelsShown;
      if (panels != null && panels > 0) {
        throw StateError('moving camera while panels are shown '
            'creates artifacts.');
      }

      var speed = switch (move.speed) {
        CameraSpeed.one => 1,
        CameraSpeed.two => 2,
        CameraSpeed.four => 4,
        CameraSpeed.eight => 8,
      };

      return move.to.withPosition(
          memory: _memory,
          asm: ((x, y) => Asm([
                if (_memory.cameraLock == true) events_asm.lockCamera(false),
                events_asm.moveCamera(
                  x: x,
                  y: y,
                  speed: speed.i,
                ),
                if (_memory.cameraLock == true) events_asm.lockCamera(true),
              ])));
    });
  }

  @override
  void partyMove(RelativePartyMove move) {
    _addToEvent(move, (i) {
      var moves = IndividualMoves()
        ..moves[BySlot(1)] = move.movement
        ..speed = move.speed;
      return moves.toAsm(_memory,
          eventIndex: i, fieldRoutines: _fieldRoutines, followLead: true);
    });
  }

  @override
  void pause(Pause pause) {
    _checkNotFinished();

    var frames = pause.duration.toFrames();
    if (frames == 0) {
      return;
    }

    Asm generateEvent(i) {
      // if (_isProcessingInteraction) {
      //   return EventAsm.of(doInteractionUpdatesLoop(Word(frames)));
      // } else {
      return _waitFrames(frames);
    }

    switch (pause.duringDialog) {
      case true:
        _generateQueueInCurrentMode();
        _runOrContinueDialog(pause);
        _addToDialog(PauseCode(frames.toByte).toAsm());
        break;
      case false:
        _addToEvent(pause, generateEvent);
        break;
      case null:
        _addToEventOrDialog(pause, inDialog: () {
          _addToDialog(PauseCode(frames.toByte).toAsm());
        }, inEvent: generateEvent);
        break;
    }
  }

  @override
  void setContext(SetContext set) {
    _checkNotFinished();
    set(_memory);
  }

  @override
  void ifFlag(IfFlag ifFlag) {
    _checkNotFinished();

    if (ifFlag.isSet.isEmpty && ifFlag.isUnset.isEmpty) {
      return;
    }

    final flag = ifFlag.flag;

    // If a state already exists for this flag,
    // ensure it is updated with changes that apply from this parent.
    // It is also invalid for multiple states to have queued changes at once,
    // because we will not know in what order to apply the changes
    // to reachable states.
    // This event is currently the only one that would change states
    // and thus add changes, so it must be called here.
    // TODO(state graph): could this still allow out of order changes?
    _updateStateGraph();

    if (_currentCondition[flag] case var knownState?) {
      // one branch is dead code so only run the other, and skip useless
      // conditional check
      // also, no need to manage flags in scene graph because this flag is
      // already set.
      var events = knownState ? ifFlag.isSet : ifFlag.isUnset;
      for (var event in events) {
        event.visit(this);
      }

      return;
    }

    switch (_gameMode) {
      case InteractionMode startingMode:
        // attempt to process in dialog
        // this must be the only event in the dialog in that case,
        // because it is treated as a hard fork.
        // there can be no common events as there is no one scene now;
        // it is split into two after this.

        final ifSet = DialogAsm.empty();
        final currentDialogId = _currentDialogIdOrStart();
        final ifSetId = _currentDialogTree().add(ifSet);
        final ifSetOffset = ifSetId - currentDialogId as Byte;

        // memory may change while flag is set, so remember this to branch
        // off of for unset branch
        final parent = _memory;

        _addToDialog(extendableEventCheck(
            _eventFlags.toConstantValue(flag), ifSetOffset));
        _flagIsNotSet(flag);

        runEventIfNeeded(ifFlag.isUnset,
            nameSuffix: '${ifFlag.flag.name}_unset');

        for (var event in ifFlag.isUnset) {
          event.visit(this);
        }

        // Wrap up this branch
        finish(appendNewline: true, allowIncompleteDialogTrees: true);

        if (_inEvent) {
          // we may be in event now, but we have to go back to dialog generation
          // since we're playing out the "isSet" branch now
          _gameMode = startingMode;
        }

        _flagIsSet(flag, parent: parent);
        _resetCurrentDialog(id: ifSetId, asm: ifSet);

        runEventIfNeeded(ifFlag.isSet, nameSuffix: '${ifFlag.flag.name}_set');

        for (var event in ifFlag.isSet) {
          event.visit(this);
        }

        // Wrap up this branch
        finish(appendNewline: true, allowIncompleteDialogTrees: true);

        _flagUnknown(flag);

        // no more events can be added
        // because we would have to add them to both branches
        // which is not supported when starting from dialog loop
        // todo: finished is actually a per-branch state,
        //   but we're using 'empty' condition
        //   to proxy for the original state or 'root' state
        if (_currentCondition == Condition.empty()) {
          _setCurrentStateFinished();
        }

        // TODO(ifflag): should we update state graph here?

        break;
      case EventMode() || RunEventMode():
        _addToEventOrRunEvent(ifFlag, (i, asm) {
          // note that if we need to move further than beq.w
          // we will need to branch to subroutine
          // which then jsr/jmp to another
          // TODO: need to approximate code size so we can handle jump distance

          // use event counter in case flag is checked again
          var ifUnset = Label('.${flag.name}_unset$i');
          var ifSet = Label('.${flag.name}_set$i');

          // For readability, set continue scene label based on what branches
          // there are.
          var continueScene = ifFlag.isSet.isEmpty
              ? ifSet
              : (ifFlag.isUnset.isEmpty
                  ? ifUnset
                  : Label('.${flag.name}_cont$i'));

          // memory may change while flag is set, so remember this to branch
          // off of for unset branch
          var parent = _memory;

          // If we came here from dialog, terminate it.
          // Keep dialog though,
          // in case either branch goes right back into dialog.
          // TODO: this is probably always a no-op because running in an
          // event already terminates dialog
          _terminateDialog(keepDialog: true);
          // Update child states to reflect termination
          _updateStateGraph();

          // Save the current mode now to be restored later
          // when processing the alternate branch (if needed).
          final startingMode = _gameMode;

          // run isSet events unless there are none
          if (ifFlag.isSet.isEmpty) {
            asm.add(branchIfExtendableFlagSet(
                _eventFlags.toConstantValue(flag), continueScene));
          } else {
            if (ifFlag.isUnset.isEmpty) {
              asm.add(branchIfExtendableFlagNotSet(
                  _eventFlags.toConstantValue(flag), continueScene));
            } else {
              asm.add(branchIfExtendableFlagNotSet(
                  _eventFlags.toConstantValue(flag), ifUnset));
            }

            _flagIsSet(flag);

            // If the dialog loop is only needed,
            // this won't run an event immediately.
            // The purpose of this is to catch if we need a cutscene
            // while we know what events will be visited.
            runEventIfNeeded(ifFlag.isSet,
                nameSuffix: '_${ifFlag.flag.name}_set');

            for (var event in ifFlag.isSet) {
              event.visit(this);
            }

            if (startingMode is RunEventMode && _gameMode is! RunEventMode) {
              // We're done with the event code; finish it.
              // If we need an event at this point it will be a new event.
              finish(appendNewline: true, allowIncompleteDialogTrees: true);
            } else {
              // Keep dialog in case event after IfFlag is still dialog
              _terminateDialog(keepDialog: true);

              // skip past unset events
              if (ifFlag.isUnset.isNotEmpty && !_isFinished) {
                asm.add(bra.w(continueScene));
              }
            }

            _gameMode = startingMode;
          }

          // define routine for unset events if there are any
          if (ifFlag.isUnset.isNotEmpty) {
            _flagIsNotSet(flag, parent: parent);

            if (ifFlag.isSet.isNotEmpty) {
              asm.add(setLabel(ifUnset.name));
            }

            runEventIfNeeded(ifFlag.isUnset,
                nameSuffix: '_${ifFlag.flag.name}_unset');

            for (var event in ifFlag.isUnset) {
              event.visit(this);
            }

            if (startingMode is RunEventMode && _gameMode is! RunEventMode) {
              // We're done with the event code; finish it.
              // If we need an event at this point it will be a new event.
              finish(appendNewline: true, allowIncompleteDialogTrees: true);
            } else {
              // Keep dialog in case event after IfFlag is still dialog
              _terminateDialog(keepDialog: true);
            }
          }

          _updateStateGraphAndSibling(flag);
          _flagUnknown(flag);
          _gameMode = startingMode;

          // Check if both branches had events. If this is a run event,
          // then there is no need to define continue label (it is unused)
          // TODO: if finished was a per branch (+ per mode?) state,
          //  we could just check finished flag here
          // Semantically that is what this is doing.
          final bothBranchesAreFinished =
              _finishedStates.contains(_currentCondition.withSet(flag)) &&
                  _finishedStates.contains(_currentCondition.withNotSet(flag));
          if (bothBranchesAreFinished) {
            // ...then implicity this parent state is finished, too
            // TODO: this ignores newlines on finish() call
            _setCurrentStateFinished();
          } else {
            asm.add(setLabel(continueScene.name));
          }
        }, keepDialog: true);

        break;
    }
  }

  @override
  void setFlag(SetFlag setFlag) {
    _addToEventOrDialog(setFlag, inDialog: () {
      var flag = _eventFlags.toConstantValue(setFlag.flag);
      if (flag.value > Byte.max) {
        _addToDialog(dc.b([Byte(0xf2), Byte(0xd)]));
        _addToDialog(dc.w([flag.constant]));
      } else {
        _addToDialog(dc.b([Byte(0xf2), Byte(0xb)]));
        _addToDialog(dc.b([flag.constant]));
      }
    }, inEvent: (_) {
      var flag = _eventFlags.toConstantValue(setFlag.flag);
      return setEventFlag(flag);
    });
  }

  @override
  void ifValue(IfValue ifValue) {
    _addToEventOrRunEvent(ifValue, (i, asm) {
      // This event will apply changes to reachable states in the graph.
      // Because of this, we need to be sure any queued changes
      // are applied first,
      // since they must come before this event.
      _updateStateGraph();

      /*
      lets say parent has queued set position
      then in ifvalues we change that position
      then next ifflag the set position could get applied to children erroneously

      */

      // Evaluate expression at runtime if needed
      // at code where expression is true, fork memory state,
      var parent = _memory;
      var startingMode = _gameMode;

      // These branches are not added to state graph intentionally,
      // since we don't have ways to express these conditions in the graph
      // currently.
      var states = <Memory>[];

      void runBranch(List<Event> events) {
        states.add(_memory = parent.branch());

        runEventIfNeeded(events);

        for (var event in events) {
          event.visit(this);
        }

        if (startingMode is RunEventMode && _gameMode is! RunEventMode) {
          // We're done with the event code; finish it.
          // If we need an event at this point it will be a new event.
          // TODO(if value/run events): if we put value based states
          //  in condition graph, we would use finish()
          _finish(appendNewline: true);
        } else {
          _terminateDialog();
        }
      }

      var branches = BranchLabels('.${i}_', ifValue);

      // Run comparisons, given branch labels
      asm.add(ifValue.compare(memory: _memory, branches: branches));

      // Add remaining branch instructions for final comparison
      for (var (b, lbl) in branches.excludingFallThrough) {
        asm.add(b.condition.mnemonicUnsigned(lbl));
      }

      // Now run branches, fall through first since it by definition
      // doesn't rely on a branch instruction to "fall through"

      if (branches.labeledFallThrough case var lbl?) {
        // Fall through may be labeled, however,
        // in case there were multiple comparisons and
        // one short-circuited to this.
        asm.add(label(lbl));
      }
      runBranch(branches.fallThrough.events);

      for (var (b, lbl) in branches.excludingFallThrough) {
        if (b.isEmpty) continue;

        _gameMode = startingMode;

        // If the prior branch didn't already return, we need to jump
        // ahead to continue.
        // This is not needed with the fallback branch,
        // since there is no branch before it.
        // TODO(if value/run events): if we put value based states in condition
        //  graph, we could make this check less hacky
        var lastBranchFinished =
            _gameMode is RunEventMode && asm.lastOrNull == rts.single;
        if (!lastBranchFinished) {
          asm.add(bra(branches.labelContinue()));
        }

        asm.add(label(lbl));
        runBranch(b.events);
      }

      // If this the end (e.g. of a run event),
      // then the continue label may not be needed.
      if (branches.continued case var lbl?) {
        asm.add(label(lbl));
      } else {
        _setCurrentStateFinished();
      }

      _memory = parent;
      _gameMode = startingMode;

      // As for now we are not tracking these states in the graph,
      // consider their events as possibly applied
      // to the parent of these branches and
      // any reachable state from this point in the graph.
      // TODO(optimization): technically we could model these conditions
      // in the graph, also, and avoid unnecessary calculations later on.
      for (var state in states) {
        for (var change in state.changes) {
          for (var reachable in concat([
            [_memory],
            _reachableStates()
          ])) {
            change.mayApply(reachable);
          }
        }
      }

      return null;
    });
  }

  @override
  void yesOrNoChoice(YesOrNoChoice yesNo) {
    _checkNotFinished();
    _generateQueueInCurrentMode();
    _runOrContinueDialog(yesNo, interruptDialog: false);

    var startingMode = _gameMode;

    // Trigger the yes-no choice window.
    _addToDialog(dc.b(ControlCodes.yesNo));

    // Create the dialog for the "yes" condition
    // and determine its offset.
    var ifYes = DialogAsm.empty();
    var currentDialogId = _currentDialogIdOrStart();
    var ifYesId = _currentDialogTree().add(ifYes);
    var ifYesOffset = ifYesId - currentDialogId as Byte;

    // Tell the yes-no routine where to jump to
    // for the different branches.
    _addToDialog(dc.b([ifYesOffset, Byte.zero]));

    // Before we run branches, and possibly refer to or modify states,
    // ensure state graph is update to date.
    _updateStateGraph();

    // Save parent state to pop back to when done.
    var parent = _memory;

    // Run no branch in current dialog tree (offset 0).
    var noBranch = _memory = parent.branch();
    var eventAsmLength = _eventAsm.length;
    var yesLbl = Label('.${_eventCounter}_yes_choice');
    var continueLbl = Label('.${_eventCounter}_choice_continue');

    void runBranch(List<Event> branch) {
      for (var d in branch) {
        if (d is YesOrNoChoice) {
          throw UnimplementedError(
              'nested yes or no choices are not supported');
        }
        d.visit(this);
      }
    }

    if (_inEvent) {
      // Preempt event code for "no" branch
      _eventAsm.add(tst.b(Constant('Yes_No_Option').w));
      _eventAsm.add(beq.w(yesLbl));
      eventAsmLength = _eventAsm.length;

      runBranch(yesNo.ifNo);

      // Must terminate dialog first,
      // since it may trigger some event code is written lazily.
      _terminateDialog();

      // Prempt event code for "yes" branch
      if (_eventAsm.length == eventAsmLength) {
        // If there was no "no" event code,
        // then change logic to instead skip ahead if "no"
        _eventAsm.replace(eventAsmLength - 1, bne.w(continueLbl));
      } else {
        // Otherwise, skip ahead at end of "no" branch
        _eventAsm.add(bra.w(continueLbl));
      }
    } else {
      runBranch(yesNo.ifNo);
      _terminateDialog();
    }

    // Note inclusion of setting the last dialog event, also.
    // This is the same last event as the no branch had,
    // and we must restore that for this branch.
    // Both branches act as if the other never happened,
    // since of course only one ever happens in-game.
    _resetCurrentDialog(id: ifYesId, asm: ifYes, lastEventForDialog: yesNo);
    var yesBranch = _memory = parent.branch();

    // We're back in dialog, for the next branch.
    _gameMode = startingMode;

    if (_inEvent) {
      _eventAsm.add(setLabel(yesLbl.name));
      runBranch(yesNo.ifYes);
      _terminateDialog();
      _eventAsm.add(setLabel(continueLbl.name));
      // Add continue label for earlier jump
    } else {
      runBranch(yesNo.ifYes);
      // If we're in dialog loop, we cannot do anything else after this.
      // Terminating both branches means we're done.
      finish();
    }

    // Pop current memory state back to parent.
    _memory = parent;

    // As for now we are not tracking these states in the graph,
    // consider their events as possibly applied
    // to the parent of these branches and
    // any reachable state from this point in the graph.
    // TODO(optimization): technically we could model these conditions
    // in the graph, also, and avoid unnecessary calculations later on.
    for (var state in [noBranch, yesBranch]) {
      for (var change in state.changes) {
        for (var reachable in concat([
          [_memory],
          _reachableStates()
        ])) {
          change.mayApply(reachable);
        }
      }
    }
  }

  @override
  void fadeInField(FadeInField fadeIn) {
    _checkNotFinished();

    // Sometimes we might not know its not shown (e.g. at the start of a scene)
    // if (_memory.isFieldShown == true) return;

    _addToEvent(fadeIn, (eventIndex) {
      var wasFieldShown = _memory.isFieldShown;
      // TODO(optimization): if reload palette only needed,
      // might be able to do:
      // lea	(Palette_Table_Buffer_2).w, a0
      // lea	(Palette_Table_Buffer).w, a1
      // move.w	#$3F, d7
      // trap	#1
      // Though this assumes buffer 2 is what we want.
      // Could we use LoadMapPalette and MapPaletteAddr?
      var reloadPalette =
          _memory.isMapInCram != true || _memory.isDialogInCram != true;
      var needsRefresh = _memory.isMapInVram != true;
      var panelsShown = _memory.panelsShown;

      _memory.isDisplayEnabled = true;
      _memory.isFieldShown = true;
      _memory.isMapInVram = true;
      _memory.isMapInCram = true;
      _memory.isDialogInCram = true;
      _memory.panelsShown = 0;
      _memory.unknownAddressRegisters();

      return Asm([
        if (wasFieldShown == false && (panelsShown ?? 0) > 0) ...[
          // todo: as an optimization, we could potentially replace dialog routine
          // with 5, to do the same thing in this condition
          // however technically we'd only definitely be able to do this if the
          // last event was dialog, otherwise it may reorder scene events in
          // perceivable ways
          // (for example, if there was dialog, pause, then fade)
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          jsr(Label('Panel_DestroyAll').l)
        ],
        // I guess we assume map was the same as before
        // so no need to reload secondary objects
        // LoadMap events take care of that
        if (needsRefresh)
          refreshMap(refreshObjects: false)
        else if (reloadPalette) ...[
          movea.l('Map_Palettes_Addr'.w, a0),
          jsr('LoadMapPalette'.l)
        ],
        if (fadeIn.instantly)
          jsr(Label('VDP_EnableDisplay').l)
        else
          jsr(Label('Pal_FadeIn').l)
      ]);
    });
  }

  @override
  void fadeOut(FadeOut fadeOut) {
    _checkNotFinished();

    _addToEvent(fadeOut, (eventIndex) {
      _memory.isFieldShown = false;
      _memory.isMapInCram = false;
      _memory.isDialogInCram = false;
      _memory.isDisplayEnabled = false;

      // map vram untouched.
      // if we fade back in, though,
      // we'd need to either clear vram (via initvramandcram)
      // or set cram via refreshmap

      // notes about old logic:
      // sometimes we fade out just to change a map
      // so this logic is really like, "fade out for cutscene"
      // that is, fade out for panels
      // i guess it might work though because
      // when fading back in, refreshmap preps cram and such
      // perhaps it is an optimization to
      // not be based on just whether the field was shown
      // but based on later events
      // e.g. if after fading out, we want to show a panel,
      // the swap it to initvramandcram & fadein

      switch (fadeOut.speed) {
        case VariableSpeed s:
          _eventAsm.add(Asm([
            move.b(s.value.i, 0xffffed52.w),
            jsr(Label('Pal_VariableFadeOut').l),
          ]));
        case Normal():
          _eventAsm.add(events_asm.fadeOut(initVramAndCram: false));
        case Instantly():
          _eventAsm.add(Asm([
            lea((Palette_Table_Buffer).w, a0),
            move.w(0x1F.i, d7),
            trap(0.i),
            move.b(1.i, ('CRAM_Update_Flag').w),
            jsr((VInt_Prepare).l),
            jsr(('ClearSpriteTableBuf').l)
          ]));
      }

      if ((_memory.panelsShown ?? 0) > 0) {
        _eventAsm.add(jsr(Label('Panel_DestroyAll').l));
        _memory.panelsShown = 0;
      }

      return null;
    });
  }

  @override
  void increaseTone(IncreaseTone increase) {
    _checkNotFinished();

    // It takes 28 frames max to go fully white from any palette.
    var frames = (increase.percent * 28).ceil();

    if (frames > 0) {
      _addToEvent(increase, (eventIndex) {
        var extraFrames = frames - 1;
        return Asm([
          if (extraFrames <= 128)
            moveq(extraFrames.toByte.i, d7)
          else
            move.w(extraFrames.i, d7),
          label(Label('.increase_tone$eventIndex')),
          jsr(Pal_IncreaseTone.l),
          _waitFrames(1),
          dbf(d7, Label('.increase_tone$eventIndex')),
        ]);
      });
    }

    pause(Pause(increase.wait));
  }

  @override
  void flashScreen(FlashScreen flash) {
    _checkNotFinished();

    _addToEvent(flash, (i) {
      _eventAsm.add(Asm([
        // Copy current palette to buffer 2
        lea(Palette_Table_Buffer.w, a0),
        lea(Palette_Table_Buffer_2.w, a1),
        move.w(0x3F.i, d7),
        trap(1.i)
      ]));

      var sequence = 0;

      void doFlash(
        double percent,
        int flashedFrames,
        int calmFrames,
      ) {
        if (flash.sound case var s?) {
          playSound(PlaySound(s));
        }

        _eventAsm.add(Asm([
          lea(Palette_Table_Buffer.w, a0),
          // Rewrite the palette white
          moveq(0x1F.i, d7),
          label(Label('.flash${i}_$sequence')),
          // Two words at a time
          move.l(0x0EEE0EEE.i, a0.postIncrement()),
          dbf(d7, Label('.flash${i}_$sequence')),
        ]));

        var additionalRestoreFrames = max(0, (percent * 28 - 1).ceil());
        var loop = Label('.restore_palette${i}_$sequence');

        _eventAsm.add(Asm([
          _waitFrames(flashedFrames),
          move.w(additionalRestoreFrames.i, d7),
          label(loop),
          jsr(Pal_DecreaseToneToPal2.l),
          _waitFrames(1),
          dbf(d7, loop),
          _waitFrames(calmFrames)
        ]));

        sequence++;
      }

      for (var partial in flash.partialFlashes) {
        doFlash(partial, 1, 0);
      }

      // TODO(flash): maybe allow 0 frames?
      doFlash(1, min(1, flash.flashed.toFrames()), flash.calm.toFrames());
    });
  }

  @override
  void prepareMap(PrepareMap prepareMap) {
    _checkNotFinished();

    _addToEvent(prepareMap,
        (eventIndex) => refreshMap(refreshObjects: prepareMap.resetObjects));

    _memory.isMapInCram = true;
    _memory.isMapInVram = true;
    _memory.isDialogInCram = true;
  }

  @override
  void loadMap(LoadMap loadMap) {
    _checkNotFinished();

    var currentMap = _memory.currentMap;
    var newMap = loadMap.map;
    var startPos = loadMap.startingPosition;
    var arrangement = loadMap.arrangement;
    var facing = loadMap.facing;

    var currentId = currentMap?.map((m) => mapIdToAsm(m.id));
    var newId = mapIdToAsm(newMap.id);
    var x = startPos.x ~/ 8;
    var y = startPos.y ~/ 8;
    var alignByte = arrangement.toAsm;

    _addToEvent(loadMap, (eventIndex) {
      switch (loadMap.updateParty) {
        case ChangePartyOrder changeParty:
          if (changeParty.saveCurrentParty) {
            _eventAsm.add(saveCurrentPartySlots());
          }

          var newParty = changeParty.party;
          var partyIds = newParty.map((c) {
            if (c == null) {
              throw UnimplementedError(
                  'party update on load map cannot be sparse');
            }
            return c.charId;
          }).toList(growable: false);

          _eventAsm.add(loadPartySlots(
              partyIds, Current_Party_Slots.w, Current_Party_Slot_5.w));

          _memory.slots.setPartyOrder(newParty,
              saveCurrent: changeParty.saveCurrentParty);
          break;
        case RestoreSavedPartyOrder():
          _memory.slots.restorePreviousParty();
          _eventAsm.add(restoreSavedPartySlots());
          break;
        case null:
          break;
      }

      if (loadMap.showField) {
        if (_memory.isDisplayEnabled == false) {
          if (_memory.isMapInCram != false) {
            _eventAsm.add(events_asm.fadeOut());
            _memory.isMapInCram = false;
            _memory.isDialogInCram = false;
          }
          _eventAsm.add(jsr(Label('Pal_FadeIn').l));
          _eventAsm.add(jsr(Label('VInt_Prepare').l));
          _memory.isDisplayEnabled = true;
        }
      }

      return events_asm.changeMap(
          to: newId.i,
          from: currentId?.i,
          startX: Word(x).i,
          startY: Word(y).i,
          facingDir: facing.constant.i,
          partyArrangement: alignByte.i);
    });

    _terminateDialog();

    _memory.currentMap = newMap;
    // todo: wondering if these should automatically be set by virtue of
    //   setting current map

    _dialogTree = _dialogTrees.forMap(newMap.id);
    _memory.loadedDialogTree = _dialogTree;
    _memory.hasSavedDialogPosition = false;
    _memory.isMapInCram = true;
    _memory.isDialogInCram = true;
    _memory.isMapInVram = true;

    // Due to new map, clear known positions.
    //TODO: _memory.clearAllFacing();
    _memory.positions.clear();
    _memory.slots.reloadObjects();

    for (var i = 1; i <= 5; i++) {
      // If party slots are known, reposition party in memory using
      // the new position and arrangement.
      var obj = switch (_memory.slots[i]) {
        Character c => c,
        // TODO(loadmap): take into account num characters
        null when i == 1 => BySlot(i),
        null => null,
      };
      if (obj == null) continue;
      _memory.positions[obj] = arrangement.offsets[i - 1] + startPos;
    }
  }

  @override
  void showPanel(ShowPanel showPanel) {
    var index = showPanel.panel.panelIndex;

    if (showPanel.showDialogBox) {
      // This is not using add to dialog or event,
      // because it HAS to run in dialog in this case.
      // It is like a Dialog event in that way.
      _generateQueueInCurrentMode();
      _runOrContinueDialog(showPanel);
      _memory.addPanel();

      var p = showPanel.portrait;
      _addToDialog(Asm([
        if (_memory.dialogPortrait != p) portrait(toPortraitCode(p)),
        dc.b([Byte(0xf2), Byte.zero]),
        dc.w([Word(index)]),
      ]));

      _memory.dialogPortrait = p;
    } else {
      _addToEvent(showPanel, (_) {
        _memory.addPanel();

        if (_memory.isDisplayEnabled == false) {
          if (_memory.isMapInVram == true) {
            _initVramAndCram();
          }
          _eventAsm.add(jsr(Label('Pal_FadeIn').l));
          _memory.isDisplayEnabled = true;
        }

        return Asm([
          move.w(index.toWord.i, d0),
          jsr('Panel_Create'.toLabel.l),
          dmaPlanesVInt(),
        ]);
      });
    }
  }

  @override
  void hideAllPanels(HideAllPanels hidePanels) {
    _checkNotFinished();

    // FIXME: state check is broken due to possibly queued generations
    var panelsShown = _memory.panelsShown;
    if (panelsShown == 0) return;

    if (panelsShown == 1) {
      hideTopPanels(HideTopPanels(1));
      return;
    }

    if (hidePanels.instantly) {
      _addToEvent(
          hidePanels,
          (i) => Asm([
                if (panelsShown == null) ...[
                  moveq(0.i, d0),
                  move.b(Constant('Panel_Num').w, d0),
                  subq.b(1.i, d0),
                ] else
                  unsignedMoveL((panelsShown - 1).i, d0),
                label(Label('.${i}_nextPanel')),
                jsr(Label('Panel_Destroy').l),
                dbf(d0, Label('.${i}_nextPanel')),
                jsr(Label('DMAPlanes_VInt').l),
              ]));

      _memory.panelsShown = 0;
    } else {
      _addToEventOrDialog(hidePanels, inDialog: () {
        _addToDialog(dc.b([Byte(0xf2), Byte.two]));
      }, inEvent: (_) {
        return jsr(Label('Panel_DestroyAll').l);
      }, after: () {
        _memory.panelsShown = 0;
      });
    }
  }

  @override
  void hideTopPanels(HideTopPanels hidePanels) {
    _checkNotFinished();

    var panels = hidePanels.panelsToHide;
    // FIXME: state check is broken due to possibly queued generations
    var panelsShown = _memory.panelsShown;

    if (panelsShown == 0) return;

    if (panelsShown != null) {
      panels = min(panels, panelsShown);
    }

    // todo(hide top panels): support instantly
    if (hidePanels.instantly) {
      throw UnimplementedError('HideTopPanels.instantly');
    }

    _addToEventOrDialog(hidePanels, inDialog: () {
      _memory.removePanels(panels);

      _addToDialog(Asm([
        for (var i = 0; i < panels; i++) dc.b([Byte(0xf2), Byte.one]),
        // todo: this is used often but not always, how to know when?
        // it might be if the field is not faded out, but not always
        if (_memory.isFieldShown == true) dc.b([Byte(0xf2), Byte(6)]),
      ]));
    }, inEvent: (eventIndex) {
      _memory.removePanels(panels);

      var skip = '.skipHidePanel$eventIndex';
      return Asm([
        for (var i = 0; i < panels; i++) ...[
          if (panelsShown == null)
            Asm([
              tst.b(Constant('Panel_Num').w),
              // if too many panels .s might be broken :X
              beq.s(Label(skip)),
            ]),
          jsr('Panel_Destroy'.toLabel.l),
          // in Panel_DestroyAll it is done after each,
          // so assuming this is needed here
          dmaPlanesVInt(),
        ],
        if (panelsShown == null) setLabel(skip),
      ]);
    });
  }

  @override
  void playSound(PlaySound playSound) {
    _addToEventOrDialog(playSound, inDialog: () {
      _addToDialog(dc.b([Byte(0xf2), Byte(3)]));
      _addToDialog(dc.b([playSound.sound.sfxId]));
    }, inEvent: (_) {
      return Asm([
        // Necessary to ensure previous sound change occurs
        // TODO: as last event in current dialog is relevant to current dialog
        // depending on how dialog generation is managed this may miss cases
        if (_lastEventInCurrentDialog is PlaySound ||
            _lastEventInCurrentDialog is PlayMusic)
          _waitFrames(1),
        move.b(playSound.sound.sfxId.i, Constant('Sound_Index').l),
      ]);
    });
  }

  @override
  void playMusic(PlayMusic playMusic) {
    /*
    ; $F2 = Determines actions during dialogues. The byte after this has the following values:
    3 = Loads sound; the byte after this is the Sound index
    4 = Loads sound; the byte after this is the Sound index
    8 = Pauses music
    9 = Resumes music
     */
    var musicId = playMusic.music.musicId;

    _addToEventOrDialog(playMusic, inDialog: () {
      _addToDialog(dc.b([Byte(0xf2), Byte(3)]));
      _addToDialog(dc.b([musicId]));
      // TODO: note in this case, saved sound index is not set
    }, inEvent: (_) {
      return Asm([
        // Necessary to ensure previous sound change occurs
        // TODO: as last event in current dialog is relevant to current dialog
        // depending on how dialog generation is managed this may miss cases
        // TODO(frame perfect): may need to run tiles/map updates
        if (_lastEventInCurrentDialog is PlaySound ||
            _lastEventInCurrentDialog is PlayMusic)
          _waitFrames(1),
        move.b(musicId.i, Constant('Sound_Index').l),
        move.b(musicId.i, Constant('Saved_Sound_Index').w)
      ]);
    });
  }

  @override
  void stopMusic(StopMusic stopMusic) {
    /*
    ; $F2 = Determines actions during dialogues. The byte after this has the following values:
    3 = Loads sound; the byte after this is the Sound index
    4 = Loads sound; the byte after this is the Sound index
    8 = Pauses music
  move.b	#1, $00FF5007
  jsr	(VInt_Prepare).l
    9 = Resumes music
  move.b	#$80, ($FF5007).l
  jsr	(VInt_Prepare).l
     */
    _addToEvent(
        stopMusic,
        (_) => Asm([
              move.b(const Constant('Sound_StopMusic').i,
                  Constant('Sound_Index').l),
              clr.b(Constant('Saved_Sound_Index').w)
            ]));
  }

  @override
  void addMoney(AddMoney addMoney) {
    _checkNotFinished();

    // addi.l	#300, (Current_Money).w
    // 	addi.l	#100, (Current_Money).w

    if (addMoney.meseta == 0) {
      return;
    }

    var diff = addMoney.meseta;

    _addToEvent(
        addMoney,
        (_) => diff > 0
            ? addi.l(diff.i, const Constant('Current_Money').w)
            : subi.l(diff.i, const Constant('Current_Money').w));
  }

  @override
  void resetObjectRoutine(ResetObjectRoutine resetRoutine) {
    _checkNotFinished();

    var obj = resetRoutine.object.resolve(_memory);

    if (obj is! MapObject) {
      throw ArgumentError.value(
          obj,
          'resetRoutine.object',
          'can only change routines for MapObjects '
              'but type=${obj.runtimeType}');
    }

    // TODO(object routine): only reset if not already reset

    var routine = obj.routine(_fieldRoutines);

    changeObjectRoutine(
        ChangeObjectRoutine(resetRoutine.object, routine.factory.routineModel));
  }

  @override
  void changeObjectRoutine(ChangeObjectRoutine change) {
    _addToEvent(change, (eventIndex) {
      var obj = change.object.resolve(_memory);

      if (obj is! MapObject) {
        throw ArgumentError.value(
            obj,
            'change.object',
            'can only change routines for MapObjects '
                'but type=${obj.runtimeType}');
      }

      var routine = _fieldRoutines.bySpecModel(change.routine);

      if (routine == null) {
        // TODO(object routines): technically we could get by with just index
        // and use the jump table
        throw ArgumentError.value(
            change.routine,
            'change.routine',
            'routine not found in field routines. '
                'try adding field routine metadata to generator.');
      }

      _memory.setRoutine(obj, change.routine);

      return Asm([
        if (_memory.inAddress(a4)?.obj != obj) obj.toA4(_memory),
        move.w(routine.index.i, a4.indirect),
        jsr(routine.label.l)
      ]);
    });
  }

  @override
  // TODO: we cannot support add here any more.
  // this is only swap order. add has to accompany a load map
  void changeParty(ChangePartyOrder changeParty) {
    _checkNotFinished();

    _addToEvent(changeParty, (_) {
      if (changeParty.saveCurrentParty) {
        _eventAsm.add(saveCurrentPartySlots());
      }

      var newParty = changeParty.party;

      if (changeParty.maintainOrder) {
        _eventAsm.add(Asm([
          loadPartySlots(
              newParty
                  .map((c) => c?.charId ?? Byte.max)
                  .toList(growable: false),
              d0,
              d1),
          jsr('Event_OrderParty'.l),
        ]));

        _memory.putInAddress(a0, null);
        _memory.putInAddress(a3, null);
        _memory.putInAddress(a4, null);
      } else {
        bool partial = false;
        for (var i = 0; i < newParty.length; i++) {
          var member = newParty[i];
          if (member == null) {
            partial = true;
            continue;
          }
          if (!partial && i == 4) {
            // Last party member can be skipped.
            // Due to swapping, the last member
            // must already be in the right place.
            // TODO: if we know actual party length,
            //  we can make this a little smarter.
            continue;
          }
          _eventAsm.add(Asm([
            moveq(member.charId.i, d0),
            moveq(i.i, d1),
            jsr(Label('Event_SwapCharacter').l),
          ]));
        }
      }

      _memory.slots.setPartyOrder(newParty,
          saveCurrent: changeParty.saveCurrentParty,
          maintainOrder: changeParty.maintainOrder);

      return null;
    });
  }

  @override
  void restoreSavedParty(RestoreSavedPartyOrder restoreParty) {
    _checkNotFinished();
    _addToEvent(restoreParty, (_) {
      _memory.slots.restorePreviousParty((i, prior, current) {
        if (_memory.slots.partyOrderMaintained) {
          if (i == 5) return;
        } else if (prior == current) {
          return;
        }
        _eventAsm.add(Asm([
          move.b((Constant('Saved_Char_ID_Mem_$i').w), d0),
          moveq((i - 1).i, d1),
          jsr(Label('Event_SwapCharacter').l),
        ]));
      });
      return null;
    });
  }

  @override
  void onExitRunBattle(OnExitRunBattle onExit) {
    _checkNotFinished();

    // TODO(onexit): this event has to be at the end of a scene to work,
    //  we could be smarter than that.
    _addToEvent(onExit, (_) {
      // See RunDialogue2, which is normally used before boss battles.
      _eventAsm.add(Asm([
        moveq(0.i, d0),
        move.b(d0, (Panel_Num).w),
      ]));

      if (onExit.postBattleSound case Sound s) {
        _eventAsm.add(move.b(s.soundId.i, Constant('Saved_Sound_Index').w));
      }

      var controlFadeInBit = onExit.postBattleFadeInMap ? bclr : bset;
      _eventAsm.add(controlFadeInBit(7.i, Map_Load_Flags.w));

      var controlObjectsBit = onExit.postBattleReloadObjects ? bclr : bset;
      _eventAsm.add(controlObjectsBit(3.i, Map_Load_Flags.w));

      _eventAsm.add(Asm([
        move.b(onExit.battleIndex.toByte.i, Constant('Event_Battle_Index').w),
        bset(3.i, Constant('Routine_Exit_Flags').w),
      ]));

      _memory.onExitRunBattle = true;

      return null;
    });
  }

  @override
  void onNextInteraction(OnNextInteraction onNext) {
    _checkNotFinished();

    _addToEvent(onNext, (_) {
      // Generate the new interaction,
      // which may introduce its own subroutine its own event or cutscene.
      var tree = _currentDialogTree();
      var nextDialogId = tree.nextDialogIdOrThrow();
      var map = _memory.currentMap;
      var nextEvent = EventAsm.empty();

      if (map == null) {
        throw StateError('current map not set; cannot generate '
            'interaction dialog for onNextInteraction. '
            'event=$onNext');
      }

      SceneAsmGenerator.forInteraction(map, SceneId('${id.id}_next'),
          _dialogTrees, nextEvent, _eventRoutines,
          eventFlags: _eventFlags, withObject: const InteractionObject())
        ..runEventIfNeeded(onNext.onInteract.events)
        ..scene(onNext.onInteract)
        ..finish(appendNewline: true, allowIncompleteDialogTrees: true);

      if (tree.length <= nextDialogId.value) {
        throw StateError("no interaction dialog generated");
      }

      if (nextEvent.trim() case var event when event.isNotEmpty) {
        _postAsm.add(event);
      }

      // Update map elements' dialog ID's
      for (var objId in onNext.withObjects) {
        var obj = map.object(objId);
        if (obj == null) {
          throw StateError('cannot set dialog for non-existent map element. '
              'object_id=$objId current_map=${map.id}');
        }

        _eventAsm.add(Asm([
          obj.toA4(_memory),
          move.b(nextDialogId.i, dialogue_id(a4)),
        ]));
      }
    });
  }

  void finish(
      {bool appendNewline = false, bool allowIncompleteDialogTrees = false}) {
    // todo: also apply all changes for current mem across graph
    // not sure if still need to do this
    // seems useless because memory won't ever be consulted again after
    // finishing

    if (!_isFinished) {
      _finish(appendNewline: appendNewline);
      if (!allowIncompleteDialogTrees) _dialogTree?.validate();
      _setCurrentStateFinished();
    }
  }

  void _finish({bool appendNewline = false}) {
    // If we're in dialog loop,
    // we don't want to generate
    // because that would cause an unwanted interrupt

    var needToShowField =
        _memory.onExitRunBattle == false && _memory.isFieldShown == false;
    var needToHidePanels =
        _memory.onExitRunBattle == false && (_memory.panelsShown ?? 0) > 0;

    switch (_gameMode) {
      case EventMode(priorMode: InteractionMode(), type: EventType.cutscene):
        if (needToShowField) {
          if (_replaceDialogRoutine != null) {
            // dialog 5 will fade out the whole screen
            // before map reload happens
            // (destroy window -> fade out -> destroy panels)
            _replaceDialogRoutine!(5);
          } else {
            // todo: but what if there isn't dialog?
            //  do we need to do palfadout?
            // doesn't usually happen
            // but might i think depending on conditional logic
            throw UnimplementedError('need to reload during cutscene '
                'but no dialog');
          }
        }

        _terminateDialog();

        if (_memory.cameraLock == true) {
          unlockCamera(UnlockCamera());
        }

        // clears z bit so we don't reload the map from cutscene
        _eventAsm.add(comment('Finish'));
        _eventAsm.add(moveq(needToShowField ? 0.i : 1.i, d0));
        _eventAsm.add(rts);

        break;

      case EventMode(priorMode: InteractionMode(), type: EventType.event):
        _terminateDialog();

        if (needToShowField) {
          fadeInField(FadeInField());
        } else if (needToHidePanels) {
          hideAllPanels(HideAllPanels());
        }

        if (_memory.cameraLock == true) {
          unlockCamera(UnlockCamera());
        }

        _eventAsm.add(comment('Finish'));
        _eventAsm.add(returnFromInteractionEvent());

        break;

      case EventMode(priorMode: RunEventMode? prior, type: var type):
        _terminateDialog();

        if (needToShowField) {
          fadeInField(FadeInField());
        } else if (needToHidePanels) {
          // unfortunately this will produce unwanted interrupt
          hideAllPanels(HideAllPanels());
        }

        if (_memory.cameraLock == true) {
          unlockCamera(UnlockCamera());
        }

        if (type == EventType.cutscene) {
          // clears z bit so we don't reload the map from cutscene
          _eventAsm.add(comment('Finish'));
          _eventAsm.add(moveq(needToShowField ? 0.i : 1.i, d0));
        }

        if (prior != null) {
          _eventAsm.add(rts);
        }

        break;

      case InteractionMode():
        // todo: not sure about this. might want to do this after terminating
        // dialog only?
        if (needToHidePanels) {
          // unfortunately this will produce unwanted interrupt
          hideAllPanels(HideAllPanels());
        }

        _terminateDialog();

        break;
      case RunEventMode():
        _context.runEventAsm.add(bra.w(RunEvent_NoEvent));
        break;
    }

    if (appendNewline) {
      switch (_gameMode) {
        case EventMode():
          if (_eventAsm.isNotEmpty && _eventAsm.last.isNotEmpty) {
            _eventAsm.addNewline();
          }
          break;
        case RunEventMode():
          if (_context.runEventAsm.isNotEmpty &&
              _context.runEventAsm.last.isNotEmpty) {
            _context.runEventAsm.addNewline();
          }
          break;
        default:
          // empty
          break;
      }
    }

    for (var subroutine in _postAsm) {
      _eventAsm.add(subroutine);

      if (appendNewline) {
        _eventAsm.addNewline();
      }
    }
  }

  void _checkNotFinished() {
    if (_isFinished) {
      throw StateError('scene is finished; cannot add more to scene');
    }
  }

  Asm _waitFrames(int frames) {
    checkArgument(frames >= 0, message: 'frames must be non-negative');
    if (frames == 0) return Asm.empty();

    if (_memory.isFieldShown == false || (_memory.panelsShown ?? 0) > 0) {
      return frames == 1 ? vIntPrepare() : vIntPrepareLoop(Word(frames - 1));
    } else {
      return doMapUpdateLoop(Word(frames - 1));
    }
  }

  _flagIsSet(EventFlag flag, {Memory? parent}) {
    parent = parent ?? _memory;
    _currentCondition = _currentCondition.withSet(flag);
    var state = _stateGraph[_currentCondition];
    if (state == null) {
      _stateGraph[_currentCondition] = state = parent.branch();
    }
    _memory = state;
  }

  _flagIsNotSet(EventFlag flag, {Memory? parent}) {
    parent = parent ?? _memory;
    _currentCondition = _currentCondition.withNotSet(flag);
    var state = _stateGraph[_currentCondition];
    if (state == null) {
      _stateGraph[_currentCondition] = state = parent.branch();
    }
    _memory = state;
  }

  _flagUnknown(EventFlag flag) {
    _currentCondition = _currentCondition.without(flag);
    var state = _stateGraph[_currentCondition];
    if (state == null) {
      // nothing can be known in this case? or is this error case?
      _stateGraph[_currentCondition] = state = Memory();
    }
    _memory = state;
  }

  /// This takes changes applied to the current state of this branch
  /// (defined by its [branchFlag])
  /// and it's immediate sibling,
  /// and updates the graph based on the following logic:
  ///
  /// * All branches which contain *at least* the current condition are updated.
  /// If there are any event flag checks following this,
  /// we know the state changes here must apply, since they are most recent.
  /// * All branches which contain *at least* the sibling condition are updated
  /// in the same fashion with that branch's changes.
  /// * In both cases, branches where we know the [branchFlag] is different, do
  /// not apply changes, because we know these must not apply.
  /// * In all of the remaining branches, we won't know if these flags are also
  /// set or not the next they are evaluated, so we have to tell these states
  /// that these changes may have applied.
  void _updateStateGraphAndSibling(EventFlag branchFlag) {
    var currentBranch = _currentCondition[branchFlag];
    if (currentBranch == null) {
      throw ArgumentError.value(
          branchFlag,
          'branchFlag',
          'is not in current branch conditions, '
              'so it must not be the current branch flag');
    }

    var changes = _memory.changes;
    // there may be no sibling if that branch had no events
    var sibling =
        _stateGraph[_currentCondition.withFlag(branchFlag, !currentBranch)];
    var siblingChanges = sibling == null
        ? List<StateChange>.empty(growable: true)
        : sibling.changes;

    graph:
    for (var entry in _stateGraph.entries) {
      var condition = entry.key;
      var state = entry.value;
      // a peer is a state where all other current conditions are also set
      // *except* for the branch flag. in all of these branches we know the
      // changes don't apply.
      var mayBePeer = false;

      for (var flagEntry in _currentCondition.entries) {
        // should include parent states (must be at least as specific)
        var currentFlag = flagEntry.key;
        var stateValue = condition[currentFlag];
        if (stateValue != flagEntry.value) {
          if (currentFlag == branchFlag && stateValue != null) {
            mayBePeer = true;
            // keep evaluating other conditions, because it may not be a peer.
            continue;
          }

          // if flag other than branch flag is different, it must not be a peer
          // and is therefore an alternative branch to be considered.
          for (var change in changes) {
            change.mayApply(state);
          }

          // Sibling changes may also apply!
          for (var change in siblingChanges) {
            change.mayApply(state);
          }
          continue graph;
        }
      }

      if (mayBePeer) {
        if (state != sibling) {
          // Superset of sibling, so we know sibling changes apply
          for (var change in siblingChanges) {
            change.apply(state);
          }
        }
        continue;
      }

      // this state definitely has all of the current conditions set, so
      // changes will apply.
      for (var change in changes) {
        change.apply(state);
      }
    }

    _memory.clearChanges();
    sibling?.clearChanges();
  }

  /// Applies the same logic as [_updateStateGraphAndSibling] but for
  /// only the [_currentCondition]'s changes.
  ///
  /// This is appropriate if this state is the only state with queued changes.
  /// When a sibling state has changes queued (such as during [ifFlag]),
  /// [_updateStateGraphAndSibling] must be used instead.
  /// Otherwise, changes may be applied out of order in the graph.
  void _updateStateGraph() {
    for (var (reachability, state) in _allStates()) {
      switch (reachability) {
        case _Reachability.child:
          for (var change in _memory.changes) {
            change.apply(state);
          }
          break;
        case _Reachability.reachable:
          for (var change in _memory.changes) {
            change.mayApply(state);
          }
          break;
        case _Reachability.unreachable:
          break;
      }
    }
    _memory.clearChanges();
  }

  Iterable<(_Reachability, Memory)> _allStates() sync* {
    for (var MapEntry(key: condition, value: state) in _stateGraph.entries) {
      if (_currentCondition.conflictsWith(condition)) {
        yield (_Reachability.unreachable, state);
      } else if (_currentCondition.isSatisfiedBy(condition)) {
        yield (_Reachability.child, state);
      } else {
        yield (_Reachability.reachable, state);
      }
    }
  }

  /// Returns all states that are "reachable" from the current conditions.
  ///
  /// This means that, while the current condition is true, it is also possible
  /// that any of the returned states' conditions may be true.
  Iterable<Memory> _reachableStates() sync* {
    for (var MapEntry(key: condition, value: state) in _stateGraph.entries) {
      if (!_currentCondition.conflictsWith(condition)) {
        yield state;
      }
    }
  }

  /// Ensures the dialog mode is entered and tracks necessary state.
  ///
  /// Use before running any dialog event.
  ///
  /// Assumes consecutive events in dialog should wait for player input,
  /// called an "interrupt." If this is not the case, set
  /// [interruptDialog] to false.
  void _runOrContinueDialog(Event event, {bool interruptDialog = true}) {
    // TODO: call generatequeueincurrentmode here instead of before calling this method

    _expectFacePlayerFirstIfInteraction();

    switch (_gameMode) {
      case InteractionMode() || EventMode(isInDialogLoop: true):
        if (_lastEventInCurrentDialog is Dialog && interruptDialog) {
          // Add cursor for previous dialog
          // This is delayed because this interrupt may be a termination
          _addToDialog(interrupt());
        }
        break;
      case EventMode m:
        _runDialog(m);
        break;
      case RunEventMode():
        var m = runEvent();
        _runDialog(m);
        break;
    }

    _lastEventInCurrentDialog = event;
  }

  void _expectFacePlayerFirstIfInteraction() {
    if (!_inEvent &&
        _isInteractingWithObject &&
        _lastEventInCurrentDialog == null) {
      // Not starting with face player, so signal not to.
      _addToDialog(dc.b(Bytes.of(0xf3)));
    }
  }

  void _runDialog(EventMode mode) {
    _eventAsm.add(
        Asm([comment('${_context.getAndIncrementEventCount()}: $Dialog')]));

    // todo if null, have to check somehow?
    // todo: not sure if this is right
    if (_memory.isFieldShown == false) {
      if (_memory.isDisplayEnabled == false) {
        // if cram cleared but vram not,
        // fading in will cause artifacts
        // otherwise, fade in may fade in map,
        // but consider this intentional
        if ((_memory.isMapInVram == true && _memory.isMapInCram == false) ||
            _memory.isDialogInCram == false) {
          _initVramAndCram();
        }
        _eventAsm.add(jsr(Label('Pal_FadeIn').l));
        _memory.isDisplayEnabled = true;
      } else if (_memory.isDialogInCram == false) {
        _eventAsm.add(Asm([
          lea(Constant('Pal_Init_Line_3').l, a0),
          lea(Constant('Palette_Line_3').w, a1),
          move.w(0xF.i, d7),
          trap(1.i),
        ]));
        _memory.isDialogInCram = true;
      }

      _eventAsm.add(move.b(1.i, Constant('Render_Sprites_In_Cutscenes').w));
    }

    /*
    differences in panel handling after button press:

    rundialog - destory panels, then destroy window
    rundialog2 - leave everything up, but reset counts - used before battles
    rundialog3 - destroy window, don't touch panels
    rundialog4 - destroy window, don't touch panels
      (but uses runtext3 instead - used in ending for non-interactive dialog)
    rundialog5 - destroy window, then fade screen (then destroy panels silently)

    problem is we have to know how we want to handle panels in the future
    before we run dialog.

    we could lookahead and see what's about to happen:

    - if no more events
      - if there are panels
        - if field is faded
          - run5
        - run regular
      - run regular
    - run3

    we could also look back? remember where the last rundialog routine was
    and change it accordingly?

    the behavior of destroying a panel before the window is more like a dialog
    behavior. so we'd set a flag on the dialog to say whether it should close
    panels with it, and then look ahead in dialog for that.

    fade out can just be done explicitly, but might check if we have already
    faded the field, in which case only call the palfadeout routine. that is,
    default to rundialog3.
     */

    if (_memory.hasSavedDialogPosition) {
      _eventAsm.add(popdlg);
      var line = _eventAsm.add(jsr(Label('Event_RunDialogue3').l));
      _replaceDialogRoutine = ([i]) =>
          _eventAsm.replace(line, jsr(Label('Event_RunDialogue${i ?? ""}').l));
    } else {
      var id = _currentDialogIdOrStart();
      if (id < Byte(128)) {
        _eventAsm.add(moveq(id.i, d0));
      } else {
        _eventAsm.add(move.b(id.i, d0));
      }
      var line = _eventAsm.add(jsr(Label('Event_GetAndRunDialogue3').l));
      _replaceDialogRoutine = ([i]) => _eventAsm.replace(
          line, jsr(Label('Event_GetAndRunDialogue${i ?? ""}').l));
    }

    _memory.unknownAddressRegisters();
    _memory.keepDialog = false;

    _gameMode = mode.enterDialogLoop();
  }

  /// Terminates the current dialog, if there is any,
  /// regardless of whether current generating within dialog loop or not.
  void _terminateDialog(
      {bool? hidePanels, bool keepDialog = false, int? forEventBreak}) {
    var wasInDialog = false;

    switch (_gameMode) {
      case DialogCapableMode m when m.isInDialogLoop:
        wasInDialog = true;

        switch (m) {
          case EventMode m:
            _gameMode = m.exitDialogLoop();

            break;
          case InteractionMode():
            // We can't run in event (because we're not in one),
            // so do in dialog
            _generateQueueInCurrentMode();
            break;
        }

        if (_currentDialog != null) {
          if (keepDialog) {
            _addToDialog(dc.b(ControlCodes.keepDialog));
            _memory.keepDialog = true;
          } else {
            _memory.keepDialog = false;
            _memory.dialogPortrait = Portrait.none;
          }

          if (forEventBreak != null) {
            _addToDialog(comment('scene event $forEventBreak'));
            _lastEventBreak = _addToDialog(eventBreak());
            _memory.hasSavedDialogPosition = true;
          } else {
            _addToDialog(terminateDialog());
          }
        }

        break;
      default:
        // If this isn't for an event break, but we're in an event break,
        // need to go back and terminate for real.
        // Otherwise, ignore–if we're already in an event break, nothing to do.
        if (_lastEventBreak >= 0 && forEventBreak == null) {
          // i think this is only ever the last line so could simplify
          // Do not keepDialog; we rely on event break having already set
          // the appropriate control code at that time
          _currentDialog!.replace(_lastEventBreak, terminateDialog());
        }
        break;
    }

    // TODO: these may need to be conditional on forEventBreak == null

    // fixme: hidePanels tracking not implemented yet
    //   (remember from last dialog event?)
    // if replace routine is null,
    // this should mean that we are processing interaction and not in event
    // so panels will be hidden as interaction ends normally
    if (hidePanels == true && _replaceDialogRoutine != null) {
      _replaceDialogRoutine!();
    }

    if (hidePanels == false && _gameMode is InteractionMode) {
      throw StateError('ending interaction without event cannot keep panels, '
          'but hidePanels == false');
    }

    if (forEventBreak == null) {
      _resetCurrentDialog();
    }

    if (_gameMode case EventMode()) {
      // If we meant not to keep dialog,
      // ensure it's closed now as it may have been left open.
      if (!keepDialog && _memory.keepDialog != false) {
        _memory.keepDialog = false;
        _memory.dialogPortrait = Portrait.none;

        // This is a no-op if dialog not actually kept.
        _eventAsm.add(jsr('Event_CloseDialog'.l));

        // Close window, map chunk loads both mess with registers
        _memory.unknownAddressRegisters();
      }

      if (wasInDialog) {
        // Now that we're not in dialog loop, generate in event
        // so we don't run events out of order.
        // We prefer to generate in event rather than dialog,
        // because dialog can only work if there is an event
        // which should preceed a terminate cursor.
        _generateQueueInCurrentMode();
      }
    }
  }

  /// If [id] is provided, [asm] must be provided. Otherwise, sets to next id
  /// in tree. [_currentDialog] is still lazily set
  /// and must be added to using [_addToDialog].
  void _resetCurrentDialog(
      {Byte? id, DialogAsm? asm, Event? lastEventForDialog}) {
    if (id != null) {
      ArgumentError.checkNotNull(asm, 'asm');
      _currentDialogId = id;
      _currentDialog = asm;
      _lastEventInCurrentDialog = lastEventForDialog;
    } else {
      _currentDialogId = null; // _dialogTree.nextDialogId;
      _currentDialog = null;
      _lastEventInCurrentDialog = null;
    }

    // i think terminate might still save dialog position but i don't usually
    // see it used that way. just an optimization so come back to this.
    _memory.hasSavedDialogPosition = false;
    _lastEventBreak = -1;
    _replaceDialogRoutine = null;
  }

  Byte _currentDialogIdOrStart() {
    _addToDialog(Asm.empty());
    return _currentDialogId!;
  }

  // fixme: should get similar treatment as _addToEvent to handle common dialog
  // stuff like adding interrupts
  // fixme: also portraits need to be cleared if there is a dialog event
  //   without a portrait?
  int _addToDialog(Asm asm) {
    _checkNotFinished();

    if (_currentDialog == null) {
      _currentDialog = DialogAsm.empty();
      _currentDialogId = _currentDialogTree().add(_currentDialog!);
    }

    return _currentDialog!.add(asm);
  }

  DialogTree _currentDialogTree() {
    if (_dialogTree == null) {
      var map = _memory.currentMap;
      if (map == null) {
        throw StateError('cannot load dialog tree; '
            'current map is unknown');
      }
      _dialogTree = _dialogTrees.forMap(map.id);
    }
    return _dialogTree!;
  }

  /// Add to event code, switching to event from dialog if needed.
  ///
  /// [generate] may update [_eventAsm] directly, and/or it may return
  /// [Asm] to be added to `_eventAsm`.
  void _addToEvent(Event event, dynamic Function(int eventIndex) generate,
      {bool keepDialog = false}) {
    _checkNotFinished();

    var eventIndex = _context.getAndIncrementEventCount();

    switch (_gameMode) {
      case RunEventMode():
        runEvent();
        break;
      case EventMode():
        _terminateDialog(
            hidePanels: false,
            keepDialog: keepDialog,
            forEventBreak: eventIndex);
        break;
      case InteractionMode():
        throw StateError("can't add event from interaction "
            "unless it's the first event");
    }

    var length = _eventAsm.length;

    if (generate(eventIndex) case Asm asm) {
      _eventAsm.add(asm);
    }

    // TODO(asm comments): modifications don't necessarily add new lines...
    if (_eventAsm.length > length) {
      _eventAsm.insert(length, comment('$eventIndex: ${event.runtimeType}'));
    }

    _lastEventInCurrentDialog = event;
  }

  /// Adds generated assembly to either run event assembly or event assembly,
  /// depending on the current mode.
  ///
  /// The [generate] callback accepts an [asm] argument which can be used
  /// to modify the correct assembly inline if needed.
  /// Regardless, any returned assembly will be added
  /// to the appropriate assembly.
  void _addToEventOrRunEvent(
      Event event, dynamic Function(int eventIndex, Asm asm) generate,
      {bool keepDialog = false}) {
    switch (_gameMode) {
      case RunEventMode():
        _checkNotFinished();
        var eventIndex = _context.getAndIncrementEventCount();
        _context.runEventAsm.add(comment('$eventIndex: ${event.runtimeType}'));
        if (generate(eventIndex, _context.runEventAsm) case Asm asm) {
          _context.runEventAsm.add(asm);
        }
      default:
        _addToEvent(event, (i) => generate(i, _eventAsm),
            keepDialog: keepDialog);
    }
  }

  /// Adds to event if can, otherwise queues up for later.
  /// We don't want to add to dialog
  /// unless there is an eventual intended interrupt,
  /// like a Dialog or ShowPanel (with speaker) event.
  void _addToEventOrDialog(Event event,
      {required void Function() inDialog,
      required Asm? Function(int eventIndex) inEvent,
      void Function()? after,
      bool interuptDialog = true}) {
    _checkNotFinished();

    generateEvent() {
      // Keep dialog if open since this event could've been in dialog
      _addToEvent(event, inEvent, keepDialog: true);
      after?.call();
    }

    if (!inDialogLoop) {
      // just always run in event in this case
      generateEvent();
    } else {
      // may go either way
      _queuedGeneration.add(_QueuedGeneration(() {
        _runOrContinueDialog(event, interruptDialog: interuptDialog);
        inDialog();
        after?.call();
      }, generateEvent));
    }
  }

  void _generateQueueInCurrentMode() {
    while (_queuedGeneration.isNotEmpty) {
      var queued = _queuedGeneration.removeFirst();
      if (inDialogLoop) {
        queued.generateDialog();
      } else {
        queued.generateEvent();
      }
    }
  }

  void _initVramAndCram() {
    if (_memory.isDisplayEnabled != false) {
      // doesn't hurt if we do this while already disabled i guess
      _eventAsm.add(events_asm.fadeOut(initVramAndCram: true));
      _memory.isDisplayEnabled = false;
    } else {
      var last = _lastLineIfFadeOut(_eventAsm);
      if (last != null) {
        _eventAsm.replace(last, events_asm.fadeOut(initVramAndCram: true));
      } else {
        _eventAsm.add(jsr(Label('InitVRAMAndCRAMAfterFadeOut').l));
      }
    }
    _memory.isMapInCram = false;
    _memory.isMapInVram = false;
    _memory.isFieldShown = false;
    _memory.isDialogInCram = true;
  }
}

Asm? _faceInDialog(Map<FieldObject, DirectionExpression> facing,
    {required Memory memory}) {
  var asm = Asm.empty();

  for (var MapEntry(key: obj, value: dir) in facing.entries) {
    var id = obj.compactId(memory);
    var face = switch (dir) {
      Direction d => d.constant,
      DirectionOfVector(from: PositionOfObject from, to: PositionOfObject to)
          when (from.obj == obj) =>
        switch (to.obj.compactId(memory)) {
          int id => Word(id | 0x100),
          _ => null
        },
      // TODO: we could support position by using bit 15 to flag,
      // and storing x and y as bytes (would max out at 7F0, FF0).
      _ => null,
    };

    if (face == null || id == null) {
      return null;
    }

    asm.add(Asm([
      dc.b([Byte(0xf2), Byte(0xE), Byte(id)]),
      dc.w([face])
    ]));
  }

  return asm;
}

bool _canFaceInDialog(Map<FieldObject, DirectionExpression> facing) =>
    facing.entries.every((entry) {
      var MapEntry(key: obj, value: dir) = entry;
      if (!obj.hasCompactIdRepresentation) return false;
      switch (dir) {
        case Direction():
        case DirectionOfVector(
              from: PositionOfObject from,
              to: PositionOfObject to
            )
            when (from.obj == obj && to.obj.hasCompactIdRepresentation):
          return true;
        case _:
          return false;
      }
    });

int? _lastLineIfFadeOut(Asm asm) {
  for (var i = asm.lines.length - 1; i >= 0; --i) {
    var line = asm.lines[i];
    if (line.isCommentOnly) continue;
    if (line == events_asm.fadeOut(initVramAndCram: false).single) {
      return i;
    }
    break;
  }
  return null;
}

class _QueuedGeneration {
  final void Function() generateDialog;
  final void Function() generateEvent;

  _QueuedGeneration(this.generateDialog, this.generateEvent);
}

sealed class GameMode {}

sealed class DialogCapableMode extends GameMode {
  RunEventCapableMode? get priorMode;
  bool get isInDialogLoop;
}

sealed class RunEventCapableMode extends GameMode {
  EventMode toEventMode(EventType type);
}

class EventMode implements DialogCapableMode {
  @override
  final RunEventCapableMode? priorMode;
  final EventType type;
  final bool _inDialog;

  EventMode({this.priorMode, required this.type, bool inDialog = false})
      : _inDialog = inDialog;

  @override
  bool get isInDialogLoop => _inDialog;

  EventMode enterDialogLoop() =>
      EventMode(priorMode: priorMode, type: type, inDialog: true);

  EventMode exitDialogLoop() =>
      EventMode(priorMode: priorMode, type: type, inDialog: false);
}

class RunEventMode implements RunEventCapableMode {
  @override
  EventMode toEventMode(EventType type) =>
      EventMode(priorMode: this, type: type);
}

class InteractionMode implements RunEventCapableMode, DialogCapableMode {
  @override
  InteractionMode get priorMode => this;
  @override
  final isInDialogLoop = true;
  final FieldObject? withObject;

  bool get isWithObject => withObject != null;
  bool get isWithArea => !isWithObject;

  InteractionMode({required this.withObject});

  @override
  EventMode toEventMode(EventType type) =>
      EventMode(priorMode: this, type: type);
}

Word _addEventRoutine(EventRoutines r, Label name) {
  return r.addEvent(name);
}

Word _addCutsceneRoutine(EventRoutines r, Label name) {
  return r.addCutscene(name);
}

enum EventType {
  event(_addEventRoutine),
  cutscene(_addCutsceneRoutine);

  final Word Function(EventRoutines, Label) _addRoutine;

  const EventType(this._addRoutine);

  Word addRoutine(EventRoutines routines, Label name) {
    return _addRoutine(routines, name);
  }
}

class DialogTree extends IterableBase<DialogAsm> {
  final _dialogs = <DialogAsm>[];

  DialogTree();

  @override
  DialogAsm get last => _dialogs.last;

  /// Adds the dialog and returns the id of the first dialog added in the tree.
  Byte add(DialogAsm dialog) {
    if (dialog.dialogs > 1) {
      throw ArgumentError.value(dialog, 'dialog', '.dialogs must be <= 1');
    }
    var id = nextDialogId;
    if (id == null) {
      throw StateError('no more dialog can fit into dialog trees');
    }
    _dialogs.add(dialog);
    return id;
  }

  void addAll(List<DialogAsm> dialog) => dialog.forEach(add);

  // todo: rename; somewhat misleading. more like "done with what's there"
  void validate() {
    for (var dialog in _dialogs) {
      if (dialog.dialogs != 1) {
        throw ArgumentError.value(
            dialog.dialogs, 'dialog.dialogs', 'must == 1');
      }
    }
  }

  /// The ID of the next dialog that would be added.
  Byte? get nextDialogId =>
      _dialogs.length > Size.b.maxValue ? null : _dialogs.length.toByte;

  Byte nextDialogIdOrThrow() {
    return nextDialogId ?? (throw StateError('no more dialog can fit'));
  }

  DialogAsm operator [](int index) {
    return _dialogs[index];
  }

  /// Replaces the dialog at [index] with [dialog] and
  /// if necessary, extends the tree with empty dialogs
  /// in order to achieve the desired index.
  void addAndExtend(int index, DialogAsm dialog) {
    for (var i = _dialogs.length; i <= index; i++) {
      add(DialogAsm.justTerminate());
    }
    _dialogs[index] = dialog;
  }

  Asm toAsm({bool ensureFinished = true}) {
    if (ensureFinished) validate();

    var all = Asm.empty();

    for (var i = 0; i < length; i++) {
      all.add(comment('${i.toByte}'));
      all.add(this[i]);
      all.addNewline();
    }

    return all;
  }

  DialogTree withoutComments() {
    return DialogTree()
      .._dialogs.addAll(_dialogs.map((e) => e.withoutComments()));
  }

  @override
  int get length => _dialogs.length;

  @override
  Iterator<DialogAsm> get iterator => _dialogs.iterator;

  @override
  String toString() {
    return toAsm(ensureFinished: false).toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DialogTree &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(_dialogs, other._dialogs);

  @override
  int get hashCode => const ListEquality().hash(_dialogs);
}

extension FramesPerSecond on Duration {
  int toFrames(/*region*/) {
    // I think vertical interrupt is 60 times a second
    // but 50 in PAL
    // could use conditional pseudo-assembly if / else
    // see: http://john.ccac.rwth-aachen.de:8000/as/as_EN.html#sect_3_6_
    return (inMilliseconds / 1000 * 60).round();
  }
}

extension SecondsPerFrame on int {
  Duration framesToDuration() {
    // 60 fps
    // 1/60 spf
    // x frames * 1/60 = seconds * 1000 milli per sec = y milliseconds
    return Duration(milliseconds: (this / 60 * 1000).round());
  }
}

extension SoundId on Sound {
  Expression get soundId {
    return switch (this) {
      // Analyzer seems to be bugged here.
      // ignore: pattern_never_matches_value_type
      SoundEffect s => s.sfxId,
      // ignore: pattern_never_matches_value_type
      Music m => m.musicId,
    };
  }
}

extension SfxId on SoundEffect {
  Expression get sfxId {
    var s = this;
    var first = s.name.substring(0, 1);
    var rest = s.name.substring(1);
    var capitalized = '${first.toUpperCase()}$rest';
    return switch (s) {
      SoundEffect.spaceshipRadar ||
      SoundEffect.landRover ||
      SoundEffect.hydrofoil =>
        Constant('SpcSFXID_$capitalized'),
      SoundEffect.stopMusic ||
      SoundEffect.stopSFX ||
      SoundEffect.stopSpcSFX ||
      SoundEffect.stopAll =>
        Constant('Sound_$capitalized'),
      _ => Constant('SFXID_$capitalized')
    };
  }
}

extension MusicId on Music {
  static Constant _defaultConstant(Music m) {
    var first = m.name.substring(0, 1);
    var rest = m.name.substring(1);
    return Constant('MusicID_${first.toUpperCase()}$rest');
  }

  Expression get musicId {
    switch (this) {
      case Music.motaviaTown:
        return Constant('MusicID_MotabiaTown');
      case Music.motaviaVillage:
        return Constant('MusicID_MotabiaVillage');
      default:
        return _defaultConstant(this);
    }
  }
}

/*
walking speed?

2 units per frame
16 units per step
60 frames per second

what is steps per second?

1 / 8 steps per frame
8 frames per step
60 / 8 step per second (7.5)

 */

abstract class DialogTreeLookup {
  Future<DialogTree> byLabel(Label lbl);
}

// todo: unused, but consider adding to DialogTrees if needed
final _defaultDialogs = <MapId, DialogTree>{};
DialogTree _defaultDialogTree(MapId map) =>
    _defaultDialogs[map] ?? DialogTree();

class DialogTrees {
  final _trees = <MapId?, DialogTree>{};

  // note, in the original a tree is usually shared for multiple maps
  // but i don't think it will really be a problem to separate more
  DialogTree forMap(MapId map) => _trees.putIfAbsent(map, () => DialogTree());

  Map<MapId?, DialogTree> toMap() => Map.of(_trees);

  DialogTrees withoutComments() {
    return DialogTrees()
      .._trees.addAll(
          _trees.map((key, value) => MapEntry(key, value.withoutComments())));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DialogTrees &&
          runtimeType == other.runtimeType &&
          const MapEquality().equals(_trees, other._trees);

  @override
  int get hashCode => const MapEquality().hash(_trees);

  @override
  String toString() {
    return 'DialogTrees{_trees: $_trees}';
  }
}

class TestDialogTreeLookup extends DialogTreeLookup {
  final _treeByLabel = <Label, DialogTree>{};

  TestDialogTreeLookup(Map<Label, DialogTree> trees) {
    _treeByLabel.addAll(trees);
  }

  @override
  Future<DialogTree> byLabel(Label lbl) async {
    // wow what a hack :laugh:
    return _treeByLabel[lbl] ??
        (throw ArgumentError('no such dialog tree: $lbl'));
  }
}

class AsmGenerationException {
  final Memory memory;
  final Object? model;
  final Object? cause;
  final StackTrace? causeTrace;

  AsmGenerationException(this.memory, this.model, this.cause, this.causeTrace);

  @override
  String toString() {
    return 'AsmGenerationException{memory: $memory, model: $model, cause: $cause, '
        'causeTrace: $causeTrace}';
  }
}

enum _Reachability { child, reachable, unreachable }

// These offsets are used to account for assembly specifics, which allows for
// variances in maps to be coded manually (such as objects).
// todo: it might be nice to manage these with the assembly or the compiler
//  itself rather than hard coding here.
//  Program API would be the right place now that we have that.
// todo: see generator/map.dart for more of stuff like this

// generated via dart bin/macro.dart vram-tile-offsets | gsed -E 's/([^,]+),(.*)/Label('"'"'\1'"'"'): Word(\2),/'
final Map<MapId, Word> _defaultSpriteVramOffsets = {
  Label('Map_Test'): Word(0x2d0),
  Label('Map_Test_Part2'): Word(0x2d0),
  Label('Map_Dezolis'): Word(0x39b),
  Label('Map_Piata'): Word(0x2d0),
  Label('Map_PiataAcademy'): Word(0x27f),
  Label('Map_PiataAcademy_F1'): Word(0x27f),
  Label('Map_AcademyPrincipalOffice'): Word(0x27f),
  Label('Map_PiataAcademyNearBasement'): Word(0x27f),
  Label('Map_AcademyBasement'): Word(0x27f),
  Label('Map_AcademyBasement_B2'): Word(0x27f),
  Label('Map_PiataDorm'): Word(0x372),
  Label('Map_PiataInn'): Word(0x372),
  Label('Map_PiataHouse1'): Word(0x372),
  Label('Map_PiataItemShop'): Word(0x372),
  Label('Map_PiataHouse2'): Word(0x372),
  Label('Map_Mile'): Word(0x24d),
  Label('Map_MileDead'): Word(0x24d),
  Label('Map_MileWeaponShop'): Word(0x372),
  Label('Map_MileHouse1'): Word(0x372),
  Label('Map_MileItemShop'): Word(0x372),
  Label('Map_MileHouse2'): Word(0x372),
  Label('Map_MileInn'): Word(0x372),
  Label('Map_Zema'): Word(0x29d),
  Label('Map_ZemaHouse1'): Word(0x372),
  Label('Map_ZemaWeaponShop'): Word(0x372),
  Label('Map_ZemaInn'): Word(0x372),
  Label('Map_ZemaHouse2'): Word(0x372),
  Label('Map_ZemaHouse2_B1'): Word(0x372),
  Label('Map_ZemaItemShop'): Word(0x372),
  Label('Map_BirthValley_B1'): Word(0x148),
  Label('Map_Krup'): Word(0x2b8),
  Label('Map_KrupKindergarten'): Word(0x372),
  Label('Map_KrupWeaponShop'): Word(0x372),
  Label('Map_KrupItemShop'): Word(0x372),
  Label('Map_KrupHouse'): Word(0x372),
  Label('Map_KrupInn'): Word(0x372),
  Label('Map_KrupInn_F1'): Word(0x372),
  Label('Map_Molcum'): Word(0x2a6),
  Label('Map_Tonoe'): Word(0x2a8),
  Label('Map_TonoeStorageRoom'): Word(0x409),
  Label('Map_TonoeGryzHouse'): Word(0x409),
  Label('Map_TonoeHouse1'): Word(0x409),
  Label('Map_TonoeHouse2'): Word(0x409),
  Label('Map_TonoeInn'): Word(0x409),
  Label('Map_TonoeBasement_B1'): Word(0x152),
  Label('Map_TonoeBasement_B2'): Word(0x152),
  Label('Map_TonoeBasement_B3'): Word(0x152),
  Label('Map_Nalya'): Word(0x2c1),
  Label('Map_NalyaHouse1'): Word(0x409),
  Label('Map_NalyaHouse2'): Word(0x409),
  Label('Map_NalyaItemShop'): Word(0x409),
  Label('Map_NalyaHouse3'): Word(0x409),
  Label('Map_NalyaHouse4'): Word(0x409),
  Label('Map_NalyaHouse5'): Word(0x409),
  Label('Map_NalyaInn'): Word(0x409),
  Label('Map_NalyaInn_F1'): Word(0x409),
  Label('Map_Aiedo'): Word(0x29a),
  Label('Map_AiedoBakery_B1'): Word(0x372),
  Label('Map_HuntersGuild'): Word(0x372),
  Label('Map_StripClubDressingRoom'): Word(0x372),
  Label('Map_StripClub'): Word(0x372),
  Label('Map_AiedoWeaponShop'): Word(0x372),
  Label('Map_AiedoPrison'): Word(0x372),
  Label('Map_AiedoHouse1'): Word(0x372),
  Label('Map_ChazHouse'): Word(0x372),
  Label('Map_AiedoHouse2'): Word(0x372),
  Label('Map_AiedoHouse3'): Word(0x372),
  Label('Map_AiedoHouse4'): Word(0x372),
  Label('Map_AiedoHouse5'): Word(0x372),
  Label('Map_AiedoSupermarket'): Word(0x372),
  Label('Map_AiedoPub'): Word(0x372),
  Label('Map_RockyHouse'): Word(0x372),
  Label('Map_AiedoHouse6'): Word(0x372),
  Label('Map_AiedoHouse7'): Word(0x372),
  Label('Map_Kadary'): Word(0x2cd),
  Label('Map_KadaryChurch'): Word(0x293),
  Label('Map_KadaryPub'): Word(0x372),
  Label('Map_KadaryPub_F1'): Word(0x372),
  Label('Map_KadaryHouse1'): Word(0x372),
  Label('Map_KadaryHouse2'): Word(0x372),
  Label('Map_KadaryHouse3'): Word(0x372),
  Label('Map_KadaryItemShop'): Word(0x372),
  Label('Map_KadaryInn'): Word(0x372),
  Label('Map_KadaryInn_F1'): Word(0x372),
  Label('Map_Monsen'): Word(0x2c3),
  Label('Map_MonsenInn'): Word(0x372),
  Label('Map_MonsenHouse2'): Word(0x372),
  Label('Map_MonsenHouse3'): Word(0x372),
  Label('Map_MonsenHouse4'): Word(0x372),
  Label('Map_MonsenHouse5'): Word(0x372),
  Label('Map_MonsenItemShop'): Word(0x372),
  Label('Map_Termi'): Word(0x2ea),
  Label('Map_TermiItemShop'): Word(0x372),
  Label('Map_TermiHouse1'): Word(0x372),
  Label('Map_TermiWeaponShop'): Word(0x372),
  Label('Map_TermiInn'): Word(0x372),
  Label('Map_TermiHouse2'): Word(0x372),
  Label('Map_ZioFort'): Word(0x313),
  Label('Map_ZioFort_F1'): Word(0x313),
  Label('Map_ZioFortJuzaRoom'): Word(0x313),
  Label('Map_ZioFort_F3'): Word(0x313),
  Label('Map_ZioFort_F4'): Word(0x313),
  Label('Map_LadeaTower_F2'): Word(0x2e6),
  Label('Map_LadeaTower_F5'): Word(0x2e6),
  Label('Map_IslandCave'): Word(0x192),
  Label('Map_BioPlant_B4_Part2'): Word(0x222),
  Label('Map_BioPlant_B4_Part3'): Word(0x222),
  Label('Map_PlateSystem'): Word(0x22c),
  Label('Map_ClimCenter_F3'): Word(0x22c),
  Label('Map_VahalFort'): Word(0x2c1),
  Label('Map_Uzo'): Word(0x2b8),
  Label('Map_UzoHouse1'): Word(0x372),
  Label('Map_UzoHouse2'): Word(0x372),
  Label('Map_UzoInn'): Word(0x372),
  Label('Map_UzoHouse3'): Word(0x372),
  Label('Map_UzoItemShop'): Word(0x372),
  Label('Map_Torinco'): Word(0x2ea),
  Label('Map_CulversHouse'): Word(0x372),
  Label('Map_TorincoHouse1'): Word(0x372),
  Label('Map_TorincoHouse2'): Word(0x372),
  Label('Map_TorincoItemShop'): Word(0x372),
  Label('Map_TorincoInn'): Word(0x372),
  Label('Map_MonsenCave'): Word(0x148),
  Label('Map_RappyCave'): Word(0x202),
  Label('Map_StrengthTower_F4'): Word(0x260),
  Label('Map_CourageTower_F4'): Word(0x260),
  Label('Map_AngerTower_F2'): Word(0x260),
  Label('Map_Tyler'): Word(0x1e0),
  Label('Map_TylerHouse1'): Word(0x2df),
  Label('Map_TylerWeaponShop'): Word(0x2df),
  Label('Map_TylerItemShop'): Word(0x2df),
  Label('Map_TylerHouse2'): Word(0x2df),
  Label('Map_TylerInn'): Word(0x2df),
  Label('Map_Zosa'): Word(0x263),
  Label('Map_ZosaHouse1'): Word(0x2df),
  Label('Map_ZosaHouse2'): Word(0x2df),
  Label('Map_ZosaWeaponShop'): Word(0x2df),
  Label('Map_ZosaItemShop'): Word(0x2df),
  Label('Map_ZosaInn'): Word(0x2df),
  Label('Map_ZosaHouse3'): Word(0x2df),
  Label('Map_Meese'): Word(0x1c8),
  Label('Map_MeeseHouse1'): Word(0x2df),
  Label('Map_MeeseItemShop2'): Word(0x2df),
  Label('Map_MeeseItemShop1'): Word(0x2df),
  Label('Map_MeeseWeaponShop'): Word(0x2df),
  Label('Map_MeeseInn'): Word(0x2df),
  Label('Map_MeeseClinic'): Word(0x2df),
  Label('Map_MeeseClinic_F1'): Word(0x2df),
  Label('Map_Jut'): Word(0x2c2),
  Label('Map_JutHouse1'): Word(0x2df),
  Label('Map_JutHouse2'): Word(0x2df),
  Label('Map_JutHouse3'): Word(0x2df),
  Label('Map_JutHouse4'): Word(0x2df),
  Label('Map_JutHouse5'): Word(0x2df),
  Label('Map_JutWeaponShop'): Word(0x2df),
  Label('Map_JutItemShop'): Word(0x2df),
  Label('Map_JutHouse6'): Word(0x2df),
  Label('Map_JutHouse6_F1'): Word(0x2df),
  Label('Map_JutHouse7'): Word(0x2df),
  Label('Map_JutHouse8'): Word(0x2df),
  Label('Map_JutInn'): Word(0x2df),
  Label('Map_JutChurch'): Word(0x276),
  Label('Map_Ryuon'): Word(0x200),
  Label('Map_RyuonItemShop'): Word(0x2df),
  Label('Map_RyuonWeaponShop'): Word(0x2df),
  Label('Map_RyuonHouse1'): Word(0x2df),
  Label('Map_RyuonHouse2'): Word(0x2df),
  Label('Map_RyuonHouse3'): Word(0x2df),
  Label('Map_RyuonPub'): Word(0x2df),
  Label('Map_RyuonInn'): Word(0x2df),
  Label('Map_RajaTemple'): Word(0x1f3),
  Label('Map_Reshel2'): Word(0x222),
  Label('Map_Reshel3'): Word(0x222),
  Label('Map_Reshel2House'): Word(0x2df),
  Label('Map_Reshel2WeaponShop'): Word(0x2df),
  Label('Map_Reshel3House1'): Word(0x2df),
  Label('Map_Reshel3ItemShop'): Word(0x2df),
  Label('Map_Reshel3House2'): Word(0x2df),
  Label('Map_Reshel3WeaponShop'): Word(0x2df),
  Label('Map_Reshel3Inn'): Word(0x2df),
  Label('Map_Reshel3House3'): Word(0x2df),
  Label('Map_MystVale_Part2'): Word(0x202),
  Label('Map_MystVale_Part4'): Word(0x202),
  Label('Map_MystVale_Part5'): Word(0x202),
  Label('Map_Gumbious'): Word(0x286),
  Label('Map_Gumbious_F1'): Word(0x286),
  Label('Map_Gumbious_B1'): Word(0x266),
  Label('Map_Gumbious_B2_Part2'): Word(0x266),
  Label('Map_EspMansionEntrance'): Word(0x1f5),
  Label('Map_EspMansion'): Word(0x1f5),
  Label('Map_EspMansionWestRoom'): Word(0x1f5),
  Label('Map_EspMansionNorth'): Word(0x1f5),
  Label('Map_EspMansionNorthEastRoom'): Word(0x1f5),
  Label('Map_EspMansionNorthWestRoom'): Word(0x1f5),
  Label('Map_EspMansionCourtyard'): Word(0x1f5),
  Label('Map_InnerSanctuary'): Word(0x1f5),
  Label('Map_InnerSanctuary_B1'): Word(0x1f5),
  Label('Map_AirCastle_Part3'): Word(0x371),
  Label('Map_AirCastle_F1_Part10'): Word(0x371),
  Label('Map_AirCastleXeAThoulRoom'): Word(0x371),
  Label('Map_Kuran_F3'): Word(0x3b9),
  Label('Map_GaruberkTower_Part7'): Word(0x252),
}.map((l, o) => MapEntry(labelToMapId(l), o));

final _defaultBuiltInSprites = {
  MapId.BirthValley_B1: [
    SpriteVramMapping(
        tiles: 0x39,
        art: RomArt(label: Label('loc_1379A8')),
        requiredVramTile: Word(0x148))
  ],
  MapId.StripClub: [
    SpriteVramMapping(
        tiles: 0x100,
        art: RomArt(label: Label('loc_14960C')),
        requiredVramTile: Word(0x3BA))
  ],
  MapId.KadaryChurch: [
    SpriteVramMapping(
        tiles: 0x11,
        art: RomArt(label: Label('loc_151984')),
        requiredVramTile: Word(0x413))
  ]
};

Queue<Word> freeEventFlags() {
  var q = Queue<Word>();
  int next = 0;
  for (var used in eventFlags.values.sorted((a, b) => a.compareTo(b))) {
    for (; next < used.value; next++) {
      q.add(Word(next));
    }
    next = used.value + 1;
  }
  // 1ff with extension
  // we can free up more from other flag type ram if needed
  // (chest and town flags have plenty of headroom)
  q.addAll([
    for (; next <= 0x1ff; next++)
      // Ensure there are no 0xff bytes within the word,
      // since this is interpetted as a dialog terminator
      if (next & 0xff != 0xff) Word(next)
  ]);
  return q;
}
