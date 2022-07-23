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
    var fadeIn3 = g1.addSet()
      ..add(PaletteEvent(FadeState.fadeIn, Duration(seconds: 1)))
      ..add(PaletteEvent(FadeState.fadeOut, Duration(seconds: 1)));
    var fade4 = g1.addSet()
      ..add(PaletteEvent(FadeState.fadeIn, Duration(milliseconds: 500)))
      ..add(PaletteEvent(FadeState.wait, Duration(milliseconds: 500)))
      ..add(PaletteEvent(FadeState.fadeOut, Duration(milliseconds: 500)))
      ..add(PaletteEvent(FadeState.fadeIn, Duration(seconds: 1)))
      ..add(PaletteEvent(FadeState.fadeOut, Duration(seconds: 1)));
    var fadeIn2 = g2.addSet()
      ..add(PaletteEvent(FadeState.fadeIn, Duration(seconds: 3)))
      ..add(PaletteEvent(FadeState.fadeOut, Duration(seconds: 3)));
    var fadeIn5 = g2.addSet()
      ..add(PaletteEvent(FadeState.fadeIn, Duration(seconds: 2)))
      ..add(PaletteEvent(FadeState.fadeOut, Duration(seconds: 2)));
    var ctx = AsmContext.fresh();
    var asm = dislayText(
        DisplayText(
            lineOffset: 0,
            column: TextColumn(texts: [
              Text(spans: Span.parse('Hello world! '), groupSet: fadeIn1),
              Text(spans: Span.parse('Bye! '), groupSet: fadeIn2),
              Text(spans: Span.parse('Hi again! '), groupSet: fadeIn3),
              Text(
                  spans: Span.parse(
                      'This fading _business_ is really something. '),
                  groupSet: fade4),
              Text(spans: Span.parse("I'll say!"), groupSet: fadeIn5),
              Text(
                  spans: Span.parse('This is even wackier'), groupSet: fadeIn1),
            ])),
        ctx);

    print(asm);
  });
}
