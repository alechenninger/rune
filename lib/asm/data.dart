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

  Immediate get i => Immediate(this);

  Absolute get w => Absolute.word(this);

  Absolute get l => Absolute.long(this);

  Expression operator +(Expression other) {
    return ArithmaticExpression('+', this, other);
  }

  Expression operator -(Expression other) {
    return ArithmaticExpression('-', this, other);
  }

  Expression operator ~/(Expression other) {
    return ArithmaticExpression('/', this, other);
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

class ArithmaticExpression extends Expression {
  final Expression operand1;
  final Expression operand2;
  final String operator;

  ArithmaticExpression(this.operator, this.operand1, this.operand2);

  @override
  bool get isKnownZero => operand1.isKnownZero && operand2.isKnownZero;

  @override
  String toString() {
    return '($operand1$operator$operand2)';
  }
}

class Value extends Expression implements Comparable<Value> {
  final int value;

  const Value(this.value) : super.constant();

  const Value.constant(this.value) : super.constant();

  @override
  bool get isKnownZero => value == 0;

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

  @override
  String toString() => value.toString();

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

  const Constant(this.constant) : super.constant();

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

class Label extends Sized implements Address {
  static final _validLabelPattern =
      RegExp(r'^[A-Za-z\d_@.+-/]+[A-Za-z\d_/+-]*$');

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

  const LabelOrConstant(this.name) : super.constant();

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
    return _Sized(size, expression);
  }
}

class _Sized extends Sized {
  @override
  final Size size;
  final Expression expression;

  @override
  bool get canSplit => expression is Sized && (expression as Sized).canSplit;

  @override
  bool get canAppend => expression is Sized && (expression as Sized).canAppend;

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
  String toString() => expression.toString();
}

// TODO: unsigned. what about signed?
// see: http://mrjester.hapisan.com/04_MC68/Sect04Part02/Index.html
abstract class SizedValue extends Value implements Sized {
  SizedValue(int value) : super(value) {
    if (value > size.maxValue) {
      throw AsmError(value, 'too large to fit in ${size.bytes} bytes');
    }
  }

  const SizedValue._(int value) : super.constant(value);

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
  static const zero = Byte._(0);
  static const one = Byte._(1);
  static const two = Byte._(2);

  Byte(int value) : super(value);

  const Byte._(int value) : super._(value);

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
  Word(int value) : super(value);

  factory Word.concatBytes(Byte b1, Byte b2) {
    return Word((b1.value << 8) + b2.value);
  }

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
  Longword(int value) : super(value);

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

  SizedValue get maxValueSized => sizedValue(maxValue);

  Sized sizedExpression(Expression expression) {
    if (expression is Sized) {
      if (expression.size != this) {
        throw ArgumentError.value(
            expression, 'expression', 'incompatible size ${expression.size}');
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
  Word get toWord => Word(this);
  Longword get toLongword => Longword(this);
}

extension ToExpression on String {
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
  final int hexDigits;

  Data(this.bytes, this.elementSizeInBytes)
      : hexDigits = elementSizeInBytes * 2;

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
            '\$${e.toRadixString(16).toUpperCase().padLeft(hexDigits, '0')}')
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
