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

import 'package:rune/model/conditional.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

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

  Word _eventIndexOffset;

  Program({Word? eventIndexOffset})
      : _eventIndexOffset = eventIndexOffset ?? 0xa1.toWord;

  /// Returns event index by which [routine] can be referenced.
  ///
  /// The event code must be added separate with the exact label of [routine].
  Word _addEventPointer(Label routine) {
    var eventIndex = _eventIndexOffset;
    _eventPointers.add(dc.l([routine], comment: '$eventIndex'));
    _eventIndexOffset = (eventIndex.value + 1).toWord;
    return eventIndex;
  }

  SceneAsm addScene(SceneId id, Scene scene) {
    var dialogTree = DialogTree();
    var eventAsm = EventAsm.empty();
    var generator = SceneAsmGenerator.forEvent(id, dialogTree, eventAsm);

    for (var event in scene.events) {
      event.visit(generator);
    }

    generator.finish();

    return _scenes[id] = SceneAsm(
        event: eventAsm, dialogIdOffset: Byte(0), dialog: dialogTree.toList());
  }

  MapAsm addMap(GameMap map) {
    var builder = MapAsmBuilder(map, _addEventPointer);
    for (var obj in map.objects) {
      builder.addObject(obj);
    }
    return _maps[map.id] = builder.build();
  }
}

// FIXME just to track an event has happened
class AsmEvent extends Event {
  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    // TODO: implement generateAsm
    throw UnimplementedError();
  }

  @override
  void visit(EventVisitor visitor) {
    // TODO: implement visit
  }
}

class SceneAsmGenerator implements EventVisitor {
  final SceneId id;

  // Non-volatile state (state of the code being generated)
  final DialogTree _dialogTree;
  final EventAsm _eventAsm;
  final Byte _dialogIdOffset;

  Mode _gameMode = Mode.event;
  bool get inDialogLoop => _gameMode == Mode.dialog;

  // i think this should always be true if mode == event?
  /// Whether or not we are generating in the context of an existing event.
  ///
  /// This is necessary to understand whether, when in dialog mode, we can pop
  /// back to an event or have to trigger a new one.
  final bool _inEvent;

  final bool _isProcessingInteraction;

  Byte? _currentDialogId;
  DialogAsm? _currentDialog;
  var _lastEventBreak = -1;
  Event? _lastEventInCurrentDialog;
  var _eventCounter = 1;

  // conditional runtime state
  /// For currently generating branch, what is the known state of event flags
  Condition _currentCondition = Condition.empty();

  /// mem state which exactly matches current flags; other states may need
  /// updates
  Memory _memory = Memory(); // todo: ctor initialization
  /// should also contain root state
  final _stateGraph = <Condition, Memory>{};

  /// Reproduces logic in Interaction_ProcessDialogueTree to see if the events
  /// can be processed soley through dialog loop.
  ///
  /// Returns `true` if events occur in the following order:
  /// - Zero or more [IfFlag] (i.e. `$FA` control code)
  /// where each branch is also processable within dialog
  /// (recursively follows these rules)
  /// - Zero or one [FacePlayer] where `object` is [obj]
  /// (i.e. `$F3` control code)
  /// - Zero or more [Dialog]
  static bool interactionIsolatedToDialogLoop(
      List<Event> events, FieldObject obj) {
    var check = 0;
    var checks = <bool Function(Event)>[
      (event) =>
          event is IfFlag &&
          interactionIsolatedToDialogLoop(event.isSet, obj) &&
          interactionIsolatedToDialogLoop(event.isUnset, obj),
      (event) => event is FacePlayer && event.object == obj,
      (event) => event is Dialog
    ];

    event:
    for (var event in events) {
      for (var i = check; i < checks.length; i++) {
        if (checks[i](event)) {
          check = i;
          continue event;
        }
      }
      return false;
    }

    return true;
  }

  SceneAsmGenerator.forInteraction(
      GameMap map, FieldObject obj, this.id, this._dialogTree, this._eventAsm,
      {bool inEvent = false})
      : _dialogIdOffset = _dialogTree.nextDialogId!,
        _isProcessingInteraction = true,
        _inEvent = inEvent {
    _gameMode = _inEvent ? Mode.event : Mode.dialog;

    _memory.putInAddress(a3, obj);
    _memory.hasSavedDialogPosition = false;
    _memory.currentMap = map;
    _stateGraph[Condition.empty()] = _memory;
  }

  SceneAsmGenerator.forEvent(this.id, this._dialogTree, this._eventAsm)
      : _dialogIdOffset = _dialogTree.nextDialogId!,
        _isProcessingInteraction = false,
        _inEvent = true {
    _gameMode = Mode.event;
    _stateGraph[Condition.empty()] = _memory;
  }

