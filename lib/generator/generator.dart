import 'package:rune/asm/asm.dart' show Asm;
import 'package:rune/model/model.dart';

import 'dialog.dart';
import 'movement.dart';

export '../asm/asm.dart' show Asm;

class AsmGenerator {
  Asm dialogToAsm(Dialog dialog) {
    return dialog.toAsm();
  }

  Asm moveToAsm(Move move, EventContext ctx) {
    return move.toAsm(ctx);
  }
}
