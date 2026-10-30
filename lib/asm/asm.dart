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
export 'battles.dart';
export 'data.dart';
export 'objects.dart';
export 'jump_table.dart';
export 'array.dart';
// cannot export events.dart - massive conflicts

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

/// Branch if N and V are the same, and Z is clear (signed >).
const BranchMnemonic bgt = BranchMnemonic('bgt');

const AddiMnemonic addi = AddiMnemonic();
const SubMnemonic sub = SubMnemonic();
const SubiMnemonic subi = SubiMnemonic();
const SubqMnemonic subq = SubqMnemonic();
const CmpMnemonic cmp = CmpMnemonic();
const CmpiMnemonic cmpi = CmpiMnemonic();
const TstMnemonic tst = TstMnemonic();
const LsMnemonic lsl = LsMnemonic('l');
const LsMnemonic lsr = LsMnemonic('r');
const NegMnemonic neg = NegMnemonic();

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
    // Size as byte because of moveq's limitations
    return moveq(src.value.i, dst);
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

  Asm b(Address from, Address to, {String? comment}) =>
      cmd('move.b', [from, to], comment: comment);
  Asm w(Address from, Address to, {String? comment}) =>
      cmd('move.w', [from, to], comment: comment);
  Asm l(Address from, Address to, {String? comment}) =>
      cmd('move.l', [from, to], comment: comment);
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

  /// Branch, allowing the assembler to determine the size.
  Asm call(Address to, {String? comment}) =>
      cmd(_branch, [to], comment: comment);

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

class SubMnemonic {
  const SubMnemonic();

  Asm b(Address from, Address to) => cmd('sub.b', [from, to]);
  Asm w(Address from, Address to) => cmd('sub.w', [from, to]);
  Asm l(Address from, Address to) => cmd('sub.l', [from, to]);
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

class LsMnemonic {
  final String direction;
  const LsMnemonic(this.direction);

  Asm b(Address from, Address to) => cmd('ls$direction.w', [from, to]);
  Asm w(Address from, Address to) => cmd('ls$direction.w', [from, to]);
  Asm l(Address from, Address to) => cmd('ls$direction.l', [from, to]);
}

class NegMnemonic {
  const NegMnemonic();

  Asm b(Address destination) => cmd('neg.b', [destination]);
  Asm w(Address destination) => cmd('neg.w', [destination]);
  Asm l(Address destination) => cmd('neg.l', [destination]);
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

  factory Asm.fromRaw(String raw) =>
      Asm.fromInstructions(LineSplitter.split(raw).map(Instruction.parse));

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

  @override
  Instruction get last => lines.last;

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
  Instruction();

