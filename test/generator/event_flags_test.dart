import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('fixed flags preserve build IDs through every lookup', () {
    final flags = FixedEventFlags({
      Constant('EVENTFLAG_CUSTOM'): Word(0x123),
      // Even a known vanilla name must use the supplied build's assignment.
      Constant('EVENTFLAG_PIATAFIRSTTIME'): Word(0x92),
    });
    const custom = EventFlag('Custom');
    expect(flags.toId(custom), Word(0x123));
    expect(flags.toConstant(custom), Constant('EventFlag_Custom'));
    expect(flags.toConstantValue(custom),
        KnownConstantValue(Constant('EventFlag_Custom'), Word(0x123)));
    expect(flags.toId(const EventFlag('PiataFirstTime')), Word(0x92));
    expect(flags.peekNextEventFlag, isNull);
    expect(flags.customEventFlags(), isEmpty);
  });

  test('fixed flags reject unknown names, including absent vanilla flags', () {
    final flags = FixedEventFlags({});
    for (final name in ['Missing', 'PiataFirstTime']) {
      final flag = EventFlag(name);
      expect(() => flags.toId(flag), throwsArgumentError);
      expect(() => flags.toConstant(flag), throwsArgumentError);
      expect(() => flags.toConstantValue(flag), throwsArgumentError);
    }
    expect(flags.customEventFlags(), isEmpty);
  });

  test('fixed flags snapshot the input and permit aliases', () {
    final mapping = {
      Constant('EventFlag_Custom'): Word(0x123),
      Constant('EventFlag_Alias'): Word(0x123),
    };
    final flags = FixedEventFlags(mapping);
    mapping.clear();
    expect(flags.toId(const EventFlag('Custom')), Word(0x123));
    expect(flags.toId(const EventFlag('Alias')), Word(0x123));
  });

  test('fixed flags reject conflicting case aliases and out-of-range IDs', () {
    expect(
        () => FixedEventFlags({
              Constant('EventFlag_Custom'): Word(1),
              Constant('EVENTFLAG_CUSTOM'): Word(2),
            }),
        throwsArgumentError);
    expect(() => FixedEventFlags({Constant('EventFlag_Custom'): Word(0x200)}),
        throwsArgumentError);
  });

  test('ordinary flags still allocate and reuse custom IDs', () {
    final flags = EventFlags();
    final next = flags.peekNextEventFlag;
    expect(flags.toId(const EventFlag('Custom')), next);
    expect(flags.toId(const EventFlag('Custom')), next);
    expect(flags.customEventFlags(), {next: Constant('EventFlag_Custom')});
  });
}
