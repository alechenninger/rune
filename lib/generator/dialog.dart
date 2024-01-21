import 'dart:collection';
import 'dart:math';

import 'package:characters/characters.dart';
import 'package:charcode/ascii.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../asm/asm.dart';
import '../asm/dialog.dart';
import '../asm/events.dart';
import '../characters.dart';
import '../model/model.dart';
import 'cutscenes.dart';
import 'generator.dart';

class DialogAsm extends Asm {
  DialogAsm.empty() : super.empty();
  DialogAsm.justTerminate()
      : super([
          dc.b([Byte(0xff)])
        ]);
  DialogAsm.fromRaw(String raw) : super.empty() {
    add(Instruction.parse(raw));
  }
  DialogAsm(List<Asm> asm) : super(asm);

  DialogAsm.emptyDialog()
      : super([
          dc.b([Byte(0xff)])
        ]);

  DialogTree splitToTree() => DialogTree()..addAll(split());

  @override
  DialogAsm withoutComments() {
    return DialogAsm([super.withoutComments()]);
  }

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
  DialogAsm toAsm([EventState? state]) {
    var asm = DialogAsm.empty();
    var quotes = Quotes();

    // i think byte zero removes portrait if already present.
    // todo: could optimize if we know there is no portrait
    if (state?.dialogPortrait != speaker.portrait) {
      asm.add(portrait(toPortraitCode(speaker.portrait)));
      state?.dialogPortrait = speaker.portrait;
    }

    var ascii = BytesAndAscii([]);
    var codePoints = <List<ControlCode>?>[];

    for (var i = 0; i < spans.length; i++) {
      var span = spans[i];
      var spanAscii = span.toAscii(quotes);
      ascii += spanAscii;

      if (span.pause > Duration.zero) {
        codePoints.length = ascii.length + 1;
        codePoints[ascii.length] = [PauseCode(span.pause.toFrames().toByte)];
      }

      var panel = span.panel;
      if (panel != null) {
        state?.addPanel();
        codePoints.length = ascii.length + 1;
        var codes = codePoints[ascii.length] ?? [];
        codes.add(PanelCode(panel.panelIndex.toWord));
        codePoints[ascii.length] = codes;
      }
    }

    asm.add(dialog(ascii, codePoints: codePoints));

    return asm;
  }
}

// todo: this might belong in generator.dart due to symmetry with
//  SceneAsmGenerator
Scene toScene(int dialogId, DialogTree tree,
    {Speaker? defaultSpeaker, bool isObjectInteraction = false}) {
  if (dialogId >= tree.length) {
    // todo: i think this is required b/c some original asm refers to these
    // but check on it
    return Scene.none();
    //throw ArgumentError.value(dialogId, 'dialogId', 'is not available in tree');
  }

  var constants =
      ConstantIterator(tree[dialogId].iterator).toList(growable: false);
  var events = <Event>[];

  var lastConstIds = Queue<int>();
  var lastDialogIds = Queue<int>();
  var lastConstants = Queue<List<Sized>>();

  var constId = 0;

  advanceDialog(int offset) {
    lastConstIds.add(constId);
    lastDialogIds.add(dialogId);
    lastConstants.add(constants);
    // since we want to start at the beginning of offset dialog,
    // set to -1 prior to for loop increment
    constId = -1;
    dialogId = dialogId + offset;
    constants =
        ConstantIterator(tree[dialogId].iterator).toList(growable: false);
  }

  returnDialog() {
    // subtract once since constId will advance after this iteration
    // and we want to return to last constant, not move past it.
    constId = lastConstIds.removeLast() - 1;
    dialogId = lastDialogIds.removeLast();
    constants = lastConstants.removeLast();
  }

  var context = ParseContext(
    events,
    defaultSpeaker: defaultSpeaker,
    moveBack: () => constId--,
    advance: advanceDialog,
    returnToLast: returnDialog,
    isObjectInteractionRoot: isObjectInteraction,
  );

  for (; constId < constants.length; constId++) {
    var constant = constants[constId];
    context.state(constant, context);
  }

  return Scene(events);
}

class ParseContext {
  /// should not be used by states directly
  final Function() _moveBack;

  /// should not be used by states directly
  final Function(int) _advance;

  /// should not be used by states directly
  final Function() _returnToLast;

  late DialogParseState state;

  ParseContext(List<Event> events,
      {required Function() moveBack,
      required Function(int) advance,
      required Function() returnToLast,
      Speaker? defaultSpeaker,
      bool isObjectInteractionRoot = false})
      : _moveBack = moveBack,
        _advance = advance,
        _returnToLast = returnToLast {
    state = DialogState(events,
        defaultSpeaker: defaultSpeaker,
        isObjectInteractionRoot: isObjectInteractionRoot);
  }

