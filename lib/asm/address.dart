import 'asm.dart';

DirectDataRegister d(int register) => Address.d(register);
DirectAddressRegister a(int register) => Address.a(register);

const d0 = DirectDataRegister._(0);
const d1 = DirectDataRegister._(1);
const d2 = DirectDataRegister._(2);
const d3 = DirectDataRegister._(3);
const d4 = DirectDataRegister._(4);
const d5 = DirectDataRegister._(5);
const d6 = DirectDataRegister._(6);
const d7 = DirectDataRegister._(7);

const a0 = DirectAddressRegister._(0);
const a1 = DirectAddressRegister._(1);
const a2 = DirectAddressRegister._(2);
const a3 = DirectAddressRegister._(3);
const a4 = DirectAddressRegister._(4);
const a5 = DirectAddressRegister._(5);
const a6 = DirectAddressRegister._(6);
const a7 = DirectAddressRegister._(7);

abstract class Address {
  static Absolute absolute(Expression e) => Absolute.long(e);
  static Immediate immediate(Expression e) => Immediate(e);
  static DirectDataRegister d(int num) => DirectDataRegister(num);
  static DirectAddressRegister a(int num) => DirectAddressRegister(num);
}

class _Address implements Address {
  final String _string;

  const _Address(this._string);

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
  const Absolute._({required this.exp, required this.size})
      : super('$exp.$size');
  const Absolute.word(Expression e) : this._(exp: e, size: word);
  const Absolute.long(Expression e) : this._(exp: e, size: long);

  Absolute get w => size.isW ? this : Absolute._(exp: exp, size: word);
  Absolute get l => size.isL ? this : Absolute._(exp: exp, size: long);
}

class Immediate extends _Address {
  const Immediate(Expression e) : super('#$e');
}

class DirectAddressRegister extends _Address {
  final int register;

  DirectAddressRegister(this.register) : super('A$register') {
    if (register > 7 || register < 0) {
      throw AsmError(register, 'is not a valid address register');
    }
  }

  const DirectAddressRegister._(this.register) : super('A$register');

  IndirectAddressRegister get indirect => IndirectAddressRegister(register);
}

class DirectDataRegister extends _Address {
  DirectDataRegister(int num) : super('D$num') {
    if (num > 7 || num < 0) throw AsmError(num, 'is not a valid data register');
  }

  const DirectDataRegister._(int num) : super('D$num');
}

class IndirectAddressRegister extends _Address {
  final int register;
  final Expression displacement;
  final DirectDataRegister? variableDisplacement;

  IndirectAddressRegister(this.register,
      {this.displacement = Byte.zero, this.variableDisplacement})
      : super('(${[
          if (displacement.isNotZero) displacement,
          'A$register',
          if (variableDisplacement != null) variableDisplacement,
        ].join(',')})') {
    if (register > 7 || register < 0) {
      throw AsmError(register, 'is not a valid address register');
    }
  }

  IndirectAddressRegister plus(Expression exp) =>
      IndirectAddressRegister(register,
          displacement: exp, variableDisplacement: variableDisplacement);

  IndirectAddressRegister plusD(int dataRegister) =>
      IndirectAddressRegister(register,
          displacement: displacement,
          variableDisplacement: DirectDataRegister(dataRegister));
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
