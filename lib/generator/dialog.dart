import 'dart:math';

import 'package:characters/characters.dart';
import 'package:charcode/ascii.dart';

import '../asm/asm.dart';
import '../asm/dialog.dart';
import '../characters.dart';
import '../model/model.dart';

extension DialogToAsm on Dialog {
  Asm toAsm() {
    var asm = Asm.empty();
    var quotes = Quotes();

    var ascii = spans.map((s) => s.toAscii(quotes)).reduce((a1, a2) => a1 + a2);
    asm.add(dialog(speaker?.portraitCode ?? Bytes.of(0), ascii));

    return asm;
  }
}

final _transforms = {
  '‘': '[',
  '’': "'",
  '–': '=',
  '—': '=',
  '…': '...',
};

// TODO: this is a bit of a mess, clean it up

final _uppercase = RegExp('[A-Z]');
final _uppercaseStart = 65;
final _lowercase = RegExp('[a-z]');
final _lowercaseStart = 97;

final _uppercaseTileStart = 78;
final _lowercaseTileStart = _uppercaseTileStart + 26;

final _italicizedOther = {
  '!': 130,
  '?': 131,
};

final _nonItalicizedLetters = <String>{}; //{'x', 'z'};
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

    var builder = BytesBuilder();

    for (var c in transformed.characters) {
      if (_nonItalicizedLetters.contains(c)) {
        builder.writeAsciiCharacter(c);
        continue;
      }

      var other = _italicizedOther[c];
      if (other != null) {
        builder.writeByte(other);
        continue;
      }

      if (_uppercase.hasMatch(c)) {
        var code = c.codePoint - _uppercaseStart + _uppercaseTileStart;
        builder.writeByte(code);
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
        builder.writeByte(code);
        continue;
      }

      builder.writeAsciiCharacter(c);
    }

    return builder.bytes();
  }
}

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

extension Portrait on Character {
  static final _index = [null, Shay, Alys];

  Bytes get portraitCode {
    var index = _index.indexOf(runtimeType);
    return Bytes.of(max(0, index));
  }
}
