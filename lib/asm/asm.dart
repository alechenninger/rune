import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:quiver/strings.dart';
import 'package:rune/src/iterables.dart';
import 'package:rune/src/null.dart';

import 'address.dart';
import 'data.dart';

export 'address.dart';
export 'data.dart';
export 'objects.dart';
export 'jump_table.dart';
export 'array.dart';

/// Data constant
const DcMnemonic dc = DcMnemonic();
const MoveMnemonic move = MoveMnemonic();
const MoveaMnemonic movea = MoveaMnemonic();
const MovemMnemonic movem = MovemMnemonic();
const ClrMnemonic clr = ClrMnemonic();
const AndiMnemonic andi = AndiMnemonic();
const OrMnemonic or = OrMnemonic();
const DivuMnemonic divu = DivuMnemonic();
const BranchMnemonic bra = BranchMnemonic('bra');
const BranchMnemonic bsr = BranchMnemonic('bsr');

/// Branch if Z is clear
const BranchMnemonic bne = BranchMnemonic('bne');

/// Branch if N is set (negative)
const BranchMnemonic bmi = BranchMnemonic('bmi');

/// Branch if N is clear (positive)
const BranchMnemonic bpl = BranchMnemonic('bpl');

/// Branch if Z is set
const BranchMnemonic beq = BranchMnemonic('beq');

/// Branch if C is clear (unsigned ≥)
const BranchMnemonic bcc = BranchMnemonic('bcc');

/// Branch if C is set (unsigned <)
const BranchMnemonic bcs = BranchMnemonic('bcs');

/// Branch if C and Z are unset. (unsigned >)
const BranchMnemonic bhi = BranchMnemonic('bhi');

/// Branch if C or Z are set. (unsigned ≤)
const BranchMnemonic bls = BranchMnemonic('bls');

const AddiMnemonic addi = AddiMnemonic();
const SubiMnemonic subi = SubiMnemonic();
const SubqMnemonic subq = SubqMnemonic();
const CmpMnemonic cmp = CmpMnemonic();
const CmpiMnemonic cmpi = CmpiMnemonic();
const TstMnemonic tst = TstMnemonic();

final rts = cmd('rts', []);

Asm newLine() => Asm.fromInstruction(_Instruction());
Asm label(Label lbl) => Asm.fromInstruction(_Instruction(label: lbl.name));
Asm comment(String comment) => Asm.fromInstructions(LineSplitter.split(comment)
    .map((e) => _Instruction(comment: comment))
    .toList(growable: false));

/// Since the constant value of the source address is known,
/// chooses the most efficient addressing mode.
Asm leaConstant(Longword src, Address dst) {
  if (src.value == Size.l.maxValue + src.lowerWord.signedValue + 1) {
    return lea(Absolute.word(src), a4);
  }
  return lea(Absolute.long(src), a4);
}

Asm lea(Address src, Address dst) => cmd('lea', [src, dst]);
Asm moveq(Address src, Address dst) => cmd('moveq', [src, dst]);

/// Optimize using moveq if possible.
/// Assumes src is *unsigned* and therefore limits moveq to 0-127,
/// as otherwise 128 would be sign extended to -128.
Asm unsignedMoveL(Address src, Address dst) {
  if (src is Immediate && src.value <= 127) {
    return moveq(src, dst);
  }
  return move.l(src, dst);
}

Asm jsr(Address to) => cmd('jsr', [to]);
Asm jmp(Address to) => cmd('jmp', [to]);
Asm bset(Address src, Address dst) => cmd('bset', [src, dst]);
Asm bclr(Address src, Address dst, {String? comment}) =>
    cmd('bclr', [src, dst], comment: comment);
Asm bchg(Address src, Address dst) => cmd('bchg', [src, dst]);
Asm trap(Immediate vector) => cmd('trap', [vector]);
Asm swap(Address src) => cmd('swap', [src]);
Asm dbf(Address src, Address dst) => cmd('dbf', [src, dst]);

/// Set Z if bit is 0.
Asm btst(Address src, Address dst) => cmd('btst', [src, dst]);

