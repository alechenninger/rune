import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:rune/asm/asm.dart';
import 'package:test/test.dart';

void main() {
  group('scalar expression parsing', () {
    test('literals are unsized and grouping does not change symbol identity',
        () {
      final literal = Expression.parse('1');
      expect(literal, Value(1));
      expect(literal, isNot(isA<Sized>()));
      expect(Expression.parse('revision'), Constant('revision'));
      expect(Expression.parse('(revision)'), Constant('revision'));
    });

    test('unknown symbols are valid syntax', () {
      final expression = Expression.parse('missing + 1');
      expect(
          () => expression
              .evaluate(EvaluationContext(const Constants.none()))
              .requireInt(),
          throwsStateError);
    });

    for (final source in ['1,2', '1 +', '(1', 'function(1)', '(A0).w']) {
      test('rejects malformed or unsupported scalar syntax: $source', () {
        expect(() => Expression.parse(source), throwsFormatException);
      });
    }
  });

  group('assembly and line parsing', () {
    test('an instruction parser returns one instruction', () {
      final instruction = Instruction.parse('Start: move.w (A0), d1');
      expect(instruction.label, 'Start');
      expect(instruction.cmd, 'move.w');
      expect(instruction.operands, ['(A0)', 'd1']);
    });

    test('multiline input belongs to Asm', () {
      const source = 'Start:\n rts';
      expect(Asm.fromRaw(source), hasLength(2));
      expect(() => Instruction.parse(source), throwsFormatException);
    });
  });

  group('binary operator matching', () {
    for (final (source, operator) in [
      ('1<<2', ArithmeticOperator.shiftLeft),
      ('4>>1', ArithmeticOperator.shiftRight),
      ('1&2', ArithmeticOperator.and),
      ('1|2', ArithmeticOperator.or),
      ('1!2', ArithmeticOperator.xor),
    ]) {
      test('matches $source as arithmetic', () {
        expect(
            Expression.parse(source),
            isA<ArithmeticExpression>()
                .having((e) => e.operator, 'operator', operator));
      });
    }

    for (final (source, operator) in [
      ('1<2', BooleanOperator.less),
      ('1<=2', BooleanOperator.lessOrEqual),
      ('1<>2', BooleanOperator.notEqual),
      ('2>1', BooleanOperator.greater),
      ('2>=1', BooleanOperator.greaterOrEqual),
      ('1=1', BooleanOperator.equal),
      ('1==1', BooleanOperator.equal),
      ('1&&2', BooleanOperator.and),
      ('1||2', BooleanOperator.or),
      ('1!!2', BooleanOperator.xor),
    ]) {
      test('matches $source as boolean', () {
        expect(
            Expression.parse(source),
            isA<BooleanOperation>()
                .having((e) => e.operator, 'operator', operator));
      });
    }
  });

  group('instruction operand boundaries', () {
    test('preserves empty arguments for the consuming directive to validate',
        () {
      expect(Instruction.parse(' if , enabled').operands, ['', 'enabled']);
      expect(Instruction.parse(' if enabled,').operands, ['enabled', '']);
    });

    test('data directives reject empty operands', () {
      for (final operands in [', 1', '1,', '1,,2']) {
        expect(
            () => Instruction.parse(' dc.b $operands'), throwsFormatException);
      }
    });

    test('conditional arguments use the shared operand boundaries', () {
      expect(Instruction.parse(' if revision = 1').operands, ['revision = 1']);
      expect(
          Instruction.parse(' if function(1, 2)').operands, ['function(1, 2)']);
      expect(Instruction.parse(' if revision, other').operands,
          ['revision', 'other']);
      expect(Instruction.parse(' ifb first, second').operands,
          ['first', 'second']);
    });

    test('whitespace inside a data expression does not add operands', () {
      final compact = Asm.fromRaw(' dc.w 1+2').first;
      final spaced = Asm.fromRaw(' dc.w 1 + 2').first;
      expect(compact.operands, hasLength(1));
      expect(spaced.operands, hasLength(1));
      expect(spaced, compact);
    });

    test('indexed addresses retain their internal commas', () {
      expect(Asm.fromRaw(' move.w 8(a0,d0.w), (a1)'),
          cmd('move.w', ['8(a0,d0.w)', '(a1)']));
    });

    test('macro operands preserve quotes and nested delimiters', () {
      expect(Asm.fromRaw(' example "a,b;c", [1,2], {3,4} ; tail'),
          cmd('example', ['"a,b;c"', '[1,2]', '{3,4}'], comment: 'tail'));
    });

    test('data strings and numbers retain their existing encoding', () {
      final text = Bytes.ascii('a,b;(c)');
      final source = Asm.fromRaw(' dc.b "a,b;(c)", 1 ; tail');
      expect(source, dc.b(text + [Byte(1)], comment: 'tail'));
      final reader = ConstantReader.asm(source);
      expect([for (var i = 0; i < text.length; i++) reader.readByte()], text);
      expect(reader.readByte(), Byte(1));
    });

    test('escaped quotes do not end a string or start a comment', () {
      expect(Asm.fromRaw(r' dc.b "a\";b", 1 ; tail'),
          dc.b(Bytes.ascii(r'a\";b') + [Byte(1)], comment: 'tail'));
    });

    test('an escaped backslash allows the following quote to close the string',
        () {
      expect(Asm.fromRaw(r' example "path\\", next ; tail'),
          cmd('example', [r'"path\\"', 'next'], comment: 'tail'));
    });

    test('single-quoted operands retain commas and semicolons', () {
      expect(Asm.fromRaw(" example 'a,b;c', (a0) ; tail"),
          cmd('example', ["'a,b;c'", '(a0)'], comment: 'tail'));
    });

    test('unsupported assembler data syntax remains opaque', () {
      final instruction = Asm.fromRaw(' dc.w function(1, 2), +').first;
      expect(instruction.operands, hasLength(2));
      expect(instruction.operands.first.toString(), 'function(1, 2)');
      expect(instruction.operands.last.toString(), '+');
    });
  });

  group('mixed ASCII and byte operands', () {
    for (final (description, source, rendered, values) in [
      (
        'bytes before ASCII',
        r'$00, $FF, "AB"',
        r'$00, $FF, "AB"',
        [0, 255, 65, 66]
      ),
      (
        'alternating spans',
        r'"A", 0, "BC", 1, 2, "D", $FF',
        r'"A", $00, "BC", $01, $02, "D", $FF',
        [65, 0, 66, 67, 1, 2, 68, 255]
      ),
      (
        'adjacent strings',
        r'0, "A", "BC", 1',
        r'$00, "ABC", $01',
        [0, 65, 66, 67, 1]
      ),
      (
        'empty strings',
        r'"", "A", "", 0, "", "B", ""',
        r'"A", $00, "B"',
        [65, 0, 66]
      ),
      (
        'both quote styles',
        '''0, 'A,B;', 1, "C;D,E", 2''',
        r'$00, "A,B;", $01, "C;D,E", $02',
        [0, 65, 44, 66, 59, 1, 67, 59, 68, 44, 69, 2]
      ),
      (
        'byte truncation',
        r'$1FF, "A", $100, "B"',
        r'$FF, "A", $00, "B"',
        [255, 65, 0, 66]
      ),
    ]) {
      test(description, () {
        final asm = Asm.fromRaw(' dc.b $source ; mixed');
        final expected = values.map(Byte.new).toList();
        expect(asm.first.operands.toString(), rendered);
        expect(asm.first.comment, 'mixed');
        expect(ConstantIterator(asm.iterator).toList(), expected);
        expect(ConstantIterator(Asm.fromRaw(asm.toString()).iterator).toList(),
            expected);
      });
    }

    test('empty strings at either end add no bytes', () {
      final asm = Asm.fromRaw(' dc.b "", 0, "A", 1, ""');
      expect(ConstantIterator(asm.iterator).toList(),
          [Byte(0), Byte(65), Byte(1)]);
    });

    test('symbols and expressions between strings remain separate operands',
        () {
      final asm = Asm.fromRaw(' dc.b "AB", flag, "C", flag + 1, "D", 0');
      final expected = [
        Byte(65),
        Byte(66),
        Constant('flag'),
        Byte(67),
        isA<ArithmeticExpression>()
            .having((expression) => expression.toString(), 'source', 'flag+1'),
        Byte(68),
        Byte(0),
      ];
      expect(asm.first.operands, expected);
      expect(Asm.fromRaw(asm.toString()).first.operands, expected);
      final context =
          EvaluationContext(Constants.fromMap({Constant('flag'): Value(2)}));
      expect(
          ConstantIterator(asm.iterator)
              .toList()
              .map((operand) => operand.evaluate(context).requireInt()),
          [65, 66, 2, 67, 3, 68, 0]);
    });

    test('opaque assembler expressions do not swallow following strings', () {
      final asm = Asm.fromRaw(' dc.b "A", function(1, 2), "B", 0');
      expect(asm.first.operands, [
        Byte(65),
        UnknownExpression('function(1, 2)'),
        Byte(66),
        Byte(0),
      ]);
      expect(Asm.fromRaw(asm.toString()), asm);
    });
  });
}
