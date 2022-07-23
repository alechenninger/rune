import 'package:rune/generator/generator.dart';
import 'package:rune/generator/text.dart';
import 'package:rune/model/model.dart';
import 'package:rune/model/text.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  test('test', () {
    var g1 = TextGroup();
    var g2 = TextGroup();
    var fadeIn1 = g1.addSet()
      ..add(PaletteEvent(FadeState.fadeIn, Duration(seconds: 1)))
      ..add(PaletteEvent(FadeState.wait, Duration(seconds: 1)))
      ..add(PaletteEvent(FadeState.fadeOut, Duration(seconds: 1)));
    // var fadeIn3 = g1.addSet()
    //   ..add(PaletteEvent(FadeState.fadeIn, Duration(seconds: 1)))
    //   ..add(PaletteEvent(FadeState.fadeOut, Duration(seconds: 1)));
    var fadeIn2 = g2.addSet()
      ..add(PaletteEvent(FadeState.fadeIn, Duration(seconds: 3)))
      ..add(PaletteEvent(FadeState.fadeOut, Duration(seconds: 3)));
    var ctx = AsmContext.fresh();
    var asm = dislayText(
        DisplayText(
            lineOffset: 0,
            column: TextColumn(texts: [
              Text(spans: Span.parse('Hello world! '), groupSet: fadeIn1),
              Text(spans: Span.parse('Bye! '), groupSet: fadeIn2),
              // Text(spans: Span.parse('Hi again!'), groupSet: fadeIn3),
            ])),
        ctx);

    print(asm);
  });
}
