import 'dart:collection';

import 'package:quiver/collection.dart';

import 'asm.dart';

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
const sp = a7;

abstract class Address implements RegisterListOrAddress {
  static Absolute absolute(Expression e) => Absolute.long(e);
  static Immediate immediate(Expression e) => Immediate(e);
  static DirectDataRegister d(int num) => DirectDataRegister(num);
  static DirectAddressRegister a(int num) => DirectAddressRegister(num);
}

sealed class RegisterListOrAddress {}

class RegisterList extends Iterable<Register> implements RegisterListOrAddress {
  final Set<Register> _registers;

  const RegisterList.empty() : _registers = const {};

  RegisterList.of(Iterable<Register> registers)
      : _registers = TreeSet<Register>(comparator: (a, b) {
          return switch ((a, b)) {
            (DirectDataRegister(), DirectAddressRegister()) => -1,
            (DirectAddressRegister(), DirectDataRegister()) => 1,
            _ => a.register.compareTo(b.register),
          };
        }) {
    _registers.addAll(registers);
  }

  @override
  bool get isNotEmpty => _registers.isNotEmpty;
  @override
  bool get isEmpty => _registers.isEmpty;
  @override
  int get length => _registers.length;

  /// Returns the [RegisterList] as an expression.
  ///
  /// Consecutive registers are delimited by the first and last with a "-"
  /// between.
  ///
  /// Otherwise, registers are enumerated with a "/" between.
  @override
  String toString() {
    var output = StringBuffer();
    Register previous = _registers.first;
    bool range = false;

    output.write(previous);

    for (Register r in _registers.skip(1)) {
      if (previous.next == r) {
        range = true;
      } else {
        if (range) {
          output.write('-$previous');
          range = false;
        }
        output.write('/');
        output.write(r);
      }
      previous = r;
    }

    if (range) {
      output.write('-$previous');
    }

    return output.toString();
  }

  @override
  Iterator<Register> get iterator => _registers.iterator;
}

sealed class Register<T extends Register<T>> implements Address {
  int get register;
  T? get next;
  RegisterList operator -(T other);
  RegisterList operator /(Register other);
}

abstract class AddressRegister implements Address {
  int get register;
  AddressRegister withRegister(int num);
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

/// Value at a fixed memory address
class Absolute extends _Address {
  final Expression exp;
  final Size size;
  Absolute._({required this.exp, required this.size})
      : super('${exp.withParenthesis()}.$size');
  Absolute.word(Expression e) : this._(exp: e, size: word);
  Absolute.long(Expression e) : this._(exp: e, size: long);

  Absolute get w => size.isW ? this : Absolute._(exp: exp, size: word);
  Absolute get l => size.isL ? this : Absolute._(exp: exp, size: long);
}

extension ToAbsolute on int {
  Absolute get w => Absolute.word(toValue);
  Absolute get l => Absolute.long(toValue);
}

/// A fixed value
class Immediate extends _Address {
  const Immediate(Expression e) : super('#$e');

  int get value {
    var e = toString().substring(1);
    if (e.startsWith(r'$')) return int.parse(e.substring(1), radix: 16);
    return int.parse(e);
  }
}

/// Value in one of the address registers
class DirectAddressRegister extends _Address
    implements AddressRegister, Register<DirectAddressRegister> {
  @override
  final int register;

  DirectAddressRegister(this.register) : super('a$register') {
    if (register > 7 || register < 0) {
      throw AsmError(register, 'is not a valid address register');
    }
  }

  @override
  DirectAddressRegister withRegister(int register) =>
      DirectAddressRegister(register);

  const DirectAddressRegister._(this.register) : super('a$register');

  IndirectAddressRegister plus(Expression exp) => indirect.plus(exp);

  IndirectAddressRegister plusD(int dataRegister) =>
      indirect.plusD(dataRegister);

  IndirectAddressRegister get indirect => IndirectAddressRegister(register);

  PreDecAddress operator -() => PreDecAddress(register);

  PostIncAddress postIncrement() => PostIncAddress(register);

  @override
  RegisterList operator -(DirectAddressRegister other) {
    return RegisterList.of([
      for (var i = register; i <= other.register; i++) DirectAddressRegister(i)
    ]);
  }

  @override
  RegisterList operator /(Register other) {
    return RegisterList.of([this, other]);
  }

  @override
  DirectAddressRegister get next => DirectAddressRegister(register + 1);
}

/// Value in one of the data registers
class DirectDataRegister extends _Address
    implements Register<DirectDataRegister> {
  DirectDataRegister(this.register) : super('d$register') {
    if (register > 7 || register < 0) {
      throw AsmError(register, 'is not a valid data register');
    }
  }

  const DirectDataRegister._(this.register) : super('d$register');

  @override
  final int register;

  @override
  RegisterList operator -(Register other) {
    var (maxDataRegister, maxAddressRegister) = switch (other) {
      DirectDataRegister() => (other.register, 0),
      DirectAddressRegister() => (7, other.register),
    };
    return RegisterList.of([
      for (var i = register; i <= maxDataRegister; i++) DirectDataRegister(i),
      for (var i = 0; i <= maxAddressRegister; i++) DirectAddressRegister(i)
    ]);
  }

  @override
  RegisterList operator /(Register other) {
    return RegisterList.of([this, other]);
  }

  @override
  DirectDataRegister? get next =>
      register <= 7 ? DirectDataRegister(register + 1) : null;
}

/// Value in memory at an address pointed to by an address register
class IndirectAddressRegister extends _Address implements AddressRegister {
  @override
  final int register;
  final Expression displacement;
  final DirectDataRegister? variableDisplacement;

  IndirectAddressRegister(this.register,
      {this.displacement = Byte.zero, this.variableDisplacement})
      : super('(${[
          if (displacement.isNotKnownZero) displacement,
          'A$register',
          if (variableDisplacement != null) variableDisplacement,
        ].join(',')})') {
    if (register > 7 || register < 0) {
      throw AsmError(register, 'is not a valid address register');
    }
  }

  @override
  IndirectAddressRegister withRegister(int register) =>
      IndirectAddressRegister(register,
          displacement: displacement,
          variableDisplacement: variableDisplacement);

  IndirectAddressRegister plus(Expression exp) =>
      IndirectAddressRegister(register,
          displacement: exp, variableDisplacement: variableDisplacement);

  IndirectAddressRegister plusD(int dataRegister) =>
      IndirectAddressRegister(register,
          displacement: displacement,
          variableDisplacement: DirectDataRegister(dataRegister));
}

extension ExpressionDisplacement on Expression {
  IndirectAddressRegister call(DirectAddressRegister a) =>
      a.indirect.plus(this);
}

extension IntDisplacement on int {
  IndirectAddressRegister call(DirectAddressRegister a) =>
      a.indirect.plus(toValue);
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
