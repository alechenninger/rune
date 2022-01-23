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

    // Steps travelled so far
    var traveled = 0;

    // List of moves to make in parallel
    var currentParallelMoves = <AssignedMovement>[];

    var remainingMoves = Map.of(movements);

    if (ctx.followLead) {
      asm.add(followLeader(ctx.followLead = false));
    }

    while (remainingMoves.isNotEmpty) {
      // Copy remaining to avoid concurrent modification.
      var remaining = Map.of(remainingMoves);
      remainingMoves.clear();
      currentParallelMoves.clear();

      // The soonest move in the remaining set may not be immediate; this tracks
      // the number of total steps the soonest remaining move should start at.
      int? nextRemainingStartSteps;

      // Of remaining, find moves we should make now
      for (var move in remaining.entries) {
        var moveable = move.key;
        var movement = move.value;

        if (movement.delay > traveled) {
          remainingMoves[moveable] = movement;
          nextRemainingStartSteps =
              nextRemainingStartSteps.orMax(movement.delay);
        } else {
          currentParallelMoves.add(AssignedMovement(moveable, movement));
        }
      }

      if (currentParallelMoves.isEmpty) {
        // Nothing to do now, skip ahead to next remaining
        if (nextRemainingStartSteps != null) traveled = nextRemainingStartSteps;
        continue;
      }

      // I tried using a sorted set but iterator was bugged
      currentParallelMoves.sort(_shortestDistanceLast(ctx));

      // We have to break up the movements we make based on what movements are
      // completely parallel, versus what movements are partially parallel (e.g.
      // one character keeps moving after another has stopped. We also have to
      // make sure we don't move too long without considering remaining moves
      // which are just delayed.
      var maxParallelSteps = currentParallelMoves
          .map((e) => e.movement.distance)
          .reduce((maxParallel, d) => maxParallel = math.min(maxParallel, d));
      var stepsUntilNextRemaining = nextRemainingStartSteps == null
          ? null
          : nextRemainingStartSteps - traveled;
      // This is the actual amount of steps we can make in the current batch of
      // moves.
      var maxSteps = stepsUntilNextRemaining.orMax(maxParallelSteps);
      Moveable? a4;

      void toA4(Moveable moveable) {
        if (a4 != moveable) {
          asm.add(moveable.toA4(ctx));
          a4 = moveable;
        }
      }

      // Now start actually generating movement code for current batch up until
      // maxSteps.

      for (var move in currentParallelMoves) {
        var moveable = move.moveable;
        var movement = move.movement;
        var isLast = moveable == currentParallelMoves.last.moveable;

        toA4(moveable);

        // NOTE: each movement ends with a slight pause so one direction at a
        // time is not as smooth as setting both

        // Could consider polymorphic movements by adding this signature to
        // Movement:
        //    Movement? move(ctx, moveable, maxSteps, asm)
        // returns movement if it still has more to move
        // of course can't do that with model/generator layer separation
        if (movement is StepDirection) {
          var current = ctx.positions[moveable];
          if (current == null) {
            throw StateError('no current position set for $moveable');
          }

          var steps = movement.distance.orMax(maxSteps);
          var destination =
              current + (movement.direction.normal * steps) * unitsPerStep;
          ctx.positions[moveable] = destination;
          ctx.facing[moveable] = movement.direction;

          var x = Word(destination.x).i;
          var y = Word(destination.y).i;

          if (isLast) {
            asm.add(moveCharacter(x: x, y: y));
          } else {
            asm.add(setDestination(x: x, y: y));
          }

          if (movement.distance > steps) {
            remainingMoves[moveable] = movement.less(steps);
          }
        } else if (movement is StepToPoint) {}
      }

      // Should we wait until everything done moving for this?
      for (var next in currentParallelMoves.reversed) {
        var moveable = next.moveable;
        var movement = next.movement;
        if (movement is StepDirection) {
          if (!remainingMoves.containsKey(moveable) &&
              ctx.facing[moveable] != movement.direction) {
            toA4(moveable);
            asm.add(updateObjFacing(movement.direction.address));
          }
        }
      }

      // TODO: is it always maxNow?
      // if less was moved, it means delay is greater than actual moved spaces
      traveled += maxSteps;
    }

    return asm;
  }
}

int Function(AssignedMovement, AssignedMovement) _shortestDistanceLast(
    EventContext ctx) {
  return (AssignedMovement move1, AssignedMovement move2) {
    var comparison = move2.movement.distance.compareTo(move1.movement.distance);
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
  int orMax(int other) {
    var self = this;
    return self == null ? other : math.min(self, other);
  }
}

extension MoveableToA4 on Moveable {
  Asm toA4(EventContext ctx) {
    var moveable = this;
    if (moveable is Character) {
      var slot = ctx.slots.indexOf(moveable);
      if (slot >= 0) {
        // Slot 1 indexed
        return characterBySlotToA4(slot + 1);
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

class AssignedMovement {
  final Moveable moveable;
  final Movement movement;

  AssignedMovement(this.moveable, this.movement);

  @override
  String toString() {
    return 'AssignedMovement{moveable: $moveable, movement: $movement}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignedMovement &&
          runtimeType == other.runtimeType &&
          moveable == other.moveable &&
          movement == other.movement;

  @override
  int get hashCode => moveable.hashCode ^ movement.hashCode;
}
