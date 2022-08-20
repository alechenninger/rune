import 'dart:collection';

import '../asm/asm.dart';
import '../asm/dialog.dart';
import '../asm/events.dart';
import '../asm/events.dart' as asmevents;
import '../model/model.dart';
import '../model/text.dart';
import '../numbers.dart';
import 'dialog.dart';
import 'event.dart';
import 'map.dart';
import 'movement.dart';
import 'scene.dart';
import 'text.dart' as text;

export '../asm/asm.dart' show Asm;

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

  final Asm _eventPointers = Asm.empty();
  Asm get eventPointers => Asm([_eventPointers]);

  Word _eventIndexOffset = 'a0'.hex.toWord;
  Word get peekNextEventIndex => (_eventIndexOffset.value + 1).toWord;

  /// Returns next event index to add a new event in EventPtrs.
  Word _nextEventIndex() {
    _eventIndexOffset = peekNextEventIndex;
    return _eventIndexOffset;
  }

  /// Returns event index by which [routine] can be referenced.
  ///
  /// The event code must be added separate with the exact label of [routine].
  Word addEventPointer(Label routine) {
    var eventIndex = _nextEventIndex();
    _eventPointers.add(dc.l([routine], comment: '$eventIndex'));
    return eventIndex;
  }

  void addScene(SceneId id, Scene scene) {
    var dialogTree = DialogTree();
    var eventAsm = EventAsm.empty();
    var generator = SceneAsmGenerator.forEvent(id, dialogTree, eventAsm);

    for (var event in scene.events) {
      event.visit(generator);
    }

    generator.finish();

    _scenes[id] = SceneAsm(
        event: eventAsm, dialogIdOffset: Byte(0), dialog: dialogTree.toList());
  }

  void addMap(GameMap map) {
    var builder = MapAsmBuilder(map, addEventPointer);
    for (var obj in map.objects) {
      builder.addObject(obj);
    }
    _maps[map.id] = builder.build();
  }
}

// should track transient state about code generation
// the known values of registers and memory
// should be reset with every event or interaction
// may not be relevant to all generation, for ex map objects
// this is the state of running code
class AsmContext {
  AsmContext.fresh({Mode gameMode = Mode.event})
      : _gameMode = gameMode,
        state = EventState() {
    if (inDialogLoop) {
      _inEvent = false;
    }
  }

  AsmContext.forInteractionWith(FieldObject obj, this.state) {
    startDialogInteractionWith(obj, state: state);
  }

  AsmContext.forDialog(this.state)
      : _gameMode = Mode.dialog,
        _inEvent = false;

  AsmContext.forEvent(this.state) : _gameMode = Mode.event;

  // todo: probably shouldn't have all of this stuff read/write

  EventState state;

  Mode _gameMode = Mode.event;

  // i think this should always be true if mode == event?
  var _inEvent = true;

  bool get inDialogLoop => _gameMode == Mode.dialog;

  /// Whether or not we are generating in the context of an existing event.
  ///
  /// This is necessary to understand whether, when in dialog mode, we can pop
  /// back to an event or have to trigger a new one.
  bool get inEvent => _inEvent;
  bool hasSavedDialogPosition = false;

  bool _isProcessingInteraction = false;

  bool get isProcessingInteraction => _isProcessingInteraction;

  final _inAddress = <DirectAddressRegister, AddressOf>{};

  AddressOf? inAddress(DirectAddressRegister a) {
    return _inAddress[a];
  }

  void putInAddress(DirectAddressRegister a, Object? obj) {
    if (obj == null) {
      _inAddress.remove(a);
    } else {
      _inAddress[a] = AddressOf(obj);
    }
  }

  void clearRegisters() {
    _inAddress.clear();
  }

  // todo: this one is a bit different. this is like, asm state. state of
  //  generated code.
  // the others (including eventstate) are more the state of active generation?
  Word _eventIndexOffset = 'a0'.hex.toWord;
  final Asm _eventPointers = Asm.empty();

  Asm get eventPointers => Asm([_eventPointers]);

  Word get peekNextEventIndex => (_eventIndexOffset.value + 1).toWord;

  /// Returns next event index to add a new event in EventPtrs.
  Word _nextEventIndex() {
    _eventIndexOffset = peekNextEventIndex;
    return _eventIndexOffset;
  }

