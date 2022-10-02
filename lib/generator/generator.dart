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

import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../asm/asm.dart';
import '../asm/dialog.dart';
import '../asm/dialog.dart' as asmdialog;
import '../asm/events.dart';
import '../asm/events.dart' as asmevents;
import '../asm/text.dart';
import '../model/conditional.dart';
import '../model/model.dart';
import '../model/text.dart';
import 'cutscenes.dart';
import 'dialog.dart';
import 'event.dart';
import 'map.dart';
import 'memory.dart';
import 'movement.dart';
import 'scene.dart';
import 'text.dart' as text;

export '../asm/asm.dart' show Asm;
export 'deprecated.dart';

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
    var builder = MapAsmBuilder(map, _ProgramEventRoutines(this));
    for (var obj in map.objects) {
      builder.addObject(obj);
    }
    return _maps[map.id] = builder.build();
  }
}

abstract class EventRoutines {
  Word addEvent(Label name);
  //Word addCutscene(Label name);
}

class _ProgramEventRoutines extends EventRoutines {
  final Program _program;

  _ProgramEventRoutines(this._program);

  @override
  Word addEvent(Label routine) => _program._addEventPointer(routine);
}

class _AsmEvent extends Event {
  @override
  void visit(EventVisitor visitor) {}
}

class SceneAsmGenerator implements EventVisitor {
  final SceneId id;

  // Non-volatile state (state of the code being generated)
  final DialogTree _dialogTree;
  final EventAsm _eventAsm;
  // required if processing interaction (see todo on ctor)
  EventRoutines? _eventRoutines;
  final Byte _dialogIdOffset;

  Mode _gameMode = Mode.event;
  bool get inDialogLoop => _gameMode == Mode.dialog;

  // i think this should always be true if mode == event?
  /// Whether or not we are generating in the context of an existing event.
  ///
  /// This is necessary to understand whether, when in dialog mode, we can pop
  /// back to an event or have to trigger a new one.
  bool _inEvent;

  final FieldObject? _interactingWith;
  bool get _isProcessingInteraction => _interactingWith != null;

  Byte? _currentDialogId;
  DialogAsm? _currentDialog;
  var _lastEventBreak = -1;
  Event? _lastEventInCurrentDialog;
  var _eventCounter = 1;
  var _finished = false;

  // conditional runtime state
  /// For currently generating branch, what is the known state of event flags
  Condition _currentCondition = Condition.empty();

  /// mem state which exactly matches current flags; other states may need
  /// updates
  Memory _memory = Memory(); // todo: ctor initialization
  /// should also contain root state
  final _stateGraph = <Condition, Memory>{};

  // todo: This might be a subclass really
  SceneAsmGenerator.forInteraction(GameMap map, FieldObject obj, this.id,
      this._dialogTree, this._eventAsm, EventRoutines eventRoutines)
      : _dialogIdOffset = _dialogTree.nextDialogId!,
        _interactingWith = obj,
        _eventRoutines = eventRoutines,
        _inEvent = false {
    _gameMode = _inEvent ? Mode.event : Mode.dialog;

    _memory.putInAddress(a3, obj);
    _memory.hasSavedDialogPosition = false;
    _memory.currentMap = map;
    _stateGraph[Condition.empty()] = _memory;
  }

  SceneAsmGenerator.forEvent(this.id, this._dialogTree, this._eventAsm)
      : _dialogIdOffset = _dialogTree.nextDialogId!,
        _interactingWith = null,
        _inEvent = true {
    _gameMode = Mode.event;
    _stateGraph[Condition.empty()] = _memory;
  }

  void scene(Scene scene) {
    for (var event in scene.events) {
      event.visit(this);
    }
  }

  /// Returns true if an event routine is needed in code generated for [events].
  ///
  /// Reproduces logic in Interaction_ProcessDialogueTree to see if the events
  /// can be processed soley through dialog loop.
  ///
  /// Returns `false` if events occur in the following order:
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
  /// See also: [runEventFromInteraction]
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
  bool needsEvent(List<Event> events) {
    var obj = _interactingWith;
    if (obj == null) return true; // todo: not quite sure about this
    if (events.length == 1 && events[0] is IfFlag) return false;

    var check = 0;
    var checks = <bool Function(Event)>[
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
      return true;
    }

    return false;
  }