  /// Parses one assembly line. Use [Asm.fromRaw] for multiline source.
  factory Instruction.parse(String line) {
    if (line.contains('\n') || line.contains('\r')) {
      throw FormatException('expected one assembly line', line);
    }
    return _Instruction.parse(line);
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
          final tail = _InstructionTail.parse(chars.skip(i).join());
          final size = cmd!.toLowerCase().startsWith('dc.')
              ? Size.valueOf(attribute!)
              : null;
          // Non-data operands stay as source text until their consumer needs
          // to interpret them, including conditional-assembly expressions.
          final operands = size != null
              ? _parseDataOperands(tail.operands, size)
              : tail.operands;
          return _Instruction(
              label: labelOrPseudo,
              cmd: cmd,
              operands: operands,
              comment: tail.comment);
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
      return _Instruction(label: labelOrPseudo, cmd: cmd, comment: comment);
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

/// Reads data constants from the selected conditional-assembly branches.
///
/// Conditions use [constants]; ordinary data operands remain symbolic. Syntax
/// and nesting are checked as instructions are consumed, including by [remaining].
class ConstantIterator implements Iterator<Sized> {
  final _ConditionalInstructions _asm;
  final Queue<Sized> _remainingLineConstants = Queue();
  final List<Instruction> _pendingLines = [];
  Instruction? _stoppedAt;
  bool _done = false;
  Sized? _current;

  ConstantIterator(Iterator<Instruction> asm,
      {Constants constants = const Constants.none()})
      : _asm = _ConditionalInstructions(asm, Constants.of(constants));

  /// Consumes and returns all unread assembly, including buffered operands.
  ///
  /// Already-entered conditionals are finished using their selected branches,
  /// without orphaned else/endif directives. Complete new conditional blocks
  /// are preserved for the assembler, even within a selected continuation.
  Asm get remaining {
    final result = _constantData(_remainingLineConstants);
    _remainingLineConstants.clear();
    result.lines.addAll(_pendingLines);
    _pendingLines.clear();
    if (_stoppedAt case final instruction?) {
      result.addLine(instruction);
      _stoppedAt = null;
    }
    result.lines.addAll(_asm.takeRemaining());
    _current = null;
    _done = true;
    return result;
  }

  @override
  Sized get current =>
      _current ?? (throw StateError('iterator has not started or is finished'));

  @override
  bool moveNext() {
    _current = null;
    if (_done) return false;
    while (_remainingLineConstants.isEmpty) {
      if (!_asm.moveNext()) {
        _done = true;
        return false;
      }
      final next = _asm.current;
      if (next.cmd == null) {
        // Retain labels/comments if a non-data instruction ends this reader.
        _pendingLines.add(next);
        continue;
      }
      if (next.cmdWithoutAttribute?.toLowerCase() != 'dc') {
        _stoppedAt = next;
        _done = true;
        return false;
      }
      final size = Size.valueOf(next.attribute ?? '');
      if (size == null) throw FormatException('expected a dc size', '$next');
      _pendingLines.clear();
      _remainingLineConstants
          .addAll(next.operands.cast<Expression>().map(size.sizedExpression));
    }
    _current = _remainingLineConstants.removeFirst();
    return true;
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
  // ignore: unused_field
  final Map<Constant, SizedValue> _constantTable = {};
  final _queue = Queue<Sized>();

  ConstantReader.asm(Asm asm, {Constants constants = const Constants.none()})
      : this(ConstantIterator(asm.iterator, constants: constants));
  ConstantReader(this._iter);

  /// Consumes and returns the unread data and standalone assembly continuation.
  /// See [ConstantIterator.remaining] for conditional-assembly handling.
  Asm get remaining {
    final result = _constantData(_queue);
    _queue.clear();
    result.add(_iter.remaining);
    return result;
  }

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

class DataIterable<T extends Sized> extends IterableBase<T> {
  final ConstantReader _reader;
  final T Function(ConstantReader) _readFunction;

  DataIterable(this._reader, this._readFunction);

  @override
  Iterator<T> get iterator => _DataIterator(_reader, _readFunction);
}

class _DataIterator<T extends Sized> implements Iterator<T> {
  final ConstantReader _reader;
  final T Function(ConstantReader) _readFunction;
  T? _current;

  _DataIterator(this._reader, this._readFunction);

  @override
  T get current => switch (_current) {
        null => throw StateError('iterator has not started or is finished'),
        var c => c
      };

  @override
  bool moveNext() {
    try {
      _current = _readFunction(_reader);
      return true;
    } catch (e) {
      _current = null;
      return false;
    }
  }
}

class ByteIterable extends DataIterable<Byte> {
  ByteIterable(ConstantReader reader) : super(reader, (r) => r.readByte());
}

/// Source-level splitting shared by all instruction operand grammars.
/// Commas inside quotes, addresses, or macro delimiters are not separators.
class _InstructionTail {
  final List<String> operands;
  final String? comment;

  _InstructionTail(this.operands, this.comment);

  factory _InstructionTail.parse(String source) {
    final operands = <String>[];
    String? quote;
    var escaped = false;
    var depth = 0;
    var start = 0;
    var end = source.length;
    for (var i = 0; i < source.length; i++) {
      final character = source[i];
      if (quote != null) {
        if (!escaped && character == quote) quote = null;
        escaped = !escaped && character == r'\';
      } else if (character == '"' || character == "'") {
        quote = character;
      } else if (character == ';') {
        end = i;
        break;
      } else if ('([{'.contains(character)) {
        depth++;
      } else if (')]}'.contains(character)) {
        // Delimiters in unsupported syntax remain the assembler's concern.
        if (depth > 0) depth--;
      } else if (character == ',' && depth == 0) {
        // Empty spans are arguments too; the consumer decides their validity.
        operands.add(source.substring(start, i).trim());
        start = i + 1;
      }
    }
    final last = source.substring(start, end).trim();
    if (last.isNotEmpty || operands.isNotEmpty) operands.add(last);
    return _InstructionTail(operands,
        end < source.length ? source.substring(end + 1).trimLeft() : null);
  }
}

/// Decodes dc operands without evaluating symbolic expressions. Literal sizing
/// and quoted-data encoding belong here, outside the scalar expression parser.
List<Expression> _parseDataOperands(List<String> sources, Size size) {
  List<Expression> expressions = [];
  for (final source in sources) {
    if (source.isEmpty) throw FormatException('empty dc operand');
    final string = _parseDataString(source);
    if (string != null) {
      if (expressions.isEmpty) {
        expressions = string;
      } else if (expressions is Bytes) {
        expressions += string;
      } else {
        expressions.addAll(string);
      }
      continue;
    }
    Expression expression;
    try {
      expression = Expression.parse(source);
    } on FormatException {
      // AS supports more syntax than our scalar grammar, including functions,
      // repetition, and anonymous labels. Preserve it for the assembler.
      expression = UnknownExpression(source);
    }
    if (expression is Value) expression = size.truncate(expression.value);
    if (expressions.isEmpty && expression is Byte) {
      expressions = Bytes.from([expression]);
    } else if (expressions is Bytes && expression is Byte) {
      expressions += [expression];
    } else {
      if (expressions is Bytes) expressions = List<Expression>.of(expressions);
      expressions.add(expression);
    }
  }
  return expressions;
}

Ascii? _parseDataString(String source) {
  final quote = source[0];
  if (quote != '"' && quote != "'") return null;
  var escaped = false;
  for (var i = 1; i < source.length; i++) {
    final character = source[i];
    if (!escaped && character == quote) {
      if (i != source.length - 1) return null;
      // TODO: this assumes each character represents a byte,
      // but this depends on the attribute of the dc instruction.
      return Bytes.ascii(source.substring(1, i));
    }
    escaped = !escaped && character == r'\';
  }
  return null;
}

/// Traverses selected instructions without interpreting their data or opcodes.
/// Keeping this cursor separate also lets remaining return code after dc data.
class _ConditionalInstructions implements Iterator<Instruction> {
  final Iterator<Instruction> _source;
  final Constants _constants;
  final List<_ConditionalFrame> _frames = [];
  Instruction? _current;
  int _lineNumber = 0;
  bool _done = false;

  static const _openers = {
    'if',
    'ifdef',
    'ifndef',
    'ifused',
    'ifnused',
    'ifexist',
    'ifnexist',
    'ifb',
    'ifnb',
  };

  _ConditionalInstructions(this._source, this._constants);

  /// Whether ordinary instructions at the current position should be emitted.
  /// The innermost frame includes its parent's activity; no frames means that
  /// the current source is unconditional.
  bool get _active => _frames.isEmpty || _frames.last.active;

  /// The instruction returned by the last successful [moveNext].
  /// Throws a [StateError] before that first success, after exhaustion, or after
  /// [takeRemaining] has been fully consumed.
  @override
  Instruction get current =>
      _current ?? (throw StateError('iterator has not started or is finished'));

  /// Advances to the next ordinary instruction in a selected branch.
  ///
  /// Consumes directives and updates their frames without yielding them.
  /// Excluded branches still have their nesting checked, but their conditions
  /// are not evaluated. Later alternatives after a match are also unevaluated.
  /// Returns false and clears [current] when the balanced source is exhausted.
  @override
  bool moveNext() {
    _current = null;
    if (_done) return false;
    while (_advance()) {
      final next = _source.current;
      if (!_directive(next) && _active) {
        _current = next;
        return true;
      }
    }
    return false;
  }

  /// Consumes the unread continuation as standalone assembly, excluding [current].
  ///
  /// Finishes the frames already open when enumeration begins, retaining their
  /// selected bodies and removing their control directives. New whole blocks
  /// within those bodies are copied or discarded as a unit, with their structure
  /// checked but their conditions unevaluated.
  ///
  /// Once the inherited frames close, yields all later source unchanged, leaving
  /// its conditional interpretation and validation to the assembler. Fully
  /// consuming this iterable marks the cursor finished and clears [current].
  Iterable<Instruction> takeRemaining() sync* {
    if (_done) return;
    while (_frames.isNotEmpty && _advance()) {
      final next = _source.current;
      if (_openers.contains(next.cmd?.toLowerCase())) {
        // New whole blocks require no symbol values. Copy or discard the
        // entire block according to the already-selected enclosing branch.
        final retain = _active;
        final depth = _frames.length;
        var line = next;
        do {
          // Regardless of whether the line is a directive,
          // push/pop the frame stack as needed,
          // until we're back top-level.
          _directive(line, evaluate: false);
          // If the current frame is active, yield the line
          if (retain) yield line;
          // Must have consumed opener and end; check the next line for opener
          if (_frames.length == depth) break;
          // Advance until end
          if (!_advance()) return;
          line = _source.current;
        } while (true);
      } else if (!_directive(next) && _active) {
        yield next;
      }
    }
    // All inherited context is closed. Future source belongs to the assembler.
    while (_source.moveNext()) {
      yield _source.current;
    }
    _done = true;
    _current = null;
  }

  /// Advances the raw source once and updates the one-based source line number.
  ///
  /// Does not interpret directives or change [current]. At end of source, throws
  /// a [FormatException] if a frame is still open; otherwise marks the cursor
  /// finished and returns false.
  bool _advance() {
    if (_source.moveNext()) {
      _lineNumber++;
      return true;
    }
    if (_frames.isNotEmpty) {
      final frame = _frames.last;
      throw FormatException('unterminated conditional from assembly line '
          '${frame.lineNumber}');
    }
    _done = true;
    return false;
  }

  /// Processes [line] as a conditional directive, returning whether it was one.
  ///
  /// Updates the frame stack and checks pairing, alternative order, and argument
  /// counts for supported directives. Ordinary instructions return false without
  /// changing the stack. The caller must already have advanced the source so
  /// diagnostics refer to [line]'s position.
  ///
  /// Conditions are tested only with an active parent and no earlier match.
  /// Setting [evaluate] to false suppresses those tests while retaining frame
  /// bookkeeping and structural validation, allowing whole blocks to be preserved.
  bool _directive(Instruction line, {bool evaluate = true}) {
    final name = line.cmd?.toLowerCase();
    if (_openers.contains(name)) {
      // Other openers are balanced without interpreting their argument grammar
      // in skipped or preserved blocks. Selecting one reports it as unsupported.
      if (const {'if', 'ifdef', 'ifndef'}.contains(name) &&
          line.operands.length != 1) {
        _invalid('expected one condition', line);
      }
      final parentActive = _active;
      final selected = evaluate && parentActive && _test(line);
      _frames.add(_ConditionalAlternatives(_lineNumber, parentActive,
          selected ? _Branch.selected : _Branch.unmatched));
      return true;
    }
    if (name == 'else' || name == 'elseif') {
      if (_frames.isEmpty) _invalid('unmatched $name', line);
      final frame = _frames.removeLast();
      if (frame is! _ConditionalAlternatives) {
        _invalid('$name after a default branch', line);
      }
      if (line.operands.isEmpty) {
        _frames.add(_ConditionalDefault(frame.lineNumber,
            frame.parentActive && frame.branch == _Branch.unmatched));
      } else {
        if (line.operands.length != 1) _invalid('expected one condition', line);
        final branch = frame.branch == _Branch.unmatched
            ? (evaluate && frame.parentActive && _test(line)
                ? _Branch.selected
                : _Branch.unmatched)
            : _Branch.matched;
        _frames.add(_ConditionalAlternatives(
            frame.lineNumber, frame.parentActive, branch));
      }
      return true;
    }
    if (name == 'endif') {
      if (line.operands.isNotEmpty) _invalid('endif takes no operands', line);
      if (_frames.isEmpty) _invalid('unmatched endif', line);
      _frames.removeLast();
      return true;
    }
    return false;
  }

  /// Evaluates one condition after [_directive] has checked its argument count.
  ///
  /// Definedness tests inspect symbol membership without resolving its value.
  /// Other supported conditions require a known integer, with zero meaning
  /// false. Unsupported directives throw [UnsupportedError]; unresolved values
  /// throw [StateError]. Scalar syntax errors can throw [FormatException].
  bool _test(Instruction line) {
    switch (line.cmd!.toLowerCase()) {
      case 'ifdef':
      case 'ifndef':
        final source = line.operands.single.toString();
        if (!Constant.isValidConstantName(source)) {
          _invalid('expected a symbol name', line);
        }
        final defined = _constants.containsConstantNamed(source);
        return line.cmd!.toLowerCase() == 'ifdef' ? defined : !defined;
      case 'if':
      case 'else':
      case 'elseif':
        final source = line.operands.single.toString();
        try {
          return Expression.parse(source)
                  .evaluate(EvaluationContext(_constants))
                  .requireInt() !=
              0;
        } on StateError catch (error) {
          throw StateError(
              'assembly line $_lineNumber: $line: ${error.message}');
        }
      default:
        throw UnsupportedError('unsupported conditional at assembly line '
            '$_lineNumber: $line');
    }
  }

  /// Reports [message] as a [FormatException] with the current line and its source.
  Never _invalid(String message, Instruction line) =>
      throw FormatException('$message at assembly line $_lineNumber', '$line');
}

/// Selection state of the current alternative in an if/elseif chain.
///
/// When evaluation is enabled and the parent is active, `if 0`, `elseif 1`,
/// `elseif unknown` produce [unmatched], [selected], and [matched], respectively.
/// The last condition is never evaluated.
/// Enclosing branch activity is tracked separately by
/// [_ConditionalAlternatives.parentActive]; defaults use [_ConditionalDefault].
enum _Branch {
  /// No alternative in this chain has been selected yet.
  ///
  /// A later elseif may still be selected, or the default may be taken. This
  /// state also applies when evaluation is suppressed by an inactive parent or
  /// while preserving a whole block, so it does not imply conditions were false.
  unmatched,

  /// This is the first alternative whose condition evaluated to true.
  ///
  /// Its body is active. Reaching a subsequent elseif changes the state to
  /// [matched], ending this body and preventing another alternative from running.
  selected,

  /// An earlier alternative was selected and its body has already been passed.
  ///
  /// The current and all later alternatives are skipped without evaluating
  /// their conditions, even if those conditions would also be true.
  matched,
}

sealed class _ConditionalFrame {
  final int lineNumber;

  _ConditionalFrame(this.lineNumber);

  bool get active;
}

final class _ConditionalAlternatives extends _ConditionalFrame {
  final bool parentActive;
  final _Branch branch;

  _ConditionalAlternatives(super.lineNumber, this.parentActive, this.branch);

  @override
  bool get active => parentActive && branch == _Branch.selected;
}

/// Entering the default removes the ability to accept further alternatives.
final class _ConditionalDefault extends _ConditionalFrame {
  @override
  final bool active;

  _ConditionalDefault(super.lineNumber, this.active);
}

Asm _constantData(Iterable<Sized> values) {
  final result = Asm.empty();
  final operands = <Expression>[];
  Size? size;
  for (final value in values) {
    if (size != null && size != value.size) {
      result.add(dc.size(size, operands.toList()));
      operands.clear();
    }
    size = value.size;
    operands.add(value);
  }
  if (size != null) result.add(dc.size(size, operands));
  return result;
}
