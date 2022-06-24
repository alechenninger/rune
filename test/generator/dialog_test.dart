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
    test('just pause', () {
      var dialog = Dialog(
          speaker: Alys(), spans: [Span("", pause: Duration(seconds: 1))]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $02
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
  });
}
