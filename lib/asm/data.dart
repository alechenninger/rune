import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:quiver/check.dart';
import 'package:rune/numbers.dart';
import 'package:rune/src/iterables.dart';

import '../characters.dart';
import 'asm.dart';

const byte = Size.b;
const word = Size.w;
const long = Size.l;

abstract class Expression {
  // todo: maybe remove?
  bool get isKnownZero;
  bool get isNotKnownZero => !isKnownZero;

  Expression();

  const Expression.constant();

  /// Parses exactly one scalar expression, independent of symbols or data size.
  ///
  /// Throws a [FormatException] for unsupported or malformed expression syntax.
  /// Instruction addresses and other opaque operands are parsed by [Instruction].
  static Expression parse(String source) => _ExpressionParser(source).parse();

  Immediate get i => Immediate(this);

  Absolute get w => Absolute.word(this);

  Absolute get l => Absolute.long(this);

  /// Resolves known constants and operations, retaining symbolic expressions
  /// whose values are not available in [context]. Recursive evaluation uses
  /// the same context to retain symbol-cycle detection.
  Expression evaluate(EvaluationContext context);

  /// Returns this expression's known integer value.
  ///
  /// Throws a [StateError] if this expression remains symbolic. Call
  /// [evaluate] first to resolve constants and operations.
  int requireInt() => throw StateError('expected a known integer, got $this');

  Expression operator +(Expression other) {
    if (isKnownZero) return other;
    return ArithmeticExpression(ArithmeticOperator.add, this, other);
  }

  Expression operator -(Expression other) {
    return ArithmeticExpression(ArithmeticOperator.subtract, this, other);
  }

  Expression operator ~/(Expression other) {
    return ArithmeticExpression(ArithmeticOperator.divide, this, other);
  }

  Expression operator <<(Expression other) {
    if (other.isKnownZero) return this;
    return ArithmeticExpression(ArithmeticOperator.shiftLeft, this, other);
  }

  Expression operator |(Expression other) {
    if (other.isKnownZero) return this;
    return ArithmeticExpression(ArithmeticOperator.or, this, other);
  }

  /// Assembly representation of the expression.
  @override
  String toString();

  String withParenthesis() {
    var str = toString();
    if (str.startsWith('(') && str.endsWith(')')) {
      return str;
    }
    return '($str)';
  }
}

class ArithmeticExpression extends Expression {
  final Expression left;
  final Expression right;
  final ArithmeticOperator operator;

  ArithmeticExpression(this.operator, this.left, this.right);

  @override
  bool get isKnownZero => switch (operator) {
        ArithmeticOperator.divide || ArithmeticOperator.modulo => false,
        _ => left.isKnownZero && right.isKnownZero,
      };

  @override
  Expression evaluate(EvaluationContext context) {
    final left = this.left.evaluate(context);
    final right = this.right.evaluate(context);
    if (left is Value && right is Value) {
      return Value(operator.apply(left.value, right.value));
    }
    return ArithmeticExpression(operator, left, right);
  }

  String toStringOperand(ArithmeticOperator parent) {
    return parent.rank < operator.rank ? '($this)' : toString();
  }

  @override
  String toString() {
    var left = switch (this.left) {
      Value(:final value) when value < 0 => '(${this.left})',
      ArithmeticExpression a => a.toStringOperand(operator),
      var l => l.toString()
    };
    var right = switch (this.right) {
      Value(:final value) when value < 0 => '(${this.right})',
      // Equal precedence on the right also needs parentheses: a-(b-c).
      ArithmeticExpression a when a.operator.rank >= operator.rank => '($a)',
      var r => r.toString()
    };
    return '$left$operator$right';
  }
}

// See http://john.ccac.rwth-aachen.de:8000/as/as_EN.html#sect_2_10_6_
// for precedence
enum ArithmeticOperator implements _BinaryOperator {
  add('+', 10),
  subtract('-', 10),
  multiply('*', 9),
  divide('/', 9),
  modulo('#', 9),
  xor('!', 7),
  shiftLeft('<<', 3),
  shiftRight('>>', 3),
  and('&', 5),
  or('|', 6);

  @override
  final String operator;

  /// Lower number means higher precedence.
  @override
  final int rank;

  const ArithmeticOperator(this.operator, this.rank);

  int apply(int left, int right) => switch (this) {
        add => left + right,
        subtract => left - right,
        multiply => left * right,
        divide => left ~/ right,
        modulo => left.remainder(right),
        shiftLeft => left << right,
        shiftRight => left >> right,
        and => left & right,
        or => left | right,
        xor => left ^ right,
      };

  @override
  String toString() => operator;
}

class BooleanOperation extends Expression {
  final Expression operand1;
  final Expression operand2;
  final BooleanOperator operator;

  BooleanOperation(this.operator, this.operand1, this.operand2);

  @override
  bool get isKnownZero => false;

  @override
  Expression evaluate(EvaluationContext context) {
    final left = operand1.evaluate(context);
    final right = operand2.evaluate(context);
    if (left is Value && right is Value) {
      return Value.boolean(operator.apply(left.value, right.value));
    }
    return BooleanOperation(operator, left, right);
  }

  @override
  String toString() => '($operand1$operator$operand2)';
}

