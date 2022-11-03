import 'dart:typed_data';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:rune/asm/asm.dart';
import 'package:test/test.dart';

main() {
  group('raw instruction', () {
    test('withoutComment', () {
      var asm = Asm.fromRaw('\tdc.b\t"Abc"\t; test!');
      expect(asm.first.withoutComment(), dc.b(Bytes.ascii('Abc')).first);
    });

    test('withoutComment and no comment is noop', () {
      var asm = Asm.fromRaw('\tdc.b\t"Abc"\t');
      expect(asm.first.withoutComment(), Asm.fromRaw('\tdc.b\t"Abc"\t').first);
    });

    group('equivalent to model', () {
      test('empty', () {
        expect(Asm.fromRaw(''), newLine());
        expect(Asm.fromRaw('   '), newLine());
        expect(Asm.fromRaw('\t'), newLine());
      });

      test('dc.b with bytes', () {});

      test('dc.w with words', () {
        expect(Asm.fromRaw(r' dc.w $00'), dc.w([Word(0)]));
      });
    });

    group('equivalent back to string', () {
      test('address displacement', () {
        var asm =
            Asm.fromRaw(r'	move.w	$30(a4), $38(a4)	; move current to dest x');
        expect(asm.toString(),
            r'	move.w	$30(a4), $38(a4)	; move current to dest x');
      });
    });
  });

  test('instruction without comment removes comment', () {
    var asm = dc.b(Bytes.ascii('Abc'), comment: 'test!');
    expect(asm.first.withoutComment(), dc.b(Bytes.ascii('Abc')).first);
  });

  group('constant', () {
    group('iterator', () {
      test('reads bytes', () {
        var asm = dc.b(Bytes.list([1, 0, 1, 3, 10]));
        var iterator = ConstantIterator(asm.iterator);
        expect(
            iterator.toList(), [Byte(1), Byte(0), Byte(1), Byte(3), Byte(10)]);
      });

      test('reads words', () {
        var asm = dc.w(Words(Uint16List.fromList([1, 0, 1, 3, 10])));
        var iterator = ConstantIterator(asm.iterator);
        expect(
            iterator.toList(), [Word(1), Word(0), Word(1), Word(3), Word(10)]);
      });

      test('reads bytes multi line', () {
        var asm = Asm([
          dc.b(Bytes(Uint8List.fromList([1, 0, 1, 3, 10]))),
          dc.b(Bytes(Uint8List.fromList([0, 4, 2, 1])))
        ]);
        var iterator = ConstantIterator(asm.iterator);
        expect(iterator.toList(), [
          Byte(1),
          Byte(0),
          Byte(1),
          Byte(3),
          Byte(10),
          Byte(0),
          Byte(4),
          Byte(2),
          Byte(1),
        ]);
      });

      test('reads bytes and words multi line', () {
        var asm = Asm([
          dc.b(Bytes(Uint8List.fromList([1, 0, 1, 3, 10]))),
          dc.w(Words(Uint16List.fromList([0, 4, 2, 1])))
        ]);
        var iterator = ConstantIterator(asm.iterator);
        expect(iterator.toList(), [
          Byte(1),
          Byte(0),
          Byte(1),
          Byte(3),
          Byte(10),
          Word(0),
          Word(4),
          Word(2),
          Word(1),
        ]);
      });
    });

    group('reader', () {
      test('splits words into bytes', () {
        var asm = dc.w(Words(Uint16List.fromList([0x1234, 0x5678, 0x0205])));
        var reader = ConstantReader.asm(asm);
        expect(reader.readByte(), Byte(0x12));
        expect(reader.readByte(), Byte(0x34));
      });

      test('splits longs into words', () {
        var asm = dc.l([Longword(0x12345678)]);
        var reader = ConstantReader.asm(asm);
        expect(reader.readWord(), Word(0x1234));
        expect(reader.readWord(), Word(0x5678));
      });

      test('splits longs into bytes', () {
        var asm = dc.l([Longword(0x12345678)]);
        var reader = ConstantReader.asm(asm);
        expect(reader.readByte(), Byte(0x12));
        expect(reader.readByte(), Byte(0x34));
      });

      test('splits longs into bytes and words', () {
        var asm = dc.l([Longword(0x12345678)]);
        var reader = ConstantReader.asm(asm);
        expect(reader.readByte(), Byte(0x12));
        expect(reader.readByte(), Byte(0x34));
        expect(reader.readWord(), Word(0x5678));
      });

      test('joins bytes into word', () {
        var asm = dc.b(Bytes.list([0x12, 0x34, 0x02]));
        var reader = ConstantReader.asm(asm);
        expect(reader.readWord(), Word(0x1234));
      });

      test('joins words into long', () {
        var asm = dc.b(Bytes.list([0x12, 0x34, 0x02]));
        var reader = ConstantReader.asm(asm);
        expect(reader.readWord(), Word(0x1234));
      });

      test('label', () {
        var asm = dc.l([Label('test')]);
        var reader = ConstantReader.asm(asm);
        expect(reader.readLabel(), Label('test'));
      });

      test('mix', () {
        var asm = Asm([
          dc.l(Longwords.fromLongword(0x12345678)),
          dc.l([Label('test')]),
          dc.w([Word(0xffff)]),
        ]);
        var reader = ConstantReader.asm(asm);
        expect(reader.readWord(), Word(0x1234));
        expect(reader.readWord(), Word(0x5678));
        expect(reader.readLabel(), Label('test'));
        expect(reader.readWord(), Word(0xffff));
      });
    });
  });
}