  /// reparses the last byte with new state of [state]
  void reparseWith(DialogParseState state) {
    _moveBack();
    this.state = state;
  }

  void advanceDialogsBy(int offset, {required DialogState newState}) {
    _advance(offset);
    state = newState;
  }

  void returnToLastDialog({required DialogState newState}) {
    _returnToLast();
    state = newState;
  }
}

abstract class DialogParseState {
  void call(Expression constant, ParseContext context);
}

class DialogState implements DialogParseState {
  Speaker? speaker;
  final List<Event> events;

  bool _needsFacePlayer;

  DialogState(this.events,
      {Speaker? defaultSpeaker, bool isObjectInteractionRoot = false})
      : speaker = defaultSpeaker,
        _needsFacePlayer = isObjectInteractionRoot;

  @override
  void call(Expression constant, ParseContext context) {
    if (constant == Byte(0xF2)) {
      _facePlayerIfNeeded();
      context.state = ActionState(this);
    } else if (constant == Byte(0xF3)) {
      _needsFacePlayer = false;
    } else if (constant == Byte(0xF4)) {
      _facePlayerIfNeeded();
      context.state = PortraitState(this);
    } else if (constant == Byte(0xF6)) {
      context.state = RunEventState(this);
    } else if (constant == Byte(0xFA)) {
      context.state =
          EventCheckState(this, isObjectInteractionRoot: _needsFacePlayer);
      // Will be handled by branches instead.
      _needsFacePlayer = false;
    } else if (constant == Byte(0xFF)) {
      _facePlayerIfNeeded();
      terminate(context);
    } else if (constant is Byte &&
        constant.value >= 0xF2 &&
        constant.value != 0xF9) {
      // todo: this should be the state that handles all that stuff
      _needsFacePlayer = false; // ?
    } else {
      _facePlayerIfNeeded();
      context.reparseWith(SpanState(this));
    }
  }

  void terminate(ParseContext context) {
    context.state = DoneState();
  }

  void _facePlayerIfNeeded() {
    if (_needsFacePlayer) {
      events.add(InteractionObject.facePlayer());
      _needsFacePlayer = false;
    }
  }
}

class RunEventState extends DialogParseState {
  final DialogState dialog;

  RunEventState(this.dialog);

  @override
  void call(Expression constant, ParseContext context) {
    dialog.events.add(AsmEvent(comment('run event index $constant')));
    context.state = dialog;
  }
}

class ActionState extends DialogParseState {
  final DialogState parent;

  ActionState(this.parent);

  @override
  void call(Expression constant, ParseContext context) {
    if (constant is! Value) {
      throw Exception('cannot parse constant from non-value '
          '(need constant/symbol table)');
    }

    switch (constant.value) {
      case 0:
        context.state = PanelState(parent);
        break;
      case 1:
        parent.events.add(HideTopPanels(1));
        context.state = parent;
        break;
      case 2:
        parent.events.add(HideAllPanels());
        context.state = parent;
        break;
      case 3:
      case 4:
        context.state = SoundState(parent);
        break;
      case 5:
        throw Exception('unknown action 5');
      case 6:
        throw Exception('unsupported event 6, update palettes');
      case 7:
        throw Exception("unsupported event 7, update zio's eyes");
      case 8:
        throw Exception("unsupported event 8, pause music");
      case 9:
        throw Exception("unsupported event 9, resume music");
      case 0xA:
        throw Exception("unsupported event 0xA, alarm");
      case 0xB:
        context.state = SetEventFlagState(parent);
        break;
      case 0xC:
        throw Exception("unsupported event 0xC, elsydeon breaks");
    }
  }
}

class PanelState extends DialogParseState {
  final DialogState parent;

  PanelState(this.parent);

  @override
  void call(Expression constant, ParseContext context) {
    if (constant is! Word) {
      throw Exception('expected word but got $constant');
    }

    var index = constant.value;
    parent.events.add(ShowPanel(PanelByIndex(index)));
    context.state = parent;
  }
}

class SoundState extends DialogParseState {
  final DialogState parent;

  SoundState(this.parent);

  @override
  void call(Expression constant, ParseContext context) {
    // TODO parse sound pointer -> sound in model
    //parent.events.add(PlaySound(Sound.));
  }
}

class SetEventFlagState extends DialogParseState {
  final DialogState parent;

  SetEventFlagState(this.parent);

  @override
  void call(Expression constant, ParseContext context) {
    if (constant is! Byte) {
      throw Exception('expected byte but got $constant');
    }

    var eventFlag = toEventFlag(constant);
    parent.events.add(SetFlag(eventFlag));
    context.state = parent;
  }
}

class DoneState implements DialogParseState {
  @override
  void call(Expression constant, ParseContext context) {
    //throw StateError('todo');
  }
}

