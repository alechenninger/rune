// ignore_for_file: constant_identifier_names

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/map.dart';

import '../asm/asm.dart';
import '../asm/asm.dart' as asmlib;
import '../model/model.dart';
import 'event.dart';
import 'memory.dart';

const unitsPerStep = 16;

const FacingDir_Up = Constant('FacingDir_Up');
const FacingDir_Down = Constant('FacingDir_Down');
const FacingDir_Left = Constant('FacingDir_Left');
const FacingDir_Right = Constant('FacingDir_Right');
const FieldObj_Step_Offset = Constant('FieldObj_Step_Offset');

/*
Follow lead flag notes:

* Followers only move as long as it takes the leader to get into position; it
does not guarantee followers are "behind" the leader after the leader is done
* Followers take a direct route; whatever gets them closer based on where they
and the leader currently are
* Appears to have no effect if the moving character is not currently the leader

Follow lead is really an optimization over individual moves
Individual moves play out both:
1. follow lead moves
2. independent moves

if independent moves == follow lead moves, just use follow lead flag

 */

extension IndividualMovesToAsm on IndividualMoves {
  EventAsm toAsm(EventState ctx) {
    var asm = EventAsm.empty();
    var generator = _MovementGenerator(asm, ctx);

    // We're going to loop through all movements and remove those from the map
    // when there's nothing left to do.
    var remainingMoves = Map.of(moves.map(
        (moveable, movement) => MapEntry(moveable.resolve(ctx), movement)));

    generator.prepare(remainingMoves.keys);
    generator.setSpeed(speed);

    while (remainingMoves.isNotEmpty) {
      // I tried using a sorted set but iterator was bugged and skipped elements
      var movesList = remainingMoves.entries
          .map((e) => RelativeMove(e.key, e.value))
          .toList();
      var done = <FieldObject, RelativeMovement>{};

      // We could consider sorting movesList by slot
      // so we always start with lead character,
      // which may allow the following movements to simply follow the leader
      // (using the follow lead movement flag in the generated ASM).
      // But, sorting meant some changes to behavior such as who's facing is
      // updated first.

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
          .map((m) => m.movement.delayOrContinuousStepsWithFirstAxis(Axis.x))
          .reduce((min, s) => min = min.min(s));
      var maxStepsYFirst = movesList
          .map((m) => m.movement.delayOrContinuousStepsWithFirstAxis(Axis.y))
          .reduce((min, s) => min = min.min(s));

      // Axis we will end up moving first
      Axis firstAxis;

      // This is the actual amount of steps we can make in the current batch of
      // moves.
      Steps maxSteps;

      if (maxStepsXFirst > maxStepsYFirst) {
        firstAxis = Axis.x;
        maxSteps = maxStepsXFirst;
      } else {
        // Keep first axis from context or default to x if either is equivalent
        firstAxis = maxStepsYFirst > maxStepsXFirst
            ? Axis.y
            : (ctx.startingAxis ?? Axis.x);
        maxSteps = maxStepsYFirst;
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
      var lastMoveIndex = movesList
          .lastIndexWhere((element) => element.movement.delay == 0.steps);

      // Now start actually generating movement code for current batch up until
      // maxSteps.
      for (var i = 0; i < movesList.length; i++) {
        var move = movesList[i];
        var moveable = move.moveable;
        var movement = move.movement;
        var stepsToTake = maxSteps;

        if (movement.delay == 0.steps) {
          allDelay = false;

          stepsToTake = movement.distance.min(maxSteps);
          var afterSteps = movement.lookahead(stepsToTake);

          if (afterSteps.relativeDistance > 0.steps) {
            var current = ctx.positions[moveable];
            if (current == null) {
              // TODO: We can do some math instead, maybe store in register
              // e.g. look up cur position, save in data register
              // might need to look up each time based on necessary math and
              // available data registers
              throw StateError('no current position set for $moveable');
            }

            var destination = current + afterSteps.relativePosition;
            ctx.positions[moveable] = destination;
            ctx.setFacing(moveable, afterSteps.facing);

            var x = Word(destination.x).i;
            var y = Word(destination.y).i;

            generator.toA4(moveable);
            generator.ensureScriptable(moveable);

            if (i == lastMoveIndex) {
              asm.add(moveCharacter(x: x, y: y));
            } else {
              asm.add(setDestination(x: x, y: y));
            }
          } else if (movement.distance == 0.steps &&
              movement.direction != ctx.getFacing(moveable)) {
            generator.updateFacing(moveable, movement.direction);
          }
        }

        movement = movement.less(stepsToTake);

        // todo: but this ignores delay?
        if (movement.distance == 0.steps &&
            movement.direction == ctx.getFacing(moveable)) {
          remainingMoves.remove(moveable);
          done[moveable] = movement;
        } else {
          remainingMoves[moveable] = movement;
        }
      }

      if (allDelay) {
        // Just guessing at 8 frames per step?
        // look at x/y_step_constant and FieldObj_Move routine
        asm.add(doMapUpdateLoop((8 * maxSteps.toInt).toWord));
      }
    }

    generator.resetObjects();
    generator.resetSpeedFrom(speed);

    return asm;
  }
}

int Function(RelativeMove<FieldObject>, RelativeMove<FieldObject>)
    _longestFirst(EventState ctx) {
  return (RelativeMove<FieldObject> move1, RelativeMove<FieldObject> move2) {
    var comparison = move2.movement.duration.compareTo(move1.movement.duration);
    if (comparison == 0) {
      return move2.moveable.compareTo(move2.moveable, ctx);
    }
    return comparison;
  };
}

class _MovementGenerator {
  _MovementGenerator(this.asm, this.ctx);