// It looks like this should be limited to 32 bytes per line
class DcMnemonic {
  const DcMnemonic();

  Asm b(List<Expression> c, {String? comment}) =>
      cmd('dc.b', c, comment: comment);
  Asm w(List<Expression> c, {String? comment}) =>
      cmd('dc.w', c, comment: comment);
  Asm l(List<Expression> c, {String? comment}) =>
      cmd('dc.l', c, comment: comment);

  Asm size(Size size, List<Expression> constants, {String? comment}) =>
      cmd('dc.$size', constants, comment: comment);
}

class MoveMnemonic {
  const MoveMnemonic();

  Asm b(Address from, Address to) => cmd('move.b', [from, to]);
  Asm w(Address from, Address to) => cmd('move.w', [from, to]);
  Asm l(Address from, Address to) => cmd('move.l', [from, to]);
}

class MoveaMnemonic {
  const MoveaMnemonic();

  Asm w(Address from, Address to) => cmd('movea.w', [from, to]);
  Asm l(Address from, Address to) => cmd('movea.l', [from, to]);
}

class MovemMnemonic {
  const MovemMnemonic();

  Asm w(RegisterListOrAddress from, RegisterListOrAddress to) =>
      cmd('movem.l', [from, to]);
  Asm l(RegisterListOrAddress from, RegisterListOrAddress to) =>
      cmd('movem.l', [from, to]);
}

class ClrMnemonic {
  const ClrMnemonic();
  //clr.b	(Render_Sprites_In_Cutscenes).w
  Asm b(Address dst) => cmd('clr.b', [dst]);
  Asm w(Address dst) => cmd('clr.w', [dst]);
}

/// http://68k.hax.com/TST
class TstMnemonic {
  const TstMnemonic();
  Asm b(Address dst) => cmd('tst.b', [dst]);
  Asm w(Address dst) => cmd('tst.w', [dst]);
}

class AndiMnemonic {
  const AndiMnemonic();

  Asm b(Address from, Address to) => cmd('andi.b', [from, to]);
  Asm w(Address from, Address to) => cmd('andi.w', [from, to]);
  Asm l(Address from, Address to) => cmd('andi.l', [from, to]);
}

class BranchMnemonic {
  final String _branch;
  const BranchMnemonic(this._branch);

  Asm s(Address to, {String? comment}) =>
      cmd('$_branch.s', [to], comment: comment);
  Asm w(Address to, {String? comment}) =>
      cmd('$_branch.w', [to], comment: comment);
}

class AddiMnemonic {
  const AddiMnemonic();

  Asm b(Address from, Address to) => cmd('addi.b', [from, to]);
  Asm w(Address from, Address to) => cmd('addi.w', [from, to]);
  Asm l(Address from, Address to) => cmd('addi.l', [from, to]);
}

class SubiMnemonic {
  const SubiMnemonic();

  Asm b(Address from, Address to) => cmd('subi.b', [from, to]);
  Asm w(Address from, Address to) => cmd('subi.w', [from, to]);
  Asm l(Address from, Address to) => cmd('subi.l', [from, to]);
}

class SubqMnemonic {
  const SubqMnemonic();

  Asm b(Address from, Address to) => cmd('subq.b', [from, to]);
  Asm w(Address from, Address to) => cmd('subq.w', [from, to]);
  Asm l(Address from, Address to) => cmd('subq.l', [from, to]);
}

class DivuMnemonic {
  const DivuMnemonic();

  Asm w(Address from, Address to) => cmd('divu.w', [from, to]);
  Asm l(Address from, Address to) => cmd('divu.l', [from, to]);
}

class CmpMnemonic {
  const CmpMnemonic();

  Asm b(Address from, Address to) => cmd('cmp.b', [from, to]);
  Asm w(Address from, Address to) => cmd('cmp.w', [from, to]);
  Asm l(Address from, Address to) => cmd('cmp.l', [from, to]);
}

class CmpiMnemonic {
  const CmpiMnemonic();