/// AS comparison and logical operators, with the assembler's precedence.
enum BooleanOperator implements _BinaryOperator {
  equal('=', 14),
  notEqual('<>', 14),
  less('<', 14),
  lessOrEqual('<=', 14),
  greater('>', 14),
  greaterOrEqual('>=', 14),
  and('&&', 11),
  or('||', 12),
  xor('!!', 13);

  @override
  final String operator;
  @override
  final int rank;

  const BooleanOperator(this.operator, this.rank);

  bool apply(int left, int right) => switch (this) {
        equal => left == right,
        notEqual => left != right,
        less => left < right,
        lessOrEqual => left <= right,
        greater => left > right,
        greaterOrEqual => left >= right,
        and => left != 0 && right != 0,
        or => left != 0 || right != 0,
        xor => (left != 0) != (right != 0),
      };

  @override
  String toString() => operator;
}

class UnaryOperation extends Expression {
  final UnaryOperator operator;
  final Expression operand;

  UnaryOperation(this.operator, this.operand);

  @override
  bool get isKnownZero => false;

  @override
  Expression evaluate(EvaluationContext context) {
    final operand = this.operand.evaluate(context);
    return operand is Value
        ? Value(operator.apply(operand.value))
        : UnaryOperation(operator, operand);
  }

  @override
  // Unary signs bind more loosely than shifts/bitwise operations in AS.
  // Parenthesize the whole operation when embedding it in another expression.
  String toString() => '($operator($operand))';
}

enum UnaryOperator {
  plus('+'),
  negate('-'),
  complement('~'),
  not('~~');

  final String operator;

  const UnaryOperator(this.operator);

  int apply(int operand) => switch (this) {
        plus => operand,
        negate => -operand,
        complement => ~operand,
        not => operand == 0 ? 1 : 0,
      };

  @override
  String toString() => operator;
}

class Constants extends IterableBase<MapEntry<Constant, Expression>> {
  final Map<Constant, Expression> _map;

  const Constants.none() : _map = const {};
  const Constants.wrap(Map<Constant, Expression> constants) : _map = constants;
  Constants.of(Constants constants) : _map = Map.of(constants._map);
  Constants.fromMap(Map<Constant, Expression> constants)
      : _map = Map.of(constants);

  Map<Constant, Expression> toMap() {
    return UnmodifiableMapView(_map);
  }

  void add(Constant flag, Expression value) => _map[flag] = value;

  Expression? resolve(Constant constant) => _map[constant];

  // todo: eh
  bool containsConstantNamed(String constant) =>
      _map.keys.map((e) => e.constant).toSet().contains(constant);

  @override
  Iterator<MapEntry<Constant, Expression>> get iterator =>
      _map.entries.iterator;
}

/// A synchronous expression-evaluation session and its symbol-resolution path.
///
/// Expressions share this context when evaluating children and definitions.
/// Resolution state is cleared on success or failure, so the context may also
/// be reused for subsequent evaluations.
class EvaluationContext {
  final Constants _constants;
  final Set<Constant> _resolving = {};

  EvaluationContext(this._constants);

  /// Evaluates a symbol's definition, or returns null if it is unavailable.
  ///
  /// Throws a [StateError] for cyclic definitions. Symbol identity uses its
  /// name, independently of sized wrappers or other expression metadata.
  Expression? resolve(Constant symbol) {
    final name = Constant(symbol.constant);
    final definition = _constants.resolve(name);
    if (definition == null) return null;
    if (!_resolving.add(name)) {
      throw StateError('cyclic assembly constant: '
          '${[..._resolving, name].join(' -> ')}');
    }
    try {
      return definition.evaluate(this);
    } finally {
      _resolving.remove(name);
    }
  }
}

class UnknownExpression extends Expression {
  final String expression;
  @override
  final isKnownZero = false;

  const UnknownExpression(this.expression) : super.constant();

  @override
  Expression evaluate(EvaluationContext context) => this;

  @override
  String toString() {
    return expression;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnknownExpression &&
          runtimeType == other.runtimeType &&
          expression == other.expression;

  @override
  int get hashCode => expression.hashCode;
}

class Value extends Expression implements Comparable<Value> {
  final int value;

  /// An unsized integer, including negative intermediate results.
  Value(this.value) : super.constant();

  const Value.constant(this.value) : super.constant();
  const Value.boolean(bool bool)
      : value = bool ? 1 : 0,
        super.constant();

  @override
  bool get isKnownZero => value == 0;

  @override
  Expression evaluate(EvaluationContext context) => this;

  @override
  int requireInt() => value;

  @override
  int compareTo(Value other) => value.compareTo(other.value);

  @override
  Expression operator +(Expression other) {
    if (other is Value) {
      return Value(value + other.value);
    }
    return super + other;
  }

  @override
  Expression operator -(Expression other) {
    if (other is Value) {
      return Value(value - other.value);
    }
    return super - other;
  }

  @override
  Expression operator ~/(Expression other) {
    if (other is Value) {
      return Value(value ~/ other.value);
    }
    return super ~/ other;
  }

  bool operator >(Value other) {
    return value > other.value;
  }

  bool operator >=(Value other) {
    return value >= other.value;
  }

  bool operator <(Value other) {
    return value < other.value;
  }

  bool operator <=(Value other) {
    return value <= other.value;
  }