  /// Returns event index by which [routine] can be referenced.
  ///
  /// The event code must be added separate with the exact label of [routine].
  Word addEventPointer(Label routine) {
    var eventIndex = _nextEventIndex();
    _eventPointers.add(dc.l([routine], comment: '$eventIndex'));
    return eventIndex;
  }

  void startDialogInteractionWith(FieldObject obj, {EventState? state}) {
    _gameMode = Mode.dialog;
    _inEvent = false;
    _isProcessingInteraction = true;
    putInAddress(a3, obj);
    hasSavedDialogPosition = false;
    state = state ?? EventState();
  }

  void startEvent([EventState? knownState]) {
    _gameMode = Mode.event;
    _inEvent = true;
    state = knownState ?? EventState();
    // todo: should reset saved dialog position too?
  }

  void runDialog() {
    if (_gameMode != Mode.event) {
      throw StateError('expected event mode $_gameMode');
    }
    _gameMode = Mode.dialog;
  }

  void dialogEventBreak() {
    if (_gameMode != Mode.dialog) {
      throw StateError('expected event mode $_gameMode');
    }
    if (!_inEvent) {
      throw StateError('cannot break to event; not in event '
          '(dialog must first run event using f6 control code)');
    }
    _gameMode = Mode.event;
  }
}

class SceneAsmGenerator implements EventVisitor {
  final SceneId id;

  final EventState _state = EventState();
  Mode _gameMode = Mode.event;
  bool get inDialogLoop => _gameMode == Mode.dialog;

  // i think this should always be true if mode == event?
  var _inEvent = true;

  /// Whether or not we are generating in the context of an existing event.
  ///
  /// This is necessary to understand whether, when in dialog mode, we can pop
  /// back to an event or have to trigger a new one.
  bool get inEvent => _inEvent;

  bool _hasSavedDialogPosition = false;

  final bool _isProcessingInteraction;
  bool get isProcessingInteraction => _isProcessingInteraction;
  bool get startedInEvent => _isProcessingInteraction;

  final _inAddress = <DirectAddressRegister, AddressOf>{};

  final DialogTree _dialogTree;
  final EventAsm _eventAsm;
  final Byte _dialogIdOffset;

  late Byte _currentDialogId;
  var _currentDialog = DialogAsm.empty();
  var _lastEventBreak = -1;
  Event? _lastEvent;
  var _eventCounter = 1;

  static bool interactionIsolatedToDialogLoop(
      List<Event> events, FieldObject obj) {
    bool _isInteractionObjFacePlayer(Event event, FieldObject obj) {
      if (event is! FacePlayer) return false;
      return event.object == obj;
    }

    var first = events.first;
    return (_isInteractionObjFacePlayer(first, obj) &&
            events.skip(1).every((event) => event is Dialog)) ||
        events.every((event) => event is Dialog);
  }

  SceneAsmGenerator.forInteraction(
      FieldObject obj, this.id, this._dialogTree, this._eventAsm,
      {bool inEvent = false})
      : _dialogIdOffset = _dialogTree.nextDialogId!,
        _isProcessingInteraction = true {
    _currentDialogId = _dialogIdOffset;
    _gameMode = _inEvent ? Mode.event : Mode.dialog;
    _inEvent = inEvent;

    _putInAddress(a3, obj);
    _hasSavedDialogPosition = false;
  }

  SceneAsmGenerator.forEvent(this.id, this._dialogTree, this._eventAsm)
      : _dialogIdOffset = _dialogTree.nextDialogId!,
        _isProcessingInteraction = false {
    _currentDialogId = _dialogIdOffset;
    _gameMode = Mode.event;
    _inEvent = true;
  }

  @override
  void asm(Asm asm) {
    _eventAsm.add(asm);
  }

  @override
  void dialog(Dialog dialog) {
    if (isProcessingInteraction && _lastEvent == null) {
      // Not starting with face player, so signal not to.
      _currentDialog.add(dc.b(Bytes.of(0xf3)));
    }

    if (!inDialogLoop) {
      if (_hasSavedDialogPosition) {
        _eventAsm.add(popAndRunDialog);
        _eventAsm.addNewline();
      } else {
        _eventAsm.add(getAndRunDialog(_currentDialogId.i));
      }
      _gameMode = Mode.dialog;
    } else if (_lastEvent is Dialog) {
      // Consecutive dialog, new cursor in between each dialog
      _currentDialog.add(interrupt());
    }

    _currentDialog.add(dialog.toAsm());
    _lastEvent = dialog;
  }

