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

  group('a cursor separates', () {
    test('between dialogs', () {
      var dialog1 = Dialog(speaker: Alys(), spans: Span.parse('Hi'));
      var dialog2 = Dialog(speaker: Shay(), spans: Span.parse('Hello'));

      var scene = Scene([dialog1, dialog2]);
      var sceneAsm =
          generator.sceneToAsm(scene, AsmContext.fresh(gameMode: Mode.dialog));

      expect(sceneAsm.dialog[0].toString(), '''${dialog1.toAsm()}
	dc.b	\$FD
${dialog2.toAsm()}
	dc.b	\$FF''');
    });
  });

  group('just dialog', () {
    test('does not run an event', () {
      var dialog1 = Dialog(speaker: Alys(), spans: Span.parse('Hi'));
      var dialog2 = Dialog(speaker: Shay(), spans: Span.parse('Hello'));

      var scene = Scene([dialog1, dialog2]);
      var sceneAsm =
          generator.sceneToAsm(scene, AsmContext.fresh(gameMode: Mode.dialog));

      expect(
          sceneAsm.allDialog.withoutComments().toString(), '''${dialog1.toAsm()}
	dc.b	\$FD
${dialog2.toAsm()}
	dc.b	\$FF''');
      expect(sceneAsm.event, Asm.empty());
      expect(sceneAsm.eventPointers, Asm.empty());
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

      var dialog1 = Dialog(speaker: Alys(), spans: Span.parse('Hi'));
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
          sceneAsm.eventPointers.withoutComments(),
          Asm([
            dc.l([
              Label('Event_GrandCross_${eventIndex.value.toRadixString(16)}')
            ])
          ]));
    });

    test('given dialog, event, dialog; event code runs dialog', () {
      var ctx = AsmContext.forDialog(state);
      var eventIndex = ctx.peekNextEventIndex;

      var dialog1 = Dialog(speaker: Alys(), spans: Span.parse('Hi'));
      var moves = IndividualMoves();
      moves.moves[alys] = StepPath()..distance = 1.step;
      var dialog2 = Dialog(speaker: Shay(), spans: Span.parse('Hi'));

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
            returnFromDialogEvent()
          ]));
    });

    test(
        'given many exchanges between dialog and event; event code runs dialog',
        () {
      var ctx = AsmContext.forDialog(state);
      var eventIndex = ctx.peekNextEventIndex;

      var dialog1 = Dialog(speaker: Alys(), spans: Span.parse('Hi'));
      var move1 = IndividualMoves();
      move1.moves[alys] = StepPath()..distance = 1.step;
      var dialog2 = Dialog(speaker: Shay(), spans: Span.parse('Hi'));
      var move2 = IndividualMoves();
      move2.moves[shay] = StepPath()..distance = 1.step;
      var dialog3 = Dialog(speaker: Shay(), spans: Span.parse('How are you'));
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
            generator
                .individualMovesToAsm(move2, AsmContext.forEvent(origState))
                .withoutComments(),
            popAndRunDialog,
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

      var dialog = Dialog(speaker: Alys(), spans: Span.parse('Hi'));
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
