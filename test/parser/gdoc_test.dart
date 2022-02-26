import 'package:rune/asm/asm.dart';
import 'package:rune/gapps/document.dart';
import 'package:rune/model/model.dart';
import 'package:rune/parser/gdocs.dart';
import 'package:rune/parser/movement.dart';
import 'package:test/test.dart';

void main() {
  group('tech.parse', () {
    test('aggregate groups many events', () {
      var tech = Tech.parse<Event>(Paragraph()
        ..addChild(
            InlineImage(altTitle: 'tech:aggregate', altDescription: '''---
tech:pause_seconds
---
3
---
tech:asm_event
---
; test''')));

      expect(tech, isA<AggregateEvent>());

      var agg = tech as AggregateEvent;

      expect(agg.events.length, equals(2));
      expect(agg.events[0], isA<Pause>());
      expect(agg.events[1], isA<AsmEvent>());

      var pause = agg.events[0] as Pause;
      expect(pause.duration, equals(Duration(seconds: 3)));

      var asm = agg.events[1] as AsmEvent;
      expect(asm.asm, equals(Asm.fromRaw('; test')));
    });

    test('footnote parses as event tech', () {
      var footnote = Footnote(FootnoteSection()..setText('Alys faces up'));
      var tech = Tech.parse(Paragraph()..addChild(footnote));

      expect(tech, equals(parseEvent('Alys faces up')));
    });
  });
}
