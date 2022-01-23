import 'package:rune/asm/asm.dart' show Asm;
import 'package:rune/asm/data.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/model/model.dart';

import 'dialog.dart';
import 'movement.dart';

export '../asm/asm.dart' show Asm;

class AsmGenerator {
  Asm dialogToAsm(Dialog dialog) {
    return dialog.toAsm();
  }

  Asm individualMovesToAsm(IndividualMoves move, EventContext ctx) {
    return move.toAsm(ctx);
  }

  Asm partyMoveToAsm(PartyMove move, EventContext ctx) {
    throw UnsupportedError('partyMoveToAsm');
  }

  Asm pauseToAsm(Pause pause) {
    // I think vertical interrupt is 60 times a second
    // but 50 in PAL
    // could use conditional pseudo-assembly if / else
    // see: http://john.ccac.rwth-aachen.de:8000/as/as_EN.html#sect_3_6_
    var frames = pause.duration.inSeconds * 60;
    return vIntPrepareLoop(Word(frames.toInt()));
  }
}
