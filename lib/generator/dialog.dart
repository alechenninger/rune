import 'dart:math';

import 'package:characters/characters.dart';
import 'package:charcode/ascii.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/conditional.dart';

import '../asm/asm.dart';
import '../asm/dialog.dart';
import '../characters.dart';
import '../model/model.dart';

class DialogAsm extends Asm {
  DialogAsm.empty() : super.empty();
  DialogAsm.fromRaw(String raw) : super.fromRaw(raw);
  DialogAsm(List<Asm> asm) : super(asm);

  DialogAsm.emptyDialog()
      : super([
          dc.b([Byte(0xff)])
        ]);

  /// If the ASM contains multiple dialogs, split each into their own element.
  ///
  /// A dialog must be terminated for it to be considered.
  List<DialogAsm> split() {
    var dialogs = <DialogAsm>[];
    var dialog = DialogAsm.empty();
    for (var line in lines) {
      var lineAlreadyAdded = false;

      if (line.cmd == 'dc.b') {
        for (var i = 0; i < line.operands.length; i++) {
          var op = line.operands[i];
          if (op is Byte) {
            if (op == Byte(0xff)) {
              var last = dc.b(
                  line.operands.sublist(0, i + 1) as List<Expression>,
                  comment: line.comment);
              dialog.add(last);
              dialogs.add(dialog);
              dialog = DialogAsm.empty();
              var remaining = line.operands.sublist(i + 1) as List<Expression>;
              if (remaining.isNotEmpty) {
                line = dc.b(remaining, comment: line.comment).first;
                i = 0;
              } else {
                lineAlreadyAdded = true;
              }
            }
          } else {
            // ignored (likely a constant)
          }
        }

        if (!lineAlreadyAdded) {
          dialog.addLine(line);
        }
      } else {
        dialog.addLine(line);
      }
    }
    return dialogs;
  }

  int get dialogs => split().length;
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

Future<Scene> toScene(int dialogId, DialogTree tree) async {
  var dialogs = <Dialog>[];

  var dialogIndex = 0;
  Speaker? speaker;
  EventFlag? flag;

  for (var ins in tree.toAsm()) {
    if (ins.cmd != 'dc.b') {
      throw UnimplementedError();
      // return dialogs;
    }

    var bytes = ins.operands as List<Expression>;

    for (var i = 0; i < bytes.length; ++i) {
      var b = bytes[i];

      // parse() {
      //   var result = parseState(b);
      //
      //   var newState = result.newState;
      //   if (newState != null) {
      //     if (parseState is _SpanParse) {
      //       var span = parseState.span();
      //     }
      //   }
      //
      //   if (!result.parsed) {
      //     parse();
      //   }
      // }
      //
      // parse();
    }
  }

  throw UnimplementedError();
  // return dialogs;
}

abstract class DialogParseState {
  ContinueParse call(Expression byte);
}

// class Root implements DialogParseState {
//   DialogParseState? state;
//
//   ContinueParse call(Expression byte) {}
// }

class ContinueParse {
  /// Whether or not the byte was processed already or should be processed
  /// by another state.
  final bool parsed;

  /// Next state to set which processes the next byte.
  ///
  /// The next byte is the last byte is [parsed] is [false].
  final DialogParseState? newState;

  ContinueParse()
      : parsed = true,
        newState = null;
  ContinueParse.unparsed()
      : parsed = false,
        newState = null;
  ContinueParse.newState(DialogParseState state, {this.parsed = true})
      : newState = state;
}

class _SpanParse implements DialogParseState {
  final _buffer = StringBuffer();

  Span span() {
    return Span(_buffer.toString());
  }

  @override
  ContinueParse call(Expression byte) {
    if (byte is! Byte) {
      // ignored? constant? TODO
      return ContinueParse.unparsed();
    }

    if (byte.value >= 0xF2) {
      // just continue from this instruction
      return ContinueParse.unparsed();
    }

    _buffer.write(String.fromCharCode(byte.value));

    return ContinueParse();
  }
}

class _EventCheck implements DialogParseState {
  EventFlag? flag;
  int? ifSetOffset;
  List<Event> ifSet = [];
  List<Event> ifUnset = [];

  // DialogParseState state = Root();

  @override
  ContinueParse call(Expression byte) {
    if (flag == null) {
      flag = toEventFlag(byte);
      return ContinueParse();
    }

    if (byte is! Byte) {
      throw ArgumentError.value(byte.runtimeType, 'byte.runtimeType',
          'expected byte expression to be of type Byte');
    }

    if (ifSetOffset == null) {
      ifSetOffset = byte.value;
      return ContinueParse();
    }

    // state(byte);
    return ContinueParse();
  }
}

EventFlag? toEventFlag(Expression byte) {
  // TODO
  return EventFlag('TODO');
}

/*
parse states:
event flag (may have child states)
portrait
 */

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
        builder.writeByteValue(other);
        continue;
      }

      if (_uppercase.hasMatch(c)) {
        var code = c.codePoint - _uppercaseStart + _uppercaseTileStart;
        builder.writeByteValue(code);
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
        builder.writeByteValue(code);
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
