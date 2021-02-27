import 'package:rune/generator/dialog.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('generates asm from dialog', () {
    var dialog = Dialog(
        speaker: Alys(), markup: "Hi I'm Alys! _What are you doing here?_");

    var asm = dialog.toAsm();

    print(asm);

    expect(asm.toString(), '''''');
  });
}
