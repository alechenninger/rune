import 'package:collection/collection.dart';
import 'package:rune/asm/asm.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/cutscenes.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  late Program program;
  late GameMap map;

  setUp(() {
    program = Program();
    map = GameMap(MapId.Test);
  });

  EventAsm generateEventAsm(List<Event> events, [EventState? ctx]) {
    var asm = EventAsm.empty();
    var gen = SceneAsmGenerator.forEvent(SceneId('test'), DialogTrees(), asm)
      ..setContext(setContext(ctx));
    for (var e in events) {
      e.visit(gen);
    }
    gen.finish();
    return asm;
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
      var scene = Scene([(PlaySound(Sound.selection))]);
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
            getAndRunDialog3(Byte.one.i),
            generateEventAsm([moves], origState).withoutComments(),
            returnFromDialogEvent()
          ]));

      expect(
          program.eventPointers.withoutComments(),
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
              getAndRunDialog3(Byte.one.i),
              generateEventAsm([
                IndividualMoves()..moves[alys] = (StepPath()..distance = 1.step)
              ], origState)
                  .withoutComments()
                  .trim(),
              returnFromDialogEvent()
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
              getAndRunDialog3(Byte.one.i),
              generateEventAsm([moves], origState).withoutComments(),
              popAndRunDialog3,
              returnFromDialogEvent()
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
              getAndRunDialog3(Byte.one.i),
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
              returnFromDialogEvent()
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
              getAndRunDialog3(Byte.one.i),
              generateEventAsm([pause]).withoutComments(),
              returnFromDialogEvent()
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
              returnFromDialogEvent()
            ]));
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
        ..runEventFromInteractionIfNeeded(events);

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
        ..runEventFromInteractionIfNeeded(events);

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
            getAndRunDialog3(Byte.zero.i),
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
            getAndRunDialog3(Byte.zero.i),
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
            getAndRunDialog3(Byte.zero.i),
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
            beq.w(Label('test_Test_unset1')),
            pause1.withoutComments(),
            setLabel('test_Test_unset1')
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
            bne.w(Label('test_Test_set1')),
            pause1.withoutComments(),
            setLabel('test_Test_set1')
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
            beq.w(Label('test_Test_unset1')),
            pause2,
            bra.w(Label('test_Test_cont1')),
            setLabel('test_Test_unset1'),
            pause1,
            setLabel('test_Test_cont1')
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
            beq.w(Label('test_Test_unset1')),
            pause(3),
            bra.w(Label('test_Test_cont1')),
            setLabel('test_Test_unset1'),
            pause2,
            setLabel('test_Test_cont1')
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

      print(eventAsm);

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('test_Test_unset1')),
            pause2,
            bra.w(Label('test_Test_cont1')),
            setLabel('test_Test_unset1'),
            pause1,
            setLabel('test_Test_cont1'),
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('test_Test_unset4')),
            pause(4),
            bra.w(Label('test_Test_cont4')),
            setLabel('test_Test_unset4'),
            pause(3),
            setLabel('test_Test_cont4'),
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

      print('> event');
      print(eventAsm);
      print('> dialog');
      print(dialog);

      expect(
          eventAsm.withoutComments(),
          EventAsm([
            moveq(Constant('EventFlag_Test').i, d0),
            jsr(Label('EventFlags_Test').l),
            beq.w(Label('test_Test_unset1')),
            getAndRunDialog3(0.toByte.i),
            setLabel('test_Test_unset1'),
            getAndRunDialog3(1.toByte.i),
          ]).withoutComments());

      expect(
          dialog.forMap(map.id).toAsm(),
          containsAllInOrder(Asm([
            dc.b(hello[0].toAscii()),
            terminateDialog(),
            dc.b(greetings[0].toAscii()),
            terminateDialog()
          ])));
    });

    test('events which require context should fail if context is unknown', () {
      var eventAsm = EventAsm.empty();

      var generator =
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
            ]));

      // generator should not have failed at this point.
      print(eventAsm);

      // but then, add a relative move. because we do not know where alys might
      // be to start with, this should fail
      // (unless relative move code is later updated to deal with this
      // ambiguity, in which case we'll have to test it does generate code that
      // deals with that e.g. performs arithmetic in the asm)
      expect(() {
        generator.individualMoves(
            IndividualMoves()..moves[alys] = (StepPath()..distance = 2.steps));
      }, throwsStateError);
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
        ]));

      print(eventAsm);

      // success if doesn't throw; but should also assert output
    });

    group('in interactions', () {
      var map = GameMap(MapId.Test);
      var obj = MapObject(
          startPosition: Position(0x50, 0x50),
          spec: Npc(Sprite.PalmanOldMan1, WanderAround(Direction.down)));
      map.addObject(obj);

      late DialogTrees dialog;
      late EventAsm asm;
      late SceneAsmGenerator generator;
      late TestEventRoutines eventRoutines;

      setUp(() {
        dialog = DialogTrees();
        asm = EventAsm.empty();
        eventRoutines = TestEventRoutines();
      });

      test('in event, flag is checked in event code', () {
        generator = SceneAsmGenerator.forInteraction(
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

        var returnFromDialog = returnFromDialogEvent().withoutComments()
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
                .needsEvent([
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
                .needsEvent([
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
                .needsEvent([
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

      group('cannot then run event in interaction', () {
        test('if another event other than IfFlag has occurred', () {
          var generator = SceneAsmGenerator.forInteraction(
              map, SceneId('interact'), dialog, asm, eventRoutines)
            ..dialog(Dialog(spans: DialogSpan.parse('Flag1 is set')));

          expect(() => generator.runEventFromInteraction(), throwsStateError);
        });

        test('if already in event', () {
          var generator =
              SceneAsmGenerator.forEvent(SceneId('event'), dialog, asm);

          expect(() => generator.runEventFromInteraction(), throwsStateError);
        });

        test('if already run event in interaction', () {
          var generator = SceneAsmGenerator.forInteraction(
              map, SceneId('interact'), dialog, asm, eventRoutines)
            ..runEventFromInteraction();

          expect(() => generator.runEventFromInteraction(), throwsStateError);
        });
      });
    });
  });
}

SetContext setContext(EventState? ctx) {
  return SetContext((c) {
    c.followLead = ctx?.followLead ?? c.followLead;
    ctx?.positions.forEach((obj, pos) => c.positions[obj] = pos);
  });
}

MapObject testObjectForScene(Scene scene, {String id = '0'}) {
  return MapObject(
      id: id,
      startPosition: Position(0x200, 0x200),
      spec: Npc(Sprite.PalmanWoman1,
          WanderAround(Direction.down, onInteract: scene)));
}

extension EasyDuration on int {
  Duration get second => Duration(seconds: this);
  Duration get seconds => Duration(seconds: this);
}
