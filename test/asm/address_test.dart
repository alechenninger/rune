import 'package:rune/asm/asm.dart';
import 'package:test/test.dart';

void main() {
  group('DirectDataRegister', () {
    group('operator -', () {
      test('d0 - d1 produces only d0 and d1', () {
        var list = d0 - d1;
        expect(list.toList(), equals([d0, d1]));
      });

      test('d0 - d1 toString is d0-d1', () {
        expect((d0 - d1).toString(), equals('d0-d1'));
      });

      test('d0 - d3 produces d0 through d3', () {
        var list = d0 - d3;
        expect(list.toList(), equals([d0, d1, d2, d3]));
      });

      test('d2 - d5 produces d2 through d5', () {
        var list = d2 - d5;
        expect(list.toList(), equals([d2, d3, d4, d5]));
      });

      test('d0 - d0 produces only d0', () {
        var list = d0 - d0;
        expect(list.toList(), equals([d0]));
      });

      test('d0 - d7 produces all data registers', () {
        var list = d0 - d7;
        expect(list.toList(), equals([d0, d1, d2, d3, d4, d5, d6, d7]));
      });

      test('d0 - a0 produces d0 through d7 and a0', () {
        var list = d0 - a0;
        expect(list.toList(), equals([d0, d1, d2, d3, d4, d5, d6, d7, a0]));
      });

      test('d0 - a6 produces d0 through d7 and a0 through a6', () {
        var list = d0 - a6;
        expect(
            list.toList(),
            equals(
                [d0, d1, d2, d3, d4, d5, d6, d7, a0, a1, a2, a3, a4, a5, a6]));
      });
    });

    group('operator /', () {
      test('d0 / d2 produces d0 and d2', () {
        var list = d0 / d2;
        expect(list.toList(), equals([d0, d2]));
      });

      test('d0 / a4 produces d0 and a4', () {
        var list = d0 / a4;
        expect(list.toList(), equals([d0, a4]));
      });
    });
  });

  group('DirectAddressRegister', () {
    group('operator -', () {
      test('a0 - a1 produces only a0 and a1', () {
        var list = a0 - a1;
        expect(list.toList(), equals([a0, a1]));
      });

      test('a0 - a3 produces a0 through a3', () {
        var list = a0 - a3;
        expect(list.toList(), equals([a0, a1, a2, a3]));
      });
    });
  });

  group('RegisterList', () {
    test('toString for range', () {
      expect(RegisterList.of([d0, d1, d2]).toString(), equals('d0-d2'));
    });

    test('toString for non-contiguous', () {
      expect(RegisterList.of([d0, d2]).toString(), equals('d0/d2'));
    });

    test('toString for mixed range and individual', () {
      expect(RegisterList.of([d0, d1, d2, a4]).toString(), equals('d0-d2/a4'));
    });

    test('toString for d2/a4', () {
      expect((d2 / a4).toString(), equals('d2/a4'));
    });
  });
}