  void scene(Scene scene) {
    for (var event in scene.events) {
      event.visit(this);
    }
  }

  @override
  void asm(Asm asm) {
    _addToEvent(AsmEvent(), (i) => asm);
  }

  @override
  void dialog(Dialog dialog) {
    if (!_inEvent &&
        _isProcessingInteraction &&
        _lastEventInCurrentDialog == null) {
      // Not starting with face player, so signal not to.
      _addToDialog(dc.b(Bytes.of(0xf3)));
    }

    if (!inDialogLoop) {
      _eventAsm.add(Asm([comment('${_eventCounter++}: $Dialog')]));
      if (_memory.hasSavedDialogPosition) {
        _eventAsm.add(popAndRunDialog);
        _eventAsm.addNewline();
      } else {
        _eventAsm.add(getAndRunDialog(_currentDialogIdOrStart().i));
      }
      _gameMode = Mode.dialog;
    } else if (_lastEventInCurrentDialog is Dialog) {
      // Consecutive dialog, new cursor in between each dialog
      _addToDialog(interrupt());
    }

    _addToDialog(dialog.toAsm());
    _lastEventInCurrentDialog = dialog;
  }

  @override
  void displayText(DisplayText display) {
    _addToEvent(display, (i) {
      _terminateDialog();
      var asm = text.displayTextToAsm(display, dialogTree: _dialogTree);
      return asm.event;
    });
  }

  @override
  void facePlayer(FacePlayer face) {
    if (!_inEvent &&
        _isProcessingInteraction &&
        _lastEventInCurrentDialog == null) {
      // this already will happen by default if the first event
      _lastEventInCurrentDialog = face;
      return;
    }

    _addToEvent(face, (i) {
      var asm = EventAsm.empty();

      if (_memory.inAddress(a3) != AddressOf(face.object)) {
        asm.add(face.object.toA3(_memory));
        _memory.putInAddress(a3, face.object);
      }

      asm.add(jsr(Label('Interaction_UpdateObj').l));

      return asm;
    });
  }

  @override
  void individualMoves(IndividualMoves moves) {
    _addToEvent(moves, (i) => moves.toAsm(_memory));
  }

  @override
  void lockCamera(LockCamera lock) {
    _addToEvent(lock,
        (i) => EventAsm.of(asmevents.lockCamera(_memory.cameraLock = true)));
  }

  @override
  void partyMove(PartyMove move) {
    _addToEvent(move, (i) => move.toIndividualMoves(_memory).toAsm(_memory));
  }

  @override
  void pause(Pause pause) {
    _addToEvent(pause, (i) {
      var frames = pause.duration.toFrames();
      return EventAsm.of(vIntPrepareLoop(Word(frames)));
    });
  }

  @override
  void setContext(SetContext set) {
    set(_memory);
  }

  @override
  void unlockCamera(UnlockCamera unlock) {
    _addToEvent(unlock,
        (i) => EventAsm.of(asmevents.lockCamera(_memory.cameraLock = false)));
  }