  /// If in interaction and not yet in an event, run an event from dialog.
  ///
  /// If [eventIndex] is not provided, a new event will be added with optional
  /// [nameSuffix].
  void runEventFromInteraction({Word? eventIndex, String? nameSuffix}) {
    _checkNotFinished();

    if (_inEvent) {
      throw StateError('cannot run event; already in event');
    }

    if (_lastEventInCurrentDialog != null &&
        _lastEventInCurrentDialog is! IfFlag) {
      throw StateError('can only run events first or after IfFlag events '
          'but last event was $_lastEventInCurrentDialog');
    }

    if (eventIndex == null) {
      // only include event counter if we're in a branch condition
      // todo: we might not always start with an empty condition so this should
      // maybe be something about root or starting condition
      var eventName = nameSuffix == null
          ? '$id${_currentCondition == Condition.empty() ? '' : _eventCounter}'
          : '$id$nameSuffix';
      var eventRoutine = Label('Event_GrandCross_$eventName');
      eventIndex = _eventRoutines!.addEvent(eventRoutine);
      _eventAsm.add(setLabel(eventRoutine.name));
    }

    _addToDialog(asmdialog.runEvent(eventIndex));
    _inEvent = true;

    _terminateDialog();
  }

  @override
  void asm(Asm asm) {
    _addToEvent(_AsmEvent(), (i) => asm);
  }

  @override
  void dialog(Dialog dialog) {
    _checkNotFinished();

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
    _checkNotFinished();

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
    _checkNotFinished();
    set(_memory);
  }

  @override
  void unlockCamera(UnlockCamera unlock) {
    _addToEvent(unlock,
        (i) => EventAsm.of(asmevents.lockCamera(_memory.cameraLock = false)));
  }

