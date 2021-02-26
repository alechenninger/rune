import 'dart:typed_data';

import 'asm.dart';

int hex(String d) => int.parse('0x$d');

abstract class Data<T extends List<int>, D extends Data<T, D>> {
  final T bytes;
  final int elementSizeInBytes;
  final int hexDigits;

  Data(this.bytes, this.elementSizeInBytes)
      : hexDigits = elementSizeInBytes * 2;

  D _new(T t);

  int get length => bytes.length;

  /// Trims both trailing and leading bytes equal to [byte].
  D trim(int byte) {
    return _new(bytes.trim(value: byte) as T);
  }

  int operator [](int index) => bytes[index];

  @override
  String toString() {
    return bytes
        .map((e) =>
            '\$${e.toRadixString(16).toUpperCase().padLeft(hexDigits, '0')}')
        .join(',');
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
}

class Bytes extends Data<Uint8List, Bytes> {
  Bytes(Uint8List bytes) : super(bytes, bytes.elementSizeInBytes);

  factory Bytes.ascii(String d) {
    return _AsciiBytes(Uint8List.fromList(d.codeUnits));
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
  Bytes _new(Uint8List bytes) => Bytes(bytes);
}

class _AsciiBytes extends Bytes {
  _AsciiBytes(Uint8List bytes) : super(bytes) {
    bytes.asMap().forEach((key, value) {
      if (value > 127) {
        throw AsmError(
            bytes,
            'contains code unit incompatible with ascii at index $key: '
            '$value "${String.fromCharCode(value)}"');
      }
    });
  }

  @override
  _AsciiBytes trim(int byte) {
    return _AsciiBytes(bytes.trim(value: byte));
  }

  @override
  _AsciiBytes sublist(int start, [int? end]) {
    return _AsciiBytes(bytes.sublist(start, end));
  }

  @override
  String toString() {
    return '"${String.fromCharCodes(bytes)}"';
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
}

extension TrimBytes on Uint8List {
  Uint8List trim({int value = 0}) {
    return Uint8List.fromList(toList(growable: false).trim(value: value));
  }
}

extension TrimWords on Uint16List {
  Uint16List trim({int value = 0}) {
    return Uint16List.fromList(toList(growable: false).trim(value: value));
  }
}

extension TrimLongwords on Uint32List {
  Uint32List trim({int value = 0}) {
    return Uint32List.fromList(toList(growable: false).trim(value: value));
  }
}

extension TrimList on List<int> {
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
