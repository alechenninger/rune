import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  var generator = AsmGenerator();

  group('a cursor separates', () {
    test('between dialogs', () {
      var dialog1 = Dialog(speaker: Alys(), spans: Span.parse("Hi"));
      var dialog2 = Dialog(speaker: Shay(), spans: Span.parse("Hello"));

      var scene = Scene([dialog1, dialog2]);
      var sceneAsm = generator.sceneToAsm(scene);

      expect(sceneAsm.dialog.toString(), '''${dialog1.toAsm()}
	dc.b	\$FD
${dialog2.toAsm()}
	dc.b	\$FF''');
    });
  });
}
