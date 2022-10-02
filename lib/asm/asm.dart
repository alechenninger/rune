import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'address.dart';
import 'data.dart';

export 'address.dart';
export 'data.dart';

/// Data constant
const DcMnemonic dc = DcMnemonic();
const MoveMnemonic move = MoveMnemonic();
const MoveaMnemonic movea = MoveaMnemonic();
const ClrMnemonic clr = ClrMnemonic();
const AndiMnemonic andi = AndiMnemonic();
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
const AddiMnemonic addi = AddiMnemonic();
const SubiMnemonic subi = SubiMnemonic();
const CmpiMnemonic cmpi = CmpiMnemonic();
const TstMnemonic tst = TstMnemonic();

final rts = cmd('rts', []);

Asm newLine() => Asm.fromInstruction(_Instruction());
Asm comment(String comment) => Asm.fromInstructions(LineSplitter()
    .convert(comment)
    .map((e) => _Instruction(comment: comment))
    .toList(growable: false));

Asm lea(Address src, Address dst) => cmd('lea', [src, dst]);
Asm moveq(Address src, Address dst) => cmd('moveq', [src, dst]);
Asm jsr(Address to) => cmd('jsr', [to]);
Asm jmp(Address to) => cmd('jmp', [to]);
Asm bset(Address src, Address dst) => cmd('bset', [src, dst]);
Asm bclr(Address src, Address dst) => cmd('bclr', [src, dst]);
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

class ClrMnemonic {
  const ClrMnemonic();
  //clr.b	(Render_Sprites_In_Cutscenes).w
  Asm b(Address dst) => cmd('clr.b', [dst]);
  Asm w(Address dst) => cmd('clr.w', [dst]);
}

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

  Asm s(Address to) => cmd('$_branch.s', [to]);
  Asm w(Address to) => cmd('$_branch.w', [to]);
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

class DivuMnemonic {
  const DivuMnemonic();

  Asm w(Address from, Address to) => cmd('divu.w', [from, to]);
  Asm l(Address from, Address to) => cmd('divu.l', [from, to]);
}

class CmpiMnemonic {
  const CmpiMnemonic();

  Asm b(Address from, Address to) => cmd('cmpi.b', [from, to]);
  Asm w(Address from, Address to) => cmd('cmpi.w', [from, to]);
  Asm l(Address from, Address to) => cmd('cmpi.l', [from, to]);
}

class AsmError extends ArgumentError {
  AsmError(dynamic value, String message) : super.value(value, message);
}

class Asm extends IterableBase<Instruction> {
  final List<Instruction> lines = [];

  Asm.empty();

  Asm(List<Asm> asm) {
    asm.forEach(add);
  }

  Asm.fromInstruction(Instruction line) {
    addLine(line);
  }

  Asm.fromInstructions(List<Instruction> lines) {
    lines.forEach(addLine);
  }

  Asm.fromRaw(String raw) {
    LineSplitter.split(raw).map((e) => _RawInstruction(e)).forEach(addLine);
  }

  Asm withoutComments() => Asm.fromInstructions(lines.expand((line) {
        var stringed = line.toString();
        var withoutComment =
            stringed.replaceFirst(RegExp(';.*'), '').trimRight();
        if (withoutComment.trimLeft().isEmpty &&
            stringed.trimLeft().isNotEmpty) {
          return <Instruction>[];
        }
        return [_RawInstruction(withoutComment)];
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

  Asm tail(int lines) {
    lines = min(lines, length);
    return Asm.fromInstructions(this.lines.sublist(length - lines));
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
}

Asm setLabel(String label) {
  return Asm.fromInstruction(_Instruction(label: label));
}

Asm cmd(String cmd, List operands, {String? label, String? comment}) {
  return Asm.fromInstruction(_Instruction(
      label: label, cmd: cmd, operands: operands, comment: comment));
}

abstract class Instruction {
  Asm toAsm() {
    return Asm.fromInstruction(this);
  }

  bool get isEmpty => toString().isEmpty;
  bool get isNotEmpty => toString().isNotEmpty;

  @override
  String toString();

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

class _RawInstruction extends Instruction {
  final String _instruction;

  _RawInstruction(this._instruction);

  @override
  String toString() {
    return _instruction;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Instruction && _instruction == other.toString();

  @override
  int get hashCode => super.hashCode ^ _instruction.hashCode;
}

class _Instruction extends Instruction {
  final String? label;
  final String? cmd;
  final List operands;
  final String? comment;

  final String line;

  static final _validLabelPattern = RegExp(r'^[A-Za-z\d_@.+-]+[A-Za-z\d_+-]*$');

  _Instruction({this.label, this.cmd, this.operands = const [], this.comment})
      : line = [
          if (label == null) '' else '$label:',
          if (cmd != null) cmd,
          if (operands.isNotEmpty)
            if (operands is Data) operands else operands.join(', '),
          if (comment != null) '; $comment'
        ].join('\t') {
    if (line.length > 255) {
      throw ArgumentError(
          'Instructions cannot be longer than 255 characters but was: $line');
    }

    var l = label;
    if (l != null && !_validLabelPattern.hasMatch(l)) {
      throw ArgumentError.value(label, 'label',
          'did not match allowed characters: $_validLabelPattern');
    }
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
