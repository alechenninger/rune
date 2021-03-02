import 'data.dart';

export 'data.dart';

/// Data constant
const Dc dc = Dc();
const Move move = Move();

Asm lea(Address src, Address dst) => cmd('lea', [src, dst]);
Asm moveq(Address src, Address dst) => cmd('moveq', [src, dst]);
Asm jsr(Address to) => cmd('jsr', [to]);

// It looks like this should be limited to 32 bytes per line
class Dc {
  const Dc();

  Asm b(Bytes d) => cmd('dc.b', [d]);
  Asm w(Words d) => cmd('dc.w', [d]);
  Asm l(Longwords d) => cmd('dc.l', [d]);
}

class Move {
  const Move();

  Asm b(Address from, Address to) => cmd('move.b', [from, to]);
  Asm w(Address from, Address to) => cmd('move.w', [from, to]);
  Asm l(Address from, Address to) => cmd('move.l', [from, to]);
}

class AsmError extends ArgumentError {
  AsmError(dynamic value, String message) : super.value(value, message);
}

class Asm {
  final List<String> lines = [];

  Asm.empty();

  Asm(List<Asm> asm) {
    asm.forEach((a) => add(a));
  }

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

abstract class Address {
  static Absolute absolute(Expression e) => Absolute.longword(e);
  static Immediate immediate(Expression e) => Immediate(e);
  static DirectDataRegister d(int num) => DirectDataRegister(num);
}

class _Address implements Address {
  final String _string;

  _Address(this._string);

  @override
  String toString() => _string;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Address &&
          runtimeType == other.runtimeType &&
          _string == other._string;

  @override
  int get hashCode => _string.hashCode;
}

class Absolute extends _Address {
  final Expression exp;
  final Size size;
  Absolute._({required this.exp, required this.size}) : super('$exp.$size');
  Absolute.word(Expression e) : this._(exp: e, size: word);
  Absolute.longword(Expression e) : this._(exp: e, size: long);

  Absolute get w => size.isW ? this : Absolute._(exp: exp, size: word);
  Absolute get l => size.isL ? this : Absolute._(exp: exp, size: long);
}

class Immediate extends _Address {
  Immediate(Expression e) : super('#$e');
}

class DirectAddressRegister extends _Address {
  DirectAddressRegister(int num) : super('A$num') {
    if (num > 7 || num < 0) {
      throw AsmError(num, 'is not a valid address register');
    }
  }
}

class DirectDataRegister extends _Address {
  DirectDataRegister(int num) : super('D$num') {
    if (num > 7 || num < 0) throw AsmError(num, 'is not a valid data register');
  }
}

class IndirectAddressRegister extends _Address {
  final int register;
  final Expression displacement;
  final DirectDataRegister? variableDisplacement;

  IndirectAddressRegister(this.register,
      {this.displacement = Byte.zero, this.variableDisplacement})
      : super([
          '(',
          if (displacement.isNotZero) displacement,
          'A$register',
          if (variableDisplacement != null) variableDisplacement,
          ')',
        ].join()) {
    if (register > 7 || register < 0) {
      throw AsmError(register, 'is not a valid address register');
    }
  }
}

class PostIncAddress extends _Address {
  final int register;
  PostIncAddress(this.register) : super('(A$register)+') {
    if (register > 7 || register < 0) {
      throw AsmError(register, 'is not a valid address register');
    }
  }
}

class PreDecAddress extends _Address {
  final int register;
  PreDecAddress(this.register) : super('-(A$register)') {
    if (register > 7 || register < 0) {
      throw AsmError(register, 'is not a valid address register');
    }
  }
}

Asm setLabel(String label) {
  return Asm.fromLine('$label:');
}

Asm cmd(String cmd, List operands, {String? label}) {
  return Asm.fromLine([
    if (label == null) '' else '$label:',
    cmd,
    operands.join(', ')
  ].join('	'));
}
