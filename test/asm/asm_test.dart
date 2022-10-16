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

    group('equivalence', () {
      test('empty', () {
        expect(Asm.fromRaw(''), newLine());
        expect(Asm.fromRaw('   '), newLine());
        expect(Asm.fromRaw('\t'), newLine());
      });
    });
  });

  test('instruction without comment removes comment', () {
    var asm = dc.b(Bytes.ascii('Abc'), comment: 'test!');
    expect(asm.first.withoutComment(), dc.b(Bytes.ascii('Abc')).first);
  });
}
