import 'package:rune/asm/asm.dart';
import 'package:rune/gapps/document.dart';
import 'package:rune/model/model.dart';
import 'package:rune/parser/gdocs.dart';
import 'package:rune/parser/movement.dart';
import 'package:test/test.dart';

void main() {
  group('tech.parse', () {
    test('aggregate groups many events', () {
      var techs = Tech.parse<Event>(Paragraph()
        ..addChild(
            InlineImage(altTitle: 'tech:aggregate', altDescription: '''---
tech:pause_seconds
---
3
---
tech:asm_event
---
; test''')));

      expect(techs, isNotNull);
      expect(techs!.length, equals(2));
      expect(techs[0], isA<Pause>());
      expect(techs[1], isA<AsmEvent>());

      var pause = techs[0] as Pause;
      expect(pause.duration, equals(Duration(seconds: 3)));

      var asm = techs[1] as AsmEvent;
      expect(asm.asm, equals(Asm.fromRaw('; test')));
    });

    test('footnote parses as event tech', () {
      var footnote = Footnote(FootnoteSection()..setText('Alys faces up'));
      var tech = Tech.parse<Event>(Paragraph()..addChild(footnote));

      expect(tech, equals(parseEvents('Alys faces up')));
    });

    test('parses footnotes and tech images', () {
      var footnote = Footnote(FootnoteSection()..setText('Alys faces up'));
      var paragraph = Paragraph()
        ..addChild(
            InlineImage(altTitle: 'tech:aggregate', altDescription: '''---
tech:pause_seconds
---
3
---
tech:asm_event
---
; test'''))
        ..addChild(footnote);

      var techs = Tech.parse<Event>(paragraph);

      expect(
          techs,
          equals([
            Pause(Duration(seconds: 3)),
            AsmEvent(Asm.fromRaw('; test')),
            ...parseEvents('Alys faces up')
          ]));
    });
  });

  group('dialog parse', () {
    test('parses narrative text', () {
      var p = Paragraph()..addChild(Text('narrative text: test 123'));
      var dialog = parseDialog(p);

      var expected = Dialog(spans: [Span('test 123', false)]);

      expect(dialog, expected);
    });
  });
}
