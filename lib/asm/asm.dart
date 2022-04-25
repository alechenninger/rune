import 'dart:collection';
import 'dart:convert';

import 'address.dart';
import 'data.dart';

export 'address.dart';
export 'data.dart';

/// Data constant
const DcMnemonic dc = DcMnemonic();
const MoveMnemonic move = MoveMnemonic();
const ClrMnemonic clr = ClrMnemonic();

Asm comment(String comment) => _Instruction(comment: comment).toAsm();

Asm lea(Address src, Address dst) => cmd('lea', [src, dst]);
Asm moveq(Address src, Address dst) => cmd('moveq', [src, dst]);
Asm jsr(Address to) => cmd('jsr', [to]);
Asm bset(Address src, Address dst) => cmd('bset', [src, dst]);
Asm bclr(Address src, Address dst) => cmd('bclr', [src, dst]);

// It looks like this should be limited to 32 bytes per line
class DcMnemonic {
  const DcMnemonic();

  Asm b(List<Expression> c) => cmd('dc.b', c);
  Asm w(List<Expression> c) => cmd('dc.w', c);
  Asm l(List<Expression> c) => cmd('dc.l', c);
}

class MoveMnemonic {
  const MoveMnemonic();

  Asm b(Address from, Address to) => cmd('move.b', [from, to]);
  Asm w(Address from, Address to) => cmd('move.w', [from, to]);
  Asm l(Address from, Address to) => cmd('move.l', [from, to]);
}

class ClrMnemonic {
  const ClrMnemonic();
  //clr.b	(Render_Sprites_In_Cutscenes).w
  Asm b(Address dst) => cmd('clr.b', [dst]);
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

  /// returns position in list in which asm was added.
  int add(Asm asm) {
    // TODO: max length
    lines.addAll(asm.lines);
    return lines.length - asm.length;
  }

  void replace(int index, Asm asm) {
    lines.removeRange(index, index + asm.length);
    lines.insertAll(index, asm.lines);
  }

  void addLine(Instruction line) {
    lines.add(line);
  }

  void addNewline() {
    lines.add(_Instruction());
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

Asm cmd(String cmd, List operands, {String? label}) {
  return Asm.fromInstruction(
      _Instruction(label: label, cmd: cmd, operands: operands));
}

abstract class Instruction {
  Asm toAsm() {
    return Asm.fromInstruction(this);
  }

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
      other is _RawInstruction &&
          runtimeType == other.runtimeType &&
          _instruction == other._instruction;

  @override
  int get hashCode => super.hashCode ^ _instruction.hashCode;
}

class _Instruction extends Instruction {
  final String? label;
  final String? cmd;
  final List operands;
  final String? comment;

  final String line;

  _Instruction({this.label, this.cmd, this.operands = const [], this.comment})
      : line = [
          if (label == null) '' else '$label:',
          if (cmd != null) cmd,
          if (operands.isNotEmpty)
            if (operands is Data) operands else operands.join(', '),
          if (comment != null) '; $comment'
        ].join('\t') {
    if (line.length > 255) {
      throw StateError(
          'Instructions cannot be longer than 255 characters but was: $line');
    }
  }

  @override
  String toString() {
    return line;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _Instruction && line == other.line;

  @override
  int get hashCode => line.hashCode;
}