class PortraitState implements DialogParseState {
  final DialogState parent;

  PortraitState(this.parent);

  @override
  void call(Expression constant, ParseContext context) {
    if (constant is! Byte) {
      throw ArgumentError.value(constant, 'byte', 'expected Byte');
    }

    parent.speaker = _toSpeaker(constant);
    context.state = parent;
  }
}

class SpanState implements DialogParseState {
  final DialogState parent;
  final _spans = <DialogSpan>[];
  final _buffer = StringBuffer();
  Duration _pause = Duration.zero;

  SpanState(this.parent);

  List<DialogSpan> spans() {
    _flush();
    return _spans;
  }

  void _flush() {
    if (_buffer.isNotEmpty || _pause > Duration.zero) {
      var next = DialogSpan(_buffer.toString(), pause: _pause);
      _spans.add(next);
      _buffer.clear();
      _pause = Duration.zero;
    }
  }

  @override
  void call(Expression constant, ParseContext context) {
    if (constant is! Byte) {
      done(context);
      return;
    }

    if (constant == Byte(0xFC)) {
      // TODO: should do newline?
      _buffer.write(' ');
    } else if (constant == Byte(0xF9)) {
      context.state = SpanPauseState((p) {
        _pause = p;
        _flush();
        context.state = this;
      });
    } else {
      if (constant.value >= 0xF2) {
        // unsupported control code or terminator...
        done(context);
        return;
      }

      _buffer.write(String.fromCharCode(constant.value));
    }
  }

  void done(ParseContext context) {
    var s = spans();
    if (s.isNotEmpty) {
      var dialog = Dialog(speaker: parent.speaker, spans: s);
      parent.events.add(dialog);
    }
    context.reparseWith(parent);
  }
}

class SpanPauseState extends DialogParseState {
  final Function(Duration) _setPause;

  SpanPauseState(this._setPause);

  @override
  void call(Expression constant, ParseContext context) {
    if (constant is! Value) {
      throw ArgumentError.value(constant.runtimeType, 'constant.runtimeType',
          'expected constant expression to be of type Value');
    }

    var frames = constant.value;
    // NOTE: assumes timings were tuned for english translation
    _setPause(Duration(seconds: frames ~/ 60));
  }
}

class EventCheckState implements DialogParseState {
  EventFlag? flag;

  final DialogState parent;
  final bool isObjectInteractionRoot;

  EventCheckState(this.parent, {required this.isObjectInteractionRoot});

  @override
  void call(Expression constant, ParseContext context) {
    if (flag == null) {
      flag = toEventFlag(constant);
      return;
    }

    if (constant is! Byte) {
      throw ArgumentError.value(constant.runtimeType, 'byte.runtimeType',
          'expected byte expression to be of type Byte');
    }

    var ifSetOffset = constant.value;
    context.state = IfUnsetState(flag!, ifSetOffset, parent,
        isObjectInteractionRoot: isObjectInteractionRoot);
  }
}

class IfUnsetState extends DialogState {
  final EventFlag flag;
  final int ifSetOffset;
  final DialogState parent;
  final bool isObjectInteractionRoot;

  IfUnsetState(this.flag, this.ifSetOffset, this.parent,
      {required this.isObjectInteractionRoot})
      : super([], isObjectInteractionRoot: isObjectInteractionRoot) {
    speaker = parent.speaker;
  }

  @override
  void terminate(ParseContext context) {
    context.advanceDialogsBy(ifSetOffset,
        newState: IfSetState(flag, parent, events,
            isObjectInteractionRoot: isObjectInteractionRoot));
  }
}

class IfSetState extends DialogState {
  final EventFlag flag;
  final DialogState parent;
  final List<Event> ifUnset;

  IfSetState(this.flag, this.parent, this.ifUnset,
      {required super.isObjectInteractionRoot})
      : super([]) {
    speaker = parent.speaker;
  }

  @override
  void terminate(ParseContext context) {
    context.returnToLastDialog(newState: parent);
    parent.events.add(IfFlag(flag, isSet: events, isUnset: ifUnset));
  }
}

// todo: relies on constant globals. fine?
// See EventFlags interface, might be able to move this here
EventFlag toEventFlag(Expression byte) {
  var constant = eventFlags.inverse[byte];
  if (constant == null) {
    return EventFlag('unknown_$byte');
  }
  var name = constant.constant.replaceFirst('EventFlag_', '');
  return EventFlag(name);
}

final _transforms = {
  '‘': '[',
  '’': "'",
  '–': '=',
  '—': '=',
  '…': '...',
  'é': 'e',
};

