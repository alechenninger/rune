import 'data.dart';

export 'data.dart';

/// Data constant
const Dc dc = Dc();
const Move move = Move();

Asm lea(Address src, Address dst) => cmd('lea', [src, dst]);

// It looks like this should be limited to 32 bytes per line
class Dc {
  const Dc();

  Asm b(Bytes d) => cmd('dc.b', [d]);
  Asm w(Words d) => cmd('dc.w', [d]);
  Asm l(Longwords d) => cmd('dc.l', [d]);
}

class Move {
  const Move();

  Asm b(from, to) => cmd('move.b', [from, to]);
  Asm w(from, to) => cmd('move.w', [from, to]);
  Asm l(from, to) => cmd('move.l', [from, to]);
}

class AsmError extends ArgumentError {
  AsmError(dynamic value, String message) : super.value(value, message);
}

class Asm {
  final List<String> lines = [];

  Asm.empty();

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
  static Absolute absolute(Value v) => Absolute.longword(v);
  static Immediate<T> immediate<T extends Value<T>>(T v) => Immediate<T>(v);
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
  final String value;
  final String size;
  Absolute._({required this.value, required this.size}) : super('$value.$size');
  Absolute.word(Value v) : this._(value: v.hex, size: 'w');
  Absolute.longword(Value v) : this._(value: v.hex, size: 'l');
  Absolute.constant(String c) : this._(value: c, size: 'w');
  Absolute.constantLongword(String c) : this._(value: c, size: 'l');

  Absolute get w => size == 'w' ? this : Absolute._(value: value, size: 'w');
  Absolute get l => size == 'l' ? this : Absolute._(value: value, size: 'l');
}

class Immediate<T extends Value<T>> extends _Address {
  Immediate(T value) : super('#${value.hex}');
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
  final int fixedOffset; // TODO: need to allow constant here
  final DirectDataRegister? variableOffset;

  IndirectAddressRegister(this.register,
      {this.fixedOffset = 0, this.variableOffset})
      : super([
          '(',
          if (fixedOffset > 0) fixedOffset,
          'A$register',
          if (variableOffset != null) variableOffset,
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

Asm cmd(String cmd, List args, {String? label}) {
  return Asm.fromLine(
      [if (label == null) '' else '$label:', cmd, args.join(', ')].join('	'));
}