  Asm b(Address from, Address to) => cmd('cmpi.b', [from, to]);
  Asm w(Address from, Address to) => cmd('cmpi.w', [from, to]);
  Asm l(Address from, Address to) => cmd('cmpi.l', [from, to]);
}

class OrMnemonic {
  const OrMnemonic();

  Asm b(Address from, Address to) => cmd('or.b', [from, to]);
  Asm w(Address from, Address to) => cmd('or.w', [from, to]);
  Asm l(Address from, Address to) => cmd('or.l', [from, to]);
}

class AsmError extends ArgumentError {
  AsmError(dynamic value, String message) : super.value(value, message);
}

class Asm extends IterableBase<Instruction> {
  final List<Instruction> lines;

  Asm.empty() : lines = [];

  /// Const constructor. Cannot be modified.
  const Asm.none() : lines = const [];

  Asm(List<Asm> asm) : lines = [] {
    asm.forEach(add);
  }

  Asm.fromInstruction(Instruction line) : lines = [] {
    addLine(line);
  }

  Asm.fromInstructions(Iterable<Instruction> lines) : lines = [] {
    lines.forEach(addLine);
  }

  factory Asm.fromRaw(String raw) {
    return Instruction.parse(raw);
  }

  Asm withoutComments() => Asm.fromInstructions(lines.expand((line) {
        var withoutComment = line.withoutComment();
        if (withoutComment.isEmpty && line.isNotEmpty) {
          return <Instruction>[];
        }
        return [withoutComment];
      }).toList(growable: false));

  /// returns position in list in which asm was added.
  int add(Asm asm) {
    // TODO: max length
    lines.addAll(asm.lines);
    return lines.length - asm.length;
  }

  Asm operator [](int i) => Asm.fromInstruction(lines[i]);

  void replace(int index, Asm asm) {
    lines.removeRange(index, index + asm.length);
    lines.insertAll(index, asm.lines);
  }

  void insert(int index, Asm asm) {
    lines.insertAll(index, asm);
  }

  void addLine(Instruction line) {
    lines.add(line);
  }

  void addNewline() {
    lines.add(_Instruction());
  }

  /// Removes the line at [line] and all subsequent lines.
  void truncate(int line) {
    lines.removeRange(line, lines.length);
  }

  Asm range(int start, [int? end]) {
    return Asm.fromInstructions(lines.sublist(start, end));
  }

  Asm head(int lines) {
    if (lines < 0) {
      lines = length + lines;
      lines = max(0, lines);
    } else {
      lines = min(lines, length);
    }
    return Asm.fromInstructions(this.lines.sublist(0, lines));
  }

  Asm tail(int lines) {
    lines = min(lines, length);
    return Asm.fromInstructions(this.lines.sublist(length - lines));
  }

  Asm trim() {
    return Asm.fromInstructions(lines
        .skipWhile((instr) => instr.toString().trim().isEmpty)
        .toList(growable: false)
        .reversed
        .skipWhile((instr) => instr.toString().trim().isEmpty)
        .toList(growable: false)
        .reversed
        .toList(growable: false));
  }

  Asm withoutEmptyLines() {
    return Asm.fromInstructions(lines.whereNot((line) => line.isEmpty));
  }

  @override
  int get length => lines.length;

  @override
  String toString() {
    return lines.join('\n');
  }

  // I originally modelled Instructions for better == but in hindsight, this
  // is only useful if we were parsing different String representations.
  // Equivalent asm generated from the model always has the same String
  // representation.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Asm &&
          runtimeType == other.runtimeType &&
          toString() == other.toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  Iterator<Instruction> get iterator => lines.iterator;
}

Asm setLabel(String label) {
  return Asm.fromInstruction(_Instruction(label: label));
}

Asm cmd(String cmd, List operands, {String? label, String? comment}) {
  return Asm.fromInstruction(_Instruction(
      label: label, cmd: cmd, operands: operands, comment: comment));
}