  @override
  String toString() => value > 128
      ? '\$${value.toRadixString(16).toUpperCase()}'
      : value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Value &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class Constant extends Expression {
  final String constant;

  @override
  final bool isKnownZero = false;

  static final _wordCharactersOnly = RegExp(r'^\w+$');

  static bool isValidConstantName(String name) =>
      _wordCharactersOnly.hasMatch(name);

  const Constant(this.constant) : super.constant();

  @override
  Expression evaluate(EvaluationContext context) =>
      context.resolve(this) ?? this;

  @override
  String toString() => constant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Constant &&
          runtimeType == other.runtimeType &&
          constant == other.constant;

  @override
  int get hashCode => constant.hashCode;
}

class KnownConstantValue {
  final Constant constant;
  final Value value;

  KnownConstantValue(this.constant, this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnownConstantValue &&
          runtimeType == other.runtimeType &&
          constant == other.constant &&
          value == other.value;

  @override
  int get hashCode => constant.hashCode ^ value.hashCode;

  @override
  String toString() {
    return 'KnownConstantValue{$constant=$value}';
  }
}

// TODO(addressing modes): technically is MemoryLocation
// but mem location is sealed in another package
class Label extends Sized implements Address {
  static final _validLabelPattern =
      RegExp(r'^([A-Za-z\d_@.$]+[A-Za-z\d_]*|[+-/]+)$');

  static bool isValidLabelName(String expression) =>
      _validLabelPattern.hasMatch(expression);

  final String name;

  @override
  final bool isKnownZero = false;

  @override
  Size get size => Size.l;

  Label(this.name) {
    if (!_validLabelPattern.hasMatch(name)) {
      throw ArgumentError.value(
          name, 'name', 'invalid label. must match: $_validLabelPattern');
    }
  }

  const Label.known(this.name) : super.constant();

  Label withSuffix(String s) {
    return Label('$name$s');
  }

  @override
  Expression evaluate(EvaluationContext context) => this;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Label && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class LabelOrConstant extends Expression {
  final String name;

  @override
  final bool isKnownZero = false;

  const LabelOrConstant.knownValid(this.name) : super.constant();

  LabelOrConstant(this.name) {
    // todo: we may be able to determine if name is only valid as a label
    checkArgument(
        Constant.isValidConstantName(name) && Label.isValidLabelName(name),
        message: name);
  }

  @override
  Expression evaluate(EvaluationContext context) =>
      context.resolve(Constant(name)) ?? this;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelOrConstant &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

abstract class Sized extends Expression {
  Sized();
  const Sized.constant() : super.constant();

  Size get size;

  bool get canSplit => false;

  bool get canAppend => false;

  /// [size] must be ≤ [this.size].
  List<Sized> splitInto(Size size) => canSplit
      ? throw UnimplementedError('splitInto')
      : throw StateError('cannot split');

  Sized appendLower(Sized s) => canAppend
      ? throw UnimplementedError('appendLower')
      : throw StateError('cannot append');

  // Sized append

  static Sized expression(Size size, Expression expression) {
    if (expression is Sized) {
      if (expression.size != size) {
        throw ArgumentError.value(
            expression,
            'expression',
            'expression is already sized with a different size. '
                '${size.name} != ${expression.size.name}');
      }
      return expression;
    }

    if (expression is Constant) {
      return SizedConstant(expression, size);
    }

    return _Sized(size, expression);
  }
}

class SizedConstant extends Sized implements Constant {
  SizedConstant(this._c, this.size);

  final Constant _c;

  @override
  final Size size;

  @override
  final isKnownZero = false;

  @override
  String get constant => _c.constant;

  @override
  Expression evaluate(EvaluationContext context) => context.resolve(_c) ?? this;

  @override
  String toString() => constant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SizedConstant &&
          runtimeType == other.runtimeType &&
          _c == other._c &&
          size == other.size;

  @override
  int get hashCode => _c.hashCode ^ size.hashCode;
}

class _Sized extends Sized {
  @override
  final Size size;
  final Expression expression;

  @override
  bool get canSplit => false;

  @override
  bool get canAppend => false;

  /// [size] must be ≤ [this.size].
  @override
  List<Sized> splitInto(Size size) => canSplit
      ? (expression as Sized).splitInto(size)
      : throw StateError('cannot split $this');

  @override
  Sized appendLower(Sized s) => canAppend
      ? (expression as Sized).appendLower(s)
      : throw StateError('cannot split $this');

  _Sized(this.size, this.expression);

  @override
  bool get isKnownZero => expression.isKnownZero;

  @override
  Expression evaluate(EvaluationContext context) =>
      size.sizedExpression(expression.evaluate(context));

  @override
  String toString() => expression.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Sized &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          expression == other.expression;

  @override
  int get hashCode => size.hashCode ^ expression.hashCode;
}

// TODO: unsigned. what about signed?
// see: http://mrjester.hapisan.com/04_MC68/Sect04Part02/Index.html
abstract class SizedValue extends Value implements Sized {
  SizedValue(int value) : super(value) {
    _checkValue(value, size);
  }

  SizedValue.signed(int value, Size size)
      : super(_negativeToSigned(value, size)) {
    _checkValue(this.value, size);
  }

  static int truncate(int value, Size size) {
    return (size.nextLarger.sizedValue(value).splitInto(size)[1] as Value)
        .value;
  }

  static int _negativeToSigned(int value, Size size) {
    if (!size.fitsSigned(value)) {
      throw AsmError(value, 'value too large for signed ${size.bytes} bytes');
    }

    if (value < 0) {
      return size.maxValue + value + 1;
    }
    return value;
  }

  static void _checkValue(int value, Size size) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'must be >= 0');
    }
    if (value > size.maxValue) {
      throw AsmError(value, 'too large to fit in ${size.bytes} bytes');
    }
  }

