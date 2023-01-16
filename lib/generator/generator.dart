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
import 'package:rune/src/null.dart';

import '../asm/asm.dart';
import '../asm/dialog.dart';
import '../asm/dialog.dart' as asmdialoglib;
import '../asm/events.dart';
import '../asm/events.dart' as asmeventslib;
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
import 'text.dart' as textlib;

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

  final dialogTrees = DialogTrees();

  final Asm _eventPointers = Asm.empty();
  Asm get eventPointers => Asm([_eventPointers]);

  Word _eventIndexOffset;
  Word get peekNextEventIndex => _eventIndexOffset;

  final Asm _cutscenesPointers = Asm.empty();
  Asm get cutscenesPointers => Asm([_cutscenesPointers]);
  Word _cutsceneIndexOffset;

  final Map<MapId, Word> _vramTileOffsets = {};

  Program({
    Word? eventIndexOffset,
    Word? cutsceneIndexOffset,
    Map<MapId, Word>? vramTileOffsets,
  })  : _eventIndexOffset = eventIndexOffset ?? 0xa1.toWord,
        _cutsceneIndexOffset = cutsceneIndexOffset ?? 0x22.toWord {
    _vramTileOffsets.addAll(vramTileOffsets ?? _defaultSpriteVramOffsets);
  }

  /// Returns event index by which [routine] can be referenced.
  ///
  /// The event code must be added separate with the exact label of [routine].
  Word _addEventPointer(Label routine) {
    var eventIndex = _eventIndexOffset;
    _eventPointers.add(dc.l([routine], comment: '$eventIndex'));
    _eventIndexOffset = (_eventIndexOffset.value + 1).toWord;
    return eventIndex;
  }

  /// Returns event index by which [routine] can be referenced.
  ///
  /// The event code must be added separate with the exact label of [routine].
  Word _addCutscenePointer(Label routine) {
    var cutsceneIndex = _cutsceneIndexOffset;
    _cutscenesPointers.add(dc.l([routine], comment: '$cutsceneIndex'));
    _cutsceneIndexOffset = (cutsceneIndex.value + 1).toWord;
    return (cutsceneIndex + Word(0x8000)) as Word;
  }

  SceneAsm addScene(SceneId id, Scene scene, {GameMap? startingMap}) {
    var eventAsm = EventAsm.empty();
    var generator = SceneAsmGenerator.forEvent(id, dialogTrees, eventAsm,
        startingMap: startingMap);

    for (var event in scene.events) {
      event.visit(generator);
    }

    generator.finish();

    return _scenes[id] = SceneAsm(event: eventAsm);
  }

  MapAsm addMap(GameMap map) {
    // trees are already written to, and we don't know which ones, and which
    // branches
    if (_maps.containsKey(map.id)) {
      throw ArgumentError.value(
          map.id.name, 'map', 'map with same id already added');
    }

    var spriteVramOffset = _vramTileOffsets[map.id];
    return _maps[map.id] = compileMap(
        map, _ProgramEventRoutines(this), spriteVramOffset,
        dialogTrees: dialogTrees);
  }
}

abstract class EventRoutines {
  Word addEvent(Label name);
  Word addCutscene(Label name);
}

class _ProgramEventRoutines extends EventRoutines {
  final Program _program;

  _ProgramEventRoutines(this._program);

  @override
  Word addEvent(Label routine) => _program._addEventPointer(routine);

  @override
  Word addCutscene(Label routine) => _program._addCutscenePointer(routine);
}

class SceneAsmGenerator implements EventVisitor {
  final SceneId id;

  // Non-volatile state (state of the code being generated)
  final DialogTrees _dialogTrees;
  final EventAsm _eventAsm;
  // required if processing interaction (see todo on ctor)
  EventRoutines? _eventRoutines;
  //final Byte _dialogIdOffset;

  Mode _gameMode = Mode.event;
  bool get inDialogLoop => _gameMode == Mode.dialog;