abstract class Instruction {
  static Asm parse(String asm) {
    var lines = LineSplitter.split(asm).map((line) => _Instruction.parse(line));
    return Asm.fromInstructions(lines.toList());
  }

  Asm toAsm() {
    return Asm.fromInstruction(this);
  }

  String? get label;
  String? get cmd;
  String? get attribute {
    var split = cmd?.split('.');
    return split?[1];
  }

  String? get cmdWithoutAttribute {
    var split = cmd?.split('.');
    return split?[0];
  }

  List get operands;
  String? get comment;
  bool get isEmpty => toString().isEmpty;
  bool get isNotEmpty => toString().isNotEmpty;
  bool get isCommentOnly => cmd == null && label == null && comment != null;

  Instruction withoutComment();

  @override
  String toString();

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

class _Instruction extends Instruction {
  @override
  final String? label;
  @override
  final String? cmd;
  @override
  final List operands;
  @override
  final String? comment;

  final String line;

  static final _validLabelPattern =
      RegExp(r'^[A-Za-z\d_@.+-/$]+[A-Za-z\d_/+-]*$');
  static final _noColonLabel = RegExp(r'^(\++|/+|-+|\.\S+)$');

  /// appends : depending on the kind of label
  static String _delimitLabel(String label) {
    if (_noColonLabel.hasMatch(label)) return label;
    return '$label:';
  }

  _Instruction({this.label, this.cmd, this.operands = const [], this.comment})
      : line = [
          if (label == null) '' else _delimitLabel(label),
          if (cmd != null) cmd,
          if (operands.isNotEmpty)
            if (operands is Data) operands else operands.join(', '),
          if (comment != null) '; $comment'
        ].join('\t').trimRight() {
    // TODO: This causes false positives.
    // Perhaps it with constants? (i.e. 255 is limit of data but not
    // considering constant names)
    // if (line.length > 255) {
    //   throw ArgumentError(
    //       'Instructions cannot be longer than 255 characters but was: $line');
    // }

    var l = label;
    if (l != null && !_validLabelPattern.hasMatch(l)) {
      throw ArgumentError.value(label, 'label',
          'did not match allowed characters: $_validLabelPattern');
    }
  }

  _Instruction.pseudo(String pseudo, {this.comment})
      : label = null,
        cmd = null,
        operands = const [],
        line =
            [pseudo, if (comment != null) '; $comment'].join('\t').trimRight();

  factory _Instruction.parse(String line) {
    var chars = line.characters.toList();

    bool pseudo = false;
    String? labelOrPseudo;
    String? cmd;
    String? attribute;
    List<Expression> ops = [];
    String? comment;

    var state = _Token.root;

    for (var i = 0; i < chars.length + 1; i++) {
      var c = i == chars.length ? null : chars[i];
      switch (state) {
        case _Token.root:
          if (isNotBlank(c)) {
            if (c == ';') {
              state = _Token.comment;
            } else if (i == 0) {
              state = _Token.label;
              i--;
            } else if (cmd == null) {
              state = _Token.cmd;
              i--;
            } else if (c == ',') {
              // skip
            } else {
              state = _Token.operand;
              i--;
            }
          }
          break;
        case _Token.label:
          if (c == ':') {
            state = _Token.root;
          } else if (c == ';') {
            state = _Token.comment;
          } else {
            if (c != null) {
              labelOrPseudo ??= "";
              labelOrPseudo += c;
            }

            if (isBlank(c)) {
              pseudo = true;
              state = _Token.pseudo;
            }
          }
          break;
        case _Token.cmd:
          if (isBlank(c)) {
            state = _Token.root;
          } else {
            cmd ??= "";
            cmd += c!;

            attribute = cmd.split('.').skip(1).firstOrNull;
          }
          break;
        case _Token.operand:
          var remaining = chars.sublist(i);
          Size? size;
          if (cmd!.startsWith('dc.')) {
            size = attribute?.map((a) => Size.valueOf(a));
          }
          var parsed = Expression.parse(remaining, size: size);
          ops = parsed.expressions;
          i += parsed.charactersParsed;
          state = _Token.root;
          break;
        case _Token.comment:
          if (comment == null && isBlank(c)) {
            break;
          }
          comment ??= "";
          if (c != null) {
            comment += c;
          }
          break;
        case _Token.pseudo:
          if (c == ';') {
            state = _Token.comment;
          } else if (c == null) {
            break;
          } else {
            labelOrPseudo ??= "";
            labelOrPseudo += c;
          }
          break;
      }
    }

    if (pseudo) {
      return _Instruction.pseudo(labelOrPseudo!, comment: comment);
    } else {
      return _Instruction(
          label: labelOrPseudo, cmd: cmd, operands: ops, comment: comment);
    }
  }