  @override
  void ifFlag(IfFlag ifFlag) {
    if (ifFlag.isSet.isEmpty && ifFlag.isUnset.isEmpty) {
      return;
    }

    var flag = ifFlag.flag;

    var knownState = _currentCondition[flag];
    if (knownState != null) {
      // one branch is dead code so only run the other, and skip useless
      // conditional check
      // also, no need to manage flags in scene graph because this flag is
      // already set.
      var events = knownState ? ifFlag.isSet : ifFlag.isUnset;
      for (var event in events) {
        event.visit(this);
      }
    } else if (!_inEvent) {
      // attempt to process in dialog
      // we can assume at this point that all events will be processed in dialog

      var ifSet = DialogAsm.empty();
      var currentDialogId = _currentDialogIdOrStart();
      var ifSetId = _dialogTree.add(ifSet);
      var ifSetOffset = ifSetId - currentDialogId as Byte;

      _addToDialog(eventCheck(flag.toConstant, ifSetOffset));

      for (var event in ifFlag.isUnset) {
        event.visit(this);
      }

      if (!inDialogLoop) {
        throw StateError('expected dialog loop');
      }

      _terminateDialog();
      _currentDialog = ifSet;
      _currentDialogId = ifSetId;

      for (var event in ifFlag.isSet) {
        event.visit(this);
      }
    } else {
      _addToEvent(ifFlag, (i) {
        // note that if we need to move further than beq.w we will need to branch
        // to subroutine which then jsr/jmp to another
        // TODO: need to approximate code size so we can handle jump distance

        // use event counter in case flag is checked again
        var ifUnset = Label('${id}_${flag.name}_unset$i');
        var ifSet = Label('${id}_${flag.name}_set$i');

        // For readability, set continue scene label based on what branches
        // there are.
        var continueScene = ifFlag.isSet.isEmpty
            ? ifSet
            : (ifFlag.isUnset.isEmpty
                ? ifUnset
                : Label('${id}_${flag.name}_cont$i'));

        // memory may change while flag is set, so remember this to branch
        // off of for unset branch
        var parent = _memory;

        // run isSet events unless there are none
        if (ifFlag.isSet.isEmpty) {
          _eventAsm.add(branchIfEventFlagSet(flag.toConstant.i, continueScene));
        } else {
          if (ifFlag.isUnset.isEmpty) {
            _eventAsm
                .add(branchIfEvenfFlagNotSet(flag.toConstant.i, continueScene));
          } else {
            _eventAsm.add(branchIfEvenfFlagNotSet(flag.toConstant.i, ifUnset));
          }

          _flagIsSet(flag);
          for (var event in ifFlag.isSet) {
            event.visit(this);
          }

          _terminateDialog();

          // skip past unset events
          if (ifFlag.isUnset.isNotEmpty) {
            _eventAsm.add(bra.w(continueScene));
          }
        }

        // define routine for unset events if there are any
        if (ifFlag.isUnset.isNotEmpty) {
          _flagIsNotSet(flag, parent: parent);
          if (ifFlag.isSet.isNotEmpty) {
            _eventAsm.add(setLabel(ifUnset.name));
          }
          for (var event in ifFlag.isUnset) {
            event.visit(this);
          }

          _terminateDialog();
        }

        _updateStateGraph(flag);
        _flagUnknown(flag);

        // define routine for continuing
        _eventAsm.add(setLabel(continueScene.name));

        return null;
      });
    }
  }

