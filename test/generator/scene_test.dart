import 'package:collection/collection.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/cutscenes.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

import '../fixtures.dart';
import '../fixtures.dart' as fixtures;

void main() {
  late Program program;
  late GameMap map;

  setUp(() {
    program = Program();
    map = GameMap(MapId.Test);
  });

  // Shim for backwards compat with fixture library
  Asm generateEventAsm(List<Event> events, [EventState? ctx]) {
    return fixtures.generateEventAsm(events, context: ctx, inMap: map);
  }

  group('a cursor separates', () {
    test('between dialogs', () {
      var dialog1 = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
      var dialog2 = Dialog(speaker: Shay(), spans: DialogSpan.parse('Hello'));

      var scene = Scene([dialog1, dialog2]);
      program.addScene(SceneId('test'), scene, startingMap: map);

      expect(
          program.dialogTrees
              .forMap(map.id)
              .toAsm()
              .withoutComments()
              .trim()
              .toString(),
          '''${dialog1.toAsm()}
	dc.b	\$FD
${dialog2.toAsm()}
	dc.b	\$FF''');
    });

    test('between dialog and panel', () {
      program.addScene(
          SceneId('test'),
          Scene([
            Dialog(speaker: alys, spans: [DialogSpan('Hi')]),
            Dialog(spans: [DialogSpan('', panel: PrincipalPanel.principal)])
          ]),
          startingMap: map);

      expect(
          program.dialogTrees.forMap(map.id)[0].withoutComments(),
          Asm([
            dc.b([Byte(0xF4), (toPortraitCode(alys.portrait))]),
            dc.b(Bytes.ascii('Hi')),
            dc.b([Byte(0xFD)]),
            dc.b([Byte(0xF4), (toPortraitCode(UnnamedSpeaker().portrait))]),
            dc.b([Byte(0xF2), Byte.zero]),
            dc.w([Word(PrincipalPanel.principal.panelIndex)]),
            dc.b([Byte(0xff)])
          ]));
    });
  });

  group('events', () {
    test('play sounds', () {
      var scene = Scene([(PlaySound(SoundEffect.selection))]);
      var program = Program();
      var asm = program.addScene(SceneId('test'), scene);
      expect(asm.event.withoutComments(),
          move.b(Constant('SFXID_Selection').i, Constant('Sound_Index').l));
    });
  });

  group('dialog with event', () {
    late EventState state;
    late EventState origState;

    var dialog1 = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
    var moves = IndividualMoves();
    moves.moves[alys] = StepPath()..distance = 1.step;

    late GameMap map;

    setUp(() {
      state = EventState()
        ..positions[alys] = Position('50'.hex, '50'.hex)
        ..positions[shay] = Position('60'.hex, '60'.hex);
      origState = EventState()
        ..positions[alys] = Position('50'.hex, '50'.hex)
        ..positions[shay] = Position('60'.hex, '60'.hex);

      map = GameMap(MapId.Test);
      var obj = MapObject(
          id: 'testObj', startPosition: Position(0, 0), spec: AlysWaiting());
      obj.onInteract = Scene([
        SetContext((ctx) => ctx.positions[alys] = Position(0x50, 0x50)),
        dialog1,
        moves
      ]);
      map.addObject(obj);
    });

    test(
        'when dialog is first, dialog runs event and event immediately runs dialog at next offset',
        () {
      var program = Program();
      var eventIndex = program.peekNextEventIndex;
      var mapAsm = program.addMap(map);

      expect(
          program.dialogTrees.forMap(map.id).toAsm().withoutComments().trim(),
          Asm([
            dc.b(Bytes.hex('F6')),
            dc.w([eventIndex]),
            dc.b(Bytes.hex('FF')),
            newLine(),
            dialog1.toAsm(),
            dc.b(Bytes.hex('ff')),
          ]));

      expect(
          mapAsm.events.withoutComments().trim(),
          Asm([
            setLabel('Event_GrandCross_Test_testObj'),
            move.b(SoundEffect.selection.sfxId.i, Constant('Sound_Index').l),
            getAndRunDialog3LowDialogId(Byte.one.i),
            generateEventAsm([moves], origState).withoutComments(),
            returnFromInteractionEvent()
          ]));

      expect(
          program.additionalEventPointers.withoutComments(),
          Asm([
            dc.l([Label('Event_GrandCross_Test_testObj')])
          ]));
    });

    group('during interaction', () {
      late GameMap map;

      setUp(() {
        map = GameMap(MapId.Test);
      });

      test(
          'when facing player is first but there are other events, faces player from within event',
          () {
        map.addObject(MapObject(
            id: '0',
            startPosition: Position(0x200, 0x200),
            spec: AlysWaiting(),
            onInteractFacePlayer: true,
            onInteract: Scene([
              SetContext((ctx) => ctx.positions[alys] = state.positions[alys]),
              Dialog(spans: [DialogSpan('Hi')]),
              IndividualMoves()..moves[alys] = (StepPath()..distance = 1.step)
            ])));

        var mapAsm = program.addMap(map);

        expect(
            mapAsm.events.withoutComments().trim(),
            Asm([
              setLabel('Event_GrandCross_Test_0'),
              jsr(Label('Interaction_UpdateObj').l),
              move.b(SoundEffect.selection.sfxId.i, Constant('Sound_Index').l),
              getAndRunDialog3LowDialogId(Byte.one.i),
              generateEventAsm([
                IndividualMoves()..moves[alys] = (StepPath()..distance = 1.step)
              ], origState)
                  .withoutComments()
                  .trim(),
              returnFromInteractionEvent()
            ]));
      });

      test('when only facing player and dialog, does not run event', () {
        map.addObject(MapObject(
            id: '0',
            startPosition: Position(0x200, 0x200),
            spec: Npc(
                Sprite.PalmanWoman1,
                WanderAround(Direction.down,
                    onInteract: Scene.forNpcInteraction([
                      Dialog(spans: [DialogSpan('Hello')])
                    ])))));

        var mapAsm = program.addMap(map);

        print(mapAsm);

        expect(mapAsm.events.withoutComments().trim(), Asm.empty());
      });

      test(
          'when only set context, facing player and dialog, does not run event',
          () {
        map.addObject(MapObject(
            id: '0',
            startPosition: Position(0x200, 0x200),
            spec: Npc(
                Sprite.PalmanWoman1,
                WanderAround(Direction.down,
                    onInteract: Scene([
                      SetContext((ctx) {}),
                      InteractionObject.facePlayer(),
                      Dialog(spans: [DialogSpan('Hello')])
                    ])))));

        var mapAsm = program.addMap(map);

        print(mapAsm);

        expect(mapAsm.events.withoutComments().trim(), Asm.empty());
      });

      test('given dialog, event, dialog; event code runs dialog', () {
        var eventIndex = program.peekNextEventIndex;

        var dialog1 = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
        var moves = IndividualMoves();
        moves.moves[alys] = StepPath()..distance = 1.step;
        var dialog2 = Dialog(speaker: Shay(), spans: DialogSpan.parse('Hi'));

        var scene = Scene.forNpcInteraction(
            [setContext(state), dialog1, moves, dialog2]);

        map.addObject(testObjectForScene(scene));

        var mapAsm = program.addMap(map);

        expect(
            program.dialogTrees
                .forMap(map.id)
                .map((e) => e.withoutComments())
                .toList(),
            [
              DialogAsm([
                dc.b(Bytes.hex('F6')),
                dc.w([eventIndex]),
                dc.b(Bytes.hex('FF')),
              ]),
              DialogAsm([
                dialog1.toAsm(),
                dc.b(Bytes.hex('f7')),
                dialog2.toAsm(),
                dc.b(Bytes.hex('ff')),
              ])
            ]);

        expect(
            mapAsm.events.withoutComments().trim(),
            Asm([
              setLabel('Event_GrandCross_Test_0'),
              jsr(Label('Interaction_UpdateObj').l),
              move.b(SoundEffect.selection.sfxId.i, Constant('Sound_Index').l),
              getAndRunDialog3LowDialogId(Byte.one.i),
              generateEventAsm([moves], origState).withoutComments(),
              popAndRunDialog3,
              returnFromInteractionEvent()
            ]));
      });

      test(
          'given many exchanges between dialog and event; event code runs dialog',
          () {
        var dialog1 = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
        var move1 = IndividualMoves();
        move1.moves[alys] = StepPath()..distance = 1.step;
        var dialog2 = Dialog(speaker: Shay(), spans: DialogSpan.parse('Hi'));
        var move2 = IndividualMoves();
        move2.moves[shay] = StepPath()..distance = 1.step;
        var dialog3 =
            Dialog(speaker: Shay(), spans: DialogSpan.parse('How are you'));
        var move3 = IndividualMoves();
        move3.moves[alys] = StepPath()..distance = 1.step;

        var eventIndex = program.peekNextEventIndex;
        var scene = Scene.forNpcInteraction([
          setContext(state),
          dialog1,
          move1,
          dialog2,
          move2,
          dialog3,
          move3
        ]);

        map.addObject(testObjectForScene(scene));
        var mapAsm = program.addMap(map);

        expect(
            program.dialogTrees
                .forMap(map.id)
                .map((e) => e.withoutComments())
                .toList(),
            [
              DialogAsm([
                dc.b(Bytes.hex('F6')),
                dc.w([eventIndex]),
                dc.b(Bytes.hex('FF')),
              ]),
              DialogAsm([
                dialog1.toAsm(),
                dc.b(Bytes.hex('f7')),
                dialog2.toAsm(),
                dc.b(Bytes.hex('f7')),
                dialog3.toAsm(),
                dc.b(Bytes.hex('ff')),
              ])
            ]);

        expect(
            mapAsm.events.withoutComments().trim(),
            Asm([
              setLabel('Event_GrandCross_Test_0'),
              jsr(Label('Interaction_UpdateObj').l),
              move.b(SoundEffect.selection.sfxId.i, Constant('Sound_Index').l),
              getAndRunDialog3LowDialogId(Byte.one.i),
              generateEventAsm([move1], origState).withoutComments(),
              popAndRunDialog3,
              generateEventAsm([move2], origState..followLead = false)
                  .withoutComments(),
              popAndRunDialog3,
              generateEventAsm(
                      [move3],
                      origState
                        ..followLead = false
                        ..positions[alys] =
                            (origState.positions[alys]! + 1.step.up.asPosition))
                  .withoutComments(),
              returnFromInteractionEvent()
            ]));
      });

      test('if starting with dialog then pause, pause within event', () {
        var dialog = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
        var pause = Pause(Duration(seconds: 2));

        var eventIndex = program.peekNextEventIndex;
        var scene = Scene([dialog, pause]);
        map.addObject(testObjectForScene(scene));
        var mapAsm = program.addMap(map);

        expect(
            program.dialogTrees
                .forMap(map.id)
                .map((e) => e.withoutComments())
                .toList(),
            [
              DialogAsm([
                dc.b(Bytes.hex('F6')),
                dc.w([eventIndex]),
                dc.b(Bytes.hex('FF')),
              ]),
              DialogAsm([
                dialog.toAsm(),
                dc.b(Bytes.hex('ff')),
              ])
            ]);

        expect(
            mapAsm.events.withoutComments().trim(),
            Asm([
              setLabel('Event_GrandCross_Test_0'),
              move.b(SoundEffect.selection.sfxId.i, Constant('Sound_Index').l),
              getAndRunDialog3LowDialogId(Byte.one.i),
              generateEventAsm([pause]).withoutComments(),
              returnFromInteractionEvent()
            ]));
      });

      test("if only pausing, pause within event and don't run dialog", () {
        var eventIndex = program.peekNextEventIndex;
        var pause = Pause(Duration(seconds: 2));
        map.addObject(testObjectForScene(Scene([pause])));

        var mapAsm = program.addMap(map);

        expect(
            program.dialogTrees
                .forMap(map.id)
                .map((e) => e.withoutComments())
                .toList(),
            [
              DialogAsm([
                dc.b(Bytes.hex('F6')),
                dc.w([eventIndex]),
                dc.b(Bytes.hex('FF')),
              ]),
            ]);

        expect(
            mapAsm.events.withoutComments().trim(),
            Asm([
              setLabel('Event_GrandCross_Test_0'),
              generateEventAsm([pause]).withoutComments(),
              returnFromInteractionEvent()
            ]));
      });

      test('if pause is during Dialog, pause within dialog', () {
        var dialog = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
        var pause = Pause(Duration(milliseconds: 33), duringDialog: true);

        var scene =
            Scene([InteractionObject.facePlayer(), dialog, pause, dialog]);
        map.addObject(testObjectForScene(scene));
        var mapAsm = program.addMap(map);

        expect(
            program.dialogTrees
                .forMap(map.id)
                .map((e) => e.withoutComments())
                .toList(),
            [
              DialogAsm([
                dialog.toAsm(state),
                dc.b([Byte(0xfd)]),
                // Dialog pause is frames to pause for, not frames - 1
                dc.b([Byte(0xf9), Byte(2)]),
                dialog.toAsm(state),
                dc.b([Byte.max]),
              ])
            ]);

        expect(mapAsm.events.withoutComments().trim(), Asm.empty());
      });
    });

    test('if dialog while faded, uses cutscene routine', () {
      var map = GameMap(MapId.Test);
      var obj = MapObject(
          startPosition: Position(0x50, 0x50),
          spec: Npc(Sprite.PalmanOldMan1, WanderAround(Direction.down)));
      map.addObject(obj);

      var dialog = DialogTrees();
      var asm = EventAsm.empty();
      var eventRoutines = TestEventRoutines();
      var events = [
        Pause(Duration(seconds: 1)),
        FadeOut(),
        Dialog(spans: DialogSpan.parse('Hello world')),
      ];

      var generator = SceneAsmGenerator.forInteraction(
          map, SceneId('testscene'), dialog, asm, eventRoutines)
        ..runEventIfNeeded(events);

      for (var event in events) {
        event.visit(generator);
      }

      generator.finish();

      print(asm);

      expect(eventRoutines.cutsceneRoutines, hasLength(1));
    });

    test('if cutscene in conditional branch, ends with fade and map reload',
        () {
      var map = GameMap(MapId.Test);
      var obj = MapObject(
          startPosition: Position(0x50, 0x50),
          spec: Npc(Sprite.PalmanOldMan1, WanderAround(Direction.down)));
      map.addObject(obj);

      var dialog = DialogTrees();
      var asm = EventAsm.empty();
      var eventRoutines = TestEventRoutines();
      var events = [
        IfFlag(EventFlag('test'), isSet: [
          Dialog(spans: DialogSpan.parse('Bye world')),
        ], isUnset: [
          FadeOut(),
          Dialog(spans: DialogSpan.parse('Hello world')),
          SetFlag(EventFlag('test')),
        ]),
      ];

      var generator = SceneAsmGenerator.forInteraction(
          map, SceneId('testscene'), dialog, asm, eventRoutines)
        ..runEventIfNeeded(events);

      for (var event in events) {
        event.visit(generator);
      }

      generator.finish();

      print(asm);

      expect(eventRoutines.cutsceneRoutines, hasLength(1));
      expect(
          asm.withoutComments().tail(4),
          Asm([
            jsr(Label('Event_GetAndRunDialogue5').l),
            moveq(0.i, d0),
            rts,
            newLine()
          ]));
    });

    test('movement then dialog update facing before dialog', () {
      var scene = Scene([
        SetContext((ctx) {
          ctx.followLead = false;
          ctx.slots[1] = alys;
          ctx.positions[alys] = Position(0x50, 0x50);
        }),
        IndividualMoves()
          ..moves[alys] = (StepPath()
            ..distance = 2.steps
            ..direction = Direction.right),
        Dialog(spans: DialogSpan.parse('Hello')),
      ]);

      var program = Program();
      var sceneAsm = program.addScene(SceneId('testscene'), scene);

      expect(
          sceneAsm.event.withoutComments().trim(),
          Asm([
            lea(Constant('Character_1').w, a4),
            move.w(Word(0x70).i, d0),
            move.w(Word(0x50).i, d1),
            jsr(Label('Event_MoveCharacter').l),
            lea(Constant('Character_1').w, a4), // todo: can optimize this out
            updateObjFacing(Direction.right.address),
            getAndRunDialog3LowDialogId(Byte.zero.i),
          ]));
    }, skip: 'TODO: impl functionality');

    test('facing then dialog update facing before dialog', () {
      var scene = Scene([
        SetContext((ctx) {
          ctx.followLead = false;
          ctx.slots[1] = alys;
          ctx.positions[alys] = Position(0x50, 0x50);
        }),
        IndividualMoves()..moves[alys] = Face(Direction.right),
        Dialog(spans: DialogSpan.parse('Hello')),
      ]);

      var program = Program();
      var sceneAsm =
          program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          sceneAsm.event.withoutComments().trim(),
          Asm([
            lea(Constant('Character_1').w, a4), // todo: can optimize this out
            updateObjFacing(Direction.right.address),
            getAndRunDialog3LowDialogId(Byte.zero.i),
          ]));
    });

    test('move then facing then dialog update facing before dialog', () {
      var scene = Scene([
        SetContext((ctx) {
          ctx.followLead = false;
          ctx.slots[1] = alys;
          ctx.positions[alys] = Position(0x50, 0x50);
        }),
        IndividualMoves()
          ..moves[alys] = (StepPaths()
            ..step(StepPath()
              ..direction = Direction.right
              ..distance = 2.steps)
            ..face(Direction.down)),
        Dialog(spans: DialogSpan.parse('Hello')),
      ]);

      var program = Program();
      var sceneAsm =
          program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          sceneAsm.event.withoutComments().trim(),
          Asm([
            lea(Constant('Character_1').w, a4),
            move.w(Word(0x70).i, d0),
            move.w(Word(0x50).i, d1),
            jsr(Label('Event_MoveCharacter').l),
            updateObjFacing(Direction.down.address),
            getAndRunDialog3LowDialogId(Byte.zero.i),
          ]));
    });

    test(
        'dialog then event then dialog with same speaker shows portrait after event',
        () {
      var scene = Scene([
        SetContext((ctx) {
          ctx.followLead = false;
          ctx.slots[1] = alys;
          ctx.positions[alys] = Position(0x50, 0x50);
        }),
        Dialog(speaker: alys, spans: DialogSpan.parse('Hello')),
        IndividualMoves()
          ..moves[alys] = (StepPaths()
            ..step(StepPath()
              ..direction = Direction.right
              ..distance = 2.steps)
            ..face(Direction.down)),
        Dialog(speaker: alys, spans: DialogSpan.parse('Hello')),
      ]);

      var program = Program();
      program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          program.dialogTrees.forMap(map.id).toAsm().withoutComments().trim(),
          Asm([
            dc.b([Byte(0xf4), (toPortraitCode(alys.portrait))]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xf7)]),
            dc.b([Byte(0xf4), (toPortraitCode(alys.portrait))]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xff)])
          ]));
    });

    test('dialog with setflag sets flag in event', () {
      var scene = Scene([
        SetFlag(EventFlag('AlysFound')),
        Dialog(speaker: alys, spans: DialogSpan.parse('Hello')),
      ]);

      var program = Program();
      program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          program.dialogTrees.forMap(map.id).toAsm().withoutComments().trim(),
          Asm([
            dc.b([Byte(0xf4), (toPortraitCode(alys.portrait))]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xff)])
          ]));

      expect(
          program.scenes[SceneId('testscene')]?.event
              .withoutComments()
              .withoutEmptyLines(),
          Asm([
            setEventFlag(EventFlags().toConstantValue(EventFlag('AlysFound'))),
            moveq(Byte.zero.i, d0),
            jsr(Label('Event_GetAndRunDialogue3').l),
          ]));
    });

    test('dialog with facing mid dialog', () {
      var scene = Scene([
        Dialog(speaker: alys, spans: [
          DialogSpan('Hello',
              events: [IndividualMoves()..moves[alys] = Face(Direction.down)]),
          DialogSpan(' there.')
        ]),
      ]);

      var program = Program();
      program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          program.dialogTrees.forMap(map.id).toAsm().withoutComments().trim(),
          Asm([
            dc.b([Byte(0xf4), (toPortraitCode(alys.portrait))]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xf2), Byte(0xe), alys.compactId(state)!.toByte]),
            dc.w([down.constant]),
            dc.b(Bytes.ascii(' there.')),
            dc.b([Byte(0xff)])
          ]));
    });

    test('dialog with facing mid dialog with long line', () {
      var scene = Scene([
        Dialog(speaker: alys, spans: [
          DialogSpan('Hello',
              events: [IndividualMoves()..moves[alys] = Face(Direction.down)]),
          DialogSpan(' there. This is a long span that should break.')
        ]),
      ]);

      var program = Program();
      program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          program.dialogTrees.forMap(map.id).toAsm().withoutComments().trim(),
          Asm([
            dc.b([Byte(0xf4), (toPortraitCode(alys.portrait))]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xf2), Byte(0xe), alys.compactId(state)!.toByte]),
            dc.w([down.constant]),
            dc.b(Bytes.ascii(' there. This is a long span')),
            dc.b(ControlCodes.newLine),
            dc.b(Bytes.ascii('that should break.')),
            dc.b([Byte(0xff)])
          ]));
    });

    test('facing mid dialog updates context', () {
      // Face a direction,
      // then face a direction mid dialog
      // then face back the original direction.
      // If context is not updated, the third facing will be optimized out and not take place.
      var scene = Scene([
        SetContext((ctx) {
          ctx.positions[alys] = Position(0x50, 0x50);
          ctx.followLead = false;
          ctx.slots[1] = alys;
        }),
        IndividualMoves()..moves[alys] = Face(Direction.down),
        Dialog(speaker: alys, spans: [
          DialogSpan('Hello',
              events: [IndividualMoves()..moves[alys] = Face(Direction.right)]),
          DialogSpan(' there.'),
        ]),
        IndividualMoves()..moves[alys] = Face(Direction.down),
      ]);

      var program = Program();
      program.addScene(SceneId('testscene'), scene, startingMap: map);

      // Expect event asm to have both movements
      expect(
          program.scenes[SceneId('testscene')]?.event
              .withoutComments()
              .withoutEmptyLines(),
          Asm([
            lea(Constant('Character_1').w, a4),
            updateObjFacing(Direction.down.address),
            getAndRunDialog3LowDialogId(Byte.zero.i),
            lea(Constant('Character_1').w, a4),
            updateObjFacing(Direction.down.address),
          ]));
    });
  });

  group('conditional events', () {
    var sceneId = SceneId('test');

    Asm pause(int seconds) {
      var asm = EventAsm.empty();
      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), asm)
          .pause(Pause(seconds.seconds));
      return asm;
    }

    var pause1 = pause(1);
    var pause2 = pause(2);

    test('runs if-set events iff event flag is set', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [Pause(1.second)]))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset1')),
            pause1.withoutComments(),
            setLabel('.Test_unset1')
          ]));
    });

    test('runs if-unset events iff event flag is unset', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifFlag(IfFlag(EventFlag('Test'), isUnset: [Pause(1.second)]))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            bne.w(Label('.Test_set1')),
            pause1.withoutComments(),
            setLabel('.Test_set1')
          ]));
    });

    test('runs if-set events iff set, and if-unset events iff unset', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifFlag(IfFlag(EventFlag('Test'),
            isUnset: [Pause(1.second)], isSet: [Pause(2.seconds)]))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset1')),
            pause2,
            bra.w(Label('.Test_cont1')),
            setLabel('.Test_unset1'),
            pause1,
            setLabel('.Test_cont1')
          ]).withoutComments());
    });

    test('nested conditionals skip impossible branches', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifFlag(IfFlag(EventFlag('Test'), isUnset: [
          IfFlag(EventFlag('Test'),
              isSet: [Pause(1.second)], isUnset: [Pause(2.second)])
        ], isSet: [
          Pause(3.seconds)
        ]))
        ..finish();

      print(eventAsm);

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset1')),
            pause(3),
            bra.w(Label('.Test_cont1')),
            setLabel('.Test_unset1'),
            pause2,
            setLabel('.Test_cont1')
          ]).withoutComments());
    });

    test('additional checks use different branch routines', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifFlag(IfFlag(EventFlag('Test'),
            isUnset: [Pause(1.second)], isSet: [Pause(2.seconds)]))
        ..ifFlag(IfFlag(EventFlag('Test'),
            isUnset: [Pause(3.second)], isSet: [Pause(4.seconds)]))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset1')),
            pause2,
            bra.w(Label('.Test_cont1')),
            setLabel('.Test_unset1'),
            pause1,
            setLabel('.Test_cont1'),
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset4')),
            pause(4),
            bra.w(Label('.Test_cont4')),
            setLabel('.Test_unset4'),
            pause(3),
            setLabel('.Test_cont4'),
          ]).withoutComments());
    });

    test('dialog in branch terminates and clears saved dialog state', () {
      var eventAsm = EventAsm.empty();
      var dialog = DialogTrees();

      var hello = DialogSpan.parse('Hello!');
      var greetings = DialogSpan.parse('Greetings!');

      SceneAsmGenerator.forEvent(sceneId, dialog, eventAsm, startingMap: map)
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [Dialog(spans: hello)]))
        ..dialog(Dialog(spans: greetings))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset1')),
            getAndRunDialog3LowDialogId(0.toByte.i),
            setLabel('.Test_unset1'),
            getAndRunDialog3LowDialogId(1.toByte.i),
          ]).withoutComments());

      expect(
          dialog.forMap(map.id).toAsm(),
          containsAllInOrder(Asm([
            dc.b(hello[0].toAscii()),
            terminateDialog(keepDialog: true),
            dc.b(greetings[0].toAscii()),
            terminateDialog()
          ])));
    });

    test('dialog in both branches terminates and clears saved dialog state',
        () {
      var eventAsm = EventAsm.empty();
      var dialog = DialogTrees();

      var hello = DialogSpan.parse('Hello!');
      var hello2 = DialogSpan.parse('hello 2');
      var greetings = DialogSpan.parse('Greetings!');

      SceneAsmGenerator.forEvent(sceneId, dialog, eventAsm, startingMap: map)
        ..ifFlag(IfFlag(EventFlag('Test'),
            isSet: [Dialog(spans: hello)], isUnset: [Dialog(spans: hello2)]))
        ..dialog(Dialog(spans: greetings))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset1')),
            getAndRunDialog3LowDialogId(0.toByte.i),
            bra.w(Label('.Test_cont1')),
            setLabel('.Test_unset1'),
            getAndRunDialog3LowDialogId(1.toByte.i),
            setLabel('.Test_cont1'),
            getAndRunDialog3LowDialogId(2.toByte.i),
          ]).withoutComments());

      expect(
          dialog.forMap(map.id).toAsm(),
          containsAllInOrder(Asm([
            dc.b(hello[0].toAscii()),
            terminateDialog(keepDialog: true),
            dc.b(hello2[0].toAscii()),
            terminateDialog(keepDialog: true),
            dc.b(greetings[0].toAscii()),
            terminateDialog()
          ])));
    });

    test(
      'dialog in consecutive if value followed by dialog keeps dialog',
      () {
        var eventAsm = EventAsm.empty();
        var dialog = DialogTrees();

        var dialog1 = DialogSpan.parse('Dialog 1');
        var dialog2 = DialogSpan.parse('Dialog 2');
        var dialog3 = DialogSpan.parse('Dialog 3');

        SceneAsmGenerator.forEvent(sceneId, dialog, eventAsm, startingMap: map)
          ..ifValue(IfValue(hahn.slot(),
              comparedTo: NullSlot(), notEqual: [Dialog(spans: dialog1)]))
          ..ifValue(IfValue(alys.slot(),
              comparedTo: NullSlot(), notEqual: [Dialog(spans: dialog2)]))
          ..dialog(Dialog(spans: dialog3))
          ..finish();

        expect(
            eventAsm.withoutComments(),
            EventAsm([
              moveq(hahn.charIdAddress, d0),
              jsr(('FindCharacterSlot').l),
              cmpi.b(0xFF.i, d1),
              beq(Label('.1_continue')),
              getAndRunDialog3LowDialogId(Byte.zero.i),
              setLabel('.1_continue'),
              // Should not close dialog!
              // jsr(('Event_CloseDialog').l),
              moveq(alys.charIdAddress, d0),
              jsr(('FindCharacterSlot').l),
              cmpi.b(0xFF.i, d1),
              beq(Label('.4_continue')),
              getAndRunDialog3LowDialogId(Byte.one.i),
              setLabel('.4_continue'),
              getAndRunDialog3LowDialogId(Byte.two.i),
            ]).withoutComments());

        expect(
          dialog.forMap(map.id).toAsm(),
          containsAllInOrder(Asm([
            dc.b(dialog1[0].toAscii()),
            terminateDialog(keepDialog: true),
            dc.b(dialog2[0].toAscii()),
            terminateDialog(keepDialog: true),
            dc.b(dialog3[0].toAscii()),
            terminateDialog(),
          ])),
        );
      },
    );

    test(
        'dialog in both branches terminates and clears saved dialog state with prior dialog',
        () {
      var prior = DialogSpan.parse('Prior');
      var hello = DialogSpan.parse('Hello!');
      var hello2 = DialogSpan.parse('hello 2');
      var greetings = DialogSpan.parse('Greetings!');

      var program = Program();
      var asm = program.addScene(
          sceneId,
          Scene([
            Dialog(spans: prior),
            IfFlag(EventFlag('Test'),
                isSet: [Dialog(spans: hello)],
                isUnset: [Dialog(spans: hello2)]),
            Dialog(spans: greetings)
          ]),
          startingMap: map);

      expect(
          asm.event.withoutComments(),
          EventAsm([
            getAndRunDialog3LowDialogId(0.toByte.i),
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset3')),
            getAndRunDialog3LowDialogId(1.toByte.i),
            bra.w(Label('.Test_cont3')),
            setLabel('.Test_unset3'),
            getAndRunDialog3LowDialogId(2.toByte.i),
            setLabel('.Test_cont3'),
            getAndRunDialog3LowDialogId(3.toByte.i),
          ]).withoutComments());

      expect(
          program.dialogTrees
              .forMap(map.id)
              .toAsm()
              .withoutComments()
              .withoutEmptyLines(),
          Asm([
            dc.b(prior[0].toAscii()),
            terminateDialog(keepDialog: true),
            dc.b(hello[0].toAscii()),
            terminateDialog(keepDialog: true),
            dc.b(hello2[0].toAscii()),
            terminateDialog(keepDialog: true),
            dc.b(greetings[0].toAscii()),
            terminateDialog()
          ]));
    });

    test('events which use context cannot when context is ambiguous', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..setContext(
            SetContext((ctx) => ctx.positions[alys] = Position(0x50, 0x50)))
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          IndividualMoves()..moves[alys] = (StepPath()..distance = 2.steps)
        ], isUnset: [
          IndividualMoves()
            ..moves[alys] = (StepPath()
              ..direction = Direction.right
              ..distance = 2.steps)
        ]))
        ..individualMoves(
            IndividualMoves()..moves[alys] = (StepPath()..distance = 2.steps))
        ..finish();

      // Generate the last move when context is also unknown
      var expected = generateEventAsm([
        IndividualMoves()..moves[alys] = (StepPath()..distance = 2.steps)
      ]).withoutComments();

      // Should be equivalent
      expect(expected, eventAsm.withoutComments().tail(expected.length));
    });

    test('events use context from previous branched states', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..setContext(
            SetContext((ctx) => ctx.positions[alys] = Position(0x50, 0x50)))
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          IndividualMoves()..moves[alys] = (StepPath()..distance = 2.steps)
        ], isUnset: [
          IndividualMoves()
            ..moves[alys] = (StepPath()
              ..direction = Direction.right
              ..distance = 2.steps)
        ]))
        ..pause(Pause(1.second))
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          IndividualMoves()
            ..moves[alys] = (StepPath()
              ..direction = Direction.left
              ..distance = 2.steps)
        ], isUnset: [
          IndividualMoves()
            ..moves[alys] = (StepPath()
              ..direction = Direction.up
              ..distance = 2.steps)
        ]))
        ..finish();

      expect(
          eventAsm.withoutComments().tail(12),
          Asm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset5')),
            move.w(0x30.toWord.i, d0),
            move.w(0x30.toWord.i, d1),
            jsr(Label('Event_MoveCharacter').l),
            bra.w(Label('.Test_cont5')),
            setLabel('.Test_unset5'),
            move.w(0x70.toWord.i, d0),
            move.w(0x30.toWord.i, d1),
            jsr(Label('Event_MoveCharacter').l),
            label(Label('.Test_cont5')),
          ]));
    });

    test(
        'events cannot use context from previous branched states if overwritten',
        () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm,
          startingMap: GameMap(MapId.Test))
        ..setContext(
            SetContext((ctx) => ctx.positions[alys] = Position(0x50, 0x50)))
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          IndividualMoves()..moves[alys] = (StepPath()..distance = 2.steps)
        ], isUnset: [
          IndividualMoves()
            ..moves[alys] = (StepPath()
              ..direction = Direction.right
              ..distance = 2.steps)
        ]))
        // In parent branch, overwrite address register
        ..individualMoves(
            IndividualMoves()..moves[shay] = (StepPath()..distance = 2.steps))
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          IndividualMoves()
            ..moves[alys] = (StepPath()
              ..direction = Direction.left
              ..distance = 2.steps)
        ], isUnset: [
          IndividualMoves()
            ..moves[alys] = (StepPath()
              ..direction = Direction.up
              ..distance = 2.steps)
        ]))
        ..finish();

      print(eventAsm);

      expect(
          eventAsm.withoutComments().tail(16),
          Asm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset5')),
            alys.toA4(Memory()),
            move.w(0x30.toWord.i, d0),
            move.w(0x30.toWord.i, d1),
            jsr(Label('Event_MoveCharacter').l),
            bra.w(Label('.Test_cont5')),
            setLabel('.Test_unset5'),
            alys.toA4(Memory()),
            move.w(0x70.toWord.i, d0),
            move.w(0x30.toWord.i, d1),
            jsr(Label('Event_MoveCharacter').l),
            label(Label('.Test_cont5')),
          ]));
    });

    group('in interactions', () {
      var map = GameMap(MapId.Test);
      var obj = MapObject(
          startPosition: Position(0x50, 0x50),
          spec: Npc(Sprite.PalmanOldMan1, WanderAround(Direction.down)));
      map.addObject(obj);

      late DialogTrees dialog;
      late EventAsm asm;
      late TestEventRoutines eventRoutines;

      setUp(() {
        dialog = DialogTrees();
        asm = EventAsm.empty();
        eventRoutines = TestEventRoutines();
      });

      test('in event, flag is checked in event code', () {
        SceneAsmGenerator.forInteraction(
            map, SceneId('interact'), dialog, asm, eventRoutines);
        // todo:
      }, skip: 'TODO:write test');

      test('in dialog, flag is checked in dialog', () {
        SceneAsmGenerator.forInteraction(
            map, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            InteractionObject.facePlayer(),
            Dialog(spans: DialogSpan.parse('Flag1 is set'))
          ], isUnset: [
            InteractionObject.facePlayer(),
            Dialog(spans: DialogSpan.parse('Flag1 is not set'))
          ]))
          ..finish();

        print(dialog);

        expect(asm, isEmpty);
        expect(
            dialog.forMap(map.id).toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b(DialogSpan('Flag1 is not set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b(DialogSpan('Flag1 is set').toAscii()),
              terminateDialog(),
            ]));
      });

      test('in dialog, if no dialog when flag set, terminate', () {
        SceneAsmGenerator.forInteraction(
            map, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            InteractionObject.facePlayer(),
          ], isUnset: [
            InteractionObject.facePlayer(),
            Dialog(spans: DialogSpan.parse('Flag1 is not set'))
          ]))
          ..finish();

        print(dialog);

        expect(asm, isEmpty);
        expect(
            dialog.forMap(map.id).toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b(DialogSpan('Flag1 is not set').toAscii()),
              terminateDialog(),
              newLine(),
              terminateDialog(),
            ]));
      });

      test('in dialog, dead branches are pruned', () {
        SceneAsmGenerator.forInteraction(
            map, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            // redundant check
            IfFlag(EventFlag('flag1'), isSet: [
              InteractionObject.facePlayer(),
              Dialog(spans: DialogSpan.parse('Flag1 is set'))
            ], isUnset: [
              // dead code
              Pause(1.second)
            ])
          ], isUnset: [
            InteractionObject.facePlayer(),
            Dialog(spans: DialogSpan.parse('Flag1 is not set'))
          ]))
          ..finish();

        print(dialog);

        expect(asm, isEmpty);
        expect(
            dialog.forMap(map.id).toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b(DialogSpan('Flag1 is not set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b(DialogSpan('Flag1 is set').toAscii()),
              terminateDialog(),
            ]));
      });

      test('in dialog, alternate flags are checked in same dialog', () {
        SceneAsmGenerator.forInteraction(
            map, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            InteractionObject.facePlayer(),
            Dialog(spans: DialogSpan.parse('Flag1 is set'))
          ], isUnset: [
            IfFlag(EventFlag('flag2'), isSet: [
              InteractionObject.facePlayer(),
              Dialog(spans: DialogSpan.parse('Flag1 is not set, but 2 is'))
            ], isUnset: [
              InteractionObject.facePlayer(),
              Dialog(spans: DialogSpan.parse('Flag1 and 2 are not set'))
            ]),
          ]))
          ..finish();

        print(dialog);

        expect(asm, isEmpty);
        expect(
            dialog.forMap(map.id).toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag2'), Byte(0x02)]),
              dc.b(DialogSpan('Flag1 and 2 are not set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b(DialogSpan('Flag1 is set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b(DialogSpan('Flag1 is not set, but 2 is').toAscii()),
              terminateDialog(),
            ]));
      });

      test('in dialog, nested flags are checked in consecutive dialog', () {
        SceneAsmGenerator.forInteraction(
            map, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            IfFlag(EventFlag('flag3'), isSet: [
              InteractionObject.facePlayer(),
              Dialog(spans: DialogSpan.parse('Flag1 and 3 are set'))
            ], isUnset: [
              InteractionObject.facePlayer(),
              Dialog(spans: DialogSpan.parse('Flag1 is set, but 3 is not'))
            ]),
          ], isUnset: [
            IfFlag(EventFlag('flag2'), isSet: [
              InteractionObject.facePlayer(),
              Dialog(spans: DialogSpan.parse('Flag1 is not set, but 2 is'))
            ], isUnset: [
              InteractionObject.facePlayer(),
              Dialog(spans: DialogSpan.parse('Flag1 and 2 are not set'))
            ]),
          ]))
          ..finish();

        expect(asm, isEmpty);
        expect(
            dialog.forMap(map.id).toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag2'), Byte(0x02)]),
              dc.b(DialogSpan('Flag1 and 2 are not set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag3'), Byte(0x02)]),
              dc.b(DialogSpan('Flag1 is set, but 3 is not').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b(DialogSpan('Flag1 is not set, but 2 is').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b(DialogSpan('Flag1 and 3 are set').toAscii()),
              terminateDialog(),
            ]));
      });

      test('dialog branches that need events run events', () {
        SceneAsmGenerator.forInteraction(
            map, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            SetContext((ctx) => ctx.positions[alys] = Position(0x50, 0x50)),
            IndividualMoves()..moves[alys] = (StepPath()..distance = 1.steps)
          ], isUnset: [
            InteractionObject.facePlayer(),
            Dialog(spans: DialogSpan.parse('Flag1 is not set'))
          ]))
          ..finish();

        print(asm);

        expect(eventRoutines.eventRoutines,
            [Label('Event_GrandCross_interactflag1_set')]);
        expect(asm.withoutComments().firstOrNull?.toAsm(),
            setLabel('Event_GrandCross_interactflag1_set'));
        expect(
            dialog.forMap(map.id).toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b(DialogSpan('Flag1 is not set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b([Byte(0xf6)]),
              dc.w([Word(0)]),
              terminateDialog(),
            ]));
      });

      test('unset event returns to map', () {
        SceneAsmGenerator.forInteraction(
            map, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            InteractionObject.facePlayer(),
            Dialog(spans: DialogSpan.parse('Flag1 is set'))
          ], isUnset: [
            SetContext((ctx) => ctx.positions[alys] = Position(0x50, 0x50)),
            IndividualMoves()..moves[alys] = (StepPath()..distance = 1.steps)
          ]))
          ..finish();

        print(asm);

        expect(asm.withoutComments().firstOrNull?.toAsm(),
            setLabel('Event_GrandCross_interactflag1_unset'));

        var returnFromDialog = returnFromInteractionEvent().withoutComments()
          ..addNewline();
        expect(asm.withoutComments().tail(returnFromDialog.length),
            returnFromDialog);

        expect(
            dialog.forMap(map.id).toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b([Byte(0xf6)]),
              dc.w([Word(0)]),
              terminateDialog(),
              newLine(),
              dc.b(DialogSpan('Flag1 is set').toAscii()),
              terminateDialog(),
            ]));
      });

      test('does not need event if branches only contain dialog', () {
        expect(
            SceneAsmGenerator.forInteraction(
                    map, SceneId('interact'), dialog, asm, eventRoutines)
                .needsEventMode([
              IfFlag(EventFlag('flag1'), isSet: [
                Dialog(spans: DialogSpan.parse('Flag1 is set'))
              ], isUnset: [
                Dialog(spans: DialogSpan.parse('Flag1 is not set'))
              ])
            ]),
            null);
      });

      test('does not need event even if a branch has events', () {
        expect(
            SceneAsmGenerator.forInteraction(
                    map, SceneId('interact'), dialog, asm, eventRoutines)
                .needsEventMode([
              IfFlag(EventFlag('flag1'), isSet: [
                Dialog(spans: DialogSpan.parse('Flag1 is set')),
                Pause(1.second),
              ], isUnset: [
                Dialog(spans: DialogSpan.parse('Flag1 is not set'))
              ])
            ]),
            null);
      });

      test('does need event if there are unconditional events', () {
        expect(
            SceneAsmGenerator.forInteraction(
                    map, SceneId('interact'), dialog, asm, eventRoutines)
                .needsEventMode([
              IfFlag(EventFlag('flag1'), isSet: [
                Dialog(spans: DialogSpan.parse('Flag1 is set')),
                Pause(1.second),
              ], isUnset: [
                Dialog(spans: DialogSpan.parse('Flag1 is not set'))
              ]),
              IfFlag(EventFlag('flagother'))
            ]),
            EventType.event);
      });

      test('ending with events runnable in dialog or event run in event', () {
        var map = GameMap(MapId.Test);
        map.addObject(MapObject(
            id: 'one',
            startPosition: Position(0x100, 0x100),
            spec: Npc(
                Sprite.Motavian1,
                FaceDown(
                    onInteract: Scene([
                  IfFlag(EventFlag('testflag'), isSet: [
                    Dialog(speaker: alys, spans: DialogSpan.parse('Hello')),
                    IndividualMoves()..moves[alys] = Face(down),
                  ], isUnset: [
                    Dialog(speaker: alys, spans: DialogSpan.parse('Bye')),
                  ]),
                ])))));

        var program = Program();
        var asm = program.addMap(map);

        expect(
            asm.events.withoutComments().trim().skip(1),
            Asm([
              // 0 is check & unset, 1 set (run event), 2 is set dialog
              move.b(SoundEffect.selection.sfxId.i, Constant('Sound_Index').l),
              moveq(Byte(2).i, d0),
              jsr(Label('Event_GetAndRunDialogue3').l),
              alys.toA4(Memory()),
              updateObjFacing(down.address),
              returnFromInteractionEvent(),
            ]));
      });

      group('cannot then run event in interaction', () {
        test('if another event other than IfFlag has occurred', () {
          var generator = SceneAsmGenerator.forInteraction(
              map, SceneId('interact'), dialog, asm, eventRoutines)
            ..dialog(Dialog(spans: DialogSpan.parse('Flag1 is set')));

          expect(() => generator.runEvent(), throwsStateError);
        });

        test('if already in event', () {
          var generator =
              SceneAsmGenerator.forEvent(SceneId('event'), dialog, asm);

          expect(() => generator.runEvent(), throwsStateError);
        });

        test('if already run event in interaction', () {
          var generator = SceneAsmGenerator.forInteraction(
              map, SceneId('interact'), dialog, asm, eventRoutines)
            ..runEvent();

          expect(() => generator.runEvent(), throwsStateError);
        });
      });
    });
  });

  group('ReturnControl', () {
    var sceneId = SceneId('testscene');

    test('outside conditional forces rts at end', () {
      var eventAsm1 = EventAsm.empty();
      var eventAsm2 = EventAsm.empty();

      // Scene with ReturnControl
      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm1)
        ..pause(Pause(1.second))
        ..returnControl(ReturnControl())
        ..finish();

      // Scene ending normally
      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm2)
        ..pause(Pause(1.second))
        ..finish();

      expect(
          eventAsm1.withoutComments(), eventAsm2.withoutComments()..add(rts));
    });

    test('in IfFlag isSet branch terminates only that branch', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          Pause(1.second),
          ReturnControl(),
        ], isUnset: [
          Pause(2.seconds),
        ]))
        ..pause(Pause(3.seconds))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset1')),
            // isSet branch: pause then return
            move.w(Word(0x003B).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            rts,
            bra.w(Label('.Test_cont1')),
            // isUnset branch: pause then continue
            setLabel('.Test_unset1'),
            move.w(Word(0x0077).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            setLabel('.Test_cont1'),
            // After IfFlag
            move.w(Word(0x00B3).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('in IfValue branch terminates only that branch', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifValue(IfValue(hahn.slot(), comparedTo: NullSlot(), notEqual: [
          Pause(1.second),
          ReturnControl(),
        ], equal: [
          Pause(2.seconds),
        ]))
        ..pause(Pause(3.seconds))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(hahn.charIdAddress, d0),
            jsr(Label('FindCharacterSlot').l),
            cmpi.b(0xFF.i, d1),
            beq(Label('.1_eq')),
            // notEqual branch: pause then return
            move.w(Word(0x003B).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            rts,
            bra(Label('.1_continue')),
            // equal branch: pause then continue
            setLabel('.1_eq'),
            move.w(Word(0x0077).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            setLabel('.1_continue'),
            // After IfValue
            move.w(Word(0x00B3).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('in IfFlag isUnset branch terminates only that branch', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          Pause(1.second),
        ], isUnset: [
          Pause(2.seconds),
          ReturnControl(),
        ]))
        ..pause(Pause(3.seconds))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset1')),
            // isSet branch: pause then continue
            move.w(Word(0x003B).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            bra.w(Label('.Test_cont1')),
            // isUnset branch: pause then return
            setLabel('.Test_unset1'),
            move.w(Word(0x0077).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            rts,
            setLabel('.Test_cont1'),
            // After IfFlag
            move.w(Word(0x00B3).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('in only IfFlag branch defined with ReturnControl', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          Pause(1.second),
          ReturnControl(),
        ]))
        ..pause(Pause(2.seconds))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset1')),
            // isSet branch: pause then return
            move.w(Word(0x003B).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            rts,
            // No isUnset branch, just continue
            setLabel('.Test_unset1'),
            // After IfFlag
            move.w(Word(0x0077).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('in IfValue equal branch terminates only that branch', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifValue(IfValue(hahn.slot(),
            comparedTo: NullSlot(),
            notEqual: [Pause(1.second)],
            equal: [Pause(2.seconds), ReturnControl()]))
        ..pause(Pause(3.seconds))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(hahn.charIdAddress, d0),
            jsr(Label('FindCharacterSlot').l),
            cmpi.b(0xFF.i, d1),
            beq(Label('.1_eq')),
            // notEqual branch: pause then continue
            move.w(Word(0x003B).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            bra(Label('.1_continue')),
            // equal branch: pause then return
            setLabel('.1_eq'),
            move.w(Word(0x0077).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            rts,
            setLabel('.1_continue'),
            // After IfValue
            move.w(Word(0x00B3).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('in only IfValue branch defined with ReturnControl', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifValue(IfValue(hahn.slot(),
            comparedTo: NullSlot(),
            notEqual: [Pause(1.second), ReturnControl()]))
        ..pause(Pause(2.seconds))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(hahn.charIdAddress, d0),
            jsr(Label('FindCharacterSlot').l),
            cmpi.b(0xFF.i, d1),
            beq(Label('.1_continue')),
            // notEqual branch: pause then return
            move.w(Word(0x003B).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            rts,
            // No equal branch, just continue
            setLabel('.1_continue'),
            // After IfValue
            move.w(Word(0x0077).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('nested IfFlag with ReturnControl in inner branch', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..ifFlag(IfFlag(EventFlag('Outer'), isSet: [
          IfFlag(EventFlag('Inner'), isSet: [
            Pause(1.second),
            ReturnControl(),
          ])
        ]))
        ..pause(Pause(2.seconds))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Outer').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Outer_unset1')),
            // Outer isSet branch: nested IfFlag
            moveq(Constant('EventFlag_Inner').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Inner_unset2')),
            // Inner isSet branch: pause then return
            move.w(Word(0x003B).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            rts,
            setLabel('.Inner_unset2'),
            setLabel('.Outer_unset1'),
            // After outer IfFlag
            move.w(Word(0x0077).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('after FadeOut, ReturnControl fades in field', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..fadeOut(FadeOut())
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          Pause(1.second),
          ReturnControl(),
        ]))
        ..pause(Pause(2.seconds))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            // FadeOut
            jsr(Label('PalFadeOut_ClrSpriteTbl').l),
            // IfFlag
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset2')),
            // isSet branch: pause, fade in, then return
            move.w(Word(0x003B).i, d0),
            jsr(Label('VInt_PrepareLoop').l),
            // FadeInField cleanup
            movea.l(Constant('Map_Palettes_Addr').w, a0),
            jsr(Label('LoadMapPalette').l),
            jsr(Label('Pal_FadeIn').l),
            rts,
            // isUnset continues
            setLabel('.Test_unset2'),
            move.w(Word(0x0077).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('with panel shown, ReturnControl hides panels', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..showPanel(ShowPanel(PrincipalPanel.principal))
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          Pause(1.second),
          ReturnControl(),
        ]))
        ..pause(Pause(2.seconds))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            // ShowPanel
            move.w(Word(PrincipalPanel.principal.panelIndex).i, d0),
            jsr(Label('Panel_Create').l),
            jsr(Label('DMAPlanes_VInt').l),
            // IfFlag
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset2')),
            // isSet branch: pause, hide panels, then return
            move.w(Word(0x003B).i, d0),
            jsr(Label('VInt_PrepareLoop').l),
            // HideTopPanels cleanup
            jsr(Label('Panel_Destroy').l),
            jsr(Label('DMAPlanes_VInt').l),
            rts,
            // isUnset continues
            setLabel('.Test_unset2'),
            move.w(Word(0x0077).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('with camera locked, ReturnControl unlocks camera', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTrees(), eventAsm)
        ..lockCamera(LockCamera())
        ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
          Pause(1.second),
          ReturnControl(),
        ]))
        ..pause(Pause(2.seconds))
        ..finish();

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            // LockCamera
            bset(Byte(0x02).i, Constant('Char_Move_Flags').w),
            // IfFlag
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('.Test_unset2')),
            // isSet branch: pause, unlock camera, then return
            move.w(Word(0x003B).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            // UnlockCamera cleanup
            bclr(Byte(0x02).i, Constant('Char_Move_Flags').w),
            rts,
            // isUnset continues
            setLabel('.Test_unset2'),
            move.w(Word(0x0077).i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    group('in RunEvent mode', () {
      var map = GameMap(MapId.Test);
      var config = ProgramConfiguration.empty();

      test('immediate ReturnControl branches to RunEvent_NoEvent', () {
        var eventAsm = EventAsm.empty();
        var runEventAsm = Asm.empty();

        SceneAsmGenerator.forRunEvent(sceneId,
            inMap: map,
            eventAsm: eventAsm,
            runEventAsm: runEventAsm,
            config: config)
          ..ifFlag(IfFlag(EventFlag('Test'), isSet: [
            ReturnControl(),
          ]))
          ..pause(Pause(2.seconds))
          ..finish();

        // isSet branch has no events, just ReturnControl -> RunEvent_NoEvent
        // isUnset continues to the pause event
        expect(
            runEventAsm.withoutComments(),
            Asm([
              moveq(Constant('EventFlag_Test').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.Test_unset1')),
              // isSet branch: no event, go to no-op
              bra.w(Label('RunEvent_NoEvent')),
              setLabel('.Test_unset1'),
              // isUnset: dispatch to pause event
              move.w(Word(0x0000).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
            ]));
      });

      test('nested IfFlag with immediate ReturnControl in inner branch', () {
        var eventAsm = EventAsm.empty();
        var runEventAsm = Asm.empty();

        SceneAsmGenerator.forRunEvent(sceneId,
            inMap: map,
            eventAsm: eventAsm,
            runEventAsm: runEventAsm,
            config: config)
          ..ifFlag(IfFlag(EventFlag('Outer'), isSet: [
            ReturnControl(),
          ], isUnset: [
            IfFlag(EventFlag('Inner'), isSet: [
              Pause(1.second),
            ])
          ]))
          ..pause(Pause(2.seconds))
          ..finish();

        expect(
            runEventAsm.withoutComments(),
            Asm([
              moveq(Constant('EventFlag_Outer').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.Outer_unset1')),
              // Outer isSet: immediate return
              bra.w(Label('RunEvent_NoEvent')),
              bra.w(Label('.Outer_cont1')),
              setLabel('.Outer_unset1'),
              // Outer isUnset: check inner flag
              moveq(Constant('EventFlag_Inner').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.Inner_unset2')),
              // Inner isSet: dispatch to pause event
              move.w(Word(0x0001).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
              setLabel('.Inner_unset2'),
              setLabel('.Outer_cont1'),
              // Continue to second pause event
              move.w(Word(0x0002).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
            ]));
      });

      test('IfValue with immediate ReturnControl branches to RunEvent_NoEvent',
          () {
        var eventAsm = EventAsm.empty();
        var runEventAsm = Asm.empty();

        SceneAsmGenerator.forRunEvent(sceneId,
            inMap: map,
            eventAsm: eventAsm,
            runEventAsm: runEventAsm,
            config: config)
          ..ifValue(IfValue(hahn.slot(), comparedTo: NullSlot(), notEqual: [
            ReturnControl(),
          ]))
          ..pause(Pause(2.seconds))
          ..finish();

        expect(
            runEventAsm.withoutComments(),
            Asm([
              moveq(hahn.charIdAddress, d0),
              jsr(Label('FindCharacterSlot').l),
              cmpi.b(0xFF.i, d1),
              beq(Label('.1_continue')),
              // notEqual: immediate return
              bra.w(Label('RunEvent_NoEvent')),
              setLabel('.1_continue'),
              // equal: dispatch to pause event
              move.w(Word(0x0000).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
            ]));
      });

      test('IfFlag containing IfValue with immediate ReturnControl', () {
        var eventAsm = EventAsm.empty();
        var runEventAsm = Asm.empty();

        SceneAsmGenerator.forRunEvent(sceneId,
            inMap: map,
            eventAsm: eventAsm,
            runEventAsm: runEventAsm,
            config: config)
          ..ifFlag(IfFlag(EventFlag('Outer'), isSet: [
            IfValue(hahn.slot(), comparedTo: NullSlot(), notEqual: [
              ReturnControl(),
            ])
          ]))
          ..pause(Pause(2.seconds))
          ..finish();

        expect(
            runEventAsm.withoutComments(),
            Asm([
              moveq(Constant('EventFlag_Outer').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.Outer_unset1')),
              // Outer isSet: check hahn slot
              moveq(hahn.charIdAddress, d0),
              jsr(Label('FindCharacterSlot').l),
              cmpi.b(0xFF.i, d1),
              beq(Label('.2_continue')),
              // notEqual: immediate return
              bra.w(Label('RunEvent_NoEvent')),
              setLabel('.2_continue'),
              setLabel('.Outer_unset1'),
              // Continue to pause event
              move.w(Word(0x0001).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
            ]));
      });
    });
  });
}
