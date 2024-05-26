import '../asm/asm.dart';
import '../asm/events.dart';
import '../model/model.dart';
import 'memory.dart';
import 'movement.dart';

extension IfValueAsm on IfValue {
  /// Set CCR based on subtracing comparing [operand1] with [operand2].
  ///
  /// Note that in this case, [operand1] is the destination operand,
  /// and [operand2] is the source operand.
  /// I.e. if we're checking if an x position is > some constant,
  /// the constant will be the source operand,
  /// and x position will be the the destination,
  /// as in `cmpi.w #constant, curr_x_pos(a4)`
  Asm compare({required Memory memory}) {
    var compareTo = _compare(operand1, memory);
    // Compare operand2 to operand1
    return switch (operand2) {
      PositionComponentExpression c =>
        c.withValue(memory: memory, load: a4, asm: compareTo),
      // TODO: Handle this case.
      NotInParty() => compareTo(0xFF.i),
      Slot s => compareTo(s.offset.i),
      SlotOfCharacter s => s.withValue(memory: memory, asm: compareTo),
      IsOffScreen o => o.withValue(memory: memory, asm: compareTo),
      BooleanConstant b => b.withValue(memory: memory, asm: compareTo),
      PositionExpression p => throw 'todo',
      DirectionExpression d => throw 'todo',
    };
  }
}

Asm Function(Address src) _compare(ModelExpression operand1, Memory memory) {
  // Compares [src] with [operand1] and sets the CCR.
  // Called below.
  return (Address src) {
    var asm = Asm.empty();

    switch (operand1) {
      case PositionComponent c:
        asm.add(
            c.withValue(memory: memory, asm: (dst) => _cmp(src, dst, Size.w)));
        break;
      case PositionComponentOfObject c:
        if (src is AddressRegister) {
          asm.add(lea(Address.a(src.register).indirect, a3));
          src = src.withRegister(3);
        }

        asm.add(c.withValue(
            memory: memory, load: a4, asm: (dst) => _cmp(src, dst, Size.w)));

        break;
      case NotInParty():
        asm.add(_cmp(src, 0xFF.i, Size.b));
      case Slot s:
        asm.add(_cmp(src, s.offset.i, Size.b));
        break;
      case SlotOfCharacter s:
        asm.add(s.withValue(
            memory: memory, asm: (slot) => _cmp(src, slot, Size.b)));
        break;
      case IsOffScreen o:
        asm.add(o.withValue(
            memory: memory, asm: (value) => _cmp(src, value, Size.b)));
        break;
      case BooleanConstant b:
        asm.add(b.withValue(
            memory: memory, asm: (value) => _cmp(src, value, Size.b)));
        break;
      case PositionExpression p:
        throw 'todo';
      case DirectionExpression d:
        throw 'todo';
    }

    return asm;
  };
}

Asm _cmp(Address src, Address dst, Size size, {DirectDataRegister dR = d0}) {
  var width = switch (size) {
    byte => (c) => c.b,
    word => (c) => c.w,
    long => (c) => c.l
  };

  if (src is Immediate) {
    return width(cmpi)(src, dst);
  }

  if (dst is DirectDataRegister) {
    return width(cmp)(src, dst);
  }

  return Asm([
    width(move)(dst, dR),
    width(cmp)(src, dR),
  ]);
}

extension BranchConditionAsm on BranchCondition {
  BranchMnemonic get mnemonicUnsigned => switch (this) {
        eq => beq,
        gt => bhi,
        lt => bcs,
        neq => bne,
        gte => bcc,
        lte => bls
      };
}

extension SlotOfCharacterExpressionAsm on SlotOfCharacter {
  Asm withValue(
      {required Memory memory, required Asm Function(Address slot) asm}) {
    return Asm([
      moveq(character.charIdAddress, d0),
      jsr(FindCharacterSlot.l),
      asm(d1)
    ]);
  }
}

extension OffScreenExpressionAsm on IsOffScreen {
  Asm withValue(
      {required Memory memory,
      required Asm Function(Address value) asm,
      DirectAddressRegister load = a4}) {
    return Asm([
      object.toA(load, memory),
      asm(offscreen_flag(load)),
    ]);
  }
}

extension BooleanConstantAsm on BooleanConstant {
  Asm withValue(
      {required Memory memory, required Asm Function(Address value) asm}) {
    return asm(value ? 1.i : 0.i);
  }
}
