import 'package:rune/asm/asm.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  var generator = AsmGenerator();
  late Program program;

  group('a cursor separates', () {
    test('between dialogs', () {
      var dialog1 = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
      var dialog2 = Dialog(speaker: Shay(), spans: DialogSpan.parse('Hello'));

      var scene = Scene([dialog1, dialog2]);
      var sceneAsm =
          generator.sceneToAsm(scene, AsmContext.fresh(gameMode: Mode.dialog));
      var program = Program();
      program.addScene(SceneId('test'), scene);

      expect(sceneAsm.dialog[0].toString(), '''${dialog1.toAsm()}
	dc.b	\$FD
${dialog2.toAsm()}
	dc.b	\$FF''');

      expect(program.scenes[SceneId('test')]!.dialog[0].toString(),
          '''${dialog1.toAsm()}
	dc.b	\$FD
${dialog2.toAsm()}
	dc.b	\$FF''');
    });
  });

  group('just dialog', () {
    test('does not run an event', () {
      var dialog1 = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
      var dialog2 = Dialog(speaker: Shay(), spans: DialogSpan.parse('Hello'));

      var scene = Scene([dialog1, dialog2]);
      var ctx = AsmContext.fresh(gameMode: Mode.dialog);
      var sceneAsm = generator.sceneToAsm(scene, ctx);

      expect(
          sceneAsm.allDialog.withoutComments().toString(), '''${dialog1.toAsm()}
	dc.b	\$FD
${dialog2.toAsm()}
	dc.b	\$FF
''');
      expect(sceneAsm.event, Asm.empty());
      expect(ctx.eventPointers, Asm.empty());
    });

    test('if first event is FacePlayer, also does not run an event', () {
      var dialog1 = Dialog(speaker: Alys(), spans: DialogSpan.parse('Hi'));
      var dialog2 = Dialog(speaker: Shay(), spans: DialogSpan.parse('Hello'));

      var scene = Scene([dialog1, dialog2]);
      var ctx = AsmContext.fresh(gameMode: Mode.dialog);
      var sceneAsm = generator.sceneToAsm(scene, ctx);

      expect(
          sceneAsm.allDialog.withoutComments().toString(), '''${dialog1.toAsm()}
	dc.b	\$FD
${dialog2.toAsm()}
	dc.b	\$FF
''');
      expect(sceneAsm.event, Asm.empty());
      expect(ctx.eventPointers, Asm.empty());
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
}
