import 'dart:math';
import 'dart:typed_data';

import '../characters.dart';
import 'asm.dart';

const byte = Size.b;
const word = Size.w;
const long = Size.l;

abstract class Expression {
  bool get isZero;
  bool get isNotZero => !isZero;

  Expression();

  const Expression.constant();

  Immediate get i => Immediate(this);

  Absolute get w => Absolute.word(this);

  Absolute get l => Absolute.long(this);

  /// Assembly representation of the expression.
  @override
  String toString();
}

class Constant extends Expression {
  final String constant;

  @override
  final bool isZero = false;

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

class Label extends Expression {
  final String name;

  @override
  final bool isZero = false;

  const Label(this.name) : super.constant();

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Label && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

// TODO: unsigned. what about signed?
// see: http://mrjester.hapisan.com/04_MC68/Sect04Part02/Index.html
abstract class Value<T extends Value<T>> extends Expression {
  /// Value as an [int]
  final int value;

  Value(this.value) {
    if (value >= (1 << (size.bytes * 8))) {
      throw AsmError(value, 'too large to fit in $size bytes');
    }
  }

  const Value._(this.value) : super.constant();

  /// Size in bytes
  Size get size;

  @override
  bool get isZero => value == 0;
  @override
  bool get isNotZero => !isZero;

  /// Hex representation including $ prefix.
  String get hex =>
      '\$${value.toRadixString(16).toUpperCase().padLeft(size.bytes * 2, '0')}';

  // Default to hex expression
  @override
  String toString() => hex;
}

class Byte extends Value<Byte> {
  static const zero = Byte(0);

  const Byte(int value) : super._(value);

  @override
  final size = Size.b;
}

class Word extends Value<Word> {
  Word(int value) : super(value);
  @override
  final size = Size.w;
}

class Longword extends Value<Longword> {
  Longword(int value) : super(value);
  @override
  final size = Size.l;
}

class Size {
  static const b = Size._(1, 'b');
  static const w = Size._(2, 'w');
  static const l = Size._(4, 'l');

  final int bytes;
  final String code;

  bool get isB => this == b;
  bool get isW => this == w;
  bool get isL => this == l;

  const Size._(this.bytes, this.code);

  @override
  String toString() => code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Size && runtimeType == other.runtimeType && bytes == other.bytes;

  @override
  int get hashCode => bytes.hashCode;
}

extension ToValue on int {
  Value toValue({required int size}) {
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

  Byte get byte => Byte(this);
  Word get word => Word(this);
  Longword get longword => Longword(this);
}

extension ToExpression on String {
  Constant get constant => Constant(this);
  Label get label => Label(this);
}

/// An arbitrary list of data.
abstract class Data<T extends List<int>, D extends Data<T, D>> {
  final T bytes;
  final int elementSizeInBytes;
  final int hexDigits;

  Data(this.bytes, this.elementSizeInBytes)
      : hexDigits = elementSizeInBytes * 2;

  D _new(List<int> l);

  int get length => bytes.length;

  String get immediate => '';

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

  D operator +(D other) =>
      _new(bytes.toList(growable: false) + other.bytes.toList(growable: false));

  int operator [](int index) => bytes[index];

  @override
  String toString() {
    return bytes
        .map((e) =>
            '\$${e.toRadixString(16).toUpperCase().padLeft(hexDigits, '0')}')
        .join(', ');
  }

  D sublist(int start, [int? end]) {
    return _new(bytes.sublist(start, end));
  }

  int indexWhere(bool Function(int) test, [int? start]) {
    return start == null
        ? bytes.indexWhere(test)
        : bytes.indexWhere(test, start);
  }

  bool every(bool Function(int) test) {
    return bytes.every(test);
  }

  bool get isEmpty => bytes.isEmpty;

  bool get isNotEmpty => bytes.isNotEmpty;

  bool equivalentBytes(Data other) => other.bytes == bytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Data && runtimeType == other.runtimeType && bytes == other.bytes;

  @override
  int get hashCode => bytes.hashCode;
}

class Bytes extends Data<Uint8List, Bytes> {
  Bytes(Uint8List bytes) : super(bytes, bytes.elementSizeInBytes);

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

  @override
  Bytes operator +(Bytes other) {
    if (other is Ascii) {
      return BytesAndAscii(<Bytes>[this] + [other]);
    }
    return super + (other);
  }

  @override
  Bytes _new(List<int> bytes) => Bytes(Uint8List.fromList(bytes));
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
  Bytes operator +(Bytes other) {
    if (other is! Ascii) {
      return BytesAndAscii(<Bytes>[this] + [other]);
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
      : super(Uint8List.fromList(_spans
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
  BytesAndAscii operator +(Bytes other) {
    return BytesAndAscii(_spans + [other]);
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
    return BytesAndAscii(_spans);
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

  void writeByte(int byte) {
    if (_ascii) {
      _finishSpan();
      _ascii = false;
    }

    _currentSpan.add(byte);
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

class Words extends Data<Uint16List, Words> {
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

  @override
  Words _new(List<int> bytes) => Words(Uint16List.fromList(bytes));
}

class Longwords extends Data<Uint32List, Longwords> {
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
  Longwords _new(List<int> bytes) => Longwords(Uint32List.fromList(bytes));
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
