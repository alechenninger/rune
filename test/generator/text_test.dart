import 'package:rune/generator/generator.dart';
import 'package:rune/generator/text.dart';
import 'package:rune/model/model.dart';
import 'package:rune/model/text.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  test('test', () {
    var group = TextGroup();
    var groupSet = group.addSet()
      ..add(PaletteEvent(FadeState.fadeIn, Duration(milliseconds: 500)));
    var ctx = AsmContext.fresh();
    var asm = dislayText(
        DisplayText(
            lineOffset: 0,
            column: TextColumn(texts: [
              Text(spans: Span.parse('Hello world!'), groupSet: groupSet)
            ])),
        ctx);

    print(asm);
  });
}
