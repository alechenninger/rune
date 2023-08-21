import '../asm/asm.dart';
import '../model/model.dart';
import 'memory.dart';

extension BooleanExpressionAsm on BooleanExpression {
  // Asm setCCR({required Memory memory});
}

extension ComparisonExpressionAsm on Comparison {
  // Asm branch({required Memory memory, Asm ifTrue = const Asm.none(), Asm ifFalse = const Asm.none()}) {

  // }
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
