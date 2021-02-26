import 'package:charcode/ascii.dart';
import 'package:rune/asm/asm.dart';
import 'package:test/test.dart';

void main() {
  test('0xFF byte data to string is \$FF', () {
    var b = Bytes.hex('FF');
    expect(b.toString(), equals(r'$FF'));
  });

  test('254 byte data to string is \$FE', () {
    var b = Bytes.of(254);
    expect(b.toString(), equals(r'$FE'));
  });

  test('ascii byte data to string is a quoted ascii string', () {
    var b = Bytes.ascii('Look at that great big whale!');
    expect(b.toString(), equals(r'"Look at that great big whale!"'));
  });

  test('trim trims leading and trailing bytes', () {
    var b = Bytes.ascii('  Look at that great big whale! ');
    expect(
        b.trim($space).toString(), equals(r'"Look at that great big whale!"'));
  });
}
