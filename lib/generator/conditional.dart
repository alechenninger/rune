import '../asm/asm.dart';
import '../model/model.dart';
import 'memory.dart';
import 'movement.dart';

extension IfValueAsm on IfValue {
  /// Set CCR based on subtracing comparing [op1] with [op2].
  ///
  /// Note that in this case, [op1] is the destination operand,
  /// and [op2] is the source operand.
  /// I.e. if we're checking if an x position is > some constant,
  /// the constant will be the source operand,
  /// and x position will be the the destination,
  /// as in `cmpi.w #constant, curr_x_pos(a4)`
  Asm compare({required Memory memory}) {
    Asm compareTo(Address src) {
      return switch (op1) {
        PositionComponentExpression c =>
          c.withValue(memory: memory, asm: (dst) => _cmp(src, dst, Size.w)),
        PositionExpression p => throw 'todo',
        DirectionExpression d => throw 'todo',
      };
    }

    return switch (op2) {
      PositionComponentExpression c =>
        c.withValue(memory: memory, asm: compareTo),
      PositionExpression p => throw 'todo',
      DirectionExpression d => throw 'todo',
    };
  }
}

Asm _cmp(Address src, Address dst, Size size, {DirectDataRegister dR = d0}) {
  var width = switch (size) {
    Size.b => (c) => c.b,
    Size.w => (c) => c.w,
    Size.l => (c) => c.l
  };

  if (src is Immediate) {
    return width(cmpi)(src, dst);
  }

  if (dst is Immediate) {
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
      {required Memory memory, required Asm Function(Address c) asm}) {
    return switch (this) {
      PositionComponent p => asm(Word(p.value).i),
      PositionComponentOfObject p => p.withValue(memory: memory, asm: asm)
    };
  }
}