  @override
  void ifFlag(IfFlag ifFlag) {
    _checkNotFinished();

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
      // this must be the only event in the dialog in that case,
      // because it is treated as a hard fork.
      // there can be no common events as there is no one scene now;
      // it is split into two after this.

      var ifSet = DialogAsm.empty();
      var currentDialogId = _currentDialogIdOrStart();
      var ifSetId = _dialogTree.add(ifSet);
      var ifSetOffset = ifSetId - currentDialogId as Byte;

      // memory may change while flag is set, so remember this to branch
      // off of for unset branch
      var parent = _memory;

      _addToDialog(eventCheck(flag.toConstant, ifSetOffset));
      _flagIsNotSet(flag);

      if (needsEvent(ifFlag.isUnset)) {
        runEventFromInteraction(nameSuffix: '${ifFlag.flag.name}Unset');
      }

      for (var event in ifFlag.isUnset) {
        event.visit(this);
      }

      if (_inEvent) {
        if (_isProcessingInteraction) {
          _eventAsm.add(returnFromDialogEvent());
        }
        // we may be in event now, but we have to go back to dialog generation
        // since we're playing out the "isSet" branch now
        _inEvent = false;
        _gameMode = Mode.dialog;
      }

      // Either way, terminate dialog if there is any.
      _terminateDialog();
      _resetCurrentDialog(id: ifSetId, asm: ifSet);
      _flagIsSet(flag, parent: parent);

      if (needsEvent(ifFlag.isSet)) {
        runEventFromInteraction(nameSuffix: '${ifFlag.flag.name}Set');
      }

      for (var event in ifFlag.isSet) {
        event.visit(this);
      }

      _flagUnknown(flag);

      // no more events can be added
      // because we would have to add them to both branches
      // which is not supported when starting from dialog loop
      // todo: finished is actually a per-branch state,
      //   but we're using 'empty' condition
      //   to proxy for the original state or 'root' state
      if (_currentCondition == Condition.empty()) {
        finish();
      }
    } else {
      _addToEvent(ifFlag, (i) {
        // note that if we need to move further than beq.w
        // we will need to branch to subroutine
        // which then jsr/jmp to another
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

  @override
  void setFlag(SetFlag setFlag) {
    // TODO: can implement in dialog with F2 and B i guess
    _addToEvent(
        setFlag,
        (eventIndex) => Asm([
              moveq(setFlag.flag.toConstant.i, d0),
              jsr('EventFlags_Set'.toLabel.l)
            ]));
  }

  @override
  void fadeInField(FadeInField fadeIn) {
    _addToEvent(fadeIn, (eventIndex) {
      _memory.isFieldShown = true;
      return Asm([
        // Appears to have the same effect as
        // bset 2 flag in LoadFieldMap
        // which skips reloading of secondary objects
        bset(3.i, (Constant('Map_Load_Flags')).w),
        jsr(Label('RefreshMap').l)
      ]);
    });
  }

  @override
  void fadeOutField(FadeOutField fadeOut) {
    _addToEvent(fadeOut, (eventIndex) {
      _memory.isFieldShown = false;
      return Asm([
        // This calls PalFadeOut_ClrSpriteTbl
        // which is what actually does the fade out,
        // Then it clears plane A and VRAM completely,
        // resets camera position,
        // and resets palette
        // It is used often in cutscenes but maybe does too much.
        jsr(Label('InitVRAMAndCRAM').l),
        // I think this just fades in the palette,
        // using the values set from above.
        jsr(Label('Pal_FadeIn').l),
        move.b(1.i, Constant('Render_Sprites_In_Cutscenes').w),
      ]);
    });
  }

  @override
  void showPanel(ShowPanel showPanel) {
    _checkNotFinished();

    var index = showPanel.panel.panelIndex;
    if (inDialogLoop) {
      _memory.addPanel();
      _addToDialog(Asm([
        dc.b([Byte(0xf2), Byte.zero]),
        dc.w([Word(index)]),
      ]));
    } else {
      _addToEvent(showPanel, (_) {
        _memory.addPanel();
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
    if (inDialogLoop) {
      _addToDialog(dc.b([Byte(0xf2), Byte.two]));
    } else {
      _addToEvent(hidePanels, (_) => jsr(Label('Panel_DestroyAll').l));
    }
  }

  @override
  void hideTopPanels(HideTopPanels hidePanels) {
    _checkNotFinished();

    var panels = hidePanels.panelsToHide;
    var panelsShown = _memory.panelsShown;

    if (panelsShown == 0) return;

    if (panelsShown != null) {
      panels = min(panels, panelsShown);
    }

    if (inDialogLoop) {
      _memory.removePanels(panels);

      _addToDialog(Asm([
        for (var i = 0; i < panels; i++) dc.b([Byte(0xf2), Byte.one]),
        // todo: this is used often but not always, how to know when?
        // it might be if the field is not faded out, but not always
        if (_memory.isFieldShown == true) dc.b([Byte(0xf2), Byte(6)]),
      ]));
    } else {
      _addToEvent(hidePanels, (eventIndex) {
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
  }

  void finish({bool appendNewline = false}) {
    // todo: also applfinishy all changes for current mem across graph
    // not sure if still need to do this
    if (!_finished) {
      _finished = true;

      _terminateDialog();

      if (_isProcessingInteraction && _inEvent) {
        _eventAsm.add(returnFromDialogEvent());
      }
    }

    if (appendNewline && _eventAsm.isNotEmpty && _eventAsm.last.isNotEmpty) {
      _eventAsm.addNewline();
    }
  }

  void _checkNotFinished() {
    if (_finished) {
      throw StateError('scene is finished; cannot add more to scene');
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

  /// Terminates the current dialog, if there is any,
  /// regardless of whether current generating within dialog loop or not.
  void _terminateDialog() {
    // was lastEventBreak >= 0, but i think it should be this?
    if (!inDialogLoop && _lastEventBreak >= 0) {
      // i think this is only ever the last line so could simplify
      _currentDialog!.replace(_lastEventBreak, terminateDialog());
    } else if (inDialogLoop && _currentDialog != null) {
      _currentDialog!.add(terminateDialog());
      if (_inEvent) {
        _gameMode = Mode.event;
      }
    }

    _resetCurrentDialog();
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
      _currentDialogId = _dialogTree.nextDialogId;
      _currentDialog = null;
      _lastEventInCurrentDialog = null;
    }

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
    _checkNotFinished();

    if (_currentDialog == null) {
      _currentDialog = DialogAsm.empty();
      _currentDialogId = _dialogTree.add(_currentDialog!);
    }
    return _currentDialog!.add(asm);
  }

  void _addToEvent(Event event, Asm? Function(int eventIndex) generate) {
    _checkNotFinished();

    var eventIndex = _eventCounter++;

    if (!_inEvent) {
      throw StateError("can't add event when not in event loop");
    } else if (inDialogLoop) {
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

extension EventFlagConstant on EventFlag {
  Constant get toConstant => Constant('EventFlag_$name');
}

class Condition {
  final IMap<EventFlag, bool> _flags;

  Condition(Map<EventFlag, bool> flags) : _flags = flags.lock;
  const Condition.empty() : _flags = const IMapConst({});

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
