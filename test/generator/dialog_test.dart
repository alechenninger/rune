import 'package:rune/asm/asm.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('generates asm from dialog', () {
    var dialog = Dialog(
        speaker: Alys(),
        spans: DialogSpan.parse("Hi I'm Alys! _What are you doing here?_"));

    print(dialog);

    var asm = dialog.toAsm();

    expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Hi I'm Alys! ", $64, $6F, $68, $7B, " ", $68, $79, $6C, " ", $80, $76, $7C, " ", $6B, $76, $70, $75, $6E
	dc.b	$FC
	dc.b	$6F, $6C, $79, $6C, $83''');
  });

  test('skips repeated spaces', () {
    var dialog =
        Dialog(speaker: Alys(), spans: DialogSpan.parse('Test  1 2 3'));

    print(dialog);

    var asm = dialog.toAsm();

    expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Test 1 2 3"''');
  });

  test('all italics uses ascii for non-italics characters', () {
    var dialog = Dialog(spans: [
      DialogSpan("Alys peered out over the Motavian wilds, as the rising",
          italic: true)
    ]);

    var asm = dialog.toAsm();

    print(asm);

    expect(asm.toString(), r'''	dc.b	$F4, $00
	dc.b	$4E, $73, $80, $7A, " ", $77, $6C, $6C, $79, $6C, $6B, " ", $76, $7C, $7B, " ", $76, $7D, $6C, $79, " ", $7B, $6F, $6C
	dc.b	$FC
	dc.b	$5A, $76, $7B, $68, $7D, $70, $68, $75, " ", $7E, $70, $73, $6B, $7A, ", ", $68, $7A, " ", $7B, $6F, $6C, " ", $79, $70, $7A, $70, $75, $6E''');
  });

  group('a cursor separates', () {
    test('every other line from the same dialog', () {
      var dialog = Dialog(
          speaker: Alys(),
          spans: DialogSpan.parse(
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
          speaker: Alys(),
          spans: [DialogSpan("", pause: Duration(seconds: 1))]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	$F9, $3C''');
    });

    test('just pause, no speaker', () {
      var dialog = Dialog(spans: [DialogSpan("", pause: Duration(seconds: 1))]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $00
	dc.b	$F9, $3C''');
    });

    test('pauses come at the end of spans', () {
      var dialog = Dialog(
          speaker: Alys(),
          spans: [DialogSpan("Hi I'm Alys!", pause: Duration(seconds: 1))]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Hi I'm Alys!"
	dc.b	$F9, $3C''');
    });

    test('bug1', () {
      var dialog = Dialog(speaker: Shay(), spans: [
        DialogSpan('It takes and it takes. And I owe it nothing...',
            pause: Duration(seconds: 1)),
        DialogSpan('nothing but a fight.  ', pause: Duration(seconds: 1)),
        DialogSpan('')
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
        DialogSpan('Now take heed…', pause: Duration(seconds: 1)),
        DialogSpan('else I walk alone once more.', pause: Duration(seconds: 1)),
      ]);

      var asm = dialog.toAsm();

      print(asm);
    });

    test('pause at 32 characters mid dialog', () {
      var dialog = Dialog(speaker: shay, spans: [
        DialogSpan("That you’ve always done this...",
            pause: Duration(seconds: 1)),
        DialogSpan('alone.', pause: Duration(seconds: 1))
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
        DialogSpan("That you’ve always done this...",
            pause: Duration(seconds: 1)),
      ]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $01
	dc.b	"That you've always done this..."
	dc.b	$F9, $3C''');
    });
  });

  group('dialog count', () {
    test('==0 if empty', () {
      expect(DialogAsm.empty().dialogs, 0);
      expect(DialogAsm([]).dialogs, 0);
      expect(DialogAsm([comment('foo')]).dialogs, 0);
    });

    test('==0 if no terminator', () {
      expect(DialogAsm([dc.b(Bytes.ascii("Hello"))]).dialogs, 0);
    });

    test('==1 with just 0xff', () {
      expect(DialogAsm([dc.b(Bytes.of(0xff))]).dialogs, 1);
    });

    test('==1 with one dialog', () {
      expect(
          DialogAsm([
            dc.b(Bytes.ascii("Hello")),
            dc.b([Byte(0xff)])
          ]).dialogs,
          1);
    });

    test('==1 with one dialog terminator on same line', () {
      expect(
          DialogAsm([
            dc.b(BytesAndAscii([
              Bytes.ascii("Hello"),
              Bytes.list([0xff])
            ])),
          ]).dialogs,
          1);
    });

    test('==2 with one dialog and extra terminator', () {
      expect(
          DialogAsm([
            dc.b(Bytes.ascii("Hello")),
            dc.b([Byte(0xff)]),
            dc.b([Byte(0xff)])
          ]).dialogs,
          2);
    });

    test('==2 with two dialogs on same line', () {
      expect(
          DialogAsm([
            dc.b(BytesAndAscii([
              Bytes.ascii("Hello"),
              Bytes.list([0xff]),
              Bytes.ascii("World"),
              Bytes.list([0xff]),
            ])),
          ]).dialogs,
          2);
    });
  });
}
