import 'package:rune/gapps/document.dart';
import 'package:rune/model/model.dart';
import 'package:rune/parser/gdocs.dart';
import 'package:test/test.dart';

void main() {
  group('tech', () {
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
    });
  });
}
