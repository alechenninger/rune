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
      destinationX: d0,
      destinationY: d1,
      asm: (x, y) => Asm([
            step.object.toA4(memory),
            if (step.onTop) bset(0.i, priority_flag(a4)),
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
            if (step.onTop) bclr(0.i, priority_flag(a4)),
            move.w(curr_x_pos(a4), dest_x_pos(a4)),
            move.w(curr_y_pos(a4), dest_y_pos(a4)),
          ]));
}

Asm stepObjectsToAsm(StepObjects step,
    {required Memory memory, required Labeller labeller}) {
  if (step.objects.length == 1) {
    return stepObjectToAsm(
        StepObject(step.objects.single,
            stepPerFrame: step.stepPerFrame,
            frames: step.frames,
            onTop: step.onTop,
            animate: step.animate),
        memory: memory,
        labeller: labeller);
  }

  // Step will always execute at least once.
  var asm = Asm.empty();

  var additionalFrames = step.frames - 1;
  var loop = labeller.withContext('stepobjectsloop').nextLocal();

  // Load steps and duration
  // These will be reused for all objects,
  // which we'll move one frame at a time.
  asm.add(step.stepPerFrame.withVector(
      memory: memory,
      labeller: labeller,
      destinationX: d0,
      destinationY: d1,
      asm: (x, y) => Asm([
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
            // Push d0 and d1 to stack
            movem.l(d0 - d1, -(sp)),

            // Mark beginning of loop which will run for each frame
            label(loop)
          ])));

  // Now set the step for each object, for just one frame
  for (var obj in step.objects) {
    // For each char
    // Load character
    asm.add(Asm([
      obj.toA4(memory, force: true),
      if (step.onTop) bset(0.i, priority_flag(a4)),
      // Grab d0 and d1 from stack but leave the stack pointer there
      move.l(sp.indirect, d1),
      move.l(4(sp), d0),
      // Step object one frame
      if (step.animate)
        jsr(Label('Event_StepObjectNoWait').l)
      else
        jsr(Label('Event_StepObjectNoWaitNoAnimate').l),
      // Loop to next char...
    ]));
  }

  // Now complete the frame:
  // update sprites, wait for vint, and loop for the next frame
  asm.add(Asm([
    movem.l(d2 / a4, -(sp)),
    jsr(Label('Field_LoadSprites').l),
    jsr(Label('Field_BuildSprites').l),
    jsr(Label('AnimateTiles').l),
    jsr(Label('RunMapUpdates').l),
    jsr(Label('VInt_Prepare').l),
    movem.l(sp.postIncrement(), d2 / a4),
    dbf(d2, loop),

    // When done, move the stack off of x/y from before
    lea(8(sp), sp),
  ]));

  var knownStep = step.stepPerFrame.known(memory);

  // Now reset all step constants and update memory
  for (var obj in step.objects.reversed) {
    asm.add(Asm([
      obj.toA4(memory),
      moveq(0.i, d0),
      if (knownStep?.x != 0) move.l(d0, x_step_constant(a4)),
      if (knownStep?.y != 0) move.l(d0, y_step_constant(a4)),
      // Set destination to current position.
      // This is needed if routine will move to destination.
      // If not set in that case, the object will move the next time
      // the field object routine is run.
      setDestination(x: curr_x_pos(a4), y: curr_y_pos(a4)),
    ]));

    if ((memory.positions[obj]) case var current?) {
      if (knownStep case var known?) {
        var totalSteps = (known * step.frames).truncate();
        memory.positions[obj] = current + Position.fromPoint(totalSteps);
      } else {
        // If we don't know the step, we can't set the position.
        memory.positions[obj] = null;
      }
    }
  }

  return asm;
}
