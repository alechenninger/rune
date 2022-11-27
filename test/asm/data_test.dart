import 'package:charcode/ascii.dart';
import 'package:rune/asm/asm.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  group('byte', () {
    test('0xFF byte data to string is \$FF', () {
      var b = Byte('FF'.hex);
      expect(b.toString(), equals(r'$FF'));
    });

    test('254 byte data to string is \$FE', () {
      var b = Byte(254);
      expect(b.toString(), equals(r'$FE'));
    });

    test('isNegative & isPositive', () {
      expect(Byte(0x80).isNegative, isTrue);
      expect(Byte(0x80).isPositive, isFalse);
      expect(Byte(0xFF).isNegative, isTrue);
      expect(Byte(0xFF).isPositive, isFalse);
      expect(Byte(0x7F).isPositive, isTrue);
      expect(Byte(0x7F).isNegative, isFalse);
      expect(Byte(0x00).isNegative, isFalse);
      expect(Byte(0x00).isPositive, isTrue);
      expect(Byte(0x01).isNegative, isFalse);
      expect(Byte(0x01).isPositive, isTrue);
    });
  });

  group('word', () {
    test('isNegative & isPositive', () {
      expect(Word(0x8000).isNegative, isTrue);
      expect(Word(0x8000).isPositive, isFalse);
      expect(Word(0xFFFF).isNegative, isTrue);
      expect(Word(0xFFFF).isPositive, isFalse);
      expect(Word(0x7FFF).isPositive, isTrue);
      expect(Word(0x7FFF).isNegative, isFalse);
      expect(Word(0x0000).isNegative, isFalse);
      expect(Word(0x0000).isPositive, isTrue);
      expect(Word(0x0001).isNegative, isFalse);
      expect(Word(0x0001).isPositive, isTrue);
    });
  });

  group('longword', () {
    test('isNegative & isPositive', () {
      expect(Longword(0x80000000).isNegative, isTrue);
      expect(Longword(0x80000000).isPositive, isFalse);
      expect(Longword(0xFFFFFFFF).isNegative, isTrue);
      expect(Longword(0xFFFFFFFF).isPositive, isFalse);
      expect(Longword(0x7FFFFFFF).isPositive, isTrue);
      expect(Longword(0x7FFFFFFF).isNegative, isFalse);
      expect(Longword(0x00000000).isNegative, isFalse);
      expect(Longword(0x00000000).isPositive, isTrue);
      expect(Longword(0x00000001).isNegative, isFalse);
      expect(Longword(0x00000001).isPositive, isTrue);
    });
  });

  group('bytes', () {
    test('0xFF byte data to string is \$FF', () {
      var b = Bytes.hex('FF');
      expect(b.toString(), equals(r'$FF'));
    });

    test('254 byte data to string is \$FE', () {
      var b = Bytes.of(254);
      expect(b.toString(), equals(r'$FE'));
    });
  });

  group('ascii', () {
    test('ascii byte data to string is a quoted ascii string', () {
      var b = Bytes.ascii('Look at that great big whale!');
      expect(b.toString(), equals(r'"Look at that great big whale!"'));
    });

    test('trim trims leading and trailing bytes', () {
      var b = Bytes.ascii('  Look at that great big whale! ');
      expect(b.trim($space).toString(),
          equals(r'"Look at that great big whale!"'));
    });
  });

  group('bytes and ascii', () {
    test('maintain string representation', () {
      var data =
          BytesAndAscii([Bytes.ascii('foo '), Bytes.of(1), Bytes.ascii('bar')]);

      expect(data.toString(), equals(r'"foo ", $01, "bar"'));
    });

    group('sublist', () {
      test('start within 1st span', () {
        var data = BytesAndAscii(
            [Bytes.ascii('foo '), Bytes.of(1), Bytes.ascii('bar')]);

        expect(data.sublist(2).toString(), equals(r'"o ", $01, "bar"'));
      });

      test('start within 1st span and end within last', () {
        var data = BytesAndAscii(
            [Bytes.ascii('foo '), Bytes.of(1), Bytes.ascii('bar')]);

        expect(data.sublist(2, 7).toString(), equals(r'"o ", $01, "ba"'));
      });

      test('start at 2nd span', () {
        var data = BytesAndAscii(
            [Bytes.ascii('foo '), Bytes.of(1), Bytes.ascii('bar')]);

        expect(data.sublist(4).toString(), equals(r'$01, "bar"'));
      });

      test('start within middle span', () {
        var data = BytesAndAscii([
          Bytes.ascii('foo '),
          Bytes.of(1),
          Bytes.ascii('test'),
          Bytes.of(2),
          Bytes.ascii('bar')
        ]);

        expect(data.sublist(6).toString(), equals(r'"est", $02, "bar"'));
      });

      test('start within last span', () {
        var data = BytesAndAscii(
            [Bytes.ascii('foo '), Bytes.of(1), Bytes.ascii('bar')]);

        expect(data.sublist(6).toString(), equals(r'"ar"'));
      });

      test('end at last', () {
        var data = BytesAndAscii(
            [Bytes.ascii('foo '), Bytes.of(1), Bytes.ascii('bar')]);

        expect(data.sublist(0, 5).toString(), equals(r'"foo ", $01'));
      });

      test('end within middle', () {
        var data = BytesAndAscii([
          Bytes.ascii('foo '),
          Bytes.of(1),
          Bytes.ascii('test'),
          Bytes.of(2),
          Bytes.ascii('bar')
        ]);

        expect(data.sublist(0, 7).toString(), equals(r'"foo ", $01, "te"'));
      });
    });

    group('trim', () {});
  });
}
