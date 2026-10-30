import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:rune/asm/asm.dart';
import 'package:test/test.dart';

void main() {
  List<Sized> read(String source,
          [Map<Constant, Expression> values = const {}]) =>
      ConstantIterator(Asm.fromRaw(source).iterator,
              constants: Constants.fromMap(values))
          .toList();

  group('conditional constants', () {
    test('selects the first matching alternative and resumes after endif', () {
      expect(read('''
 if revision = 0
 dc.b 1
 elseif revision = 1
 dc.b 2
 elseif missing
 dc.b 3
 else
 dc.b 4
 endif
 dc.b 5''', {Constant('revision'): Value(1)}), [Byte(2), Byte(5)]);
    });

    test('nested selection restores its parent and sibling chains start fresh',
        () {
      expect(read('''
 if 1
 dc.b 1
 if 0
 dc.b 9
 elseif 0
 dc.b 9
 else
 dc.b 2
 endif
 dc.b 3
 else
 dc.b 9
 endif
 if 0
 dc.b 9
 endif
 dc.b 4
 if 0
 dc.b 9
 elseif 1
 dc.b 5
 endif'''), [Byte(1), Byte(2), Byte(3), Byte(4), Byte(5)]);
    });

    test('skips nested expressions and instructions in inactive branches', () {
      expect(read('''
 if 0
 if missing / 0
 include "unavailable.asm"
 else
 rts
 endif
 elseif -1
 if (255 + 1) > 255
 dc.w 256
 endif
 endif'''), [Word(256)]);
    });

    test('supports case insensitive directives and AS default aliases', () {
      expect(read('''
 IF 0
 dc.b 1
 ELSE 0
 dc.b 2
 ELSEIF
 dc.b 3
 ENDIF'''), [Byte(3)]);
    });

    test('tests definitions without requiring their numeric values', () {
      expect(read('''
 ifdef defined
 dc.b 1
 endif
 ifndef absent
 dc.b 2
 endif''', {Constant('defined'): Constant('unresolved')}), [Byte(1), Byte(2)]);
    });

    test('does not turn an unresolved condition into false', () {
      expect(() => read(' if missing=1\n dc.b 1\n endif'), throwsStateError);
    });

    test('retains symbolic data operands', () {
      expect(
          read(' if enabled\n dc.l Address\n endif',
              {Constant('enabled'): Value(1)}).single.toString(),
          'Address');
    });

    test('reports extra conditional arguments before expression evaluation',
        () {
      for (final source in [
        ' if , 1\n dc.b 1\n endif',
        ' if 1,\n dc.b 1\n endif',
        ' if missing, other\n endif',
        ' if 0\n elseif missing, other\n endif',
        ' if 0\n else missing, other\n endif',
        ' if 1\n elseif missing, other\n endif',
      ]) {
        expect(
            () => read(source),
            throwsA(isA<FormatException>().having((error) => error.message,
                'message', startsWith('expected one condition'))));
      }
    });

    test('keeps function arguments with commas deferred in skipped branches',
        () {
      expect(read('''
 if 0
 if unknown(1, 2)
 dc.b 9
 endif
 else
 dc.b 1
 endif'''), [Byte(1)]);
    });

    test('skips unsupported directives without imposing their argument grammar',
        () {
      expect(read('''
 if 0
 ifb first, second
 dc.b 9
 endif
 else
 dc.b 1
 endif'''), [Byte(1)]);
    });

    test('reports unsupported selection independently of argument count', () {
      expect(() => read(' ifb first, second\n dc.b 1\n endif'),
          throwsUnsupportedError);
    });

    for (final source in [
      ' else',
      ' elseif 1',
      ' endif',
      ' if 1\n dc.b 1',
      ' if 1\n else\n else\n endif',
      ' if 0\n else\n elseif 1\n endif',
      ' if\n endif',
      ' if 1\n endif 1',
      ' if 0\n if 0\n else\n else\n endif\n endif',
    ]) {
      test('rejects malformed structure: $source', () {
        expect(() => read(source), throwsFormatException);
      });
    }
  });

  group('remaining assembly', () {
    test('finishes an entered default branch without retaining its endif', () {
      final iterator = ConstantIterator(Asm.fromRaw('''
 if 0
 dc.b 9
 else
 dc.b 1,2
 endif
 dc.b 3''').iterator);
      expect(iterator.moveNext(), isTrue);
      expect(iterator.current, Byte(1));
      expect(
          iterator.remaining,
          Asm([
            dc.b([Byte(2)]),
            dc.b([Byte(3)])
          ]));
    });

    test('drains a partially read elseif and leaves future conditions deferred',
        () {
      final reader = ConstantReader.asm(Asm.fromRaw('''
 if 0
 dc.b 9
 elseif 1
 dc.w \$1234,\$5678
 elseif missing / 0
 dc.b 9
 else
 dc.b 9
 endif
 if unknown(1, 2)
 dc.b 3
 endif'''));
      expect(reader.readByte(), Byte(0x12));
      expect(
          reader.remaining,
          Asm([
            dc.b([Byte(0x34)]),
            dc.w([Word(0x5678)]),
            Asm.fromRaw(' if unknown(1, 2)\n dc.b 3\n endif'),
          ]));
    });

    test('preserves whole variadic conditional directives for the assembler',
        () {
      final iterator = ConstantIterator(Asm.fromRaw('''
 if 1
 dc.b 1
 ifb first, second
 dc.b 2
 endif
 endif''').iterator);
      iterator.moveNext();
      expect(iterator.remaining,
          Asm.fromRaw(' ifb first, second\n dc.b 2\n endif'));
    });

    test('preserves quoted semicolons in untouched conditions', () {
      final asm = Asm.fromRaw(' if "a;b"="a;b" ; assembler-owned condition\n'
          ' dc.b 1\n endif');
      final iterator = ConstantIterator(asm.iterator);
      final condition = iterator.remaining.first;
      expect(condition.operands.single.toString(), '"a;b"="a;b"');
      expect(condition.comment, 'assembler-owned condition');
    });

    test('before reading leaves unknown conditional assembly intact', () {
      final asm = Asm.fromRaw(' if missing\n dc.b 1\n endif');
      final iterator = ConstantIterator(asm.iterator);
      expect(iterator.remaining, asm);
    });

    test('closes entered blocks and preserves later unknown conditions', () {
      final iterator = ConstantIterator(Asm.fromRaw('''
 if 1
 if 1
 dc.b 1,2
 else
 dc.b 3
 endif
 dc.b 4
 else
 dc.b 5
 endif
 if missing
 dc.b 6
 endif''').iterator);
      expect(iterator.moveNext(), isTrue);
      expect(iterator.current, Byte(1));
      expect(
          iterator.remaining,
          Asm([
            dc.b([Byte(2)]),
            dc.b([Byte(4)]),
            Asm.fromRaw(' if missing\n dc.b 6\n endif'),
          ]));
      expect(iterator.moveNext(), isFalse);
      expect(iterator.remaining, isEmpty);
    });

    test('retains whole new blocks inside the selected continuation', () {
      final iterator = ConstantIterator(Asm.fromRaw('''
 if 1
 dc.b 1
 if missing
 dc.b 2
 else
 dc.b 3
 endif
 else
 if also_missing
 dc.b 4
 endif
 endif
 dc.b 5''').iterator);
      iterator.moveNext();
      expect(
          iterator.remaining,
          Asm([
            Asm.fromRaw(' if missing\n dc.b 2\n else\n dc.b 3\n endif'),
            dc.b([Byte(5)]),
          ]));
    });

    test('preserves code and labels that stop constant iteration', () {
      final iterator = ConstantIterator(Asm.fromRaw('''
 if 1
 dc.b 1
Routine:
 rts
 else
Skipped:
 rts
 endif
Tail:
 rts''').iterator);
      expect(iterator.toList(), [Byte(1)]);
      expect(iterator.remaining, Asm.fromRaw('Routine:\n rts\nTail:\n rts'));
    });

    test('retains partially read words and operands in order', () {
      final reader = ConstantReader.asm(Asm([
        dc.l([Longword(0x12345678), Longword(0x9abcdef0)]),
        dc.b([Byte(1)]),
      ]));
      expect(reader.readByte(), Byte(0x12));
      final remainder = ConstantReader.asm(reader.remaining);
      expect([for (var i = 0; i < 8; i++) remainder.readByte()],
          [0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0, 1].map(Byte.new));
      expect(reader.remaining, isEmpty);
    });

    test('rejects an unterminated entered block while draining', () {
      final iterator = ConstantIterator(Asm.fromRaw(' if 1\n dc.b 1').iterator);
      iterator.moveNext();
      expect(() => iterator.remaining, throwsFormatException);
    });
  });
}