  // i think this should always be true if mode == event?
  /// Whether or not we are generating in the context of an existing event.
  ///
  /// This is necessary to understand whether, when in dialog mode, we can pop
  /// back to an event or have to trigger a new one.
  bool get _inEvent => _eventType != null;
  EventType? _eventType;

  final FieldObject? _interactingWith;
  bool get _isProcessingInteraction => _interactingWith != null;

  DialogTree? _dialogTree;
  Byte? _currentDialogId;
  DialogAsm? _currentDialog;
  var _lastEventBreak = -1;
  Event? _lastEventInCurrentDialog;
  var _eventCounter = 1;
  var _finished = false;
  Function([int? dialogRoutine])? _replaceDialogRoutine;
  //var _lastFadeOut = -1;

  // conditional runtime state
  /// For currently generating branch, what is the known state of event flags
  Condition _currentCondition = Condition.empty();

  /// mem state which exactly matches current flags; other states may need
  /// updates
  Memory _memory = Memory(); // todo: ctor initialization
  /// should also contain root state
  final _stateGraph = <Condition, Memory>{};

  // todo: This might be a subclass really
  SceneAsmGenerator.forInteraction(GameMap map, this.id, this._dialogTrees,
      this._eventAsm, EventRoutines eventRoutines)
      : //_dialogIdOffset = _dialogTree.nextDialogId!,
        _interactingWith = const InteractionObject(),
        _eventRoutines = eventRoutines {
    _gameMode = Mode.dialog;

    _memory.putInAddress(a3, const InteractionObject());
    _memory.hasSavedDialogPosition = false;
    _memory.currentMap = map;
    _memory.loadedDialogTree = _dialogTrees.forMap(map.id);
    _stateGraph[Condition.empty()] = _memory;
  }

  SceneAsmGenerator.forEvent(this.id, this._dialogTrees, this._eventAsm,
      {GameMap? startingMap})
      : //_dialogIdOffset = _dialogTree.nextDialogId!,
        _interactingWith = null,
        // FIXME: also parameterize eventtype so finish() does the right thing
        _eventType = EventType.event {
    _memory.currentMap = startingMap;
    if (startingMap != null) {
      _memory.loadedDialogTree = _dialogTrees.forMap(startingMap.id);
    }
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
  EventType? needsEvent(List<Event> events) {
    // SetContext is not a perceivable event, so ignore
    events = events.whereNot((e) => e is SetContext).toList(growable: false);

    if (events.length == 1 && events[0] is IfFlag) return null;

    var dialogCheck = 0;
    var dialogChecks = <bool Function(Event, int)>[
      (event, i) => event is FacePlayer && event.object == _interactingWith,
      (event, i) =>
          (event is Dialog && !event.hidePanelsOnClose) ||
          event is PlaySound ||
          event is ShowPanel,
      (event, i) =>
          event is Dialog && event.hidePanelsOnClose && i == events.length - 1,
    ];

    var faded = false;
    var needsEvent = false;

    event:
    for (int i = 0; i < events.length; i++) {
      var event = events[i];
      for (var cIdx = dialogCheck;
          cIdx < dialogChecks.length && !needsEvent;
          cIdx++) {
        if (dialogChecks[cIdx](event, i)) {
          dialogCheck = cIdx;
          continue event;
        }
      }

      needsEvent = true;

      if (event is FadeOut) {
        faded = true;
      } else if (event is FadeInField) {
        faded = false;
      } else if (event is Dialog && faded) {
        return EventType.cutscene;
      }
    }

    if (needsEvent) return EventType.event;

    return null;
  }

  void runEventFromInteractionIfNeeded(List<Event> events,
      {Word? eventIndex, String? nameSuffix}) {
    var type = needsEvent(events);
    if (type == null) return;
    runEventFromInteraction(
        type: type, eventIndex: eventIndex, nameSuffix: nameSuffix);
  }

  /// If in interaction and not yet in an event, run an event from dialog.
  ///
  /// If [eventIndex] is not provided, a new event will be added with optional
  /// [nameSuffix].
  void runEventFromInteraction(
      {Word? eventIndex,
      String? nameSuffix,
      EventType type = EventType.event}) {
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
      eventIndex = type.addRoutine(_eventRoutines!, eventRoutine);
      _eventAsm.add(setLabel(eventRoutine.name));
    }

    _addToDialog(asmdialoglib.runEvent(eventIndex));
    _eventType = type;

    _terminateDialog();
  }

