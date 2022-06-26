import 'package:rune/generator/dialog.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('generates asm from dialog', () {
    var dialog = Dialog(
        speaker: Alys(),
        spans: Span.parse("Hi I'm Alys! _What are you doing here?_"));

    print(dialog);

    var asm = dialog.toAsm();

    expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Hi I'm Alys! ", $64, $6F, $68, $7B, " ", $68, $79, $6C, " ", $80, $76, $7C, " ", $6B, $76, $70, $75, $6E
	dc.b	$FC
	dc.b	$6F, $6C, $79, $6C, $83''');
  });

  test('skips repeated spaces', () {
    var dialog = Dialog(speaker: Alys(), spans: Span.parse('Test  1 2 3'));

    print(dialog);

    var asm = dialog.toAsm();

    expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Test 1 2 3"''');
  });

  group('a cursor separates', () {
    test('every other line from the same dialog', () {
      var dialog = Dialog(
          speaker: Alys(),
          spans: Span.parse(
              "Hi I'm Alys! Lots of words take up lots of lines. You can "
              "only have 32 characters per line! How fascinating it is to "
              "deal with assembly."));

      print(dialog);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Hi I'm Alys! Lots of words take"
	dc.b	$FC
	dc.b	"up lots of lines. You can only"
	dc.b	$FD
	dc.b	"have 32 characters per line! How"
	dc.b	$FC
	dc.b	"fascinating it is to deal with"
	dc.b	$FD
	dc.b	"assembly."''');
    });
  });

  group('spans with pauses', () {
    test('just pause and speaker', () {
      var dialog = Dialog(
          speaker: Alys(), spans: [Span("", pause: Duration(seconds: 1))]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	$F9, $3C''');
    });

    test('just pause, no speaker', () {
      var dialog = Dialog(spans: [Span("", pause: Duration(seconds: 1))]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $00
	dc.b	$F9, $3C''');
    });

    test('pauses come at the end of spans', () {
      var dialog = Dialog(
          speaker: Alys(),
          spans: [Span("Hi I'm Alys!", pause: Duration(seconds: 1))]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Hi I'm Alys!"
	dc.b	$F9, $3C''');
    });

    test('bug1', () {
      /*
      ialog{speaker: Shay, _spans: [
      Span{text: It takes and it takes. And I owe it nothing..., italic: false, pause: 0:00:01.000000},
      Span{text: nothing but a fight.  , italic: false, pause: 0:00:01.000000},
      Span{text: , italic: false, pause: 0:00:00.000000}]}}
       */
      var dialog = Dialog(speaker: Shay(), spans: [
        Span('It takes and it takes. And I owe it nothing...',
            pause: Duration(seconds: 1)),
        Span('nothing but a fight.  ', pause: Duration(seconds: 1)),
        Span('')
      ]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $01
	dc.b	"It takes and it takes. And I owe"
	dc.b	$FC
	dc.b	"it nothing..."
	dc.b	$F9, $3C
	dc.b	"nothing but a"
	dc.b	$FD
	dc.b	"fight."
	dc.b	$F9, $3C''');
    });

    test('bug2', () {
      /*
      Dialog{speaker: Alys, _spans: [
      Span{text: Now take heed…, italic: false, pause: 0:00:01.000000},
      Span{text: else I walk alone once more., italic: false, pause: 0:00:01.000000}]},
      cause: RangeError (end): Invalid value: Not in inclusive range 0..11: 12}
       */
      var dialog = Dialog(speaker: Alys(), spans: [
        Span('Now take heed…', pause: Duration(seconds: 1)),
        Span('else I walk alone once more.', pause: Duration(seconds: 1)),
      ]);

      var asm = dialog.toAsm();

      print(asm);
    });

    test('pause at 32 characters mid dialog', () {
      var dialog = Dialog(speaker: shay, spans: [
        Span("That you’ve always done this...", pause: Duration(seconds: 1)),
        Span('alone.', pause: Duration(seconds: 1))
      ]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $01
	dc.b	"That you've always done this..."
	dc.b	$FC
	dc.b	$F9, $3C
	dc.b	"alone."
	dc.b	$F9, $3C''');
    });

    test('pause at 32 characters end of dialog', () {
      var dialog = Dialog(speaker: shay, spans: [
        Span("That you’ve always done this...", pause: Duration(seconds: 1)),
      ]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $01
	dc.b	"That you've always done this..."
	dc.b	$F9, $3C''');
    });
  });
}
