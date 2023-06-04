import 'package:rune/asm/asm.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  var portrait = Bytes.of(1);

  test('line wrap', () {
    var asm =
        dialog(Bytes.ascii('This is a test of a long line that should wrap.'));
    expect(asm.toString(), equals(r'''	dc.b	"This is a test of a long line"
	dc.b	$FC
	dc.b	"that should wrap."'''));
  });

  test('maintains double space', () {
    var asm = dialog(Bytes.ascii('Maintains  a double space.'));
    expect(asm.toString(), equals(r'''	dc.b	"Maintains  a double space."'''));
  });

  test('can end line after dash', () {
    var asm = dialog(
        Bytes.ascii('It is testing a very long line--broken by dashes.'));
    expect(asm.toString(), equals(r'''	dc.b	"It is testing a very long line--"
	dc.b	$FC
	dc.b	"broken by dashes."'''));
  });

  test('can end line before end quote', () {
    var ascii = DialogSpan(
            "“The affairs of men weigh heavier than any beastly burden.”")
        .toAscii();
    var asm = dialog(ascii);
    expect(asm.toString(), equals(r'''	dc.b	"<The affairs of men weigh"
	dc.b	$FC
	dc.b	"heavier than any beastly"
	dc.b	$FD
	dc.b	"burden.>"'''));
  });

  test('cannot end line between dashes', () {
    var asm =
        dialog(Bytes.ascii("It's a test of a very long line--with dashes."));
    expect(asm.toString(), equals(r'''	dc.b	"It's a test of a very long"
	dc.b	$FC
	dc.b	"line--with dashes."'''));
  });

  test('continues many lines', () {
    var asm = dialog(
        Bytes.ascii("We'll meet head-on whatever the guild throws our way.  "
            "They'll have to go looking for new cases instead of "
            'waiting for the work to come in.'));
    expect(asm.toString(), equals(r'''	dc.b	"We'll meet head-on whatever the"
	dc.b	$FC
	dc.b	"guild throws our way.  They'll"
	dc.b	$FD
	dc.b	"have to go looking for new cases"
	dc.b	$FC
	dc.b	"instead of waiting for the work"
	dc.b	$FD
	dc.b	"to come in."'''));
  });

  test('only pause', () {
    var asm = dialog(Bytes.empty(), codePoints: [
      [PauseCode(Byte(60))]
    ]);
    expect(asm.toString(), equals(r'''	dc.b	$F9, $3C'''));
  });
}