  @override
  Instruction withoutComment() {
    return _Instruction(label: label, cmd: cmd, operands: operands);
  }

  @override
  String toString() {
    return line;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Instruction && line == other.toString();

  @override
  int get hashCode => line.hashCode;
}

enum _Token {
  root,
  label,
  cmd,
  operand,
  comment,
  pseudo,
}

final _number = RegExp(r'^(\$[0-9a-fA-F]+|\d+)$');

class ConstantIterator implements Iterator<Sized> {
  final Iterator<Instruction> _asm;
  final Constants _constants;
  late Queue<Sized> _remainingLineConstants;
  bool _done = false;
  Sized? _current;

  ConstantIterator(this._asm, {Constants constants = const Constants.wrap({})})
      : _constants = Constants.of(constants) {
    _loadNextLine();
  }

  Asm get remaining {
    // todo: remaining line constants
    return Asm.fromInstructions(_asm.toList());
  }

  _loadNextLine() {
    if (!_asm.moveNext()) {
      _done = true;
      _remainingLineConstants = Queue();
      return;
    }

    var next = _asm.current;
    if (next.cmd == null) {
      // just comment or label, skip
      _loadNextLine();
      return;
    }

    var cmd = next.cmdWithoutAttribute;

    if (cmd == 'if' || cmd == 'include' || cmd == 'endif') {
      // FIXME: evaluate conditional assembly
      // for now skip
      _loadNextLine();
      return;
    }

    if (cmd != 'dc') {
      _done = true;
      _remainingLineConstants = Queue();
      return;
    }

    var size = Size.valueOf(next.attribute!);
    if (size == null) {
      throw 'todo';
    }

    _remainingLineConstants = Queue.of(
        next.operands.cast<Expression>().map((e) => size.sizedExpression(e)));
  }

  @override
  bool moveNext() {
    if (_done) return false;
    if (_remainingLineConstants.isNotEmpty) {
      _current = _remainingLineConstants.removeFirst();
      return true;
    }
    _loadNextLine();
    return moveNext();
  }

  @override
  Sized get current {
    var current = _current;
    if (current == null) {
      throw StateError('no remaining elements');
    }
    return current;
  }
}

class ConstantReadException implements Exception {
  final Size sizeToRead;
  final List<Sized> valuesRead;

  ConstantReadException(this.sizeToRead, this.valuesRead);

  @override
  String toString() => 'ConstantReadException: '
      'could not read $sizeToRead from $valuesRead';
}

class ConstantReader {
  final ConstantIterator _iter;
  // TODO: need to do this because there are sometimes constants in mapdata
  //   like facing direction
  // could probably define a global default constant table since they are...
  // well... constants :)
  final Map<Constant, SizedValue> _constantTable = {};
  final _queue = Queue<Sized>();

  Asm get remaining => _iter.remaining;

  ConstantReader.asm(Asm asm) : this(ConstantIterator(asm.iterator));
  ConstantReader(this._iter);

  Sized _next() {
    if (_queue.isNotEmpty) {
      return _queue.removeFirst();
    }
    if (_iter.moveNext()) {
      return _iter.current;
    }
    throw StateError('no more constants');
  }

