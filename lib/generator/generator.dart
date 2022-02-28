import 'package:rune/asm/asm.dart' show Asm;
import 'package:rune/asm/data.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/model/model.dart';

import 'dialog.dart';
import 'movement.dart';
import 'scene.dart';

export '../asm/asm.dart' show Asm;

class AsmGenerator {
  SceneAsm sceneToAsm(Scene scene) {
    return scene.toAsm();
  }

  Asm dialogToAsm(Dialog dialog) {
    return dialog.toAsm();
  }

  Asm individualMovesToAsm(IndividualMoves move, EventContext ctx) {
    return move.toAsm(ctx);
  }

  Asm partyMoveToAsm(PartyMove move, EventContext ctx) {
    return individualMovesToAsm(move.toIndividualMoves(ctx), ctx);
  }

  Asm pauseToAsm(Pause pause) {
    // I think vertical interrupt is 60 times a second
    // but 50 in PAL
    // could use conditional pseudo-assembly if / else
    // see: http://john.ccac.rwth-aachen.de:8000/as/as_EN.html#sect_3_6_
    var frames = pause.duration.inSeconds * 60;
    return vIntPrepareLoop(Word(frames.toInt()));
  }

  Asm lockCameraToAsm(EventContext ctx) {
    return lockCamera(ctx.cameraLock = true);
  }

  Asm unlockCameraToAsm(EventContext ctx) {
    return lockCamera(ctx.cameraLock = false);
  }
}

/*
walking speed?

2 units per frame
16 units per step
60 frames per second

what is steps per second?

1 / 8 steps per frame
8 frames per step
60 / 8 step per second (7.5)

 */