  @override
  void displayText(DisplayText display) {
    var asm = text.displayTextToAsm(display, dialogTree: _dialogTree);
    _currentDialogId = _dialogTree.nextDialogId!;
    _currentDialog = DialogAsm.empty();
    _addToEvent(display, asm.event);
  }

  @override
  void facePlayer(FacePlayer face) {
    if (isProcessingInteraction && _lastEvent == null) {
      // this already will happen by default if the first event
      return;
    }

    var asm = EventAsm.empty();

    if (_inAddress[a3] != AddressOf(face.object)) {
      asm.add(face.object.toA3(_state));
      _inAddress[a3] = AddressOf(face.object);
    }

    asm.add(jsr(Label('Interaction_UpdateObj').l));

    _addToEvent(face, asm);
  }

  @override
  void individualMoves(IndividualMoves moves) {
    var asm = moves.toAsm(_state);
    _addToEvent(moves, asm);
  }

  @override
  void lockCamera(LockCamera lock) {
    var asm = EventAsm.of(asmevents.lockCamera(_state.cameraLock = true));
    _addToEvent(lock, asm);
  }

  @override
  void partyMove(PartyMove move) {
    // TODO: implement partyMove
  }

  @override
  void pause(Pause pause) {
    // TODO: implement pause
  }

  @override
  void setContext(SetContext set) {
    // TODO: implement setContext
  }

  @override
  void unlockCamera(UnlockCamera unlock) {
    // TODO: implement unlockCamera
  }

  void finish() {
    // was lastEventBreak >= 0, but i think it should be this?
    if (!inDialogLoop && _lastEventBreak >= 0) {
      _currentDialog.replace(_lastEventBreak, terminateDialog());
    } else if (_currentDialog.isNotEmpty) {
      _currentDialog.add(terminateDialog());
    }

    if (_currentDialog.isNotEmpty) {
      _dialogTree.add(_currentDialog);
    }

    if (!startedInEvent && inEvent) {
      _eventAsm.add(returnFromDialogEvent());
    }
  }

  void _addToEvent(Event event, Asm asm) {
    if (!inEvent) {
      throw StateError("can't add event when not in event loop");
    } else if (inDialogLoop) {
      // todo: why did we check this before?
      // i think b/c we always assumed in dialog loop to start
      //if (dialogAsm.isNotEmpty) {
      _currentDialog.add(comment('scene event $_eventCounter'));
      _lastEventBreak = _currentDialog.add(eventBreak());
      _hasSavedDialogPosition = true;
      _gameMode = Mode.event;
    }

    if (asm.isNotEmpty) {
      _eventAsm.add(comment('scene event $_eventCounter'));
      _eventAsm.add(comment('generated from type: ${event.runtimeType}'));
      _eventAsm.add(asm);
      _eventCounter++;
    }

    _lastEvent = event;
  }

  void _putInAddress(DirectAddressRegister a, Object? obj) {
    if (obj == null) {
      _inAddress.remove(a);
    } else {
      _inAddress[a] = AddressOf(obj);
    }
  }
}

class AddressOf {
  final Object obj;

  AddressOf(this.obj);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressOf &&
          runtimeType == other.runtimeType &&
          obj == other.obj;

  @override
  int get hashCode => obj.hashCode;

  @override
  String toString() {
    return 'AddressOf{$obj}';
  }
}

enum Mode { dialog, event }

class DialogTree extends IterableBase<DialogAsm> {
  final _dialogs = <DialogAsm>[];

  DialogTree({Byte? offset}) {
    if (offset != null) {
      for (var i = 0; i < offset.value; i++) {
        // todo: or null?
        _dialogs.add(DialogAsm([comment('hard coded (skipped)')]));
      }
    }
  }

  @override
  DialogAsm get last => _dialogs.last;

