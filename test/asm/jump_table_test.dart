import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:test/test.dart';

void main() {
  test('dense tables reject overflow without changing existing entries', () {
    final table = JumpTable<Byte>(
        jump: bra.w, newIndex: Byte.new, capacity: 2, labels: [Label('First')]);
    expect(table.add(Label('Last')), Byte(1));
    final before = table.toAsm().toString();
    expect(() => table.add(Label('Overflow')), throwsStateError);
    expect(table.toAsm().toString(), before);
    expect(table[Label('Overflow')], isNull);
    expect(table.labelAtIndex(2), isNull);
  });

  test('sparse tables can fill a hole at the seeded capacity', () {
    final table = JumpTable<Byte>.sparse(
        jump: withNoop(Label('Noop'), bra.w),
        newIndex: Byte.new,
        capacity: 2,
        labels: [null, Label('Last')]);
    expect(table.add(Label('First')), Byte(0));
    expect(table.labelAtIndex(1), Label('Last'));
    expect(() => table.add(Label('Overflow')), throwsStateError);
    expect(table.labelAtIndex(2), isNull);
  });

  test(
      'sparse tables reuse holes then append, preserving existing registrations',
      () {
    final table = JumpTable<Byte>.sparse(
        jump: withNoop(Label('Noop'), bra.w),
        newIndex: Byte.new,
        capacity: 3,
        labels: [Label('First'), null]);
    expect(table.add(Label('Second')), Byte(1));
    expect(table.add(Label('Last')), Byte(2));
    expect(table.add(Label('Second')), Byte(1));
    final before = table.toAsm().toString();
    expect(() => table.add(Label('Overflow')), throwsStateError);
    expect(table.toAsm().toString(), before);
    expect(table[Label('Overflow')], isNull);
  });

  test('zero capacity rejects the first registration', () {
    final table = JumpTable<Byte>(jump: bra.w, newIndex: Byte.new, capacity: 0);
    expect(() => table.add(Label('Overflow')), throwsStateError);
    expect(table.labelAtIndex(0), isNull);
  });

  for (final sparse in [false, true]) {
    test('${sparse ? 'sparse' : 'dense'} tables validate initial capacity', () {
      JumpTable<Byte> create(int capacity, List<Label> labels) => sparse
          ? JumpTable<Byte>.sparse(
              jump: withNoop(Label('Noop'), bra.w),
              newIndex: Byte.new,
              capacity: capacity,
              labels: labels)
          : JumpTable<Byte>(
              jump: bra.w,
              newIndex: Byte.new,
              capacity: capacity,
              labels: labels);
      expect(() => create(-1, []), throwsArgumentError);
      expect(() => create(1, [Label('First'), Label('Last')]),
          throwsArgumentError);
    });
  }

  for (final (name, create, capacity) in [
    ('run events', runEventsJmpTbl, 0xff),
    ('map managers', mapDataManagersJmpTbl, 0x2000),
  ]) {
    test('$name allow the final valid index and reject the next registration',
        () {
      final table = create();
      final seeded = table.toAsm().length;
      final occupied = List.generate(seeded, table.labelAtIndex)
          .where((label) => label != null)
          .length;
      var lastIndex = -1;
      for (var i = occupied; i < capacity; i++) {
        lastIndex = table.add(Label('Generated_$i')).value;
      }
      expect(lastIndex, capacity - 1);
      expect(table.labelAtIndex(lastIndex), isNotNull);
      expect(() => table.add(Label('Overflow')), throwsStateError);
      expect(table[Label('Overflow')], isNull);
      expect(table.labelAtIndex(capacity), isNull);
    });
  }

  test('unseeded run events also reserve the terminator index', () {
    final config = ProgramConfiguration.empty();
    for (var i = 0; i < 0xff; i++) {
      expect(config.addRunEvent(Label('Generated_$i')), Byte(i));
    }
    expect(() => config.addRunEvent(Label('Overflow')), throwsStateError);
  });

  test(
      'manager configurations use unseeded or Grand Cross tables like run events',
      () {
    final empty = ProgramConfiguration.empty();
    expect(empty.addMapDataManager(Label('First')), Word(0));
    expect(empty.addMapDataManager(Label('First')), Word(0));
    expect(empty.addMapDataManager(Label('Second')), Word(1));

    final seeded = ProgramConfiguration.grandCross();
    expect(seeded.addMapDataManager(Label('MapDataMan_PrincipalOffice')),
        Word(0x1d));
    expect(seeded.addMapDataManager(Label('First')), Word(0x8c));
    expect(seeded.addMapDataManager(Label('First')), Word(0x8c));
  });
}