  /// Iterates by bytes, looking for [value], and skipping ahead until it is
  /// seen [times] times.
  List<Sized> skipThrough(
      // todo: variable chunk size?
      {/*required Size chunk,*/ required SizedValue value,
      required int times}) {
    var timesSkipped = 0;
    var skippedBytes = <Sized>[];
    var buffer = QueueList<Byte>();

    Byte readByteSkippingLabels() {
      try {
        var byte = readByte();
        skippedBytes.add(byte);
        return byte;
      } on ConstantReadException catch (e) {
        var first = e.valuesRead.first;
        if (first is! Value && e.valuesRead.length == 1) {
          skippedBytes.add(first);
          // clear buffer because we're skipping data,
          // so it can't match consecutively now.
          buffer.clear();
          return readByteSkippingLabels();
        }
        rethrow;
      }
    }

    while (timesSkipped < times) {
      buffer.add(readByteSkippingLabels());

      switch (value.size) {
        case Size.b:
          if (value == buffer[0]) {
            timesSkipped++;
          }
          buffer.clear();
          break;
        case Size.w:
          if (buffer.length == 2) {
            if (value == buffer[0].appendLower(buffer[1])) {
              timesSkipped++;
              buffer.clear();
            } else {
              buffer.removeFirst();
            }
          }
          break;
        case Size.l:
          if (buffer.length == 4) {
            if (value ==
                Longword.concatBytes(
                    buffer[0], buffer[1], buffer[2], buffer[3])) {
              timesSkipped++;
              buffer.clear();
            } else {
              buffer.removeFirst();
            }
          }
          break;
      }
    }

    return skippedBytes;
  }

  Byte readByte() {
    var c = _next();
    if (c is Byte) return c;
    if (c.canSplit) {
      c.splitInto(Size.b).reversed.forEach(_queue.addFirst);
      return readByte();
    }
    throw ConstantReadException(Size.b, [c]);
  }

  // todo: test!
  Sized readByteExpression() {
    var c = _next();
    if (c.size == Size.b) return c;
    if (c.canSplit) {
      c.splitInto(Size.b).reversed.forEach(_queue.addFirst);
      return readByteExpression();
    }
    throw ConstantReadException(Size.b, [c]);
  }

  Word readWord() {
    var c = _next();
    if (c is Word) return c;
    if (c.size == Size.l && c.canSplit) {
      c.splitInto(Size.w).reversed.forEach(_queue.addFirst);
      return readWord();
    }
    if (c.size == Size.b && c.canAppend) {
      var word = c.appendLower(readByte());
      if (word is Word) return word;
    }
    throw ConstantReadException(Size.w, [c]);
  }

  // todo: test!
  Sized readWordExpression() {
    var c = _next();
    if (c.size == Size.w) return c;
    if (c.canSplit) {
      c.splitInto(Size.w).reversed.forEach(_queue.addFirst);
      return readWordExpression();
    }
    throw ConstantReadException(Size.w, [c]);
  }

  Longword readLong() {
    var c = _next();
    if (c is Longword) return c;
    if (c.canAppend) {
      var constants = <Sized>[c];
      int bytes;
      while ((bytes = constants
              .map((e) => e.size.bytes)
              .reduceOr((b1, b2) => b1 + b2, ifEmpty: 0)) <
          4) {
        var c = _next();
        if (bytes % 2 == 1) {
          if (c.size == Size.w && c.canAppend) {
            constants.add(c);
            continue;
          }
        } else if (c.size == Size.b && c.canAppend) {
          constants.add(c);
          continue;
        }
        throw ConstantReadException(Size.l, [...constants, c]);
      }
      var long =
          constants.reduce((value, element) => value.appendLower(element));
      if (long is Longword) {
        return long;
      }
      throw ConstantReadException(Size.l, [long]);
    }
    throw ConstantReadException(Size.l, [c]);
  }

  Label readLabel() {
    var c = _next();
    if (c is Label) return c;
    if (c is! Value) return Label('$c');
    throw StateError('cannot read label from $c');
  }

  Constant readConstant() {
    var c = _next();
    if (c is SizedConstant) return c;
    if (c is! Value) return Constant('$c');
    throw StateError('cannot read constant from $c');
  }
}
