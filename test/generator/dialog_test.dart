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

    expect(asm.toString(), r'''	dc.b	$F4
	dc.b	$02
	dc.b	"Hi I'm Alys! ", $64, $6F, $68, $7B, " ", $68, $79, $6C, " ", $80, $76, $7C, " ", $6B, $76, $70, $75, $6E
	dc.b	$FC
	dc.b	$6F, $6C, $79, $6C, $83''');
  });

  test('skips repeated spaces', () {
    var dialog = Dialog(speaker: Alys(), spans: Span.parse('Test  1 2 3'));

    print(dialog);

    var asm = dialog.toAsm();

    expect(asm.toString(), r'''	dc.b	$F4
	dc.b	$02
	dc.b	"Test 1 2 3"''');
  });

  group('a cursor separates', () {
    test('every other line from the same dialog', () {
      var dialog = Dialog(
          speaker: Alys(),
          spans: Span.parse(
              "Hi I'm Alys! Lots of words take up lots of lines. You can "
              "only have 32 characters per line!"));

      print(dialog);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4
	dc.b	$02
	dc.b	"Hi I'm Alys! Lots of words take"
	dc.b	$FC
	dc.b	"up lots of lines. You can only"
	dc.b	$FD
	dc.b	"have 32 characters per line!"''');
    });
  });
}