  /// Adds the dialog and returns its id in the tree.
  Byte add(DialogAsm dialog) {
    // TODO: validate dialog contains exactly one terminator and only at the end
    // or validate contains none, and add here (or add here if not already set)
    var id = nextDialogId;
    if (id == null) {
      throw StateError('no more dialog can fit into dialog trees');
    }
    _dialogs.add(dialog);
    return id;
  }

  Byte? get nextDialogId =>
      _dialogs.length > Size.b.maxValue ? null : _dialogs.length.toByte;

  DialogAsm operator [](int index) {
    return _dialogs[index];
  }

  Asm toAsm() {
    var all = Asm.empty();

    for (var i = 0; i < length; i++) {
      all.add(comment('${i.toByte}'));
      all.add(this[i]);
      all.addNewline();
    }

    return all;
  }

  @override
  int get length => _dialogs.length;

  @override
  Iterator<DialogAsm> get iterator => _dialogs.iterator;

  @override
  String toString() {
    return _dialogs.join('\n');
  }
}

class AsmGenerationException {
  final AsmContext? ctx;
  final Object? model;
  final Object? cause;
  final StackTrace? causeTrace;

  AsmGenerationException(this.ctx, this.model, this.cause, this.causeTrace);

  @override
  String toString() {
    return 'AsmGenerationException{ctx: $ctx, model: $model, cause: $cause, '
        'causeTrace: $causeTrace}';
  }
}

class AsmGenerator {
  T _wrapException<T>(T Function() generate, AsmContext? ctx, Object? model) {
    try {
      return generate();
    } catch (e, stack) {
      throw AsmGenerationException(ctx, model, e, stack);
    }
  }

  Asm eventsToAsm(List<Event> events, AsmContext ctx) {
    if (events.isEmpty) {
      return Asm.empty();
    }

    return _wrapException(
        () => events
                .map((e) => e.generateAsm(this, ctx))
                .reduce((value, element) {
              value.add(element);
              return value;
            }),
        ctx,
        events);
  }

  Asm? eventToAsm(Event event) {}

  SceneAsm sceneToAsm(Scene scene, AsmContext ctx,
      {DialogTree? dialogTree, SceneId? id}) {
    return _wrapException(
        () => scene.toAsm(this, ctx, dialogTree: dialogTree, id: id),
        ctx,
        scene);
  }

  SceneAsm displayTextToAsm(DisplayText display, AsmContext ctx,
      {DialogTree? dialogTree}) {
    return _wrapException(
        () => text.displayTextToAsm(display, dialogTree: dialogTree),
        ctx,
        display);
  }

  MapAsm mapToAsm(GameMap map, AsmContext ctx) {
    return _wrapException(() => map.toAsm(this, ctx), ctx, map);
  }

  DialogAsm dialogToAsm(Dialog dialog) {
    return _wrapException(() => dialog.toAsm(), null, dialog);
  }

  EventAsm individualMovesToAsm(IndividualMoves move, AsmContext ctx) {
    return _wrapException(() => move.toAsm(ctx.state), ctx, move);
  }

  EventAsm partyMoveToAsm(PartyMove move, AsmContext ctx) {
    return _wrapException(
        () => individualMovesToAsm(move.toIndividualMoves(ctx.state), ctx),
        ctx,
        move);
  }

  EventAsm facePlayerToAsm(FacePlayer face, AsmContext ctx) {
    return _wrapException(() {
      var asm = EventAsm.empty();

      if (ctx.inAddress(a3) != AddressOf(face.object)) {
        asm.add(face.object.toA3(ctx.state));
        // could set a3 in context, but not clearing it everywhere
      }

      asm.add(jsr(Label('Interaction_UpdateObj').l));

      return asm;
    }, ctx, face);
  }

  EventAsm pauseToAsm(Pause pause) {
    return _wrapException(() {
      var frames = pause.duration.toFrames();
      return EventAsm.of(vIntPrepareLoop(Word(frames)));
    }, null, pause);
  }

  EventAsm lockCameraToAsm(AsmContext ctx) {
    return _wrapException(
        () => EventAsm.of(lockCamera(ctx.state.cameraLock = true)), ctx, null);
  }

  EventAsm unlockCameraToAsm(AsmContext ctx) {
    return _wrapException(
        () => EventAsm.of(lockCamera(ctx.state.cameraLock = false)), ctx, null);
  }
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