  const SizedValue._(super.value) : super.constant();

  bool get isNegative => value > size.maxValue ~/ 2;
  bool get isPositive => value <= size.maxValue ~/ 2;

  int get signedValue => isPositive ? value : value - size.maxValue - 1;

  /// Size in bytes
  @override
  Size get size;

  @override
  bool get isKnownZero => value == 0;
  @override
  bool get isNotKnownZero => !isKnownZero;

  @override
  bool get canSplit => true;

  @override
  bool get canAppend => true;

  /// Hex representation including $ prefix.
  String get hex =>
      '\$${value.toRadixString(16).toUpperCase().padLeft(size.bytes * 2, '0')}';

  // Default to hex expression
  @override
  String toString() => hex;
}

class Byte extends SizedValue {
  static const zero = Byte.constant(0);
  static const one = Byte.constant(1);
  static const two = Byte.constant(2);
  static const max = Byte.constant(0xFF);

  Byte(super.value);
  Byte.signed(int value) : super.signed(value, Size.b);
  factory Byte.truncate(int value) => Size.b.truncate(value) as Byte;

  const Byte.constant(super.value) : super._();

  factory Byte.parse(String val) {
    if (val.startsWith(r'$')) {
      return Byte(val.substring(1).hex);
    }
    return Byte(int.parse(val));
  }

  @override
  final size = Size.b;

  @override
  List<Sized> splitInto(Size size) {
    switch (size) {
      case Size.b:
        return [this];
      default:
        throw ArgumentError.value(
            size, 'size', 'must be less than ${this.size}');
    }
  }

  @override
  Word appendLower(Sized s) {
    if (s is Byte) {
      return Word.concatBytes(this, s);
    }
    throw ArgumentError.value(s, 's', 'cannot append to $this');
  }

  @override
  Expression operator +(Expression other) {
    if (other is Value) {
      return Byte(value + other.value);
    }
    return super + other;
  }

  @override
  Expression operator -(Expression other) {
    if (other is Value) {
      return Byte(value - other.value);
    }
    return super - other;
  }
}

class Word extends SizedValue {
  Word(super.value);
  Word.signed(int value) : super.signed(value, Size.w);
  const Word.constant(super.value) : super._();

  factory Word.concatBytes(Byte b1, Byte b2) {
    return Word((b1.value << 8) + b2.value);
  }

  factory Word.truncate(int value) => Size.w.truncate(value) as Word;

  @override
  final size = Size.w;

  @override
  List<Sized> splitInto(Size size) {
    switch (size) {
      case Size.b:
        return splitToBytes();
      case Size.w:
        return [this];
      default:
        throw ArgumentError.value(
            size, 'size', 'must be less than ${this.size}');
    }
  }

  @override
  Longword appendLower(Sized s) {
    if (s is Word) {
      return Longword.concatWords(this, s);
    }
    throw ArgumentError.value(s, 's', 'cannot append to $this');
  }

  Bytes splitToBytes() {
    return Bytes.list([value >> 8, value & 0xff]);
  }

  @override
  Expression operator +(Expression other) {
    if (other is Value) {
      return Word(value + other.value);
    }
    return super + other;
  }

  @override
  Expression operator -(Expression other) {
    if (other is Value) {
      return Word(value - other.value);
    }
    return super - other;
  }

  @override
  Expression operator ~/(Expression other) {
    if (other is Value) {
      return Word(value ~/ other.value);
    }
    return super ~/ other;
  }
}

class Longword extends SizedValue {
  Longword(super.value);
  Longword.signed(int value) : super.signed(value, Size.l);

  factory Longword.concatBytes(Byte b1, Byte b2, Byte b3, Byte b4) {
    return Longword(
        (b1.value << 24) + (b2.value << 16) + (b3.value << 8) + b4.value);
  }

  factory Longword.concatWords(Word w1, Word w2) {
    return Longword((w1.value << 16) + w2.value);
  }

  @override
  final size = Size.l;
  @override
  final canAppend = false;

  @override
  List<Sized> splitInto(Size size) {
    switch (size) {
      case Size.b:
        return splitToBytes();
      case Size.w:
        return splitToWords();
      case Size.l:
        return [this];
    }
  }

  @override
  Sized appendLower(Sized s) {
    throw ArgumentError.value(s, 's', 'cannot append to $this');
  }

  Bytes splitToBytes() => Bytes.list([
        value >> 24,
        (value & 0xffffff) >> 16,
        (value & 0xffff) >> 8,
        value & 0xff
      ]);

  Words splitToWords() => Words.fromExpressions([upperWord, lowerWord]);

  Word get upperWord => Word(value >> 16);
  Word get lowerWord => Word(value & 0xffff);

  @override
  Expression operator +(Expression other) {
    if (other is Value) {
      return Longword(value + other.value);
    }
    return super + other;
  }

  Longword signedMultiply(double multiplier) {
    var result = (value * multiplier).truncate();
    return Longword.signed(result);
  }

  Longword operator -() => negative();

  Longword negative() {
    return Longword.signed(-value);
  }
}

enum Size {
  b(1, 'b', 0xFF),
  w(2, 'w', 0xFFFF),
  l(4, 'l', 0xFFFFFFFF);

