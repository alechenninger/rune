import 'package:charcode/ascii.dart';
import 'package:rune/asm/asm.dart';
import 'package:test/test.dart';

void main() {
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