  @override
  void asm(AsmEvent asm) {
    _addToEvent(asm, (i) => asm.asm);
  }

  @override
  void dialog(Dialog dialog) {
    _checkNotFinished();
    _runOrInterruptDialog();
    _addToDialog(dialog.toAsm(_memory));
    _lastEventInCurrentDialog = dialog;
  }

  @override
  void displayText(DisplayText display) {
    _addToEvent(display, (i) {
      _terminateDialog();
      var asm = textlib.displayTextToAsm(display, _currentDialogTree());
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
        (i) => EventAsm.of(asmeventslib.lockCamera(_memory.cameraLock = true)));
  }

  @override
  void partyMove(PartyMove move) {
    _addToEvent(move, (i) => move.toIndividualMoves(_memory).toAsm(_memory));
  }

  @override
  void pause(Pause pause) {
    // Cannot be done in dialog because,
    // while dialog supports pausing,
    // it will show a dialog window during the pause.

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
    _addToEvent(
        unlock,
        (i) =>
            EventAsm.of(asmeventslib.lockCamera(_memory.cameraLock = false)));
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
      var ifSetId = _currentDialogTree().add(ifSet);
      var ifSetOffset = ifSetId - currentDialogId as Byte;

      // memory may change while flag is set, so remember this to branch
      // off of for unset branch
      var parent = _memory;

      _addToDialog(eventCheck(flag.toConstant, ifSetOffset));
      _flagIsNotSet(flag);

      runEventFromInteractionIfNeeded(ifFlag.isUnset,
          nameSuffix: '${ifFlag.flag.name}_unset');

      for (var event in ifFlag.isUnset) {
        event.visit(this);
      }

      // Wrap up this branch
      _finish(appendNewline: true);

      if (_inEvent) {
        // we may be in event now, but we have to go back to dialog generation
        // since we're playing out the "isSet" branch now
        _eventType = null;
        _gameMode = Mode.dialog;
      }

      _resetCurrentDialog(id: ifSetId, asm: ifSet);
      _flagIsSet(flag, parent: parent);

      runEventFromInteractionIfNeeded(ifFlag.isSet,
          nameSuffix: '${ifFlag.flag.name}_set');

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
        finish(appendNewline: true);
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
    if (_memory.isFieldShown == true) return;

    _addToEvent(fadeIn, (eventIndex) {
      var wasFieldShown = _memory.isFieldShown;
      var needsRefresh =
          _memory.isMapInCram != true || _memory.isMapInVram != true;

      _memory.isFieldShown = true;
      _memory.isMapInVram = true;
      _memory.isMapInCram = true;

      return Asm([
        if (wasFieldShown == false && (_memory.panelsShown ?? 0) > 0)
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
        // I guess we assume map was the same as before
        // so no need to reload secondary objects
        // LoadMap events take care of that
        if (needsRefresh) refreshMap(refreshObjects: false),
        jsr(Label('Pal_FadeIn').l)
      ]);
    });
  }

  @override
  void fadeOut(FadeOut fadeOut) {
    _addToEvent(fadeOut, (eventIndex) {
      _memory.isFieldShown = false;
      _memory.isMapInCram = false;
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

      //_lastFadeOut =
      _eventAsm.add(asmeventslib.fadeOut(initVramAndCram: false));

      return null;
    });
  }

  @override
  void loadMap(LoadMap loadMap) {
    _checkNotFinished();

    var currentMap = _memory.currentMap;
    var newMap = loadMap.map;

    var currentId = currentMap?.map((m) => _asmMapIdOf(m.id));
    var newId = _asmMapIdOf(newMap.id);
    var x = loadMap.startingPosition.x ~/ 8;
    var y = loadMap.startingPosition.y ~/ 8;
    var facing = loadMap.facing.constant;
    var alignByte = loadMap.arrangement.map((a) {
      switch (a) {
        case PartyArrangement.overlapping:
          return 0;
        case PartyArrangement.belowLead:
          return 4;
        case PartyArrangement.aboveLead:
          return 8;
        case PartyArrangement.leftOfLead:
          return 0xC;
        case PartyArrangement.rightOfLead:
          return 0x10;
      }
    });

    _addToEvent(loadMap, (eventIndex) {
      if (loadMap.showField) {
        if (_memory.isDisplayEnabled == false) {
          if (_memory.isMapInCram != false) {
            _eventAsm.add(asmeventslib.fadeOut());
            _memory.isMapInCram = false;
          }
          _eventAsm.add(jsr(Label('Pal_FadeIn').l));
          _eventAsm.add(jsr(Label('VInt_Prepare').l));
          _memory.isDisplayEnabled = true;
        }
      }

      return asmeventslib.changeMap(
          to: newId.i,
          from: currentId?.i,
          startX: x.i,
          startY: y.i,
          facingDir: facing.i,
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
    _memory.isMapInVram = true;
  }

  @override
  void showPanel(ShowPanel showPanel) {
    var index = showPanel.panel.panelIndex;

    if (showPanel.showDialogBox) {
      _runOrInterruptDialog();
      _memory.addPanel();

      _addToDialog(Asm([
        if (_memory.dialogPortrait != const UnnamedSpeaker())
          portrait(const UnnamedSpeaker().portraitCode),
        dc.b([Byte(0xf2), Byte.zero]),
        dc.w([Word(index)]),
      ]));

      _lastEventInCurrentDialog = showPanel;
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

  @override
  void playSound(PlaySound playSound) {
    if (inDialogLoop) {
      if (_lastEventInCurrentDialog is Dialog) {
        // Panel should come after this Dialog;
        // otherwise gets rendered before player continues
        _addToDialog(interrupt());
      }

      _addToDialog(dc.b([Byte(0xf2), Byte(3)]));
      _addToDialog(dc.b([playSound.sound.sfxId]));

      _lastEventInCurrentDialog = playSound;
    } else {
      _addToEvent(playSound,
          (_) => move.b(playSound.sound.sfxId.i, Constant('Sound_Index').l));
    }
  }

  void finish({bool appendNewline = false}) {
    // todo: also apply all changes for current mem across graph
    // not sure if still need to do this
    // seems useless because memory won't ever be consulted again after
    // finishing

    if (!_finished) {
      _finish(appendNewline: false);
      _dialogTree?.finish();
      _finished = true;
    }

    if (appendNewline && _eventAsm.isNotEmpty && _eventAsm.last.isNotEmpty) {
      _eventAsm.addNewline();
    }
  }

  void _finish({bool appendNewline = false}) {
    if (_inEvent) {
      if (_isProcessingInteraction) {
        if (_eventType == EventType.cutscene) {
          var reload = _memory.isFieldShown != true;
          // clears z bit so we don't reload the map from cutscene
          _eventAsm.add(moveq(reload ? 0.i : 1.i, d0));
          _eventAsm.add(rts);
          if (reload) {
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
        } else {
          if (_memory.isFieldShown != true) {
            fadeInField(FadeInField());
          }
          _eventAsm.add(returnFromDialogEvent());
        }
      } else {
        if (_memory.isFieldShown != true) {
          fadeInField(FadeInField());
        }
      }
    }

    _terminateDialog();

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

  void _runOrInterruptDialog() {
    _expectFacePlayerFirstIfInteraction();

    if (!inDialogLoop) {
      _runDialog();
    } else if (_lastEventInCurrentDialog is Dialog) {
      // Add cursor for previous dialog
      // This is delayed because this interrupt may be a termination
      _addToDialog(interrupt());
    }
  }

  void _expectFacePlayerFirstIfInteraction() {
    if (!_inEvent &&
        _isProcessingInteraction &&
        _lastEventInCurrentDialog == null) {
      // Not starting with face player, so signal not to.
      _addToDialog(dc.b(Bytes.of(0xf3)));
    }
  }

  void _runDialog() {
    // todo: differentiate "walking" from "still" states
    /*
      idea here is that if done moving for a frame, or have called update
      facing, then the character is known to be still.
      otherwise, the character might be mid-movement frame, which is awkward
      when going to dialog. if walking, and going to dialog, we could call
      update facing to ensure still.
       */
    // var lastEvent = _lastEventInCurrentDialog;
    // if (lastEvent is IndividualMoves) {
    //   for (var obj in lastEvent.moves.keys) {
    //   }
    // }

    _eventAsm.add(Asm([comment('${_eventCounter++}: $Dialog')]));

    // todo if null, have to check somehow?
    // todo: not sure if this is right
    if (_memory.isFieldShown == false) {
      if (_memory.isDisplayEnabled == false) {
        // if cram cleared but vram not,
        // fading in will cause artifacts
        // otherwise, fade in may fade in map,
        // but consider this intentional
        if (_memory.isMapInVram == true && _memory.isMapInCram == false) {
          _initVramAndCram();
        }
        _eventAsm.add(jsr(Label('Pal_FadeIn').l));
        _memory.isDisplayEnabled = true;
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
      var dialogId = _currentDialogIdOrStart().i;
      _eventAsm.add(moveq(dialogId, d0));
      var line = _eventAsm.add(jsr(Label('Event_GetAndRunDialogue3').l));
      _replaceDialogRoutine = ([i]) => _eventAsm.replace(
          line, jsr(Label('Event_GetAndRunDialogue${i ?? ""}').l));
    }

    _gameMode = Mode.dialog;
  }

  /// Terminates the current dialog, if there is any,
  /// regardless of whether current generating within dialog loop or not.
  void _terminateDialog({bool? hidePanels}) {
    if (inDialogLoop) {
      _addToDialog(terminateDialog());
      if (_inEvent) {
        _gameMode = Mode.event;
      }
    } else if (_lastEventBreak >= 0) {
      // i think this is only ever the last line so could simplify
      _currentDialog!.replace(_lastEventBreak, terminateDialog());
    }

    // fixme: hidePanels tracking not implemented yet
    //   (remember from last dialog event?)
    // if replace routine is null,
    // this should mean that we are processing interaction and not in event
    // so panels will be hidden as interaction ends normally
    if (hidePanels == true && _replaceDialogRoutine != null) {
      _replaceDialogRoutine!();
    }

    if (hidePanels == false && _isProcessingInteraction && !_inEvent) {
      throw StateError('ending interaction without event cannot keep panels, '
          'but hidePanels == false');
    }

    _memory.dialogPortrait = UnnamedSpeaker();

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

  void _addToEvent(Event event, Asm? Function(int eventIndex) generate) {
    _checkNotFinished();

    var eventIndex = _eventCounter++;

    if (!_inEvent) {
      throw StateError("can't add event when not in event loop");
    } else if (inDialogLoop) {
      // 🐞 note that if we need to do this after a dialog loop event
      // which does not show a dialog box (e.g. panel)
      // then this will result in an extra dialog box appearing and
      // extra button press required before breaking to the event
      // see: https://trello.com/c/LhjcgZkZ

      _addToDialog(comment('scene event $eventIndex'));
      _lastEventBreak = _addToDialog(eventBreak());
      _memory.hasSavedDialogPosition = true;
      _memory.dialogPortrait = UnnamedSpeaker();
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

  void _initVramAndCram() {
    if (_memory.isDisplayEnabled != false) {
      // doesn't hurt if we do this while already disabled i guess
      _eventAsm.add(asmeventslib.fadeOut(initVramAndCram: true));
      _memory.isDisplayEnabled = false;
    } else {
      // var lastFadeOut = _lastFadeOut;
      // if (lastFadeOut == -1) {
      var last = _lastLineIfFadeOut(_eventAsm);
      if (last != null) {
        _eventAsm.replace(last, asmeventslib.fadeOut(initVramAndCram: true));
      } else {
        _eventAsm.add(jsr(Label('InitVRAMAndCRAMAfterFadeOut').l));
      }
      // } else {
      //   _eventAsm.replace(
      //       lastFadeOut, asmeventslib.fadeOut(initVramAndCram: true));
      // }
    }
    _memory.isMapInCram = false;
    _memory.isMapInVram = false;
    _memory.isFieldShown = false;
  }
}

int? _lastLineIfFadeOut(Asm asm) {
  for (var i = asm.lines.length - 1; i >= 0; --i) {
    var line = asm.lines[i];
    if (line.isCommentOnly) continue;
    if (line == asmeventslib.fadeOut(initVramAndCram: false).first) {
      return i;
    }
    break;
  }
  return null;
}

enum Mode { dialog, event }

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
  void finish() {
    for (var dialog in _dialogs) {
      if (dialog.dialogs != 1) {
        throw ArgumentError.value(dialog, 'dialog', '.dialogs must be == 1');
      }
    }
  }

  /// The ID of the next dialog that would be added.
  Byte? get nextDialogId =>
      _dialogs.length > Size.b.maxValue ? null : _dialogs.length.toByte;

  DialogAsm operator [](int index) {
    return _dialogs[index];
  }

  Asm toAsm({bool ensureFinished = true}) {
    if (ensureFinished) finish();

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

extension Sfxid on Sound {
  static Constant _defaultConstant(Sound s) {
    var first = s.name.substring(0, 1);
    var rest = s.name.substring(1);
    return Constant('SFXID_${first.toUpperCase()}$rest');
  }

  Expression get sfxId {
    switch (this) {
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

extension EventFlagConstant on EventFlag {
  Constant get toConstant {
    // todo: not all event flags are named constants
    // see toEventFlag
    return Constant('EventFlag_$name');
  }
}

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

Constant _asmMapIdOf(MapId map) {
  switch (map) {
    case MapId.ShayHouse:
      return Constant('MapID_ChazHouse');
    case MapId.PiataAcademyF1:
      return Constant('MapID_PiataAcademy_F1');
    case MapId.PiataAcademyPrincipalOffice:
      return Constant('MapID_AcademyPrincipalOffice');
    case MapId.PiataAcademyBasement:
      return Constant('MapID_AcademyBasement');
    case MapId.PiataAcademyBasementB1:
      return Constant('MapID_AcademyBasement_B1');
    case MapId.PiataAcademyBasementB2:
      return Constant('MapID_AcademyBasement_B2');
    default:
      return Constant('MapID_${map.name}');
  }
}

// These offsets are used to account for assembly specifics, which allows for
// variances in maps to be coded manually (such as objects).
// todo: it might be nice to manage these with the assembly or the compiler
//  itself rather than hard coding here.
//  Program API would be the right place now that we have that.
// todo: see generator/map.dart for more of stuff like this

// generated via dart bin/macro.dart vram-tile-offsets | gsed -E 's/([^,]+),(.*)/Label('"'"'\1'"'"'): Word(\2),/'
final Map<MapId, Word> _defaultSpriteVramOffsets = {
  Label('Map_Test'): Word(0x2d0),
  Label('Map_Dezolis'): Word(0x39b),
  Label('Map_Piata'): Word(0x2d0),
  Label('Map_PiataAcademy'): Word(0x27f),
  Label('Map_PiataAcademy_F1'): Word(0x27f),
  Label('Map_AcademyPrincipalOffice'): Word(0x27f),
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
