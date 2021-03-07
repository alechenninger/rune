import 'dart:collection';
import 'dart:math' as math;

import 'package:rune/asm/events.dart';

import '../asm/asm.dart' hide Move;
import '../model/model.dart';

const unitsPerStep = 16;
const up = Constant('FacingDir_up');
const down = Constant('FacingDir_Down');
const left = Constant('FacingDir_Left');
const right = Constant('FacingDir_Right');

extension MoveToAsm on Move {
  Asm toAsm(EventContext ctx) {
    var asm = Asm.empty();

    var traveled = 0;
    var delayed = Map<Moveable, Movement>.from(movements);
    // Shortest distance last
    var now = SplayTreeSet<MapEntry<Moveable, Movement>>((e1, e2) {
      var comparison = e2.value.distance.compareTo(e1.value.distance);
      if (comparison == 0) {
        return e2.key.toString().compareTo(e1.key.toString());
      }
      return comparison;
    });
    var individual = false;

    while (delayed.isNotEmpty) {
      var next = Map<Moveable, Movement>.from(delayed);
      int? stepsUntilDelayed;

      delayed.clear();
      now.clear();
      individual = false;

      // Sort next into new batch of delayed and now
      for (var entry in next.entries) {
        var moveable = entry.key;
        var movement = entry.value;
        if (moveable is! Party) {
          individual = true;
        }

        if (movement.delay > traveled) {
          delayed[moveable] = movement;
          stepsUntilDelayed = stepsUntilDelayed.capTo(movement.delay);
        } else {
          now.add(entry);
        }
      }

      if (now.isEmpty) {
        if (stepsUntilDelayed != null) traveled = stepsUntilDelayed;
        continue;
      }

      // TODO: in context could see if this is set already?
      // and/or have a different type of event for party movement?
      asm.add(followLeader(!individual));

      var maxParallelSteps = now
          .map((e) => e.value.distance)
          .reduce((maxParallel, d) => maxParallel = math.min(maxParallel, d));
      var maxUntilDelayed =
          stepsUntilDelayed == null ? null : stepsUntilDelayed - traveled;
      var maxNow = maxUntilDelayed.capTo(maxParallelSteps);
      Moveable? a4;

      void toA4(Moveable moveable) {
        if (a4 != moveable) {
          asm.add(moveable.toA4(ctx));
          a4 = moveable;
        }
      }

      for (var next in now) {
        var moveable = next.key;
        var movement = next.value;
        var last = next.key == now.last.key;

        toA4(moveable);

        if (movement is StepDirection) {
          var curr = ctx.positions[moveable];
          if (curr == null) {
            throw StateError('no current position set for $moveable');
          }

          var toTravel = maxNow.capTo(movement.distance);
          var dest =
              curr + (movement.direction.normal * toTravel) * unitsPerStep;
          ctx.positions[moveable] = dest;

          var x = Word(dest.x).i;
          var y = Word(dest.y).i;

          if (last) {
            asm.add(moveCharacter(x: x, y: y));
          } else {
            asm.add(setDestination(x: x, y: y));
          }

          if (movement.distance > toTravel) {
            delayed[moveable] = movement.less(toTravel);
          }
        }
      }

      // Should we wait until everything done moving for this?
      for (var next in now.toList().reversed) {
        var moveable = next.key;
        var movement = next.value;
        if (movement is StepDirection) {
          if (!delayed.containsKey(moveable)) {
            toA4(moveable);
            asm.add(updateObjFacing(movement.direction.address));
          }
        }
      }

      // TODO: is it always maxNow?
      // if less was moved, it means delay is greater than actual moved spaces
      traveled += maxNow;
    }

    return asm;
  }
}

extension Cap on int? {
  int capTo(int other) {
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
