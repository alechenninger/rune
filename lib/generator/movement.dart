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

final scriptableObjectRoutine = AsmRoutineRef(Word(0x194));

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
  EventAsm toAsm(Memory ctx) {
    var asm = EventAsm.empty();
    var generator = _MovementGenerator(asm, ctx);

    // We're going to loop through all movements and remove those from the map
    // when there's nothing left to do.
    var remainingMoves = Map.of(moves.map(
        (moveable, movement) => MapEntry(moveable.resolve(ctx), movement)));

    generator.charactersDoNotFollowLeader(remainingMoves.keys);
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

      generator.setStartingAxis(firstAxis);

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

EventAsm absoluteMovesToAsm(AbsoluteMoves moves, Memory state) {
  // We assume we don't know the current positions,
  // so we don't know which move is longer.
  // Just start all in parallel.
  // TODO: technically we might know, in which case we could convert this
  // to relative movements which would maintain some more context.
  var asm = EventAsm.empty();
  var generator = _MovementGenerator(asm, state);
  var length = moves.destinations.length;

  if (!moves.followLeader) {
    generator.charactersDoNotFollowLeader(moves.destinations.keys);
  }
  generator.setSpeed(moves.speed);
  generator.setStartingAxis(moves.startingAxis);

  moves.destinations.entries.forEachIndexed((i, dest) {
    var obj = dest.key.resolve(state);

    if (moves.followLeader &&
        (obj is Character && obj.slot(state) != 1 ||
            (obj is Slot && obj.index > 1))) {
      throw StateError(
          'cannot move $obj independently when follow leader flag is set');
    }

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

  generator.resetSpeedFrom(moves.speed);

  return asm;
}

class _MovementGenerator {
  _MovementGenerator(this.asm, this._mem);

  final EventAsm asm;
  final Memory _mem;

  void charactersDoNotFollowLeader(Iterable<FieldObject> objects) {
    // Only disable follow leader if moving any characters.
    if (_mem.followLead != false &&
        objects.any((obj) => obj.resolve(_mem) is! MapObject)) {
      asm.add(followLeader(_mem.followLead = false));
    }
  }

  void setStartingAxis(Axis axis) {
    if (_mem.startingAxis != axis) {
      asm.add(moveAlongXAxisFirst(axis == Axis.x));
      _mem.startingAxis = axis;
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
    if (_mem.inAddress(a4)?.obj != moveable) {
      asm.add(moveable.toA4(_mem));
    }
  }

  /// Returns true if object is made scriptable.
  bool ensureScriptable(FieldObject obj) {
    obj = obj.resolve(_mem);

    if (obj is MapObject && _mem.getRoutine(obj) != scriptableObjectRoutine) {
      // Make map object scriptable
      asm.add(asmlib.move.w(0x8194.toWord.i, asmlib.a4.indirect));
      _mem.setRoutine(obj, scriptableObjectRoutine);
      return true;
    }

    return false;
  }

  void updateFacing(FieldObject obj, Direction dir) {
    toA4(obj);
    // this ensures facing doesn't change during subsequent movements.
    if (ensureScriptable(obj)) {
      // Destination attributes are not always set,
      // resulting in odd character movements with this routine.
      // Ensure they're set based on context.
      var position = _mem.positions[obj];
      if (position == null) {
        throw StateError('no current position set for $obj');
      }
      asm.add(setDestination(x: position.x.i, y: position.y.i));
    }
    asm.add(updateObjFacing(dir.address));
    _mem.setFacing(obj, dir);
  }
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
  Asm toA4(Memory ctx) {
    if (ctx.inAddress(a4)?.obj == AddressOf(resolve(ctx))) {
      return Asm.empty();
    }

    var obj = this;
    var slot = obj.slot(ctx);
    if (slot != null) {
      // Slot 1 indexed
      ctx.putInAddress(a4, obj);
      return characterBySlotToA4(slot);
    } else if (obj is Character) {
      ctx.putInAddress(a4, obj);
      return characterByIdToA4(obj.charIdAddress);
    } else if (obj is MapObjectById) {
      ctx.putInAddress(a4, obj);
      var address = obj.address(ctx);
      return lea(Absolute.long(address), a4);
    } else if (obj is MapObject) {
      ctx.putInAddress(a4, obj);
      var address = obj.address(ctx);
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

  Asm toA3(Memory ctx) => toA(a3, ctx);

  Asm toA(DirectAddressRegister a, Memory memory) {
    if (memory.inAddress(a)?.obj == AddressOf(resolve(memory))) {
      return Asm.empty();
    }

    var obj = this;
    if (obj is MapObject) {
      var address = obj.address(memory);
      return lea(Absolute.long(address), a);
    } else if (obj is MapObjectById) {
      var address = obj.address(memory);
      return lea(Absolute.long(address), a);
    } else if (obj is Slot) {
      // why word? this is what asm appears to do
      return lea('Character_${obj.index}'.toConstant.w, a);
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

extension DirectionExpressionAsm on DirectionExpression {
  Asm load(Address to, Memory memory) {
    return switch (this) {
      Direction d => move.b(d.constant.i, to),
      DirectionOfVector d => d.load(to, memory),
      TowardsPlayer d => d.load(to, memory),
    };
  }
}

extension DirectionOfVectorAsm on DirectionOfVector {
  Direction? known(Memory mem) {
    var from = this.from.known(mem);
    var to = this.to.known(mem);
    if (from == null || to == null) {
      return null;
    }
    var vector = to - from;
    if (vector.x == 0 && vector.y == 0) return Direction.up;
    var angle = math.atan2(vector.y, vector.x) * 180 / math.pi;
    return switch (angle) {
      >= -45 && < 45 => Direction.right,
      >= 45 && < 135 => Direction.down,
      >= -135 && < -45 => Direction.up,
      _ => Direction.left
    };
  }

  Asm load(Address addr, Memory memory) {
    return Asm([
      moveq(FacingDir_Down.i, addr),
      from.withY(memory: memory, asm: (y) => move.w(y, d1)),
      to.withY(
          memory: memory,
          asm: (y) => y is Immediate ? cmpi.w(y, d1) : cmp.w(y, d1)),
      beq.s(Label(r'$$checkx')),
      bcc.s(Label(r'$$keep')), // keep up
      move.w(FacingDir_Up.i, addr),
      bra.s(Label(r'$$keep')), // keep
      label(Label(r'$$checkx')),
      move.w(FacingDir_Right.i, addr),
      from.withX(memory: memory, asm: (x) => move.w(x, d1)),
      to.withX(
          memory: memory,
          asm: (y) => y is Immediate ? cmpi.w(y, d1) : cmp.w(y, d1)),
      bcc.s(Label(r'$$keep')), // keep up
      move.w(FacingDir_Left.i, addr),
      label(Label(r'$$keep')),
    ]);
  }
}

extension TowardsPlayerAsm on TowardsPlayer {
  Asm load(Address addr, Memory memory) {
    if (from == PositionOfObject(InteractionObject())) {
      // Character is facing this object,
      // so we only need to face the opposite direction
      var known = memory.getFacing(Slot.one);

      if (known != null) {
        return move.b(known.opposite.address, addr);
      }

      // Evaluate at runtime
      return Asm([
        Slot.one.toA3(memory),
        move.w(facing_dir(a3), addr),
        bchg(2.i, addr),
      ]);
    }

    return DirectionOfVector(from: from, to: PositionOfObject(Slot(1)))
        .load(addr, memory);
  }
}

extension PositionExpressionAsm on PositionExpression {
  Position? known(Memory mem) => switch (this) {
        Position p => p,
        PositionOfObject p => mem.positions[p.obj]
      };

  Asm withX({required Memory memory, required Asm Function(Address) asm}) {
    return switch (this) {
      Position p => asm(p.x.toWord.i),
      PositionOfObject p => p.withX(memory: memory, asm: asm),
    };
  }

  Asm withY({required Memory memory, required Asm Function(Address) asm}) {
    return switch (this) {
      Position p => asm(p.y.toWord.i),
      PositionOfObject p => p.withY(memory: memory, asm: asm),
    };
  }
}

extension PositionOfObjectAsm on PositionOfObject {
  Asm loadX(Address to, {required Memory memory}) {
    return withX(memory: memory, asm: (x) => move.w(x, to));
  }

  Asm withX({required Memory memory, required Asm Function(Address) asm}) {
    var position = memory.positions[obj];
    if (position != null) {
      return asm(position.x.toWord.i);
    }
    return Asm([obj.toA4(memory), asm(curr_x_pos(a4))]);
  }

  Asm loadY(Address to, {required Memory memory}) {
    return withY(memory: memory, asm: (y) => move.w(y, to));
  }

  Asm withY({required Memory memory, required Asm Function(Address) asm}) {
    var position = memory.positions[obj];
    if (position != null) {
      return asm(position.y.toWord.i);
    }
    return Asm([obj.toA4(memory), asm(curr_y_pos(a4))]);
  }
}

/*
moveq    #CharID_Rune, d0
    jsr    (Event_GetCharacter).l
    lea    (a4), a3
    lea    (Field_Obj_Secondary).w, a4
    move.w    #0, d0
    move.w    $34(a3), d1
    cmp.w    $34(a4), d1    ; compare rune and dorin y
    beq.s    loc_6F112        ; branch if same
    bcc.s    loc_6F124     ; if rune above dorin
    move.w    #4, d0        ; face up
    bra.s    loc_6F124        ; otherwise face down
loc_6F112:
    move.w    #8, d0        ; face right
    ; Compare x position
    move.w    $30(a3), d1
    cmp.w    $30(a4), d1
    bcc.s    loc_6F124        ; branch if negative (always, in original)
    move.w    #$C, d0        ; face left
loc_6F124:
    jsr    (Event_UpdateObjFacing).l
*/