  final EventAsm asm;
  final EventState ctx;

  // TODO: this can move to eventstate / memory
  var madeScriptable = <MapObject>{};
  FieldObject? a4;

  void prepare(Iterable<FieldObject> objects) {
    // Only disable follow leader if moving any characters.
    if (ctx.followLead != false &&
        objects.any((obj) => obj.resolve(ctx) is! MapObject)) {
      asm.add(followLeader(ctx.followLead = false));
    }
  }

  void setSpeed(StepSpeed speed) {
    // TODO(movement): move speed to eventstate
    if (speed != StepSpeed.fast) {
      asm.add(asmlib.move.b(speed.offset.i, FieldObj_Step_Offset.w));
    }
  }

  void resetSpeedFrom(StepSpeed speed) {
    if (speed != StepSpeed.fast) {
      asm.add(asmlib.move.b(1.i, FieldObj_Step_Offset.w));
    }
  }

  void toA4(FieldObject moveable) {
    if (a4 != moveable) {
      asm.add(moveable.toA4(ctx));
      a4 = moveable;
    }
  }

  void ensureScriptable(FieldObject obj) {
    obj = obj.resolve(ctx);

    if (obj is MapObject && !madeScriptable.contains(obj)) {
      // Make map object scriptable
      asm.add(asmlib.move.w(0x8194.toWord.i, asmlib.a4.indirect));
      madeScriptable.add(obj);
    }
  }

  void updateFacing(FieldObject obj, Direction dir) {
    toA4(obj);
    // this ensures facing doesn't change during subsequent movements.
    ensureScriptable(obj);
    asm.add(updateObjFacing(dir.address));
    ctx.setFacing(obj, dir);
  }

