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
  EventAsm toAsm(Memory ctx, {int? eventIndex}) {
    var asm = EventAsm.empty();
    var generator = _MovementGenerator(asm, ctx, eventIndex);

    // We're going to loop through all movements and remove those from the map
    // when there's nothing left to do.
    var remainingMoves = Map.of(moves.map(
        (moveable, movement) => MapEntry(moveable.resolve(ctx), movement)));

    if (ctx.followLead != false &&
        remainingMoves.entries.any((move) =>
            move.key.resolve(ctx) is! MapObject &&
            move.value.distance > 0.steps)) {
      asm.add(followLeader(ctx.followLead = false));
    }
    generator.setSpeed(speed);

    while (remainingMoves.isNotEmpty) {
      // I tried using a sorted set but iterator was bugged and skipped elements
      var movesList = remainingMoves.entries
          .map((e) => RelativeMove(e.key, e.value))
          .toList();

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
            generator.ensureScriptable(moveable);

            asm.add(moveable.position().withPosition(
                memory: ctx,
                asm: (x, y) => _moveObject(
                    movement: afterSteps,
                    object: moveable,
                    runMove: i == lastMoveIndex,
                    currentX: x,
                    currentY: y,
                    mem: ctx)));
          } else {
            var facing = movement.facing;
            if (movement.distance == 0.steps &&
                facing != null &&
                facing != ctx.getFacing(moveable)) {
              generator.updateFacing(moveable, facing, i);
            }
          }
        }

        movement = movement.less(stepsToTake);

        if (movement.still) {
          remainingMoves.remove(moveable);
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

Asm _moveObject({
  required MovementLookahead movement,
  required FieldObject object,
  required bool runMove,
  required Address currentX,
  required Address currentY,
  required Memory mem,
}) {
  var relativePosition = movement.relativePosition;

  if (currentX is Immediate && currentY is Immediate) {
    var destination =
        Position(currentX.value, currentY.value) + relativePosition;
    mem.positions[object] = destination;
    mem.setFacing(object, movement.facing);

    var x = destination.x.toWord.i;
    var y = destination.y.toWord.i;

    return Asm([
      object.toA4(mem),
      if (runMove) moveCharacter(x: x, y: y) else setDestination(x: x, y: y)
    ]);
  } else {
    mem.positions[object] = null;
    mem.setFacing(object, movement.facing);

    return Asm([
      asmlib.move.w(currentX, d0),
      asmlib.move.w(currentY, d1),
      _addRelativePosition(relativePosition, d0, d1),
      object.toA4(mem),
      if (runMove)
        jsr(Label('Event_MoveCharacter').l)
      else
        setDestination(x: d0, y: d1)
    ]);
  }
}

Asm _addRelativePosition(Position position, Address x, Address y) {
  var xDiff = position.x;
  var yDiff = position.y;

  return Asm([
    if (xDiff > 0)
      addi.w(xDiff.toWord.i, x)
    else if (xDiff < 0)
      subi.w(xDiff.abs().toWord.i, x),
    if (yDiff > 0)
      addi.w(yDiff.toWord.i, y)
    else if (yDiff < 0)
      subi.w(yDiff.abs().toWord.i, y)
  ]);
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
    if (state.followLead != false &&
        moves.destinations.keys
            .any((obj) => obj.resolve(state) is! MapObject)) {
      asm.add(followLeader(state.followLead = false));
    }
  } else if (state.followLead != true) {
    asm.add(followLeader(state.followLead = true));
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

    generator.asm.add(obj.toA4(generator._mem));
    generator.ensureScriptable(obj);

    if (length == 1) {
      asm.add(moveCharacter(x: pos.x.toWord.i, y: pos.y.toWord.i));
    } else {
      asm.add(setDestination(x: pos.x.toWord.i, y: pos.y.toWord.i));
      if (i == length - 1) {
        asm.add(jsr(Label('Event_MoveCharacters').l));
      }
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
  _MovementGenerator(this.asm, this._mem, [this._eventIndex]);

  final EventAsm asm;
  final Memory _mem;
  final int? _eventIndex;

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

  /// Returns true if object is made scriptable.
  bool ensureScriptable(FieldObject obj) {
    obj = obj.resolve(_mem);

    if (!scriptable(obj)) {
      // Make map object scriptable
      asm.add(obj.toA4(_mem));
      asm.add(asmlib.move.w(0x8194.toWord.i, asmlib.a4.indirect));
      _mem.setRoutine(obj, scriptableObjectRoutine);
      return true;
    }

    return false;
  }

  bool scriptable(FieldObject obj) {
    return obj.resolve(_mem) is! MapObject ||
        _mem.getRoutine(obj) == scriptableObjectRoutine;
  }

  void updateFacing(FieldObject obj, DirectionExpression dir, int moveIndex) {
    asm.add(dir.withDirection(
        labelSuffix: '_${[
          _eventIndex,
          _labelSafeString(obj),
          moveIndex
        ].whereNotNull().join('_')}',
        memory: _mem,
        asm: (d) {
          return Asm([
            obj.toA4(_mem),
            // This ensures facing doesn't change during subsequent movements.
            if (!scriptable(obj)) ...[
              asmlib.move.w(0x8194.toWord.i, asmlib.a4.indirect),
              // Destination attributes are not always set,
              // resulting in odd character movements with this routine.
              PositionOfObject(obj).withPosition(
                  memory: _mem, asm: (x, y) => setDestination(x: x, y: y)),
            ],
            updateObjFacing(d)
          ]);
        }));

    _mem.setRoutine(obj, scriptableObjectRoutine);
    _mem.putInAddress(a3, null);

    var known = dir.known(_mem);

    if (known == null) {
      _mem.clearFacing(obj);
    } else {
      _mem.setFacing(obj, known);
    }
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

String _labelSafeString(FieldObject obj) {
  return obj.toString().replaceAll(RegExp(r'[{}:,]'), '');
}

extension FieldObjectAsm on FieldObject {
  /// NOTE! May overwrite data registers.
  Asm toA4(Memory ctx) {
    if (ctx.inAddress(a4)?.obj == resolve(ctx)) {
      return Asm.empty();
    }

    var obj = this;
    var slot = obj.slot(ctx);

    try {
      if (slot != null) {
        // Slot 1 indexed
        return characterBySlotToA4(slot);
      } else if (obj is Character) {
        return characterByIdToA4(obj.charIdAddress);
      } else if (obj is MapObjectById) {
        var address = obj.address(ctx);
        return lea(Absolute.long(address), a4);
      } else if (obj is MapObject) {
        var address = obj.address(ctx);
        return lea(Absolute.long(address), a4);
      } else if (ctx.inAddress(a3)?.obj == obj) {
        // TODO(movement): this could generalize to checking every a register
        return lea(a3.indirect, a4);
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
    } finally {
      ctx.putInAddress(a4, obj);
    }
  }

  /// NOTE! May overwrite data registers.
  Asm toA3(Memory ctx) => toA(a3, ctx);

  /// NOTE! May overwrite data registers.
  Asm toA(DirectAddressRegister a, Memory memory) {
    if (a == a4) return toA4(memory);

    if (memory.inAddress(a)?.obj == resolve(memory)) {
      return Asm.empty();
    }

    var obj = this;

    try {
      if (obj is MapObject) {
        var address = obj.address(memory);
        return lea(Absolute.long(address), a);
      } else if (obj is MapObjectById) {
        var address = obj.address(memory);
        return lea(Absolute.long(address), a);
      } else if (obj is Slot) {
        // why word? this is what asm appears to do
        return lea('Character_${obj.index}'.toConstant.w, a);
      } else if (obj is InteractionObject &&
          memory.inAddress(a3)?.obj == InteractionObject()) {
        if (a == a3) return Asm.empty();
        return lea(a3.indirect, a);
      } else {
        var asm = Asm([obj.toA4(memory), lea(a4.indirect, a)]);
        memory.putInAddress(a4, obj);
        return asm;
      }
    } finally {
      memory.putInAddress(a, obj);
    }
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
  Direction? known(Memory memory) => switch (this) {
        Direction d => d,
        DirectionOfVector d => d.known(memory),
      };

  Asm withDirection(
      {required Memory memory,
      required Asm Function(Address) asm,
      Address destination = d0,
      String? labelSuffix}) {
    return switch (this) {
      Direction d => asm(d.address),
      DirectionOfVector d => d.withDirection(
          labelSuffix: labelSuffix,
          memory: memory,
          asm: asm,
          destination: destination),
    };
  }

  Asm load(Address to, Memory memory) {
    return switch (this) {
      Direction d => move.b(d.constant.i, to),
      DirectionOfVector d => d.load(to, memory),
    };
  }
}

extension DirectionOfVectorAsm on DirectionOfVector {
  bool get playerIsFacingFrom =>
      from == const InteractionObject().position() && to == Slot.one.position();

  Direction? known(Memory mem) {
    var knownFrom = from.known(mem);
    var knownTo = to.known(mem);
    if (knownFrom == null || knownTo == null) {
      // If we know the player is facing this object,
      // try using the opposite direction of the player facing.
      if (playerIsFacingFrom) {
        var dir = mem.getFacing(Slot.one)?.opposite;
        if (dir is Direction) return dir;
      }

      return null;
    }
    var vector = knownTo - knownFrom;
    if (vector.x == 0 && vector.y == 0) return Direction.up;
    var angle = math.atan2(vector.y, vector.x) * 180 / math.pi;
    return switch (angle) {
      >= -45 && < 45 => Direction.right,
      >= 45 && < 135 => Direction.down,
      >= -135 && < -45 => Direction.up,
      _ => Direction.left
    };
  }

  Asm withDirection(
      {required Memory memory,
      required Asm Function(Address) asm,
      Address destination = d0,
      String? labelSuffix}) {
    var known = this.known(memory);
    if (known != null) {
      return asm(known.address);
    }

    if (playerIsFacingFrom) {
      return Asm([
        Slot.one.toA4(memory),
        move.w(facing_dir(a4), destination),
        bchg(2.i, destination),
        asm(destination),
      ]);
    }

    // todo(optimization): we could make this a noop IF we knew that slot
    // one direction hadn't changed since the interaction started.
    // if (to == const InteractionObject().position() &&
    //     from == Slot.one.position()) {}

    labelSuffix ??= '';

    return Asm([
      to.withY(memory: memory, asm: (y) => move.w(y, d2), load: a3),
      from.withY(
          memory: memory,
          asm: (y) => Asm([
                moveq(FacingDir_Down.i, destination),
                y is Immediate ? cmpi.w(y, d2) : cmp.w(y, d2)
              ]),
          load: a4),
      beq.s(Label(r'.checkx' + labelSuffix)),
      bcc.s(Label(r'.keep' + labelSuffix)), // keep up
      move.w(FacingDir_Up.i, destination),
      bra.s(Label(r'.keep' + labelSuffix)), // keep
      label(Label(r'.checkx' + labelSuffix)),
      move.w(FacingDir_Right.i, destination),
      to.withX(memory: memory, asm: (x) => move.w(x, d2), load: a3),
      from.withX(
          memory: memory,
          asm: (x) => x is Immediate ? cmpi.w(x, d2) : cmp.w(x, d2),
          load: a4),
      bcc.s(Label(r'.keep' + labelSuffix)), // keep up
      move.w(FacingDir_Left.i, destination),
      label(Label(r'.keep' + labelSuffix)),
      asm(destination)
    ]);
  }

  Asm load(Address addr, Memory memory) => withDirection(
      memory: memory,
      asm: (d) => d == addr ? Asm.empty() : move.b(d, addr),
      destination: addr);
}

// TODO(refactor): separate class hierarchy for asm?
// this is essentially trying to be polymorphic
// so it might make sense to convert the model
// to a parallel class hierarchy for generation
// rather than use a bunch of extension methods and switch statements

extension PositionExpressionAsm on PositionExpression {
  Position? known(Memory mem) => switch (this) {
        Position p => p,
        PositionOfObject p => mem.positions[p.obj]
      };

  Asm withPosition(
      {required Memory memory,
      required Asm Function(Address x, Address y) asm,
      DirectAddressRegister load = a4}) {
    return switch (this) {
      Position p => asm(p.x.toWord.i, p.y.toWord.i),
      PositionOfObject p =>
        p.withPosition(memory: memory, asm: asm, load: load),
    };
  }

  Asm withX(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectAddressRegister load = a4}) {
    return switch (this) {
      Position p => asm(p.x.toWord.i),
      PositionOfObject p => p.withX(memory: memory, asm: asm, load: load),
    };
  }

  Asm withY(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectAddressRegister load = a4}) {
    return switch (this) {
      Position p => asm(p.y.toWord.i),
      PositionOfObject p => p.withY(memory: memory, asm: asm, load: load),
    };
  }
}

extension PositionOfObjectAsm on PositionOfObject {
  Asm loadX(Address to, {required Memory memory}) {
    return withX(memory: memory, asm: (x) => move.w(x, to));
  }

  Asm loadY(Address to, {required Memory memory}) {
    return withY(memory: memory, asm: (y) => move.w(y, to));
  }

  Asm withPosition(
      {required Memory memory,
      required Asm Function(Address x, Address y) asm,
      DirectAddressRegister load = a4}) {
    var position = memory.positions[obj];
    if (position != null) {
      return asm(position.x.toWord.i, position.y.toWord.i);
    }
    // Evaluate at runtime
    return Asm([
      obj.toA(load, memory),
      asm(curr_x_pos(load), curr_y_pos(load)),
    ]);
  }

  Asm withX(
          {required Memory memory,
          required Asm Function(Address) asm,
          DirectAddressRegister load = a4}) =>
      withPosition(memory: memory, asm: (x, _) => asm(x), load: load);

  Asm withY(
          {required Memory memory,
          required Asm Function(Address) asm,
          DirectAddressRegister load = a4}) =>
      withPosition(memory: memory, asm: (_, y) => asm(y), load: load);
}
