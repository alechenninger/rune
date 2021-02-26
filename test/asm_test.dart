import 'package:rune/asm/asm.dart';
import 'package:test/test.dart';

void main() {
  test('0xFF byte data to string is \$FF', () {
    var b = Data.fromByteHex('FF');
    expect(b.toString(), equals(r'$FF'));
  });

  test('254 byte data to string is \$FE', () {
    var b = Data.fromByte(254);
    expect(b.toString(), equals(r'$FE'));
  });

  test('ascii byte data to string is a quoted ascii string', () {
    var b = Data.fromAscii('Look at that great big whale!');
    expect(b.toString(), equals(r'"Look at that great big whale!"'));
  });

  test('trim trims leading and trailing bytes', () {
    var b = Data.fromAscii('  Look at that great big whale! ');
    expect(b.trim(asciiSpace).toString(),
        equals(r'"Look at that great big whale!"'));
  });
}
