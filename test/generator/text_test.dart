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
    var asm = displayText(
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

  test(
      'drawing to vram and mapping plane at new location does not show phantom text',
      () {
    // need to get 2 texts to load simultaneously
    // and then after, one loads which goes past
    var g1 = TextGroup();
    var g2 = TextGroup();
    var g1s1 = g1.addSet()
      ..add(fadeIn(Duration(seconds: 1)))
      ..add(fadeOut(Duration(seconds: 1)));
    var g1s2 = g1.addSet()
      ..add(fadeIn(Duration(seconds: 1)))
      ..add(fadeOut(Duration(seconds: 1)));
    var g2s1 = g2.addSet()
      ..add(fadeIn(Duration(seconds: 1)))
      ..add(fadeOut(Duration(seconds: 1)));

    var display = DisplayText(
        lineOffset: 0,
        column: TextColumn(texts: [
          Text(spans: [Span('hello ')], groupSet: g1s1),
          Text(
              spans: [Span('1234567890abcdefghijklmnopqrstuvwxyz!-– ')],
              groupSet: g2s1),
          Text(spans: Span.parse('world '), groupSet: g1s1),
          Text(
              spans: [Span('1234567890abcdefghijklmnopqrstuvwxyz!-– ')],
              groupSet: g1s2),
        ]));

    print(displayText(display, AsmContext.fresh()));
  });
}