  final int bytes;
  final int maxValue;
  final String code;

  bool get isB => this == b;
  bool get isW => this == w;
  bool get isL => this == l;

  const Size(this.bytes, this.code, this.maxValue);

  bool operator <(Size other) {
    return bytes < other.bytes;
  }

  bool operator >(Size other) {
    return bytes > other.bytes;
  }

  /// Returns true if signed [value] can be represented in this size as a
  /// signed value.
  bool fitsSigned(int value) => switch (this) {
        b => value >= (-0xff ~/ 2 - 1) && value <= (0xff ~/ 2),
        w => value >= (-0xffff ~/ 2 - 1) && value <= (0xffff ~/ 2),
        l => value >= (-0xffffffff ~/ 2 - 1) && value <= (0xffffffff ~/ 2),
      };

  Size get nextLarger => this == b ? w : l;

  SizedValue truncate(int value) {
    var splitInto = nextLarger.sizedValue(value).splitInto(this);
    return splitInto.last as SizedValue;
  }

  SizedValue get maxValueSized => sizedValue(maxValue);

  Sized sizedExpression(Expression expression) {
    if (expression is Sized) {
      if (expression.size != this) {
        throw ArgumentError.value(expression.toString(), 'expression',
            'incompatible size ${expression.size}');
      }
      return expression;
    }

    if (expression is Value) {
      return sizedValue(expression.value);
    }

    return Sized.expression(this, expression);
  }

  SizedValue sizedValue(int value) {
    switch (code) {
      case 'b':
        return Byte(value);
      case 'w':
        return Word(value);
      case 'l':
        return Longword(value);
      default:
        throw StateError('missing swith case');
    }
  }

  List<SizedValue> sizedList(List<Expression> expressions) {
    switch (code) {
      case 'b':
        return Bytes.fromExpressions(expressions);
      case 'w':
        return Words.fromExpressions(expressions);
      case 'l':
        throw UnimplementedError();
      default:
        throw StateError('missing swith case');
    }
  }

  @override
  String toString() => code;

  static Size? valueOf(String string) {
    switch (string.toLowerCase()) {
      case 'b':
        return b;
      case 'w':
        return w;
      case 'l':
        return l;
    }
    return null;
  }
}

extension ToValue on int {
  SizedValue toSizedValue({required int size}) {
    switch (size) {
      case 1:
        return Byte(this);
      case 2:
        return Word(this);
      case 4:
        return Longword(this);
    }
    throw AsmError(size, 'invalid data size (must be 1, 2, or 4)');
  }

  Immediate get i => toValue.i;
  Value get toValue => Value(this);
  Byte get toByte => Byte(this);

  /// Value should be in the range of half max to -half max.
  Byte get toSignedByte => Byte.signed(this);
  Word get toWord => Word(this);

  /// Value should be in the range of half max to -half max.
  Word get toSignedWord => Word.signed(this);
  Longword get toLongword => Longword(this);

  /// Value should be in the range of half max to -half max.
  Longword get toSignedLongword => Longword.signed(this);
}

extension ToExpression on String {
  Immediate get i => Immediate(LabelOrConstant(this));
  Absolute get w => Absolute.word(LabelOrConstant(this));
  Absolute get l => Absolute.long(LabelOrConstant(this));
  Constant get toConstant => Constant(this);
  Label get toLabel => Label(this);
}

/// An arbitrary list of data.
///
/// [T] is the typed data list used to store the data. Size it to the right
/// typed data list type e.g.Uint8List
///
/// [E] is the type of Value represented by each element in the list.
///
/// [D] is just a self-referential recursive type to template the class.
abstract class Data<T extends List<int>, E extends SizedValue,
    D extends Data<T, E, D>> extends ListBase<E> {
  final T bytes;
  final int elementSizeInBytes;
  final int nibbles;

  Data(this.bytes, this.elementSizeInBytes) : nibbles = elementSizeInBytes * 2;

  D _new(List<int> l);

  E _newElement(int v);

  List<E> get _list => bytes.map((e) => _newElement(e)).toList(growable: false);

  @override
  int get length => bytes.length;

  @override
  set length(int newLength) => bytes.length = newLength;

  List<D> split(int splitLength) {
    checkArgument(splitLength > 0,
        message: 'length must be greater than 0 but was $splitLength');
    var taken = 0;
    var splits = <D>[];
    while (taken < length) {
      var take = min(length - taken, splitLength);
      if (take == 0) break;
      var takeTo = taken + take;
      splits.add(sublist(taken, takeTo));
      taken = takeTo;
    }
    return splits;
  }

  /// Trims both trailing and leading bytes equal to [byte].
  D trim(int byte) {
    return _new(bytes.trim(value: byte));
  }

  D trimLeading(int byte) {
    return _new(bytes.trimLeading(value: byte));
  }

  D trimTrailing(int byte) {
    return _new(bytes.trimTrailing(value: byte));
  }

  @override
  void add(E element) {
    bytes.add(element.value);
  }

  @override
  D skip(int count) {
    return _new(bytes.skip(1).toList());
  }

  @override
  D operator +(List<E> other) =>
      _new(bytes + other.map((e) => e.value).toList(growable: false));

  @override
  E operator [](int index) => _list[index];

  @override
  void operator []=(int index, E value) {
    bytes[index] = value.value;
  }

  @override
  String toString() {
    return bytes
        .map((e) =>
            '\$${e.toRadixString(16).toUpperCase().padLeft(nibbles, '0')}')
        .join(', ');
  }

  @override
  D sublist(int start, [int? end]) {
    return _new(bytes.sublist(start, end));
  }

  @override
  int indexWhere(bool Function(E) test, [int? start]) {
    return start == null
        ? _list.indexWhere(test)
        : _list.indexWhere(test, start);
  }

  @override
  bool every(bool Function(E) test) {
    return _list.every(test);
  }

  @override
  bool get isEmpty => bytes.isEmpty;

  @override
  bool get isNotEmpty => bytes.isNotEmpty;

  bool equivalentBytes(Data other) => other.bytes == bytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Data && runtimeType == other.runtimeType && bytes == other.bytes;

  @override
  int get hashCode => bytes.hashCode;
}

class Bytes extends Data<Uint8List, Byte, Bytes> {
  Bytes(Uint8List bytes) : super(bytes, bytes.elementSizeInBytes);

