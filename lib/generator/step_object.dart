import 'labels.dart';
import 'memory.dart';
import 'movement.dart';

import '../asm/asm.dart';
import '../asm/events.dart';
import '../model/model.dart';

Asm stepObjectToAsm(StepObject step,
    {required Memory memory, required Labeller labeller}) {
  /// Current x and y positions in memory are stored
  /// as a longword with fractional component.
  /// The higher order word is the position,
  /// but the lower order word can be used as a fractional part.
  /// This allows moving a pixel to take longer than one frame
  /// in the step objects loop,
  /// since the pixel is only read from the higher order word.
  /// This converts the double x and y positions
  /// to their longword counterparts.
  if (step.stepPerFrame.known(memory) case var stepPerFrame?) {
    var current = memory.positions[step.object];
    if (current != null) {
      var totalSteps = (stepPerFrame * step.frames).truncate();
      memory.positions[step.object] = current + Position.fromPoint(totalSteps);
    }
  } else {
    memory.positions[step.object] = null;
  }

  // Step will always execute at least once.
  var additionalFrames = step.frames - 1;

  return step.stepPerFrame.withVector(
      memory: memory,
      labeller: labeller,
      asm: (x, y) => Asm([
            step.object.toA4(memory),
            if (step.onTop) move.b(1.i, 5(a4)),
            switch (x) {
              d0 => Asm.empty(),
              // Use unsigned because we expect
              // the value is already encoded as signed
              Immediate x => unsignedMoveL(x, d0),
              var x => move.l(x, d0),
            },
            switch (y) {
              d1 => Asm.empty(),
              // Use unsigned because we expect
              // the value is already encoded as signed
              Immediate y => unsignedMoveL(y, d1),
              var y => move.l(y, d1),
            },
            if (additionalFrames <= 127)
              moveq(additionalFrames.toByte.i, d2)
            else
              move.w(additionalFrames.toWord.i, d2),
            if (step.animate)
              jsr(Label('Event_StepObject').l)
            else
              jsr(Label('Event_StepObjectNoAnimate').l),
            if (step.onTop) clr.b(5(a4)),
            move.w(curr_x_pos(a4), dest_x_pos(a4)),
            move.w(curr_y_pos(a4), dest_y_pos(a4)),
          ]));
}
