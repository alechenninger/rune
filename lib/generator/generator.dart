import 'package:rune/asm/data.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/map.dart';
import 'package:rune/model/model.dart';

import '../asm/asm.dart';
import 'dialog.dart';
import 'event.dart';
import 'movement.dart';
import 'scene.dart';

export '../asm/asm.dart' show Asm;

class AsmContext {
  final EventContext model;

  Mode mode = Mode.event;

  bool get inDialogLoop => mode == Mode.dialog;

  AsmContext.fresh({this.mode = Mode.event}) : model = EventContext();
  AsmContext.forDialog(this.model) : mode = Mode.dialog;
  AsmContext.forEvent(this.model) : mode = Mode.event;
}

enum Mode { dialog, event }

class AsmGenerator {
  Asm eventsToAsm(List<Event> events, AsmContext ctx) {
    if (events.isEmpty) {
      return Asm.empty();
    }

    return events.map((e) => e.generateAsm(this, ctx)).reduce((value, element) {
      value.add(element);
      return value;
    });
  }

  SceneAsm sceneToAsm(Scene scene) {
    return scene.toAsm();
  }

  MapAsm mapToAsm(GameMap map) {
    return mapToAsm(map);
  }

  DialogAsm dialogToAsm(Dialog dialog) {
    return dialog.toAsm();
  }

  EventAsm individualMovesToAsm(IndividualMoves move, AsmContext ctx) {
    return move.toAsm(ctx.model);
  }

  EventAsm partyMoveToAsm(PartyMove move, AsmContext ctx) {
    return individualMovesToAsm(move.toIndividualMoves(ctx.model), ctx);
  }

  EventAsm pauseToAsm(Pause pause) {
    // I think vertical interrupt is 60 times a second
    // but 50 in PAL
    // could use conditional pseudo-assembly if / else
    // see: http://john.ccac.rwth-aachen.de:8000/as/as_EN.html#sect_3_6_
    var frames = pause.duration.inSeconds * 60;
    return EventAsm.of(vIntPrepareLoop(Word(frames.toInt())));
  }

  EventAsm lockCameraToAsm(AsmContext ctx) {
    return EventAsm.of(lockCamera(ctx.model.cameraLock = true));
  }

  EventAsm unlockCameraToAsm(AsmContext ctx) {
    return EventAsm.of(lockCamera(ctx.model.cameraLock = false));
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