  factory Bytes.fromExpressions(List<Expression> expressions) {
    var bytes = <int>[];
    for (var exp in expressions) {
      if (exp is Byte) {
        bytes.add(exp.value);
      } else if (exp is Word) {
        bytes.add(exp.value >> 8);
        bytes.add(exp.value & 0xff);
      } else if (exp is Longword) {
        bytes.add(exp.value >> 24);
        bytes.add((exp.value & 0xffffff) >> 16);
        bytes.add((exp.value & 0xffff) >> 8);
        bytes.add(exp.value & 0xff);
      } else {
        throw ArgumentError.value(exp, 'expressions[n]', 'is not a SizedValue');
      }
    }
    return Bytes.list(bytes);
  }

  static Ascii ascii(String d) {
    var runes = d.runes.toList(growable: false);
    if (runes.any((element) => element > 127)) {
      // TODO: nicer error
      throw AsmError(d, 'contains code unit incompatible with ascii');
    }
    return Ascii(Uint8List.fromList(runes));
  }

  Bytes.empty() : this(Uint8List(0));

  factory Bytes.list(List<int> bytes) {
    for (var b in bytes) {
      if (b > 255) {
        throw AsmError(b, 'is larger than a single byte (max 255)');
      }
    }

    return Bytes(Uint8List.fromList(bytes));
  }

  factory Bytes.of(int d) {
    if (d > 255) {
      throw AsmError(d, 'is larger than a single byte (max 255)');
    }
    return Bytes(Uint8List.fromList([d]));
  }

  factory Bytes.hex(String d) {
    return Bytes.of(int.parse('0x$d'));
  }

  factory Bytes.from(List<Byte> bytes) {
    if (bytes is Bytes) return bytes;
    return Bytes.list(bytes.map((e) => e.value).toList(growable: false));
  }

  @override
  Bytes operator +(List<Byte> other) {
    if (other is Ascii) {
      return BytesAndAscii(<Bytes>[this] + [other]);
    }
    return super + (other);
  }

  @override
  Bytes _new(List<int> bytes) => Bytes(Uint8List.fromList(bytes));

  @override
  Byte _newElement(int v) => Byte(v);
}

class Ascii extends Bytes {
  Ascii(Uint8List bytes) : super(bytes) {
    bytes.asMap().forEach((key, value) {
      if (value > 127) {
        throw AsmError(
            bytes,
            'contains code unit incompatible with ascii at index $key: '
            '$value "${value.utf16}"');
      }
    });
  }

  @override
  Ascii _new(List<int> bytes) => Ascii(Uint8List.fromList(bytes));

  @override
  Bytes operator +(List<Byte> other) {
    if (other is! Ascii) {
      return BytesAndAscii(<Bytes>[this] + [Bytes.from(other)]);
    }

    var concat =
        bytes.toList(growable: false) + other.bytes.toList(growable: false);
    return Ascii(Uint8List.fromList(concat));
  }

  @override
  Ascii trim(int byte) {
    return Ascii(bytes.trim(value: byte));
  }

  @override
  Ascii sublist(int start, [int? end]) {
    return Ascii(bytes.sublist(start, end));
  }

  @override
  String toString() {
    return '"${String.fromCharCodes(bytes)}"';
  }
}

class BytesAndAscii extends Bytes {
  final List<Bytes> _spans;

  BytesAndAscii._(this._spans)
      // Hack around possible bug in + operator on uint8list?
      : super(Uint8List.fromList(_spans.isEmpty
            ? []
            : _spans
                .map((e) => e.bytes.toList(growable: false))
                .reduce((value, element) => value + element)));

  factory BytesAndAscii(List<Bytes> spans) {
    var normalized = <Bytes>[];

    void add(Bytes span) {
      if (span is BytesAndAscii) {
        // As inner spans are already normalized, just make sure the first one
        // is combined with the prior (if possible)
        add(span._spans.first);
        normalized.addAll(span._spans.skip(1));
        return;
      }

      if (normalized.isEmpty) {
        normalized.add(span);
        return;
      }
      if (normalized.last.runtimeType == span.runtimeType) {
        normalized.add(normalized.removeLast() + span);
      } else {
        normalized.add(span);
      }
    }

    for (var span in spans) {
      add(span);
    }

    return BytesAndAscii._(normalized);
  }

  @override
  BytesAndAscii operator +(List<Byte> other) {
    return BytesAndAscii(_spans + [Bytes.from(other)]);
  }

