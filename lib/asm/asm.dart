import 'dart:typed_data';

import 'package:charcode/ascii.dart';

final int asciiSpace = $space;

class AsmError extends ArgumentError {
  AsmError(dynamic value, String message) : super.value(value, message);
}

class Data {
  final Uint8List bytes;

  Data(this.bytes);

  int get length => bytes.length;

  /// Trims both trailing and leading bytes equal to [byte].
  Data trim(int byte) {
    return Data(bytes.trim(value: byte));
  }

  int operator [](int index) => bytes[index];

  @override
  String toString() {
    return bytes
        .map((e) => '\$${e.toRadixString(16).toUpperCase().padLeft(2, '0')}')
        .join(',');
  }

  Data sublist(int start, [int? end]) {
    return Data(bytes.sublist(start, end));
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

  factory Data.fromAscii(String d) {
    return _AsciiData(Uint8List.fromList(d.codeUnits));
  }

  factory Data.fromByte(int d) {
    if (d > 255) {
      throw AsmError(d, 'is larger than a single byte (max 255)');
    }
    return Data(Uint8List.fromList([d]));
  }

  factory Data.fromByteHex(String d) {
    return Data.fromByte(int.parse('0x$d'));
  }
}

int hex(String d) => int.parse('0x$d');

class _AsciiData extends Data {
  _AsciiData(Uint8List bytes) : super(bytes) {
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
  _AsciiData trim(int byte) {
    return _AsciiData(bytes.trim(value: byte));
  }

  @override
  _AsciiData sublist(int start, [int? end]) {
    return _AsciiData(bytes.sublist(start, end));
  }

  @override
  String toString() {
    return '"${String.fromCharCodes(bytes)}"';
  }
}

/// Data constant
const Dc dc = Dc();

class Dc {
  const Dc();

  /// Byte width (dc.b)
  Asm b(Data d) => Asm.fromLine('	dc.b	$d');
}

class Asm {
  final List<String> lines = [];

  Asm.empty();

  Asm.fromLine(String line) {
    addLine(line);
  }

  void add(Asm asm) {
    lines.addAll(asm.lines);
  }

  void addLine(String line) {
    // TODO: max length
    lines.add(line);
  }

  int get length => lines.length;

  @override
  String toString() {
    return lines.join('\n');
  }
}

extension Trim on Uint8List {
  Uint8List trim({int value = 0}) {
    return Uint8List.fromList(toList(growable: false).trim(value: value));
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
