import 'dart:math';
import 'dart:typed_data';

import '../characters.dart';
import 'asm.dart';

int hex(String d) => int.parse('0x$d');

abstract class Data<T extends List<int>, D extends Data<T, D>> {
  final T bytes;
  final int elementSizeInBytes;
  final int hexDigits;

  Data(this.bytes, this.elementSizeInBytes)
      : hexDigits = elementSizeInBytes * 2;

  D _new(T t);
  D _newFromList(List<int> l);

  int get length => bytes.length;

  /// Trims both trailing and leading bytes equal to [byte].
  D trim(int byte) {
    return _newFromList(bytes.trim(value: byte));
  }

  D trimLeading(int byte) {
    return _newFromList(bytes.trimLeading(value: byte));
  }

  D trimTrailing(int byte) {
    return _newFromList(bytes.trimTrailing(value: byte));
  }

  D operator +(D other) => _newFromList(
      bytes.toList(growable: false) + other.bytes.toList(growable: false));

  int operator [](int index) => bytes[index];

  @override
  String toString() {
    return bytes
        .map((e) =>
            '\$${e.toRadixString(16).toUpperCase().padLeft(hexDigits, '0')}')
        .join(', ');
  }

  D sublist(int start, [int? end]) {
    return _new(bytes.sublist(start, end) as T);
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
  Bytes _new(Uint8List bytes) => Bytes(bytes);

  @override
  Bytes _newFromList(List<int> bytes) => Bytes(Uint8List.fromList(bytes));
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
  Ascii _new(Uint8List bytes) => Ascii(bytes);

  @override
  Ascii _newFromList(List<int> bytes) => Ascii(Uint8List.fromList(bytes));

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
        for (var inner in span._spans) {
          add(inner);
        }
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

class Words extends Data<Uint16List, Words> {
  Words(Uint16List bytes) : super(bytes, bytes.elementSizeInBytes);

  factory Words.fromWord(int d) {
    if (d > 65535) {
      throw AsmError(d, 'is larger than a single word (max 65535)');
    }
    return Words(Uint16List.fromList([d]));
  }

  factory Words.fromWordHex(String d) {
    return Words.fromWord(int.parse('0x$d'));
  }

  @override
  Words _new(Uint16List bytes) => Words(bytes);

  @override
  Words _newFromList(List<int> bytes) => Words(Uint16List.fromList(bytes));
}

class Longwords extends Data<Uint32List, Longwords> {
  Longwords(Uint32List bytes) : super(bytes, bytes.elementSizeInBytes);

  factory Longwords.fromLongword(int d) {
    if (d > 4294967295) {
      throw AsmError(d, 'is larger than a single word (max 4294967295)');
    }
    return Longwords(Uint32List.fromList([d]));
  }

  factory Longwords.fromLongwordHex(String d) {
    return Longwords.fromLongword(int.parse('0x$d'));
  }

  @override
  Longwords _new(Uint32List bytes) => Longwords(bytes);

  @override
  Longwords _newFromList(List<int> bytes) =>
      Longwords(Uint32List.fromList(bytes));
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
    return takeWhile((b) => b != value).toList();
  }

  List<int> trim({int value = 0}) {
    return skipWhile((b) => b == value)
        .takeWhile((b) => b != value)
        .toList(growable: false);
  }
}