  void resetObjects() {
    // Return objects back to normal behavior
    for (var obj in madeScriptable) {
      toA4(obj);
      var routine = obj.routine;
      asm.add(asmlib.move.w(routine.index.i, asmlib.a4.indirect));
      asm.add(jsr(routine.label.l));
    }
  }
}

EventAsm absoluteMovesToAsm(AbsoluteMoves moves, Memory state) {
  // We assume we don't know the current positions,
  // so we don't know which move is longer.
  // Just start all in parallel.
  // TODO: technically we might know, in which case we could convert this
  // to relative movements which would maintain some more context.
  var asm = EventAsm.empty();
  var generator = _MovementGenerator(asm, state);
  var length = moves.destinations.length;

  generator.prepare(moves.destinations.keys);
  generator.setSpeed(moves.speed);

  moves.destinations.entries.forEachIndexed((i, dest) {
    var obj = dest.key.resolve(state);
    var pos = dest.value;

    generator.toA4(obj);
    generator.ensureScriptable(obj);

    if (i < length - 1) {
      asm.add(setDestination(x: pos.x.toWord.i, y: pos.y.toWord.i));
    } else {
      asm.add(moveCharacter(x: pos.x.toWord.i, y: pos.y.toWord.i));
    }

    state.positions[obj] = pos;
    // If we don't know which direction the object was coming from,
    // we don't know which direction it will be facing.
    state.clearFacing(obj);
  });

  generator.resetObjects();
  generator.resetSpeedFrom(moves.speed);

  return asm;
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

extension FieldObjectAsm on FieldObject {
  Asm toA4(EventState ctx) {
    var moveable = this;
    var slot = moveable.slot(ctx);
    if (slot != null) {
      // Slot 1 indexed
      return characterBySlotToA4(slot);
    } else if (moveable is Character) {
      return characterByIdToA4(moveable.charIdAddress);
    } else if (moveable is MapObjectById) {
      var address = moveable.address(ctx);
      return lea(Absolute.long(address), a4);
    } else if (moveable is MapObject) {
      var address = moveable.address(ctx);
      return lea(Absolute.long(address), a4);
    }

    /*
    notes:
	jsr	(Event_GetCharacter).l
	bmi.s	loc_6E212

    i.e. bmi branch if char id not found in party

    if don't want to load to a4, do something like

	bsr.w	FindCharacterSlot
	bmi.s	+
	lsl.w	#6, d1
	lea	(Character_1).w, a3
	lea	(a3,d1.w), a3

    that is, just use findcharslot directly.
     */

    throw UnsupportedError('$this.toA4');
  }

  Asm toA3(EventState ctx) {
    var obj = this;
    if (obj is MapObject) {
      var address = obj.address(ctx);
      return lea(Absolute.long(address), a3);
    } else if (obj is MapObjectById) {
      var address = obj.address(ctx);
      return lea(Absolute.long(address), a3);
    } else if (obj is Slot) {
      // why word? this is what asm appears to do
      return lea('Character_${obj.index}'.toConstant.w, a3);
    }

    throw UnsupportedError('must be mapobject or slot');
  }
}

extension AddressOfMapObjectId on MapObjectById {
  Longword address(EventState ctx) {
    var map = ctx.currentMap;
    if (map == null) {
      throw UnsupportedError('got field obj in map, but map was null');
    }
    var obj = inMap(map);
    if (obj == null) {
      throw UnsupportedError('got field obj in map, '
          'but <$this> is not in <$map>');
    }
    return map.addressOf(obj);
  }
}

extension AddressOfMapObject on MapObject {
  Longword address(EventState ctx) {
    var map = ctx.currentMap;
    if (map == null) {
      throw UnsupportedError('got field obj in map, but map was null');
    }
    return map.addressOf(this);
  }
}

const _characterJumpTable = [
  null,
  Shay,
  Alys,
  Hahn,
  Rune,
  Gryz,
  Rika,
  Demi,
  Wren,
  Raja,
  Kyra,
  Seth
];

extension CharacterData on Character {
  Expression get charId {
    switch (runtimeType) {
      case Shay:
        return Constant('CharID_Chaz');
      default:
        return Constant('CharID_$this');
    }
  }

  Address get charIdAddress => charId.i;

  Address get fieldObjectRoutine {
    switch (runtimeType) {
      case Shay:
        return Label('FieldObj_Chaz').l;
      default:
        return Label('FieldObj_$this').l;
    }
  }

  Value get fieldObjectIndex {
    return (_characterJumpTable.indexOf(runtimeType) * 4).toValue;
  }
}

extension DirectionToAddress on Direction {
  Constant get constant {
    switch (this) {
      case Direction.up:
        return FacingDir_Up;
      case Direction.left:
        return FacingDir_Left;
      case Direction.right:
        return FacingDir_Right;
      case Direction.down:
        return FacingDir_Down;
    }
  }

  Address get address {
    return constant.i;
  }
}

extension StepSpeedAsm on StepSpeed {
  Byte get offset {
    switch (this) {
      case StepSpeed.verySlowWalk:
        return Byte(3);
      case StepSpeed.slowWalk:
        return Byte.zero;
      case StepSpeed.walk:
        return Byte(4);
      case StepSpeed.fast:
        return Byte.one;
      case StepSpeed.double:
        return Byte.two;
    }
  }
}

extension PartyArrangementAsm on PartyArrangement {
  Value get toAsm => Value(switch (this) {
        PartyArrangement.overlapping => 0,
        PartyArrangement.belowLead => 4,
        PartyArrangement.aboveLead => 8,
        PartyArrangement.leftOfLead => 0xC,
        PartyArrangement.rightOfLead => 0x10,
      });
}

PartyArrangement? asmToArrangement(Byte b) {
  return switch (b.value) {
    0 => PartyArrangement.overlapping,
    4 => PartyArrangement.belowLead,
    8 => PartyArrangement.aboveLead,
    0xC => PartyArrangement.leftOfLead,
    0x10 => PartyArrangement.rightOfLead,
    _ => null
  };
}