  @override
  BytesAndAscii trim(int byte) {
    var _new = <Bytes>[];
    var trimming = true;
    for (var span in _spans) {
      if (trimming) {
        var trimmed = span.trimLeading(byte);
        if (trimmed.isNotEmpty) {
          _new.add(trimmed);
          trimming = false;
        }
      } else {
        _new.add(span);
      }
    }

    while (_new.isNotEmpty) {
      var last = _new.removeLast();
      var trimmed = last.trimTrailing(byte);
      if (trimmed.isNotEmpty) {
        _new.add(trimmed);
        break;
      }
    }

    return BytesAndAscii(_new);
  }

  @override
  Bytes sublist(int start, [int? end]) {
    var removed = 0;
    var _new = <Bytes>[];

    for (var span in _spans) {
      if (start >= removed + span.length) {
        removed += span.length;
        continue;
      }
      var spanStart = start - removed;
      _new.add(span.sublist(spanStart));
      removed += spanStart;
    }

    if (end != null) {
      removed = 0;
      var fromEnd = end - length;
      while (_new.isNotEmpty) {
        var last = _new.removeLast();
        var trimmed = last.sublist(0, max(0, fromEnd + removed + last.length));
        if (trimmed.isNotEmpty) {
          _new.add(trimmed);
          break;
        }
        removed += last.length;
      }
    }

    if (_new.isEmpty) return Bytes.empty();

    return BytesAndAscii(_new);
  }

  @override
  String toString() {
    return _spans.join(', ');
  }
}

class BytesBuilder {
  var _ascii = false;
  final _currentSpan = <int>[];
  final _spans = <Bytes>[];

  Bytes bytes() {
    _finishSpan();
    if (_spans.isEmpty) {
      return Bytes.empty();
    }
    return _spans.length > 1 ? BytesAndAscii(_spans) : _spans[0];
  }

  int get length {
    return _spans
        .map((e) => e.length)
        .reduceOr((s1, s2) => s1 + s2, ifEmpty: 0);
  }

  int? get lastByte {
    if (_currentSpan.isNotEmpty) {
      return _currentSpan.last;
    }

    if (_spans.isNotEmpty) {
      var lastSpan = _spans.last;
      if (lastSpan.isNotEmpty) {
        return lastSpan.bytes.last;
      }
    }

    return null;
  }

  void writeAsciiCharacter(String c) {
    if (!_ascii) {
      _finishSpan();
      _ascii = true;
    }

    _currentSpan.add(c.codePoint);
  }

  void writeByteValue(int byte) {
    if (_ascii) {
      _finishSpan();
      _ascii = false;
    }

    _currentSpan.add(byte);
  }

  void writeByte(Byte byte) {
    writeByteValue(byte.value);
  }

  void _finishSpan() {
    if (_currentSpan.isNotEmpty) {
      _spans.add(_ascii
          ? Bytes.ascii(String.fromCharCodes(_currentSpan))
          : Bytes.list(_currentSpan));
      _currentSpan.clear();
    }
  }
}

class Words extends Data<Uint16List, Word, Words> {
  Words(Uint16List bytes) : super(bytes, bytes.elementSizeInBytes);

  factory Words.fromWord(int d) {
    if (d > 65535) {
      throw AsmError(d, 'is larger than a single word (max 65535)');
    }
    return Words(Uint16List.fromList([d]));
  }

  factory Words.hex(String d) {
    return Words.fromWord(int.parse('0x$d'));
  }

  factory Words.list(List<int> list) {
    return Words(Uint16List.fromList(list));
  }

  factory Words.fromExpressions(List<Expression> expressions) {
    var words = <int>[];
    // not 100% sure partial stuff is right
    int? partial;
    for (var exp in expressions) {
      if (exp is Byte) {
        if (partial == null) {
          partial = exp.value << 8;
        } else {
          partial += exp.value;
          words.add(partial);
          partial = null;
        }
      } else if (exp is Word) {
        if (partial == null) {
          words.add(exp.value);
        } else {
          partial += exp.value >> 8;
          words.add(partial);
          partial = exp.value & 0xff;
        }
      } else if (exp is Longword) {
        if (partial == null) {
          words.add(exp.value >> 16);
          words.add(exp.value & 0xffff);
        } else {
          partial += exp.value >> 24;
          words.add(partial);
          words.add((exp.value & 0xffffff) >> 8);
          partial = exp.value & 0xff;
        }
      } else {
        throw ArgumentError.value(exp, 'expressions[n]', 'is not a SizedValue');
      }
    }
    return Words(Uint16List.fromList(words));
  }

  @override
  Words _new(List<int> l) => Words(Uint16List.fromList(l));

  @override
  Word _newElement(int v) => Word(v);
}

class Longwords extends Data<Uint32List, Longword, Longwords> {
  Longwords(Uint32List bytes) : super(bytes, bytes.elementSizeInBytes);

  factory Longwords.fromLongword(int d) {
    if (d > 4294967295) {
      throw AsmError(d, 'is larger than a longword (max 4294967295)');
    }
    return Longwords(Uint32List.fromList([d]));
  }

  factory Longwords.hex(String d) {
    return Longwords.fromLongword(int.parse('0x$d'));
  }

  @override
  Longwords _new(List<int> l) => Longwords(Uint32List.fromList(l));

