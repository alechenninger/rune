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
    Asm compareTo(Address src) {
      var asm = Asm.empty();

      switch (operand1) {
        case PositionComponent c:
          asm.add(c.withValue(
              memory: memory, asm: (dst) => _cmp(src, dst, Size.w)));
          break;
        case PositionComponentOfObject c:
          if (src is AddressRegister) {
            asm.add(lea(Address.a(src.register).indirect, a3));
            src = src.withRegister(3);
          }

          asm.add(c.withValue(
              memory: memory, load: a4, asm: (dst) => _cmp(src, dst, Size.w)));

          break;
        case Slot s:
          asm.add(_cmp(src, s.offset.i, Size.b));
        case SlotOfCharacter s:
          asm.add(s.withValue(
              memory: memory, asm: (slot) => _cmp(src, slot, Size.b)));
        case PositionExpression p:
          throw 'todo';
        case DirectionExpression d:
          throw 'todo';
      }

      return asm;
    }

    return switch (operand2) {
      PositionComponentExpression c =>
        c.withValue(memory: memory, load: a4, asm: compareTo),
      Slot s => compareTo(s.offset.i),
      SlotOfCharacter s => s.withValue(memory: memory, asm: compareTo),
      PositionExpression p => throw 'todo',
      DirectionExpression d => throw 'todo',
    };
  }
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

extension PositionComponentExpressionAsm on PositionComponentExpression {
  Asm withValue(
      {required Memory memory,
      required Asm Function(Address c) asm,
      DirectAddressRegister load = a4}) {
    return switch (this) {
      PositionComponent p => asm(Word(p.value).i),
      PositionComponentOfObject p =>
        p.withValue(memory: memory, load: load, asm: asm)
    };
  }
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
