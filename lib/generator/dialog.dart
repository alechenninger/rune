import 'dart:math';

import 'package:characters/characters.dart';
import 'package:charcode/ascii.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/model/model.dart';

import '../asm/asm.dart';
import '../characters.dart';

final _transforms = {
  '‘': '[',
  '’': "'",
  '–': '=',
  '—': '=',
  '…': '...',
};
// var quotes = _Quotes(); TODO: need to swap utf8 at another layer again
//  I think ... goes with transforms.

class Quotes {
  var _current = $less_than;
  var _next = $greater_than;

  int next() {
    var q = _current;
    _current = _next;
    _next = q;
    return q;
  }
}

extension DialogToAsm on Dialog {
  Asm toAsm() {
    var asm = Asm.empty();
    var quotes = Quotes();

    var ascii = spans.map((s) => s.toAscii(quotes)).reduce((accum, next) {
      return accum + next;
    });
    asm.add(dialog(speaker?.portraitCode ?? Bytes.of(0), ascii));

    return asm;
  }
}

extension Portrait on Character {
  static final _index = [null, Shay, Alys];

  Bytes get portraitCode {
    var index = _index.indexOf(runtimeType);
    return Bytes.of(max(0, index));
  }
}

// TODO: this is a bit of a mess, clean it up

final _uppercase = RegExp('[A-Z]');
final _uppercaseStart = 65;
final _lowercase = RegExp('[a-z]');
final _lowercaseStart = 97;

final _uppercaseTileStart = 78;
final _lowercaseTileStart = _uppercaseTileStart + 26;

final _nonItalicizedLetters = {'x', 'z'};
final _quotes = ['"', '“', '”'];

extension SpanToAscii on Span {
  Bytes toAscii([Quotes? q]) {
    var quotes = q ?? Quotes();

    var transformed = text.characters.map((e) {
      if (_quotes.contains(e)) {
        return quotes.next();
      }
      return _transforms[e] ?? e;
    }).join();

    if (!italic) {
      return Bytes.ascii(transformed);
    }

    var builder = _BytesBuilder();

    for (var c in transformed.characters) {
      if (_nonItalicizedLetters.contains(c)) {
        builder.acceptAsciiCharacter(c);
        continue;
      }

      if (_uppercase.hasMatch(c)) {
        var code = c.codePoint - _uppercaseStart + _uppercaseTileStart;
        builder.acceptByte(code);
        continue;
      }

      if (_lowercase.hasMatch(c)) {
        var code = c.codePoint - _lowercaseStart + _lowercaseTileStart;
        var skips = 0;
        for (var nonItalics in _nonItalicizedLetters) {
          if (c.codePoint > nonItalics.codePoint) {
            skips = skips + 1;
          }
        }
        code = code - skips;
        builder.acceptByte(code);
        continue;
      }

      builder.acceptAsciiCharacter(c);
    }
    return builder.bytes();
  }
}

class _BytesBuilder {
  var _ascii = false;
  final _currentSpan = <int>[];
  final _bytesList = <Bytes>[];

  Bytes bytes() {
    _finishSpan();
    return BytesAndAscii(_bytesList);
  }

  void acceptAsciiCharacter(String c) {
    if (!_ascii) {
      _finishSpan();
      _ascii = true;
    }

    _currentSpan.add(c.codePoint);
  }

  void acceptByte(int byte) {
    if (_ascii) {
      _finishSpan();
      _ascii = false;
    }

    _currentSpan.add(byte);
  }

  void _finishSpan() {
    if (_currentSpan.isNotEmpty) {
      _bytesList.add(_ascii
          ? Bytes.ascii(String.fromCharCodes(_currentSpan))
          : Bytes.list(_currentSpan));
      _currentSpan.clear();
    }
  }
}
