import '../asm/asm.dart';
import '../asm/events.dart';
import '../model/model.dart';
import '../numbers.dart';
import 'dialog.dart';
import 'event.dart';
import 'generator.dart';
import 'memory.dart';
import 'movement.dart';
import 'scene.dart';

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

  DialogAsm dialogToAsm(Dialog dialog) {
    return _wrapException(() => dialog.toAsm(), null, dialog);
  }

  EventAsm individualMovesToAsm(IndividualMoves move, AsmContext ctx) {
    return _wrapException(
        () => move.toAsm(Memory.from(SystemState(), ctx.state)), ctx, move);
  }

  EventAsm partyMoveToAsm(RelativePartyMove move, AsmContext ctx) {
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
