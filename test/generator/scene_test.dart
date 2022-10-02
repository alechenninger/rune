import 'package:collection/collection.dart';
import 'package:rune/asm/asm.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/conditional.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  var generator = AsmGenerator();
  var program = Program();

  group('a cursor separates', () {
    test('between dialogs', () {
      var dialog1 = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
      var dialog2 = Dialog(speaker: Shay(), spans: DialogSpan.parse('Hello'));

      var scene = Scene([dialog1, dialog2]);
      var sceneAsm = program.addScene(SceneId('test'), scene);

      expect(sceneAsm.dialog[0].toString(), '''${dialog1.toAsm()}
	dc.b	\$FD
${dialog2.toAsm()}
	dc.b	\$FF''');
    });
  });

  group('dialog with event', () {
    late EventState state;
    late EventState origState;

    setUp(() {
      state = EventState()
        ..positions[alys] = Position('50'.hex, '50'.hex)
        ..positions[shay] = Position('60'.hex, '60'.hex);
      origState = EventState()
        ..positions[alys] = Position('50'.hex, '50'.hex)
        ..positions[shay] = Position('60'.hex, '60'.hex);
    });

    test(
        'when dialog is first, dialog runs event and event immediately runs dialog at next offset',
        () {
      var ctx = AsmContext.forDialog(state);
      var eventIndex = ctx.peekNextEventIndex;

      var dialog1 = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
      var moves = IndividualMoves();
      moves.moves[alys] = StepPath()..distance = 1.step;

      var scene = Scene([dialog1, moves]);

      var sceneAsm = generator.sceneToAsm(scene, ctx);

      expect(sceneAsm.dialog.map((e) => e.withoutComments()).toList(), [
        DialogAsm([
          dc.b(Bytes.hex('F6')),
          dc.w([eventIndex]),
          dc.b(Bytes.hex('FF')),
        ]),
        DialogAsm([
          dialog1.toAsm(),
          dc.b(Bytes.hex('ff')),
        ])
      ]);

      expect(
          sceneAsm.event.withoutComments(),
          Asm([
            setLabel('Event_GrandCross_${eventIndex.value.toRadixString(16)}'),
            getAndRunDialog(Byte.one.i),
            generator
                .individualMovesToAsm(moves, AsmContext.forEvent(origState))
                .withoutComments(),
            returnFromDialogEvent()
          ]));

      expect(
          ctx.eventPointers.withoutComments(),
          Asm([
            dc.l([
              Label('Event_GrandCross_${eventIndex.value.toRadixString(16)}')
            ])
          ]));
    });

    group('during interaction', () {
      test(
          'when facing player is first but there are other events, faces player from within event',
          () {
        var obj = MapObject(
            startPosition: Position(0x200, 0x200),
            spec: AlysWaiting(),
            onInteractFacePlayer: true,
            onInteract: Scene([
              Dialog(spans: [DialogSpan('Hi')]),
              IndividualMoves()..moves[alys] = (StepPath()..distance = 1.step)
            ]));

        var ctx = AsmContext.forInteractionWith(obj, state);
        var sceneId = SceneId('Interact');

        var sceneAsm = generator.sceneToAsm(obj.onInteract, ctx, id: sceneId);

        print(sceneAsm);

        expect(
            sceneAsm.event.withoutComments(),
            Asm([
              setLabel('Event_GrandCross_Interact'),
              FacePlayer(obj).generateAsm(generator, ctx),
              getAndRunDialog(Byte.one.i),
              generator
                  .individualMovesToAsm(
                      IndividualMoves()
                        ..moves[alys] = (StepPath()..distance = 1.step),
                      AsmContext.forEvent(origState))
                  .withoutComments(),
              returnFromDialogEvent()
            ]));
      });
    });

    test('given dialog, event, dialog; event code runs dialog', () {
      var ctx = AsmContext.forDialog(state);
      var eventIndex = ctx.peekNextEventIndex;

      var dialog1 = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
      var moves = IndividualMoves();
      moves.moves[alys] = StepPath()..distance = 1.step;
      var dialog2 = Dialog(speaker: Shay(), spans: DialogSpan.parse('Hi'));

      var scene = Scene([dialog1, moves, dialog2]);

      var sceneAsm = generator.sceneToAsm(scene, ctx);

      expect(sceneAsm.dialog.map((e) => e.withoutComments()).toList(), [
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
          sceneAsm.event.withoutComments(),
          Asm([
            setLabel('Event_GrandCross_${eventIndex.value.toRadixString(16)}'),
            getAndRunDialog(Byte.one.i),
            generator
                .individualMovesToAsm(moves, AsmContext.forEvent(origState))
                .withoutComments(),
            popAndRunDialog,
            newLine(),
            returnFromDialogEvent()
          ]));
    });

    test(
        'given many exchanges between dialog and event; event code runs dialog',
        () {
      var ctx = AsmContext.forDialog(state);
      var eventIndex = ctx.peekNextEventIndex;

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

      var scene = Scene([dialog1, move1, dialog2, move2, dialog3, move3]);

      var sceneAsm = generator.sceneToAsm(scene, ctx);

      expect(sceneAsm.dialog.map((e) => e.withoutComments()).toList(), [
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
          sceneAsm.event.withoutComments(),
          Asm([
            setLabel('Event_GrandCross_${eventIndex.value.toRadixString(16)}'),
            getAndRunDialog(Byte.one.i),
            generator
                .individualMovesToAsm(move1, AsmContext.forEvent(origState))
                .withoutComments(),
            popAndRunDialog,
            newLine(),
            generator
                .individualMovesToAsm(move2, AsmContext.forEvent(origState))
                .withoutComments(),
            popAndRunDialog,
            newLine(),
            generator
                .individualMovesToAsm(move3, AsmContext.forEvent(origState))
                .withoutComments(),
            returnFromDialogEvent()
          ]));
    });

    test('if starting from dialog with dialog then pause, pause within event',
        () {
      var ctx = AsmContext.forDialog(state);
      var eventIndex = ctx.peekNextEventIndex;

      var dialog = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
      var pause = Pause(Duration(seconds: 2));

      var scene = Scene([dialog, pause]);
      var sceneAsm =
          generator.sceneToAsm(scene, AsmContext.fresh(gameMode: Mode.dialog));

      expect(sceneAsm.dialog.map((e) => e.withoutComments()).toList(), [
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
          sceneAsm.event.withoutComments(),
          Asm([
            setLabel('Event_GrandCross_${eventIndex.value.toRadixString(16)}'),
            getAndRunDialog(Byte.one.i),
            generator.pauseToAsm(pause),
            returnFromDialogEvent()
          ]));
    });

    test(
        "if starting from dialog and only pausing, pause within event and don't run dialog",
        () {
      var ctx = AsmContext.forDialog(state);
      var eventIndex = ctx.peekNextEventIndex;

      var pause = Pause(Duration(seconds: 2));

      var scene = Scene([pause]);
      var sceneAsm =
          generator.sceneToAsm(scene, AsmContext.fresh(gameMode: Mode.dialog));

      expect(sceneAsm.dialog.map((e) => e.withoutComments()).toList(), [
        DialogAsm([
          dc.b(Bytes.hex('F6')),
          dc.w([eventIndex]),
          dc.b(Bytes.hex('FF')),
        ]),
      ]);

      expect(
          sceneAsm.event.withoutComments(),
          Asm([
            setLabel('Event_GrandCross_${eventIndex.value.toRadixString(16)}'),
            generator.pauseToAsm(pause),
            returnFromDialogEvent()
          ]));
    });
  });

  group('conditional events', () {
    var sceneId = SceneId('test');

    Asm pause(int seconds) {
      var asm = EventAsm.empty();
      SceneAsmGenerator.forEvent(sceneId, DialogTree(), asm)
        ..pause(Pause(seconds.seconds))
        ..finish();
      return asm;
    }

    var pause1 = pause(1);
    var pause2 = pause(2);

    test('runs if-set events iff event flag is set', () {
      var eventAsm = EventAsm.empty();

      SceneAsmGenerator.forEvent(sceneId, DialogTree(), eventAsm)
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

      SceneAsmGenerator.forEvent(sceneId, DialogTree(), eventAsm)
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

      SceneAsmGenerator.forEvent(sceneId, DialogTree(), eventAsm)
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

      SceneAsmGenerator.forEvent(sceneId, DialogTree(), eventAsm)
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

      SceneAsmGenerator.forEvent(sceneId, DialogTree(), eventAsm)
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
      var dialog = DialogTree();

      var hello = DialogSpan.parse('Hello!');
      var greetings = DialogSpan.parse('Greetings!');

      SceneAsmGenerator.forEvent(sceneId, dialog, eventAsm)
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
            getAndRunDialog(0.toByte.i),
            setLabel('test_Test_unset1'),
            getAndRunDialog(1.toByte.i),
          ]).withoutComments());

      expect(
          dialog.toAsm(),
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
          SceneAsmGenerator.forEvent(sceneId, DialogTree(), eventAsm)
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

      SceneAsmGenerator.forEvent(sceneId, DialogTree(), eventAsm)
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

      late DialogTree dialog;
      late EventAsm asm;
      late SceneAsmGenerator generator;
      late TestEventRoutines eventRoutines;

      setUp(() {
        dialog = DialogTree();
        asm = EventAsm.empty();
        eventRoutines = TestEventRoutines();
      });

      test('in event, flag is checked in event code', () {
        generator = SceneAsmGenerator.forInteraction(
            map, obj, SceneId('interact'), dialog, asm, eventRoutines);
        // todo:
      });

      test('in dialog, flag is checked in dialog', () {
        SceneAsmGenerator.forInteraction(
            map, obj, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            FacePlayer(obj),
            Dialog(spans: DialogSpan.parse('Flag1 is set'))
          ], isUnset: [
            FacePlayer(obj),
            Dialog(spans: DialogSpan.parse('Flag1 is not set'))
          ]))
          ..finish();

        print(dialog);

        expect(asm, isEmpty);
        expect(
            dialog.toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 is not set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 is set').toAscii()),
              terminateDialog(),
            ]));
      });

      test('in dialog, if no dialog when flag set, terminate', () {
        SceneAsmGenerator.forInteraction(
            map, obj, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            FacePlayer(obj),
          ], isUnset: [
            FacePlayer(obj),
            Dialog(spans: DialogSpan.parse('Flag1 is not set'))
          ]))
          ..finish();

        print(dialog);

        expect(asm, isEmpty);
        expect(
            dialog.toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 is not set').toAscii()),
              terminateDialog(),
              newLine(),
              terminateDialog(),
            ]));
      });

      test('in dialog, dead branches are pruned', () {
        SceneAsmGenerator.forInteraction(
            map, obj, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            // redundant check
            IfFlag(EventFlag('flag1'), isSet: [
              FacePlayer(obj),
              Dialog(spans: DialogSpan.parse('Flag1 is set'))
            ], isUnset: [
              // dead code
              Pause(1.second)
            ])
          ], isUnset: [
            FacePlayer(obj),
            Dialog(spans: DialogSpan.parse('Flag1 is not set'))
          ]))
          ..finish();

        print(dialog);

        expect(asm, isEmpty);
        expect(
            dialog.toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 is not set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 is set').toAscii()),
              terminateDialog(),
            ]));
      });

      test('in dialog, alternate flags are checked in same dialog', () {
        SceneAsmGenerator.forInteraction(
            map, obj, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            FacePlayer(obj),
            Dialog(spans: DialogSpan.parse('Flag1 is set'))
          ], isUnset: [
            IfFlag(EventFlag('flag2'), isSet: [
              FacePlayer(obj),
              Dialog(spans: DialogSpan.parse('Flag1 is not set, but 2 is'))
            ], isUnset: [
              FacePlayer(obj),
              Dialog(spans: DialogSpan.parse('Flag1 and 2 are not set'))
            ]),
          ]))
          ..finish();

        print(dialog);

        expect(asm, isEmpty);
        expect(
            dialog.toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag2'), Byte(0x02)]),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 and 2 are not set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 is set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 is not set, but 2 is').toAscii()),
              terminateDialog(),
            ]));
      });

      test('in dialog, nested flags are checked in consecutive dialog', () {
        SceneAsmGenerator.forInteraction(
            map, obj, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            IfFlag(EventFlag('flag3'), isSet: [
              FacePlayer(obj),
              Dialog(spans: DialogSpan.parse('Flag1 and 3 are set'))
            ], isUnset: [
              FacePlayer(obj),
              Dialog(spans: DialogSpan.parse('Flag1 is set, but 3 is not'))
            ]),
          ], isUnset: [
            IfFlag(EventFlag('flag2'), isSet: [
              FacePlayer(obj),
              Dialog(spans: DialogSpan.parse('Flag1 is not set, but 2 is'))
            ], isUnset: [
              FacePlayer(obj),
              Dialog(spans: DialogSpan.parse('Flag1 and 2 are not set'))
            ]),
          ]))
          ..finish();

        expect(asm, isEmpty);
        expect(
            dialog.toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag2'), Byte(0x02)]),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 and 2 are not set').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag3'), Byte(0x02)]),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 is set, but 3 is not').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 is not set, but 2 is').toAscii()),
              terminateDialog(),
              newLine(),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 and 3 are set').toAscii()),
              terminateDialog(),
            ]));
      });

      test('dialog branches that need events run events', () {
        SceneAsmGenerator.forInteraction(
            map, obj, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            SetContext((ctx) => ctx.positions[alys] = Position(0x50, 0x50)),
            IndividualMoves()..moves[alys] = (StepPath()..distance = 1.steps)
          ], isUnset: [
            FacePlayer(obj),
            Dialog(spans: DialogSpan.parse('Flag1 is not set'))
          ]))
          ..finish();

        print(asm);

        expect(eventRoutines.routines,
            [Label('Event_GrandCross_interactflag1Set')]);
        expect(asm.withoutComments().firstOrNull?.toAsm(),
            setLabel('Event_GrandCross_interactflag1Set'));
        expect(
            dialog.toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b([Byte(0xF4), Byte.zero]),
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
            map, obj, SceneId('interact'), dialog, asm, eventRoutines)
          ..ifFlag(IfFlag(EventFlag('flag1'), isSet: [
            FacePlayer(obj),
            Dialog(spans: DialogSpan.parse('Flag1 is set'))
          ], isUnset: [
            SetContext((ctx) => ctx.positions[alys] = Position(0x50, 0x50)),
            IndividualMoves()..moves[alys] = (StepPath()..distance = 1.steps)
          ]))
          ..finish();

        print(asm);

        expect(asm.withoutComments().firstOrNull?.toAsm(),
            setLabel('Event_GrandCross_interactflag1Unset'));

        var returnFromDialog = returnFromDialogEvent().withoutComments();
        expect(asm.withoutComments().tail(returnFromDialog.length),
            returnFromDialog);

        expect(
            dialog.toAsm().withoutComments().trim(),
            Asm([
              dc.b([Byte(0xFA)]),
              dc.b([Constant('EventFlag_flag1'), Byte(0x01)]),
              dc.b([Byte(0xf6)]),
              dc.w([Word(0)]),
              terminateDialog(),
              newLine(),
              dc.b([Byte(0xF4), Byte.zero]),
              dc.b(DialogSpan('Flag1 is set').toAscii()),
              terminateDialog(),
            ]));
      });

      test('does not need event if branches only contain dialog', () {
        expect(
            SceneAsmGenerator.forInteraction(
                    map, obj, SceneId('interact'), dialog, asm, eventRoutines)
                .needsEvent([
              IfFlag(EventFlag('flag1'), isSet: [
                Dialog(spans: DialogSpan.parse('Flag1 is set'))
              ], isUnset: [
                Dialog(spans: DialogSpan.parse('Flag1 is not set'))
              ])
            ]),
            false);
      });

      test('does not need event even if a branch has events', () {
        expect(
            SceneAsmGenerator.forInteraction(
                    map, obj, SceneId('interact'), dialog, asm, eventRoutines)
                .needsEvent([
              IfFlag(EventFlag('flag1'), isSet: [
                Dialog(spans: DialogSpan.parse('Flag1 is set')),
                Pause(1.second),
              ], isUnset: [
                Dialog(spans: DialogSpan.parse('Flag1 is not set'))
              ])
            ]),
            false);
      });

      test('does need event if there are unconditional events', () {
        expect(
            SceneAsmGenerator.forInteraction(
                    map, obj, SceneId('interact'), dialog, asm, eventRoutines)
                .needsEvent([
              IfFlag(EventFlag('flag1'), isSet: [
                Dialog(spans: DialogSpan.parse('Flag1 is set')),
                Pause(1.second),
              ], isUnset: [
                Dialog(spans: DialogSpan.parse('Flag1 is not set'))
              ]),
              IfFlag(EventFlag('flagother'))
            ]),
            true);
      });

      group('cannot then run event in interaction', () {
        test('if another event other than IfFlag has occurred', () {
          var generator = SceneAsmGenerator.forInteraction(
              map, obj, SceneId('interact'), dialog, asm, eventRoutines)
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
              map, obj, SceneId('interact'), dialog, asm, eventRoutines)
            ..runEventFromInteraction();

          expect(() => generator.runEventFromInteraction(), throwsStateError);
        });
      });
    });
  });
}

extension EasyDuration on int {
  Duration get second => Duration(seconds: this);
  Duration get seconds => Duration(seconds: this);
}