  @override
  Longword _newElement(int v) => Longword(v);
}

extension TrimBytes on Uint8List {
  Uint8List trimLeading({int value = 0}) {
    return Uint8List.fromList(
        toList(growable: false).trimLeading(value: value));
  }

  Uint8List trimTrailing({int value = 0}) {
    return Uint8List.fromList(
        toList(growable: false).trimTrailing(value: value));
  }

  Uint8List trim({int value = 0}) {
    return Uint8List.fromList(toList(growable: false).trim(value: value));
  }
}

extension TrimWords on Uint16List {
  Uint16List trimLeading({int value = 0}) {
    return Uint16List.fromList(
        toList(growable: false).trimLeading(value: value));
  }

  Uint16List trimTrailing({int value = 0}) {
    return Uint16List.fromList(
        toList(growable: false).trimTrailing(value: value));
  }

  Uint16List trim({int value = 0}) {
    return Uint16List.fromList(toList(growable: false).trim(value: value));
  }
}

extension TrimLongwords on Uint32List {
  Uint32List trimLeading({int value = 0}) {
    return Uint32List.fromList(
        toList(growable: false).trimLeading(value: value));
  }

  Uint32List trimTrailing({int value = 0}) {
    return Uint32List.fromList(
        toList(growable: false).trimTrailing(value: value));
  }

  Uint32List trim({int value = 0}) {
    return Uint32List.fromList(toList(growable: false).trim(value: value));
  }
}

extension TrimList on List<int> {
  List<int> trimLeading({int value = 0}) {
    return skipWhile((b) => b == value).toList();
  }

  List<int> trimTrailing({int value = 0}) {
    return reversed
        .skipWhile((b) => b == value)
        .toList(growable: false)
        .reversed
        .toList();
  }

  List<int> trim({int value = 0}) {
    return skipWhile((b) => b == value)
        .toList(growable: false)
        .reversed
        .skipWhile((b) => b == value)
        .toList(growable: false)
        .reversed
        .toList();
  }
}

/// Shared spelling and precedence for the two binary operator families.
sealed class _BinaryOperator {
  String get operator;

  /// Lower number means higher precedence.
  int get rank;
}

/// Parses one numeric expression without treating whitespace as an operand
/// separator. Instruction operands such as addresses keep their existing parser.
class _ExpressionParser {
  final String source;
  int _offset = 0;

  static final _symbol = RegExp(r'[A-Za-z_@.$][A-Za-z0-9_@.$]*');
  static final _literal = RegExp(r'\$[0-9a-fA-F]+|[0-9]+');
  // Match longer spellings first: << and <= must be tried before <, etc.
  // The enum values supply canonical spellings; aliases are explicit here.
  static final _binaryOperators =
      List<({String spelling, _BinaryOperator operator})>.unmodifiable([
    for (final operator in <_BinaryOperator>[
      ...ArithmeticOperator.values,
      ...BooleanOperator.values,
    ])
      (spelling: operator.operator, operator: operator),
    (spelling: '==', operator: BooleanOperator.equal),
  ]..sort((a, b) => b.spelling.length.compareTo(a.spelling.length)));

  _ExpressionParser(this.source);

  Expression parse() {
    final result = _expression(0);
    _skipSpace();
    if (_offset != source.length) _invalid();
    return result;
  }

  Expression _expression(int minimumPrecedence) {
    var left = _unary();
    while (true) {
      _skipSpace();
      final match = _binaryOperators
          .where((entry) => source.startsWith(entry.spelling, _offset))
          .firstOrNull;
      if (match == null) break;
      final operator = match.operator;
      // AS ranks increase as binding strength decreases.
      final precedence = 15 - operator.rank;
      if (precedence < minimumPrecedence) break;
      _offset += match.spelling.length;
      final right = _expression(precedence + 1);
      left = switch (operator) {
        ArithmeticOperator op => ArithmeticExpression(op, left, right),
        BooleanOperator op => BooleanOperation(op, left, right),
      };
    }
    return left;
  }

  Expression _unary() {
    _skipSpace();
    for (final operator in [
      UnaryOperator.not,
      UnaryOperator.complement,
      UnaryOperator.negate,
      UnaryOperator.plus,
    ]) {
      if (source.startsWith(operator.operator, _offset)) {
        _offset += operator.operator.length;
        // In AS a unary sign binds less tightly than multiplication, shifts,
        // and bitwise operations: -1>>1 means -(1>>1).
        final operand =
            operator == UnaryOperator.negate || operator == UnaryOperator.plus
                ? _expression(6)
                : _unary();
        return UnaryOperation(operator, operand);
      }
    }
    if (source.startsWith('(', _offset)) {
      _offset++;
      final expression = _expression(0);
      _skipSpace();
      if (!source.startsWith(')', _offset)) _invalid();
      _offset++;
      return expression;
    }
    final literal = _literal.matchAsPrefix(source, _offset)?.group(0);
    if (literal != null) {
      _offset += literal.length;
      return Value(literal.startsWith(r'$')
          ? literal.substring(1).hex
          : int.parse(literal));
    }
    final symbol = _symbol.matchAsPrefix(source, _offset)?.group(0);
    if (symbol == null) _invalid();
    _offset += symbol!.length;
    return Constant(symbol);
  }

  void _skipSpace() {
    while (_offset < source.length && source[_offset].trim().isEmpty) {
      _offset++;
    }
  }

  Never _invalid() =>
      throw FormatException('invalid integer expression', source, _offset);
}