  void finish() {
    // also applfinishy all changes for current mem across graph

    _terminateDialog();

    if (_isProcessingInteraction && _inEvent) {
      _eventAsm.add(returnFromDialogEvent());
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
  void _updateStateGraph(EventFlag branchFlag) {
    var currentBranch = _currentCondition[branchFlag];
    if (currentBranch == null) {
      throw ArgumentError.value(
          branchFlag,
          'branchFlag',
          'is not in current branch conditions, '
              'so it must not be the current branch flag');
    }

    var changes = _memory._changes;
    // there may be no sibling if that branch had no events
    var sibling =
        _stateGraph[_currentCondition.withFlag(branchFlag, !currentBranch)];
    var siblingChanges = sibling == null
        ? List<StateChange>.empty(growable: true)
        : sibling._changes;

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

    changes.clear();
    siblingChanges.clear();
  }

  void _terminateDialog() {
    // was lastEventBreak >= 0, but i think it should be this?
    if (!inDialogLoop && _lastEventBreak >= 0) {
      // i think this is only ever the last line so could simplify
      _currentDialog!.replace(_lastEventBreak, terminateDialog());
    } else if (_currentDialog?.isNotEmpty == true) {
      _currentDialog!.add(terminateDialog());
      if (_inEvent) {
        _gameMode = Mode.event;
      }
    }

    _currentDialog = null;
    _currentDialogId = _dialogTree.nextDialogId;
    _lastEventInCurrentDialog = null;

    // i think terminate might still save dialog position but i don't usually
    // see it used that way. just an optimization so come back to this.
    _memory.hasSavedDialogPosition = false;
    _lastEventBreak = -1;
  }

  Byte _currentDialogIdOrStart() {
    _addToDialog(Asm.empty());
    return _currentDialogId!;
  }

  int _addToDialog(Asm asm) {
    if (_currentDialog == null) {
      _currentDialog = DialogAsm.empty();
      _currentDialogId = _dialogTree.add(_currentDialog!);
    }
    return _currentDialog!.add(asm);
  }

  void _addToEvent(Event event, Asm? Function(int eventIndex) generate) {
    var eventIndex = _eventCounter++;

    if (!_inEvent) {
      throw StateError("can't add event when not in event loop");
    } else if (inDialogLoop) {
      // todo: why did we check this before?
      // i think b/c we always assumed in dialog loop to start
      //if (dialogAsm.isNotEmpty) {
      _addToDialog(comment('scene event $eventIndex'));
      _lastEventBreak = _addToDialog(eventBreak());
      _memory.hasSavedDialogPosition = true;
      _gameMode = Mode.event;
    }

    var length = _eventAsm.length;

    var returned = generate(eventIndex);
    if (returned != null) {
      _eventAsm.add(returned);
    }

    if (_eventAsm.length > length) {
      _eventAsm.insert(
          length, Asm([comment('$eventIndex: ${event.runtimeType}')]));
    }

    _lastEventInCurrentDialog = event;
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
    return toAsm().toString();
  }
}

// should track transient state about code generation
// the known values of registers and memory
// should be reset with every event or interaction
// may not be relevant to all generation, for ex map objects
// this is the state of running code
@Deprecated('use Program/SceneAsmGenerator API instead')
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

@Deprecated('use Program API instead')
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

extension EventFlagConstant on EventFlag {
  Constant get toConstant => Constant('EventFlag_$name');
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

class Condition {
  final IMap<EventFlag, bool> _flags;

  Condition(Map<EventFlag, bool> flags) : _flags = flags.lock;
  Condition.empty() : _flags = IMap();

  Condition withFlag(EventFlag flag, bool isSet) => Condition(_flags.unlock
    ..[flag] = isSet
    ..lock);

  Condition withSet(EventFlag flag) => withFlag(flag, true);
  Condition withNotSet(EventFlag flag) => withFlag(flag, false);
  Condition without(EventFlag flag) => Condition(_flags.unlock
    ..remove(flag)
    ..lock);

  Iterable<MapEntry<EventFlag, bool>> get entries => _flags.entries;

  bool? operator [](EventFlag flag) => _flags[flag];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Condition &&
          runtimeType == other.runtimeType &&
          _flags == other._flags;

  @override
  int get hashCode => _flags.hashCode;

  @override
  String toString() {
    return 'Condition{$_flags}';
  }
}

abstract class StateChange<T> {
  T apply(Memory memory);
  mayApply(Memory memory);
}

class SystemState {
  final _inAddress = <DirectAddressRegister, AddressOf>{};
  bool _hasSavedDialogPosition = false;

  void _putInAddress(DirectAddressRegister a, Object? obj) {
    if (obj == null) {
      _inAddress.remove(a);
    } else {
      _inAddress[a] = AddressOf(obj);
    }
  }

  SystemState branch() {
    return SystemState()
      .._inAddress.addAll(_inAddress)
      .._hasSavedDialogPosition = _hasSavedDialogPosition;
  }
}

class Memory implements EventState {
  final List<StateChange> _changes = [];
  final SystemState _sysState;
  final EventState _eventState;

  Memory()
      : _sysState = SystemState(),
        _eventState = EventState();
  Memory.from(this._sysState, this._eventState);

  @override
  Memory branch() => Memory.from(_sysState.branch(), _eventState.branch());

  set hasSavedDialogPosition(bool saved) {
    _apply(SetSavedDialogPosition(saved));
  }

  bool get hasSavedDialogPosition => _sysState._hasSavedDialogPosition;

  AddressOf? inAddress(DirectAddressRegister a) => _sysState._inAddress[a];

  /// [obj] should not be wrapped in [AddressOf].
  void putInAddress(DirectAddressRegister a, Object? obj) {
    _apply(PutInAddress(a, obj));
  }

  @override
  Positions get positions => _Positions(this);
  @override
  Slots get slots => _Slots(this);

  @override
  Axis? get startingAxis => _eventState.startingAxis;

  @override
  set startingAxis(Axis? a) {
    _apply(SetStartingAxis(a));
  }

  @override
  bool? get followLead => _eventState.followLead;

  @override
  set followLead(bool? follow) => _apply(SetValue<bool>(follow,
      (m) => m._eventState.followLead, (f, m) => m._eventState.followLead = f));

  @override
  bool? get cameraLock => _eventState.cameraLock;

  @override
  set cameraLock(bool? lock) => _apply(SetValue<bool>(lock,
      (m) => m._eventState.cameraLock, (l, m) => m._eventState.cameraLock = l));

  @override
  GameMap? get currentMap => _eventState.currentMap;
  @override
  set currentMap(GameMap? map) => _apply(SetValue<GameMap>(
      map,
      (m) => m._eventState.currentMap,
      (map, m) => m._eventState.currentMap = map));

  @override
  Direction? getFacing(FieldObject obj) => _eventState.getFacing(obj);

  @override
  void setFacing(FieldObject obj, Direction dir) {
    _apply(SetFacing(obj, dir));
  }

  @override
  void clearFacing(FieldObject obj) {
    // TODO: implement clearFacing
  }

  @override
  int? slotFor(Character c) => _eventState.slotFor(c);
  @override
  int get numCharacters => _eventState.numCharacters;
  @override
  void setSlot(int slot, Character c) {
    _apply(SetSlot(slot, c));
  }

  @override
  void clearSlot(int slot) {
    _apply(SetSlot(slot, null));
  }

  @override
  void addCharacter(Character c,
      {int? slot, Position? position, Direction? facing}) {
    if (slot != null) slots[slot] = c;
    if (position != null) positions[c] = position;
    if (facing != null) setFacing(c, facing);
  }

  T _apply<T>(StateChange<T> change) {
    _changes.add(change);
    return change.apply(this);
  }
}

class _Positions implements Positions {
  final Memory _memory;

  _Positions(this._memory);

  @override
  Position? operator [](FieldObject obj) => _memory._eventState.positions[obj];

  @override
  void operator []=(FieldObject obj, Position? p) {
    _memory._apply(SetPosition(obj, p));
  }

  @override
  void addAll(Positions p) {
    _memory._apply(AddAllPositions(p));
  }

  @override
  void forEach(Function(FieldObject obj, Position pos) func) {
    _memory._eventState.positions.forEach(func);
  }
}

class _Slots implements Slots {
  final Memory _memory;

  _Slots(this._memory);

  @override
  Character? operator [](int slot) => _memory._eventState.slots[slot];

  @override
  void operator []=(int slot, Character? c) =>
      _memory._eventState.slots[slot] = c;

  @override
  int? slotFor(Character c) => _memory._eventState.slots.slotFor(c);

  @override
  int get numCharacters => _memory._eventState.numCharacters;

  @override
  void addAll(Slots slots) {
    _memory._apply(AddAllSlots(slots));
  }

  @override
  void forEach(Function(int slot, Character c) func) {
    _memory._eventState.slots.forEach(func);
  }
}

// TODO: if prior value is same, then "may apply" can keep same value
// e.g. if

class SetSavedDialogPosition implements StateChange {
  final bool saved;

  SetSavedDialogPosition(this.saved);

  @override
  apply(Memory memory) {
    memory._sysState._hasSavedDialogPosition = saved;
  }

  @override
  mayApply(Memory memory) {
    memory._sysState._hasSavedDialogPosition = false;
  }
}

class PutInAddress implements StateChange {
  final DirectAddressRegister register;
  final Object? obj;

  PutInAddress(this.register, this.obj);

  @override
  apply(Memory memory) {
    memory._sysState._putInAddress(register, obj);
  }

  @override
  mayApply(Memory memory) {
    memory._sysState._putInAddress(register, null);
  }
}

class SetFacing implements StateChange {
  final FieldObject obj;
  final Direction dir;

  SetFacing(this.obj, this.dir);

  @override
  apply(Memory memory) {
    memory._eventState.setFacing(obj, dir);
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.clearFacing(obj);
  }
}

class SetSlot implements StateChange {
  final int slot;
  final Character? char;

  SetSlot(this.slot, this.char);

  @override
  apply(Memory memory) {
    var c = char;
    if (c == null) {
      memory._eventState.clearSlot(slot);
    } else {
      memory._eventState.setSlot(slot, c);
    }
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.clearSlot(slot);
  }
}

class AddAllSlots implements StateChange {
  final Slots slots;

  AddAllSlots(this.slots);

  @override
  apply(Memory memory) {
    memory._eventState.slots.addAll(slots);
  }

  @override
  mayApply(Memory memory) {
    slots.forEach((slot, c) => memory._eventState.slots[slot] = null);
  }
}

class SetPosition implements StateChange {
  final FieldObject obj;
  final Position? pos;

  SetPosition(this.obj, this.pos);

  @override
  apply(Memory memory) {
    memory._eventState.positions[obj] = pos;
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.positions[obj] = null;
  }
}

class AddAllPositions implements StateChange {
  final Positions positions;

  AddAllPositions(this.positions);

  @override
  apply(Memory memory) {
    memory._eventState.positions.addAll(positions);
  }

  @override
  mayApply(Memory memory) {
    positions.forEach((obj, pos) => memory._eventState.positions[obj] = null);
  }
}

class SetStartingAxis implements StateChange {
  final Axis? axis;

  SetStartingAxis(this.axis);

  @override
  apply(Memory memory) {
    memory._eventState.startingAxis = axis;
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.startingAxis = null;
  }
}

class SetValue<T> implements StateChange {
  final T? _val;
  final T? Function(Memory) _get;
  final void Function(T?, Memory) _set;

  SetValue(this._val, this._get, this._set);

  @override
  apply(Memory memory) {
    _set(_val, memory);
  }

  @override
  mayApply(Memory memory) {
    // todo: not sure about this?
    if (_get(memory) != _val) {
      _set(null, memory);
    }
  }
}
