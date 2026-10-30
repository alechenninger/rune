import 'package:rune/asm/asm.dart';
import 'package:test/test.dart';

void main() {
  final constants = Constants.fromMap({
    Constant('revision'): Value(1),
    Constant('alias'): Constant('revision'),
  });
  final context = EvaluationContext(constants);

  group('expression evaluation', () {
    test('evaluates expression implementations from another library', () {
      final expression = ArithmeticExpression(
          ArithmeticOperator.add, const _RevisionExpression(), Value(2));
      expect(expression.evaluate(context).requireInt(), 3);
      expect(
          BooleanOperation(
                  BooleanOperator.equal, const _RevisionExpression(), Value(1))
              .evaluate(context)
              .requireInt(),
          1);
      expect(
          UnaryOperation(UnaryOperator.negate, const _RevisionExpression())
              .evaluate(context)
              .requireInt(),
          -1);
    });

    test('dispatches through symbol definitions and sized wrappers', () {
      final values = Constants.fromMap({
        Constant('revision'): Value(1),
        Constant('custom'): const _RevisionExpression(),
      });
      expect(
          Constant('custom').evaluate(EvaluationContext(values)).requireInt(),
          1);
      expect(
          Sized.expression(Size.w, const _RevisionExpression())
              .evaluate(EvaluationContext(values)),
          Word(1));
    });

    test('preserves each sized wrapper policy', () {
      final values = Constants.fromMap({Constant('known'): Value(2)});
      final symbol = SizedConstant(Constant('known'), Size.w);
      final unresolved = SizedConstant(Constant('missing'), Size.w);
      expect(symbol.evaluate(EvaluationContext(values)), Value(2));
      expect(unresolved.evaluate(EvaluationContext(values)), same(unresolved));
      expect(
          Sized.expression(Size.w, Value(2))
              .evaluate(EvaluationContext(values)),
          Word(2));
    });

    for (final (source, expected) in [
      ('revision', 1),
      ('alias', 1),
      ('revision = 1', 1),
      ('revision == 1', 1),
      ('revision <> 1', 0),
      ('revision < 2', 1),
      ('revision > 2', 0),
      ('revision <= 1', 1),
      ('revision >= 2', 0),
      ('1 + 2 * 3', 7),
      ('(1 + 2) * 3', 9),
      ('255 + 1', 256),
      ('4294967296', 4294967296),
      ('\$FFFFFFFFFFFFFFFF', -1),
      ('0 - 1', -1),
      ('-2 * -3', 6),
      ('7 / 2', 3),
      ('7 # 2', 1),
      ('1 << 3', 8),
      ('16 >> 2', 4),
      ('\$F0 & \$3C', 0x30),
      ('1 | 2', 3),
      ('3 ! 1', 2),
      ('~0 & \$FF', 255),
      ('~~0', 1),
      ('~~1', 0),
      ('(revision=1) && (alias=1)', 1),
      ('0 || -1', 1),
      ('1 !! 1', 0),
      // AS gives shifts and bitwise operators higher precedence than addition.
      ('1 + 1 << 2', 5),
      // Unary signs have addition's rank; bitwise/logical NOT bind tightly.
      ('-1 >> 1', 0),
      ('(-1) >> 1', -1),
      ('-1 & 1', -1),
      ('(-1) & 1', 1),
      ('~~1 + 1', 1),
    ]) {
      test('evaluates $source', () {
        expect(
            Expression.parse(source).evaluate(context).requireInt(), expected);
      });
    }

    test('compares numeric values independently of size or rendering', () {
      final expression = Expression.parse('a=b');
      expect(
          expression
              .evaluate(EvaluationContext(Constants.fromMap({
                Constant('a'): Byte(1),
                Constant('b'): Word(1),
              })))
              .requireInt(),
          1);
    });

    test('preserves unresolved expressions during partial evaluation', () {
      final expression = Expression.parse('missing + 1');
      final unresolved = expression.evaluate(context);
      expect(() => unresolved.requireInt(), throwsStateError);
      expect(
          unresolved
              .evaluate(EvaluationContext(Constants.fromMap({
                Constant('missing'): Value(2),
              })))
              .requireInt(),
          3);
    });

    test('does not compare unresolved symbol spellings', () {
      final unresolved = Expression.parse('missing=missing').evaluate(context);
      expect(() => unresolved.requireInt(), throwsStateError);
    });

    test('detects constant cycles', () {
      expect(
          () => Constant('a').evaluate(EvaluationContext(Constants.fromMap({
                Constant('a'): Constant('b'),
                Constant('b'): Constant('a'),
              }))),
          throwsStateError);
    });

    test('shares and clears cycle state across custom expression evaluation',
        () {
      final values = Constants.fromMap({
        Constant('custom'): const _RevisionExpression(),
        Constant('revision'): Constant('custom'),
      });
      final context = EvaluationContext(values);
      expect(() => Constant('custom').evaluate(context), throwsStateError);
      values.add(Constant('revision'), Value(5));
      expect(Constant('custom').evaluate(context).requireInt(), 5);
    });

    test('keeps explicit labels and unknown expressions symbolic', () {
      final label = Label('revision');
      const unknown = UnknownExpression('unknown(1)');
      expect(label.evaluate(context), same(label));
      expect(unknown.evaluate(context), same(unknown));
      expect(LabelOrConstant('revision').evaluate(context).requireInt(), 1);
    });

    test('renders signed values introduced by partial evaluation safely', () {
      final expression = Expression.parse('left >> right').evaluate(
          EvaluationContext(Constants.fromMap({Constant('left'): Value(-1)})));
      expect(
          Expression.parse(expression.toString())
              .evaluate(EvaluationContext(
                  Constants.fromMap({Constant('right'): Value(1)})))
              .requireInt(),
          -1);
    });

    test('keeps integer evaluation separate from encoded size checks', () {
      expect(Value(-1).requireInt(), -1);
      expect(() => Byte(-1), throwsArgumentError);
      expect(() => Word(-1), throwsArgumentError);
      expect(() => Longword(-1), throwsArgumentError);
      expect(Byte.signed(-1), Byte(255));
      expect(Word.signed(-1), Word(65535));
    });

    test('rejects unsupported scalar expression syntax', () {
      expect(
          () => Expression.parse('unknown(1)').evaluate(context).requireInt(),
          throwsFormatException);
    });

    for (final source in [
      '10 - (3 - 1)',
      '12 / (3 / 2)',
      '-(1 + 2)',
      '(-1) >> 1',
      '(-1) & 1',
    ]) {
      test('preserves meaning when rendering $source', () {
        final expression = Expression.parse(source);
        expect(
            Expression.parse(expression.toString())
                .evaluate(context)
                .requireInt(),
            expression.evaluate(context).requireInt());
      });
    }
  });
}

/// An expression defined outside the assembly library, using its public API.
class _RevisionExpression extends Expression {
  const _RevisionExpression() : super.constant();

  @override
  bool get isKnownZero => false;

  @override
  Expression evaluate(EvaluationContext context) =>
      context.resolve(Constant('revision')) ?? this;

  @override
  String toString() => 'revision_expression';
}
