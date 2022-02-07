import 'dart:math' as math;

import 'package:rune/asm/events.dart';

import '../asm/asm.dart' hide MoveMnemonic;
import '../model/model.dart';

const unitsPerStep = 16;
const up = Constant('FacingDir_up');
const down = Constant('FacingDir_Down');
const left = Constant('FacingDir_Left');
const right = Constant('FacingDir_Right');

/*
Follow lead flag notes:

* Followers only move as long as it takes the leader to get into position; it
does not guarantee followers are "behind" the leader after the leader is done
* Followers take a direct route; whatever gets them closer based on where they
and the leader currently are
* Appears to have no effect if the moving character is not currently the leader

 */

extension MoveToAsm on IndividualMoves {
  Asm toAsm(EventContext ctx) {
    var asm = Asm.empty();

    if (ctx.followLead) {
      asm.add(followLeader(ctx.followLead = false));
    }

    // We're going to loop through all movements and remove those from the map
    // when there's nothing left to do.
    var remainingMoves = Map.of(moves);

    while (remainingMoves.isNotEmpty) {
      // I tried using a sorted set but iterator was bugged and skipped elements
      var movesList =
          remainingMoves.entries.map((e) => Move(e.key, e.value)).toList();
      var done = <Moveable, Movement>{};

      // not sure if it actually needs to be sorted by distance/duration any
      // more?
      // but at least helps with predictable generated code for testing, so sort
      // by slot
      movesList.sort((m1, m2) => m1.moveable.compareTo(m2.moveable, ctx));

      // Figure out what's the longest we can move continuously before we have
      // to call the character move procedure again.
      // This is based on two factors:
      // 1. How many steps until there is a new character which needs to start
      // moving (is currently delayed).
      // 2. How many steps we can have of continuous movement along the X-then-Y
      // axes, or Y-then-X axes (e.g. not some X, some Y, and then some X again).
      // This is because the movement subroutine only supports changing
      // direction once (x to y, or y to x). After that, we have to break up
      // the movements into multiple subroutine calls.

      var maxStepsXFirst = movesList
          .map((m) => m.movement.delayOrContinuousStepsFirstAxis(Axis.x))
          .reduce((min, s) => min = math.min(min, s));
      var maxStepsYFirst = movesList
          .map((m) => m.movement.delayOrContinuousStepsFirstAxis(Axis.y))
          .reduce((min, s) => min = math.min(min, s));

      // Axis we will end up moving first
      Axis firstAxis;

      // This is the actual amount of steps we can make in the current batch of
      // moves.
      int maxSteps;

      if (maxStepsXFirst > maxStepsYFirst) {
        firstAxis = Axis.x;
        maxSteps = maxStepsXFirst;
      } else {
        // Keep first axis from context if either is equivalent
        firstAxis = maxStepsYFirst > maxStepsXFirst ? Axis.y : ctx.startingAxis;
        maxSteps = maxStepsYFirst;
      }

      Moveable? a4;

      void toA4(Moveable moveable) {
        if (a4 != moveable) {
          asm.add(moveable.toA4(ctx));
          a4 = moveable;
        }
      }

      if (ctx.startingAxis != firstAxis) {
        asm.add(moveAlongXAxisFirst(firstAxis == Axis.x));
        ctx.startingAxis = firstAxis;
      }

      // If no movement code is generated because all moves are delayed, we'll
      // have to add an artificial delay later.
      var allDelay = true;
      // The ASM for the last character movement should use data registers, the
      // others use memory
      var lastMoveIndex =
          movesList.lastIndexWhere((element) => element.movement.delay == 0);

      // Now start actually generating movement code for current batch up until
      // maxSteps.
      for (var i = 0; i < movesList.length; i++) {
        var move = movesList[i];
        var moveable = move.moveable;
        var movement = move.movement;
        var stepsToTake = maxSteps;

        if (movement.delay == 0) {
          allDelay = false;

          var current = ctx.positions[moveable];
          if (current == null) {
            throw StateError('no current position set for $moveable');
          }

          stepsToTake = movement.distance.min(maxSteps);
          var afterSteps = movement.lookahead(stepsToTake);

          if (afterSteps.relativeDistance > 0) {
            var destination =
                current + afterSteps.relativePosition * unitsPerStep;
            ctx.positions[moveable] = destination;
            ctx.facing[moveable] = afterSteps.facing;

            var x = Word(destination.x).i;
            var y = Word(destination.y).i;

            toA4(moveable);

            if (i == lastMoveIndex) {
              asm.add(moveCharacter(x: x, y: y));
            } else {
              asm.add(setDestination(x: x, y: y));
            }
          }
        }

        movement = movement.less(stepsToTake);

        if (movement.distance == 0) {
          remainingMoves.remove(moveable);
          done[moveable] = movement;
        } else {
          remainingMoves[moveable] = movement;
        }
      }

      if (allDelay) {
        // Just guessing at 8 frames per step?
        // look at x/y_step_constant and FieldObj_Move routine
        asm.add(vIntPrepareLoop((8 * maxSteps).word));
      }

      for (var move in done.entries) {
        var moveable = move.key;
        var movement = move.value;
        // fixme: not setting facing can make characters appear
        //  mid move when dialog comes up
        // maybe we can detect when about to switch to dialog?
        // or a way to override the optimization?
        // maybe there is a way to express a force face because this would also
        // solve for when we want to have just facing movements
        // if (ctx.facing[moveable] != movement.direction) {
        toA4(moveable);
        asm.add(updateObjFacing(movement.direction.address));
        // }
      }
    }

    return asm;
  }
}

int Function(Move, Move) _longestFirst(EventContext ctx) {
  return (Move move1, Move move2) {
    var comparison = move2.movement.duration.compareTo(move1.movement.duration);
    if (comparison == 0) {
      return move2.moveable.compareTo(move2.moveable, ctx);
    }
    return comparison;
  };
}

int minOf(int? i1, int other) {
  return i1 == null ? other : math.min(i1, other);
}

extension Cap on int? {
  int min(int other) {
    var self = this;
    return self == null ? other : math.min(self, other);
  }
}

extension MoveableToA4 on Moveable {
  Asm toA4(EventContext ctx) {
    var moveable = this;
    if (moveable is Character) {
      var slot = ctx.slotFor(moveable);
      if (slot != null) {
        // Slot 1 indexed
        return characterBySlotToA4(slot);
      } else {
        return characterByIdToA4(moveable.charId);
      }
    }
    throw UnsupportedError('$this.toA4');
  }
}

extension CharId on Character {
  Address get charId {
    switch (runtimeType) {
      case Shay:
        return Constant('CharID_Chaz').i;
      case Alys:
        return Constant('CharID_Alys').i;
    }
    throw UnsupportedError('$this.charId');
  }
}

extension DirectionToAddress on Direction {
  Address get address {
    switch (this) {
      case Direction.up:
        return up.i;
      case Direction.left:
        return left.i;
      case Direction.right:
        return right.i;
      case Direction.down:
        return down.i;
    }
    throw StateError('illegal direction $this');
  }
}