final _replacements = {
  RegExp('  +'): ' ',
  RegExp('\n+'): ' ',
  RegExp('\r+'): ' ',
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

final _portraits = const [
  null, // dc.l	0						; 0
  Portrait.Shay, // dc.l	ArtNem_ChazDialPortrait	; 1
  Portrait.Alys, // dc.l	ArtNem_AlysDialPortrait	; 2
  Portrait.Hahn, // dc.l	ArtNem_HahnDialPortrait	; 3
  Portrait.Rune, // dc.l	ArtNem_RuneDialPortrait	; 4
  Portrait.Gryz, // dc.l	ArtNem_GryzDialPortrait	; 5
  Portrait.Rika, // dc.l	ArtNem_RikaDialPortrait	; 6
  Portrait.Demi, // dc.l	ArtNem_DemiDialPortrait	; 7
  Portrait.Wren, // dc.l	ArtNem_WrenDialPortrait	; 8
  Portrait.Raja, // dc.l	ArtNem_RajaDialPortrait	; 9
  Portrait.Kyra, // dc.l	ArtNem_KyraDialPortrait	; $A
  Portrait.Seth, // dc.l	ArtNem_SethDialPortrait	; $B
  Portrait.Saya, // dc.l	ArtNem_SayaDialPortrait	; $C
  Portrait.Holt, // dc.l	ArtNem_HoltDialPortrait	; $D
  Portrait.PrincipalKroft, // dc.l	ArtNem_PrincipalDialPortrait	; $E
  Portrait.Dorin, // dc.l	ArtNem_DorinDialPortrait	; $F
  Portrait.Pana, // dc.l	ArtNem_PanaDialPortrait	; $10
  Portrait
      .HuntersGuildClerk, // dc.l	ArtNem_HntGuildReceptionistDialPortrait	; $11
  Portrait.Baker, // dc.l	ArtNem_BakerDialPortrait	; $12
  Portrait.Zio, // dc.l	ArtNem_ZioDialPortrait	; $13
  Portrait.Juza, // dc.l	ArtNem_JuzaDialPortrait	; $14
  Portrait.Gyuna, // dc.l	ArtNem_GyunaDialPortrait	; $15
  Portrait.Esper, // dc.l	ArtNem_EsperDialPortrait	; $16
  Portrait.Esper, // dc.l	ArtNem_EsperDialPortrait	; $17
  Portrait.EsperChief, // dc.l	ArtNem_EsperChiefDialPortrait	; $18
  Portrait.EsperChief, // dc.l	ArtNem_EsperChiefDialPortrait	; $19
  Portrait.GumbiousPriest, // dc.l	ArtNem_GumbiousPriestDialPortrait	; $1A
  Portrait.GumbiousBishop, // dc.l	ArtNem_GumbiousBishopDialPortrait	; $1B
  Portrait.Lashiec, // dc.l	ArtNem_LashiecDialPortrait	; $1C
  Portrait.XeAThoul, // dc.l	ArtNem_XeAThoulDialPortrait	; $1D
  Portrait.XeAThoul2, // dc.l	ArtNem_XeAThoulDialPortrait2	; $1E
  Portrait.XeAThoul2, // dc.l	ArtNem_XeAThoulDialPortrait2	; $1F
  Portrait.FortuneTeller, // dc.l	ArtNem_FortuneTellerDialPortrait	; $20
  Portrait.DElmLars, // dc.l	ArtNem_DElmLarsDialPortrait	; $21
  Portrait.AlysWounded, // dc.l	ArtNem_AlysWoundedDialPortrait	; $22
  Portrait.ReFaze, // dc.l	ArtNem_ReFazeDialPortrait	; $23
  Portrait.MissingStudent, // dc.l	ArtNem_MissingStudentDialPortrait	; $24
  Portrait.Tallas, // dc.l	ArtNem_TallasDialPortrait	; $25
  Portrait.DyingBoy, // dc.l	ArtNem_DyingBoyDialPortrait	; $26
  Portrait.Sekreas, // dc.l	ArtNem_SekreasDialPortrait	; $27
  Portrait.Shopkeeper1,
  Portrait.Shopkeeper2,
  Portrait.Shopkeeper3,
  Portrait.Shopkeeper4,
  Portrait.Shopkeeper5,
  Portrait.Shopkeeper6,
  Portrait.Shopkeeper7
];

Byte toPortraitCode(Portrait? p) {
  var index = _portraits.indexOf(p);

  return Byte(max(0, index));
}

Speaker? _toSpeaker(Byte byte) {
  if (byte.value >= _portraits.length || byte.value < 0) {
    throw ArgumentError.value(byte.value, 'byte', 'invalid portrait index');
  }
  var portrait = _portraits[byte.value];
  if (portrait == null) return null;

  return Speaker.byPortrait(portrait) ??
      Speaker.byName(portrait.name) ??
      NpcSpeaker(portrait, portrait.name);
}
