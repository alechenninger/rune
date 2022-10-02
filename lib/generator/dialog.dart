import 'dart:math';

import 'package:characters/characters.dart';
import 'package:charcode/ascii.dart';
import 'package:rune/generator/generator.dart';

import '../asm/asm.dart';
import '../asm/dialog.dart';
import '../characters.dart';
import '../model/model.dart';

class DialogAsm extends Asm {
  DialogAsm.empty() : super.empty();
  DialogAsm(List<Asm> asm) : super(asm);
}

extension DialogToAsm on Dialog {
  DialogAsm toAsm() {
    var asm = DialogAsm.empty();
    var quotes = Quotes();

    // i think byte zero removes portrait if already present.
    // todo: could optimize if we know there is no portrait
    asm.add(portrait(speaker?.portraitCode ?? Byte.zero));

    var ascii = BytesAndAscii([]);
    var pausePoints = <Byte?>[];

    for (var i = 0; i < spans.length; i++) {
      var span = spans[i];
      var spanAscii = span.toAscii(quotes);
      ascii += spanAscii;

      if (span.pause > Duration.zero) {
        pausePoints.length = ascii.length + 1;
        pausePoints[ascii.length] = span.pause.toFrames().toByte;
      }
    }

    asm.add(dialog(ascii, pausePoints: pausePoints));

    return asm;
  }
}

final _transforms = {
  '‘': '[',
  '’': "'",
  '–': '=',
  '—': '=',
  '…': '...',
  'é': 'e',
};

final _replacements = {RegExp('  +'): ' '};

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

final _nonItalicizedLetters = <String>{}; //...Quotes.characters}; //{'x', 'z'};
final _quotes = ['"', '“', '”'];

extension DialogSpanToAscii on DialogSpan {
  Bytes toAscii([Quotes? q]) {
    return span.toAscii(q);
  }
}

extension SpanToAscii on Span {
  Bytes toAscii([Quotes? q]) {
    var quotes = q ?? Quotes();

    var transformed = text.characters.map((e) {
      if (_quotes.contains(e)) {
        return quotes.next();
      }
      return _transforms[e] ?? e;
    }).join();

    // todo: can replace single char transforms with this i guess?
    //   except need to deal with quotes.
    for (var r in _replacements.entries) {
      transformed = transformed.replaceAll(r.key, r.value);
    }

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
  static final Set<String> characters = {$less_than.utf16, $greater_than.utf16};

  var _current = $less_than;
  var _next = $greater_than;

  String next() {
    var q = _current;
    _current = _next;
    _next = q;
    return q.utf16;
  }
}

extension Portrait on Speaker {
  static final _index = [
    UnnamedSpeaker, // dc.l	0						; 0
    Shay, // dc.l	ArtNem_ChazDialPortrait	; 1
    Alys, // dc.l	ArtNem_AlysDialPortrait	; 2
    null, // dc.l	ArtNem_HahnDialPortrait	; 3
    null, // dc.l	ArtNem_RuneDialPortrait	; 4
    null, // dc.l	ArtNem_GryzDialPortrait	; 5
    null, // dc.l	ArtNem_RikaDialPortrait	; 6
    null, // dc.l	ArtNem_DemiDialPortrait	; 7
    null, // dc.l	ArtNem_WrenDialPortrait	; 8
    null, // dc.l	ArtNem_RajaDialPortrait	; 9
    null, // dc.l	ArtNem_KyraDialPortrait	; $A
    null, // dc.l	ArtNem_SethDialPortrait	; $B
    null, // dc.l	ArtNem_SayaDialPortrait	; $C
    null, // dc.l	ArtNem_HoltDialPortrait	; $D
    PrincipalKroft, // dc.l	ArtNem_PrincipalDialPortrait	; $E
    null, // dc.l	ArtNem_DorinDialPortrait	; $F
    null, // dc.l	ArtNem_PanaDialPortrait	; $10
    null, // dc.l	ArtNem_HntGuildReceptionistDialPortrait	; $11
    null, // dc.l	ArtNem_BakerDialPortrait	; $12
    null, // dc.l	ArtNem_ZioDialPortrait	; $13
    null, // dc.l	ArtNem_JuzaDialPortrait	; $14
    null, // dc.l	ArtNem_GyunaDialPortrait	; $15
    null, // dc.l	ArtNem_EsperDialPortrait	; $16
    null, // dc.l	ArtNem_EsperDialPortrait	; $17
    null, // dc.l	ArtNem_EsperChiefDialPortrait	; $18
    null, // dc.l	ArtNem_EsperChiefDialPortrait	; $19
    null, // dc.l	ArtNem_GumbiousPriestDialPortrait	; $1A
    null, // dc.l	ArtNem_GumbiousBishopDialPortrait	; $1B
    null, // dc.l	ArtNem_LashiecDialPortrait	; $1C
    null, // dc.l	ArtNem_XeAThoulDialPortrait	; $1D
    null, // dc.l	ArtNem_XeAThoulDialPortrait2	; $1E
    null, // dc.l	ArtNem_XeAThoulDialPortrait2	; $1F
    null, // dc.l	ArtNem_FortuneTellerDialPortrait	; $20
    null, // dc.l	ArtNem_DElmLarsDialPortrait	; $21
    null, // dc.l	ArtNem_AlysWoundedDialPortrait	; $22
    null, // dc.l	ArtNem_ReFazeDialPortrait	; $23
    null, // dc.l	ArtNem_MissingStudentDialPortrait	; $24
    null, // dc.l	ArtNem_TallasDialPortrait	; $25
    null, // dc.l	ArtNem_DyingBoyDialPortrait	; $26
    null, // dc.l	ArtNem_SekreasDialPortrait	; $27
  ];

  Byte get portraitCode {
    var index = _index.indexOf(runtimeType);

    return Byte(max(0, index));
  }
}
