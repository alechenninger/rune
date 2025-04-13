// ignore_for_file: constant_identifier_names

import 'package:collection/collection.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/stack.dart';

import '../asm/asm.dart' as asmlib;
import '../model/model.dart';
import 'event.dart';
import 'labels.dart';
import 'memory.dart';

const FacingDir_Up = Constant('FacingDir_Up');
const FacingDir_Down = Constant('FacingDir_Down');
const FacingDir_Left = Constant('FacingDir_Left');
const FacingDir_Right = Constant('FacingDir_Right');

final scriptableObjectRoutine = AsmRoutineModel(Word(0x194));

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
  EventAsm toAsm(Memory ctx,
      {Labeller? labeller,
      FieldRoutineRepository? fieldRoutines,
      bool followLead = false}) {
    labeller ??= Labeller();
    fieldRoutines ??= defaultFieldRoutines;

    var asm = EventAsm.empty();
    var generator = _MovementGenerator(asm, ctx, labeller);

    // We're going to loop through all movements and remove those from the map
    // when there's nothing left to do.
    var remainingMoves = Map.of(moves.map(
        (moveable, movement) => MapEntry(moveable.resolve(ctx), movement)));

    if (ctx.followLead != followLead &&
        remainingMoves.entries.any((move) =>
            move.key.resolve(ctx) is! MapObject &&
            move.value.distance > 0.steps)) {
      asm.add(followLeader(ctx.followLead = followLead));
    }
    generator.setSpeed(speed);

    if (collideLead) {
      asm.add(Asm([
        BySlot(1).toA4(ctx),
        bset(2.i, priority_flag(a4)),
      ]));
    }

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
          .reduce((min, s) => min.min(s));
      var maxStepsYFirst = movesList
          .map((m) => m.movement.delayOrContinuousStepsWithFirstAxis(Axis.y))
          .reduce((min, s) => min.min(s));

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
            // TODO: may need to wait to be done moving
            // However, if this is a relative movement, we must already
            // know where the object is to prevent collision problems.
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
            if (facing != null &&
                facing != ctx.getFacing(moveable) &&
                movement.continuousPaths.first.length == 0.steps) {
              generator.updateFacing(moveable, facing, i,
                  fieldRoutines: fieldRoutines);
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
        // Subtract one since value is additional frames
        asm.add(doMapUpdateLoop((8 * maxSteps.toInt - 1).toWord));
      }
    }

    if (collideLead) {
      asm.add(Asm([
        BySlot(1).toA4(ctx),
        bclr(2.i, priority_flag(a4)),
      ]));
    }

    if (followLead) {
      for (var slot in Slots.all.skip(1)) {
        var obj = BySlot(slot);
        ctx.positions[obj] = null;
        ctx.clearFacing(obj);
      }
    }

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

EventAsm absoluteMovesToAsm(AbsoluteMoves moves, Memory state,
    {int? eventIndex, Labeller? labeller}) {
  // We assume we don't know the current positions,
  // so we don't know which move is longer.
  // Just start all in parallel.
  // TODO: technically we might know, in which case we could convert this
  // to relative movements which would maintain some more context.
  var asm = EventAsm.empty();
  var generator = _MovementGenerator(asm, state);
  var length = moves.destinations.length;
  var secondaryObjects = <(FieldObject, PositionExpression)>[];
  var doMove = moves.waitForMovements ? moveCharacter : setDestination;

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
    var pos = dest.value;
    var isLast = i == length - 1;

    if (moves.followLeader &&
        (obj is Character && obj.slotAsOf(state) != 1 ||
            (obj is BySlot && obj.index > 1))) {
      throw StateError(
          'cannot move $obj independently when follow leader flag is set');
    }

    generator.asm.add(obj.toA4(generator._mem));
    // TODO: may need to wait for object to be done moving
    // might be okay because this is moving them to a valid position.
    // also, if we're moving them, we likely know the path to avoid collisions,
    // so we probably know they're not otherwise moving randomly.
    generator.ensureScriptable(obj);

    // TODO: need to set animate flag when not waiting for movements and remove from dialog generation
    if (!moves.waitForMovements &&
        // If follow leader is set, we'll set the flags for all slots later
        (obj.isNotCharacter || !moves.followLeader)) {
      asm.add(bset(1.i, priority_flag(a4)));
    }

    switch ((isLast, i)) {
      case (true, 0):
        asm.add(pos.withPosition(
            memory: state,
            load: a3,
            load2: a2,
            asm: (x, y) => doMove(x: x, y: y)));
        break;
      case (false, _):
        asm.add(pos.withPosition(
            memory: state,
            load: a3,
            load2: a2,
            asm: (x, y) => setDestination(x: x, y: y)));

        if (obj.isNotCharacter) {
          secondaryObjects.add((obj, pos));
        }
        break;
      case (true, _):
        if (obj.isCharacter) {
          // Just set destination; we'll move all characters together later.
          asm.add(pos.withPosition(
              memory: state,
              load: a3,
              load2: a2,
              asm: (x, y) => setDestination(x: x, y: y)));
        } else {
          // Move this object (other objects will move in parallel)
          asm.add(pos.withPosition(
              memory: state,
              load: a3,
              load2: a2,
              asm: (x, y) => doMove(x: x, y: y)));

          // Finish moving any other secondary objects
          if (moves.waitForMovements) {
            for (var (obj, pos) in secondaryObjects) {
              asm.add(obj.toA4(state));
              asm.add(pos.withPosition(
                  memory: state,
                  load: a3,
                  load2: a2,
                  asm: (x, y) => moveCharacter(x: x, y: y)));
            }
          }
        }

        // Now ensure characters are done moving.
        if (moves.waitForMovements && secondaryObjects.length < length) {
          asm.add(jsr(Label('Event_MoveCharacters').l));
        }
        break;
    }

    if (moves.waitForMovements) {
      state.putInAddress(a0, null);
      state.putInAddress(a1, null);
      state.putInAddress(a2, null);
      state.putInAddress(a3, null);
      state.putInAddress(a5, null);
      state.putInAddress(a6, null);
    } else if (moves.followLeader) {
      // Because we're following the leader, other characters will move that
      // weren't referenced in destinations.
      // Because we are not waiting for movements, we need to set their animate
      // during dialog bit also.

      // TODO(optimization): this loops through objects again
      // ideally we'd do this just once to set destinations and move bit
      for (var slot in Slots.all) {
        // _memory.animatedDuringDialog(obj); TODO(correctness)
        // Would also need to know what "normal" state is,
        // so we don't clear the bit for objects where it should always be set
        asm.add(Asm([BySlot(slot).toA4(state), bset(1.i, priority_flag(a4))]));
      }
    }

    // TODO(correctness): if not wait for movement?
    // i think we'd have to set destinations in memory, which could also serve
    // as an indicator that we need to wait for movement to finish /
    // animate during dialog.
    state.positions[obj] = pos.known(state);
    // If we don't know which direction the object was coming from,
    // we don't know which direction it will be facing.
    state.clearFacing(obj);
  });

  return asm;
}

Asm waitForMovementsToAsm(WaitForMovements wait, {required Memory memory}) {
  var chars = wait.objects.where((o) => o.isCharacter).toList();
  var secondary = wait.objects.where((o) => o.isNotCharacter).toList();

  memory.stepSpeed = StepSpeed.normal();

  var asm = Asm([
    for (var obj in secondary)
      Asm([
        obj.toA4(memory),
        // TODO(optimization): this is just to redundantly set them in MoveCharacter
        // Could factor this away
        move.w(dest_x_pos(a4), d0),
        move.w(dest_y_pos(a4), d1),
        jsr(Label('Event_MoveCharacter').l),
        // Reset move in dialog bit
        // TODO: this could erroneously change an object that normally animates
        bclr(1.i, priority_flag(a4)),
      ]),
    if (chars.isNotEmpty) jsr(Label('Event_MoveCharacters').l),
    // Reset move in dialog bit
    for (var char in chars)
      Asm([
        char.toA4(memory),
        bclr(1.i, priority_flag(a4)),
      ]),
    // Reset speed
    setStepSpeed(StepSpeed.normal().offset.i),
  ]);

  memory.putInAddress(a0, null);
  memory.putInAddress(a1, null);
  memory.putInAddress(a2, null);
  memory.putInAddress(a3, null);
  memory.putInAddress(a5, null);
  memory.putInAddress(a6, null);

  return asm;
}

Asm instantMovesToAsm(InstantMoves moves, Memory memory,
    {required int eventIndex, DirectAddressRegister load = a4}) {
  var asm = EventAsm.empty();
  var generator = _MovementGenerator(asm, memory);
  var adjustCamera = false;

  for (var MapEntry(key: obj, value: (position, facing))
      in moves.destinations.entries) {
    if (position != null) {
      var slot = obj.slotAsOf(memory);
      if (slot == 1 || slot == null) {
        adjustCamera = true;
      }

      asm.add(
        position.withPosition(
            memory: memory,
            load: load == a4 ? a3 : a4,
            asm: (x, y) {
              load = memory.addressRegisterFor(obj) ?? load;

              var scriptable = generator.scriptable(obj);
              if (!scriptable) {
                memory.setRoutine(obj, scriptableObjectRoutine);
              }

              return Asm([
                obj.toA(load, memory),
                if (!scriptable) ...[
                  move.w(0x8194.toWord.i, load.indirect),
                  move.l(0.i, x_step_constant(a4)),
                  move.l(0.i, y_step_constant(a4)),
                  move.w(0.i, x_step_duration(a4)),
                  move.w(0.i, y_step_duration(a4)),
                ],
                move.w(x, curr_x_pos(load)),
                // Ensure there is no fractional component
                // We can't extend x or y to long
                // because we only have an address, not the actual value
                move.w(Word(0).i, load.plus(curr_x_pos + 2.toValue)),
                move.w(y, curr_y_pos(load)),
                // Ensure there is no fractional component
                move.w(Word(0).i, load.plus(curr_y_pos + 2.toValue)),
                // There is no fractional component to destination values
                // (they are just words)
                move.w(x, dest_x_pos(load)),
                move.w(y, dest_y_pos(load)),
              ]);
            }),
      );

      memory.positions[obj] = position.known(memory);
    }

    if (facing != null) {
      asm.add(
        facing.withDirection(
            labelSuffix: '_${[
              eventIndex,
              _labelSafeString(obj),
            ].whereNotNull().join('_')}',
            memory: memory,
            load1: load == a4 ? a3 : a4,
            load2: load == a4 ? a2 : a3,
            asm: (d) {
              var scriptable = generator.scriptable(obj);
              if (!scriptable) {
                memory.setRoutine(obj, scriptableObjectRoutine);
              }

              return Asm([
                obj.toA(load, memory),
                // TODO: if only facing,
                //  we may need to wait for movements to finish.
                if (!scriptable) move.w(0x8194.toWord.i, load.indirect),
                move.w(d, facing_dir(load)),
                if (!scriptable) ...[
                  move.w(curr_x_pos(load), dest_x_pos(load)),
                  move.w(curr_y_pos(load), dest_y_pos(load)),
                ]
              ]);
            }),
      );

      switch (facing.known(memory)) {
        case Direction d:
          memory.setFacing(obj, d);
          break;
        case null:
          memory.clearFacing(obj);
          break;
      }
    }
  }

  // Reposition objects and camera
  asm.add(Asm([
    move.l(a4, -sp),
    jsr(Label('Field_UpdateObjects').l),
    if (memory.cameraLock != true && adjustCamera) ...[
      jsr(Label('UpdateCameraXPosFG').l),
      jsr(Label('UpdateCameraYPosFG').l),
      jsr(Label('UpdateCameraXPosBG').l),
      jsr(Label('UpdateCameraYPosBG').l),
    ],
    move.l(sp.postIncrement(), a4),
  ]));

  return asm;
}

class _MovementGenerator {
  _MovementGenerator(this.asm, this._mem, [Labeller? labeller])
      : _labeller = labeller ?? Labeller();

  final EventAsm asm;
  final Memory _mem;
  final Labeller _labeller;

  void setStartingAxis(Axis axis) {
    if (_mem.startingAxis != axis) {
      asm.add(moveAlongXAxisFirst(axis == Axis.x));
      _mem.startingAxis = axis;
    }
  }

  void setSpeed(StepSpeed speed) {
    // TODO(movement): move speed to eventstate
    if (speed != _mem.stepSpeed) {
      asm.add(setStepSpeed(speed.offset.i));
      _mem.stepSpeed = speed;
    }
  }

  void resetSpeedFrom(StepSpeed speed) {
    if (speed != StepSpeed.normal()) {
      asm.add(asmlib.move.b(1.i, FieldObj_Step_Offset.w));
      _mem.stepSpeed = StepSpeed.normal();
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
    // TODO(movement generator): character routines can be used on map objects
    //  and these are scriptable.
    return obj.resolve(_mem) is! MapObject ||
        _mem.getRoutine(obj) == scriptableObjectRoutine;
  }

  void updateFacing(FieldObject obj, DirectionExpression dir, int moveIndex,
      {required FieldRoutineRepository fieldRoutines}) {
    var labeller = _labeller.withContext(obj).withContext(moveIndex);
    var labelSuffix = labeller.suffixLocal();

    // This ensures facing doesn't change during subsequent movements.
    if (!scriptable(obj)) {
      asm.add(Asm([
        // If we don't know the current position,
        // we have to be careful because the object may be mid-movement
        // TODO: this can be optimized out if object doesn't move.
        if (obj.position().known(_mem) == null)
          _waitForMovement(
              obj: obj,
              labeller: labeller,
              memory: _mem,
              fieldRoutines: fieldRoutines),
        obj.toA4(_mem),
        asmlib.move.w(0x8194.toWord.i, asmlib.a4.indirect),
        // Destination attributes are not always set,
        // resulting in odd character movements with this routine.
        PositionOfObject(obj).withPosition(
            memory: _mem, asm: (x, y) => setDestination(x: x, y: y)),
      ]));

      _mem.setRoutine(obj, scriptableObjectRoutine);
    }

    asm.add(dir.withDirection(
        labelSuffix: labelSuffix,
        memory: _mem,
        asm: (d) => Asm([
              obj.toA4(_mem,
                  maintain: d is Immediate
                      ? NoneToPush()
                      : PushToStack.one(d0, Size.b)),
              updateObjFacing(d)
            ])));

    _mem.putInAddress(a3, null);

    var known = dir.known(_mem);

    if (known == null) {
      _mem.clearFacing(obj);
    } else {
      _mem.setFacing(obj, known);
    }
  }
}

String _labelSafeString(FieldObject obj) {
  return obj.toString().replaceAll(RegExp(r'[{}:,]'), '');
}

Asm _waitForMovement(
    {required FieldObject obj,
    required Labeller labeller,
    required Memory memory,
    required FieldRoutineRepository fieldRoutines}) {
  var startOfLoop = Labeller.withContext('wait_for_movement')
      .withContextsFrom(labeller)
      .nextLocal();
  return Asm([
    label(startOfLoop),
    obj.toA4(memory, force: false),
    // We can't be sure of the routine at this point
    // –run whatever it is.
    jsr('RunSingleObject'.l),
    jsr(Label('Field_LoadSprites').l),
    jsr(Label('Field_BuildSprites').l),
    //movem.l(d0 - a4, -(sp)),
    jsr(Label('AnimateTiles').l),
    jsr(Label('RunMapUpdates').l),
    jsr(Label('VInt_Prepare').l),
    //movem.l(sp.postIncrement(), d0 - a4),
    obj.toA4(memory, force: true), // force because we know a4 is overwritten
    moveq(0.i, d0),
    move.w(x_step_duration(a4), d0),
    or.w(y_step_duration(a4), d0),
    bne.s(startOfLoop),
  ]);
}

extension FieldObjectAsm on FieldObject {
  int? compactId(EventState mem) {
    return switch (resolve(mem)) {
      // neither bit 6 nor bit 7
      Character c => c.charIdValue.value,
      // bit 7 – these two are both indexes in ram along the same table
      BySlot s => (s.index - 1) | 0x80,
      MapObject m => (mem.currentMap!.indexOf(m.id)! + 12) | 0x80,
      // bit 6, not bit 7
      InteractionObject() => 0x40,
      _ => null,
    };
  }

  bool get hasCompactIdRepresentation {
    return switch (this) {
      Character() ||
      BySlot() ||
      MapObject() ||
      MapObjectById() ||
      InteractionObject() =>
        true,
      _ => false,
    };
  }

  Address routine(FieldRoutineRepository fieldRoutines) {
    return switch (this) {
      Character c => c.routineAddress,
      MapObject m => m.routine(fieldRoutines).label.l,
      // Slot could be loaded from memory and field obj jump think
      _ => throw UnsupportedError('routine for $this')
    };
  }

  bool hasKnownAddress(Memory memory) {
    var obj = this;
    var slot = obj.slotAsOf(memory);
    return switch ((slot, obj)) {
      (int(), _) => true,
      (_, Character()) => true,
      (_, MapObject()) => true,
      (_, MapObjectById()) => true,
      _ => memory.addressRegisterFor(obj) != null,
    };
  }

  /// NOTE! May overwrite data registers.
  ///
  /// By default, will avoid a redundant load if the object is already in a4.
  /// If [force] is true, the load will happen regardless.
  /// This is useful in situations when the instruction may be reached
  /// from multiple source points (e.g. loops).
  /// It can also be useful if you know the register was overwritten
  /// and need to reload it.
  Asm toA4(Memory ctx,
      {bool force = false, PushToStack maintain = const NoneToPush()}) {
    return toA(a4, ctx, force: force, maintain: maintain);
  }

  /// NOTE! May overwrite data registers.
  Asm toA3(Memory ctx) => toA(a3, ctx);

  /// NOTE! May overwrite data registers.
  ///
  /// If [keepA4] is `true` and A4 must be overwritten,
  /// then it will be pushed/popped onto the stack so afterwards
  /// the value in A4 remains the same.
  Asm toA(DirectAddressRegister a, Memory memory,
      {bool force = false, PushToStack maintain = const NoneToPush()}) {
    var current = memory.inAddress(a)?.obj;
    if (!force && (current == this || current == resolve(memory))) {
      return Asm.empty();
    }

    var obj = this;
    Asm asm;

    switch (obj) {
      case MapObject():
        var address = obj.address(memory);
        asm = lea(Absolute.word(address), a);
      case MapObjectById():
        var address = obj.address(memory);
        asm = lea(Absolute.word(address), a);
      case BySlot():
        asm = lea(Constant('Character_${obj.index}').w, a);
      case InteractionObject():
        // TODO: we could generalize this optimization for any object
        if (memory.inAddress(a3)?.obj == obj) {
          // Already in address register; reuse.
          asm = (a == a3) ? Asm.empty() : lea(a3.indirect, a);
        } else {
          // Load index from Interaction_Object_Index
          // See also GetObjectByIndexOrId in asm
          asm = maintain.wrap(Asm([
            comment('Load interaction object'),
            moveq(0.i, d0),
            move.b('Interaction_Object_Index'.w, d0),
            lsl.w(6.i, d0),
            addi.l('Field_Obj_Secondary'.i, d0),
            movea.l(d0, a),
          ]));
        }
      case Character c:
        asm = switch (c.slotAsOf(memory)) {
          var slot? => lea(Constant('Character_$slot').w, a),
          null => maintain.wrap(a == a4
              ? characterByIdToA4(c.charIdAddress)
              : Asm([
                  moveq(c.charIdAddress, d0),
                  Asm.fromRaw('	getcharacter	$a'),
                ]))
        };
      default:
        throw UnsupportedError('toA($a, $this) not implemented');
    }
    memory.putInAddress(a, obj);
    return asm;
  }
}

extension AddressOfMapObjectId on MapObjectById {
  Longword address(EventState ctx) {
    var map = ctx.currentMap;
    if (map == null) {
      throw UnsupportedError('got field obj in map, but map was null. '
          'this=$this');
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
      throw UnsupportedError('got field obj in map, but map was null. '
          'this=$this');
    }
    return map.addressOf(this);
  }
}

const _charIds = [
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
    switch (this) {
      case Shay():
        return Constant('CharID_Chaz');
      default:
        return Constant('CharID_$this');
    }
  }

  Address get charIdAddress => charId.i;

  Address get routineAddress {
    switch (this) {
      case Shay():
        return Label('FieldObj_Chaz').l;
      default:
        return Label('FieldObj_$this').l;
    }
  }

  Value get charIdValue {
    return _charIds.indexOf(runtimeType).toValue;
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

extension DirectionExpressionToAsm on DirectionExpression {
  /// Generates the ASM to retrieve the direction within some address.
  ///
  /// This address is passed to the [asm] callback.
  ///
  /// If a direct data register is needed to load the address,
  /// it is loaded into [destination],
  /// but this does not mean the callback address is
  /// _always_ the `destination` (it may be something else).
  ///
  /// Adjust [load1] and [load2] to change address registers used
  /// to avoid conflicts. These may be used in the resulting address.
  Asm withDirection({
    required Memory memory,
    required Asm Function(Address) asm,
    Address destination = d0,
    DirectAddressRegister load1 = a4,
    DirectAddressRegister load2 = a3,
    String? labelSuffix,
  }) {
    return DirectionExpressionAsm.from(this).withDirection(
        memory: memory,
        asm: asm,
        destination: destination,
        load1: load1,
        load2: load2,
        labelSuffix: labelSuffix);
  }
}

abstract class DirectionExpressionAsm {
  final DirectionExpression expression;

  DirectionExpressionAsm(this.expression);

  factory DirectionExpressionAsm.from(DirectionExpression expression) {
    return switch (expression) {
      Direction d => DirectionAsm(d),
      DirectionOfVector d => DirectionOfVectorAsm(d),
      ObjectFaceDirection d => ObjectFaceDirectionAsm(d),
      OffsetDirection d => OffsetDirectionAsm(d),
    };
  }

  Asm withDirection({
    required Memory memory,
    required Asm Function(Address) asm,
    Address destination = d0,
    DirectAddressRegister load1 = a4,
    DirectAddressRegister load2 = a3,
    String? labelSuffix,
  });
}

class DirectionAsm extends DirectionExpressionAsm {
  final Direction direction;

  DirectionAsm(this.direction) : super(direction);

  @override
  Asm withDirection({
    required Memory memory,
    required Asm Function(Address) asm,
    Address destination = d0,
    DirectAddressRegister load1 = a4,
    DirectAddressRegister load2 = a3,
    String? labelSuffix,
  }) =>
      asm(direction.address);
}

class DirectionOfVectorAsm extends DirectionExpressionAsm {
  final DirectionOfVector directionOfVector;

  DirectionOfVectorAsm(this.directionOfVector) : super(directionOfVector);

  @override
  Asm withDirection({
    required Memory memory,
    required Asm Function(Address) asm,
    Address destination = d0,
    DirectAddressRegister load1 = a4,
    DirectAddressRegister load2 = a3,
    String? labelSuffix,
  }) {
    var known = directionOfVector.known(memory);
    if (known != null) {
      return asm(known.address);
    }

    if (directionOfVector.playerIsFacingFrom) {
      return Asm([
        BySlot.one.toA(load1, memory),
        move.w(facing_dir(load1), destination),
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
      // Diff x
      directionOfVector.to
          .withX(memory: memory, asm: (x) => move.w(x, d2), load: load2),
      directionOfVector.from.withX(
          memory: memory,
          asm: (x) => x is Immediate ? subi.w(x, d2) : sub.w(x, d2),
          load: load1),
      // Diff y
      directionOfVector.to
          .withY(memory: memory, asm: (y) => move.w(y, d3), load: load2),
      // not sure if below comment is still relevant
      // TODO(optimization): could consider allowing a force load of load1
      // even if not needed. this would be an optimization when using
      // updateobjfacing, because we wouldn't need to load later and
      // then have to deal with saving d0 to the stack
      directionOfVector.from.withY(
          memory: memory,
          asm: (y) => y is Immediate ? subi.w(y, d3) : sub.w(y, d3),
          load: load1),
      // Compute the magnitudes of the deltas
      move.w(d2, d4),
      bpl.s(Label('.positive_dx$labelSuffix')),
      neg.w(d4),
      label(Label('.positive_dx$labelSuffix')),
      move.w(d3, d5),
      bpl.s(Label('.positive_dy$labelSuffix')),
      neg.w(d5),
      label(Label('.positive_dy$labelSuffix')),
      // Compare magnitudes
      cmp.w(d4, d5),
      bgt.s(Label('.checky$labelSuffix')),

      // Check horizontal
      tst.w(d2),
      bpl.s(Label('.right$labelSuffix')),
      move.w(FacingDir_Left.i, destination),
      bra.s(Label('.keep$labelSuffix')), // keep
      label(Label('.right$labelSuffix')),
      move.w(FacingDir_Right.i, destination),
      bra.s(Label('.keep$labelSuffix')), // keep

      // Check vertical
      label(Label('.checky$labelSuffix')),
      tst.w(d3),
      bpl.s(Label('.down$labelSuffix')),
      move.w(FacingDir_Up.i, destination),
      bra.s(Label('.keep$labelSuffix')), // keep

      label(Label('.down$labelSuffix')),
      move.w(FacingDir_Down.i, destination),

      label(Label('.keep$labelSuffix')),
      asm(destination)
    ]);
  }

  Asm load(Address addr, Memory memory) => withDirection(
      memory: memory,
      asm: (d) => d == addr ? Asm.empty() : move.b(d, addr),
      destination: addr);
}

class ObjectFaceDirectionAsm extends DirectionExpressionAsm {
  final ObjectFaceDirection objectFaceDirection;

  ObjectFaceDirectionAsm(this.objectFaceDirection) : super(objectFaceDirection);

  @override
  Asm withDirection({
    required Memory memory,
    required Asm Function(Address) asm,
    Address destination = d0,
    DirectAddressRegister load1 = a4,
    DirectAddressRegister load2 = a3,
    String? labelSuffix,
  }) {
    return Asm([
      objectFaceDirection.obj.toA(load1, memory),
      asm(facing_dir(load1)),
    ]);
  }
}

class OffsetDirectionAsm extends DirectionExpressionAsm {
  final OffsetDirection offsetDirection;

  OffsetDirectionAsm(this.offsetDirection) : super(offsetDirection);

  @override
  Asm withDirection({
    required Memory memory,
    required Asm Function(Address) asm,
    Address destination = d0,
    DirectAddressRegister load1 = a4,
    DirectAddressRegister load2 = a3,
    String? labelSuffix,
  }) {
    return Asm([
      offsetDirection.base.withDirection(
        memory: memory,
        destination: destination,
        load1: load1,
        load2: load2,
        labelSuffix: labelSuffix,
        asm: offsetDirection.turns == 0
            ? asm
            : (d) {
                var skip = Label('.skip${labelSuffix ?? ''}');
                return Asm([
                  ...(switch (offsetDirection.turns) {
                    1 => [
                        move.w(d, destination),
                        bchg(3.i, destination),
                        bne(skip),
                        bchg(2.i, destination),
                        label(skip),
                      ],
                    2 => [
                        move.w(d, destination),
                        bchg(2.i, destination),
                      ],
                    3 => [
                        move.w(d, destination),
                        bchg(3.i, destination),
                        beq(skip),
                        bchg(2.i, destination),
                        label(skip),
                      ],
                    _ => []
                  }),
                  asm(destination)
                ]);
              },
      ),
    ]);
  }
}

extension PositionExpressionToAsm on PositionExpression {
  Asm withPosition(
      {required Memory memory,
      required Asm Function(Address x, Address y) asm,
      DirectDataRegister loadX = d0,
      DirectDataRegister loadY = d1,
      DirectAddressRegister load = a4,
      DirectAddressRegister load2 = a3}) {
    return PositionExpressionAsm.from(this).withPosition(
        memory: memory,
        asm: asm,
        loadX: loadX,
        loadY: loadY,
        load: load,
        load2: load2);
  }

  Asm withX(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadX = d1,
      DirectAddressRegister load = a4}) {
    return PositionExpressionAsm.from(this)
        .withX(memory: memory, asm: asm, loadX: loadX, load: load);
  }

  Asm withY(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadY = d2,
      DirectAddressRegister load = a4}) {
    return PositionExpressionAsm.from(this)
        .withY(memory: memory, asm: asm, loadY: loadY, load: load);
  }
}

// Position Expression ASM classes
abstract class PositionExpressionAsm {
  final PositionExpression expression;

  PositionExpressionAsm(this.expression);

  factory PositionExpressionAsm.from(PositionExpression expression) {
    return switch (expression) {
      Position p => PositionAsm(p),
      PositionOfObject p => PositionOfObjectAsm(p),
      PositionOfXY p => PositionOfXYAsm(p),
      OffsetPosition p => OffsetPositionAsm(p),
    };
  }

  // TODO: technically position should return longwords,
  //   but we treat as word only
  Asm withPosition(
      {required Memory memory,
      required Asm Function(Address x, Address y) asm,
      DirectDataRegister loadX = d0,
      DirectDataRegister loadY = d1,
      DirectAddressRegister load = a4,
      DirectAddressRegister load2 = a3});

  Asm withX(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadX = d1,
      DirectAddressRegister load = a4});

  Asm withY(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadY = d2,
      DirectAddressRegister load = a4});
}

class PositionAsm extends PositionExpressionAsm {
  final Position position;

  PositionAsm(this.position) : super(position);

  @override
  Asm withPosition(
      {required Memory memory,
      required Asm Function(Address x, Address y) asm,
      DirectDataRegister loadX = d0,
      DirectDataRegister loadY = d1,
      DirectAddressRegister load = a4,
      DirectAddressRegister load2 = a3}) {
    return asm(position.x.toWord.i, position.y.toWord.i);
  }

  @override
  Asm withX(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadX = d1,
      DirectAddressRegister load = a4}) {
    return asm(position.x.toWord.i);
  }

  @override
  Asm withY(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadY = d2,
      DirectAddressRegister load = a4}) {
    return asm(position.y.toWord.i);
  }
}

class PositionOfObjectAsm extends PositionExpressionAsm {
  final PositionOfObject positionOfObject;

  PositionOfObjectAsm(this.positionOfObject) : super(positionOfObject);

  @override
  Asm withPosition(
      {required Memory memory,
      required Asm Function(Address x, Address y) asm,
      DirectDataRegister loadX = d0,
      DirectDataRegister loadY = d1,
      DirectAddressRegister load = a4,
      DirectAddressRegister load2 = a3}) {
    var position = memory.positions[positionOfObject.obj];
    if (position != null) {
      return asm(position.x.toWord.i, position.y.toWord.i);
    }

    load = memory.addressRegisterFor(positionOfObject.obj) ?? load;

    // Evaluate at runtime
    return Asm([
      positionOfObject.obj.toA(load, memory),
      asm(curr_x_pos(load), curr_y_pos(load)),
    ]);
  }

  @override
  Asm withX(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadX = d1,
      DirectAddressRegister load = a4}) {
    return withPosition(memory: memory, asm: (x, _) => asm(x), load: load);
  }

  @override
  Asm withY(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadY = d2,
      DirectAddressRegister load = a4}) {
    return withPosition(memory: memory, asm: (_, y) => asm(y), load: load);
  }
}

class PositionOfXYAsm extends PositionExpressionAsm {
  final PositionOfXY positionOfXY;

  PositionOfXYAsm(this.positionOfXY) : super(positionOfXY);

  @override
  Asm withPosition(
      {required Memory memory,
      required Asm Function(Address x, Address y) asm,
      DirectDataRegister loadX = d0,
      DirectDataRegister loadY = d1,
      DirectAddressRegister load = a4,
      DirectAddressRegister load2 = a3}) {
    return positionOfXY.x.withValue(
        memory: memory,
        load: load,
        asm: (x) {
          return positionOfXY.y.withValue(
              memory: memory,
              load: load2,
              asm: (y) {
                return asm(x, y);
              });
        });
  }

  @override
  Asm withX(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadX = d1,
      DirectAddressRegister load = a4}) {
    return positionOfXY.x
        .withValue(memory: memory, load: load, asm: (x) => asm(x));
  }

  @override
  Asm withY(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadY = d2,
      DirectAddressRegister load = a4}) {
    return positionOfXY.y
        .withValue(memory: memory, load: load, asm: (y) => asm(y));
  }
}

class OffsetPositionAsm extends PositionExpressionAsm {
  final OffsetPosition offsetPosition;

  OffsetPositionAsm(this.offsetPosition) : super(offsetPosition);

  @override
  Asm withPosition(
      {required Memory memory,
      required Asm Function(Address x, Address y) asm,
      DirectDataRegister loadX = d0,
      DirectDataRegister loadY = d1,
      DirectAddressRegister load = a4,
      DirectAddressRegister load2 = a3}) {
    if (offsetPosition.known(memory) case var p?) {
      return asm(p.x.toWord.i, p.y.toWord.i);
    }

    return offsetPosition.base.withPosition(
        memory: memory,
        asm: (x, y) {
          var computation = Asm.empty();

          var xOp = switch (offsetPosition.offset.x) {
            > 0 => addi.w,
            < 0 => subi.w,
            _ => null
          };
          var yOp = switch (offsetPosition.offset.y) {
            > 0 => addi.w,
            < 0 => subi.w,
            _ => null
          };
          Address offsetX = loadX;
          Address offsetY = loadY;

          if (xOp != null) {
            if (x is DirectDataRegister) {
              offsetX = x;
            } else {
              computation.add(move.w(x, offsetX));
            }
            computation
                .add(xOp(offsetPosition.offset.x.abs().toWord.i, offsetX));
          } else {
            offsetX = x;
          }

          if (yOp != null) {
            if (y is DirectDataRegister) {
              offsetY = y;
            } else {
              computation.add(move.w(y, offsetY));
            }
            computation
                .add(yOp(offsetPosition.offset.y.abs().toWord.i, offsetY));
          } else {
            offsetY = y;
          }

          return Asm([computation, asm(offsetX, offsetY)]);
        },
        load: load,
        load2: load2);
  }

  @override
  Asm withX(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadX = d1,
      DirectAddressRegister load = a4}) {
    return offsetPosition.base.withX(
        memory: memory,
        asm: (x) {
          var computation = Asm.empty();

          var xOp = switch (offsetPosition.offset.x) {
            > 0 => addi.w,
            < 0 => subi.w,
            _ => null
          };
          Address offsetX = loadX;

          if (xOp != null) {
            if (x is DirectDataRegister) {
              offsetX = x;
            } else {
              computation.add(move.w(x, offsetX));
            }
            computation
                .add(xOp(offsetPosition.offset.x.abs().toWord.i, offsetX));
          } else {
            offsetX = x;
          }

          return Asm([computation, asm(offsetX)]);
        },
        load: load);
  }

  @override
  Asm withY(
      {required Memory memory,
      required Asm Function(Address) asm,
      DirectDataRegister loadY = d2,
      DirectAddressRegister load = a4}) {
    return offsetPosition.base.withY(
        memory: memory,
        asm: (y) {
          var computation = Asm.empty();

          var yOp = switch (offsetPosition.offset.y) {
            > 0 => addi.w,
            < 0 => subi.w,
            _ => null
          };
          Address offsetY = loadY;

          if (yOp != null) {
            if (y is DirectDataRegister) {
              offsetY = y;
            } else {
              computation.add(move.w(y, offsetY));
            }
            computation
                .add(yOp(offsetPosition.offset.y.abs().toWord.i, offsetY));
          } else {
            offsetY = y;
          }

          return Asm([computation, asm(offsetY)]);
        },
        load: load);
  }
}

extension PositionComponentExpressionToAsm on PositionComponentExpression {
  Asm withValue({
    required Memory memory,
    required Asm Function(Address) asm,
    DirectDataRegister loadVal = d0,
    DirectAddressRegister load = a4,
  }) {
    return PositionComponentExpressionAsm.from(this)
        .withValue(memory: memory, asm: asm, loadVal: loadVal, load: load);
  }
}

// Position Component Expression ASM classes
abstract class PositionComponentExpressionAsm {
  final PositionComponentExpression expression;

  PositionComponentExpressionAsm(this.expression);

  factory PositionComponentExpressionAsm.from(
      PositionComponentExpression expression) {
    return switch (expression) {
      PositionComponent p => PositionComponentAsm(p),
      PositionComponentOfObject p => PositionComponentOfObjectAsm(p),
      OffsetPositionComponent p => OffsetPositionComponentAsm(p),
    };
  }

  Asm withValue({
    required Memory memory,
    required Asm Function(Address c) asm,
    DirectDataRegister loadVal = d0,
    DirectAddressRegister load = a4,
  });
}

class PositionComponentAsm extends PositionComponentExpressionAsm {
  final PositionComponent positionComponent;

  PositionComponentAsm(this.positionComponent) : super(positionComponent);

  @override
  Asm withValue({
    required Memory memory,
    required Asm Function(Address c) asm,
    DirectDataRegister loadVal = d0,
    DirectAddressRegister load = a4,
  }) {
    return asm(Word(positionComponent.value).i);
  }
}

class PositionComponentOfObjectAsm extends PositionComponentExpressionAsm {
  final PositionComponentOfObject positionComponentOfObject;

  PositionComponentOfObjectAsm(this.positionComponentOfObject)
      : super(positionComponentOfObject);

  @override
  Asm withValue({
    required Memory memory,
    required Asm Function(Address a) asm,
    DirectDataRegister loadVal = d0,
    DirectAddressRegister load = a4,
  }) {
    var offset = switch (positionComponentOfObject.component) {
      Axis.x => curr_x_pos,
      _ => curr_y_pos
    };

    load = memory.addressRegisterFor(positionComponentOfObject.obj) ?? load;

    return Asm([
      positionComponentOfObject.obj.toA(load, memory),
      asm(offset(load)),
    ]);
  }
}

class OffsetPositionComponentAsm extends PositionComponentExpressionAsm {
  final OffsetPositionComponent offsetPositionComponent;

  OffsetPositionComponentAsm(this.offsetPositionComponent)
      : super(offsetPositionComponent);

  @override
  Asm withValue({
    required Memory memory,
    required Asm Function(Address) asm,
    DirectDataRegister loadVal = d0,
    DirectAddressRegister load = a4,
  }) {
    return offsetPositionComponent.base.withValue(
        memory: memory,
        load: load,
        asm: (b) {
          var computation = Asm.empty();

          var op = switch (offsetPositionComponent.offset) {
            > 0 => addi.w,
            < 0 => subi.w,
            _ => null
          };
          Address offsetVal = loadVal;

          if (op != null) {
            if (b is DirectDataRegister) {
              offsetVal = b;
            } else {
              computation.add(move.w(b, offsetVal));
            }
            computation.add(
                op(offsetPositionComponent.offset.abs().toWord.i, offsetVal));
          } else {
            offsetVal = b;
          }

          return Asm([computation, asm(offsetVal)]);
        });
  }
}

extension Vector2dExpressionToAsm on Vector2dExpression {
  Asm withVector({
    required Memory memory,
    required Asm Function(Address x, Address y) asm,
    Labeller? labeller,
    DirectDataRegister destinationX = d0,
    DirectDataRegister destinationY = d1,
  }) {
    return Vector2dExpressionAsm.from(this).withVector(
        memory: memory,
        asm: asm,
        labeller: labeller,
        destinationX: destinationX,
        destinationY: destinationY);
  }
}

// Vector2d Expression ASM classes
abstract class Vector2dExpressionAsm {
  final Vector2dExpression expression;

  Vector2dExpressionAsm(this.expression);

  factory Vector2dExpressionAsm.from(Vector2dExpression expression) {
    return switch (expression) {
      Vector2dOfXY v => Vector2dOfXYAsm(v),
      Vector2dProjectionExpression p => Vector2dProjectionExpressionAsm(p),
    };
  }

  Asm withVector({
    required Memory memory,
    required Asm Function(Address x, Address y) asm,
    Labeller? labeller,
    DirectDataRegister destinationX = d0,
    DirectDataRegister destinationY = d1,
  });
}

class Vector2dOfXYAsm extends Vector2dExpressionAsm {
  final Vector2dOfXY vector2dOfXY;

  Vector2dOfXYAsm(this.vector2dOfXY) : super(vector2dOfXY);

  @override
  Asm withVector({
    required Memory memory,
    required Asm Function(Address x, Address y) asm,
    Labeller? labeller,
    DirectDataRegister destinationX = d0,
    DirectDataRegister destinationY = d1,
  }) {
    labeller ??= Labeller();
    return DoubleExpressionAsm.from(vector2dOfXY.x).withValue(
        memory: memory,
        labeller: labeller,
        asm: (x) => DoubleExpressionAsm.from(vector2dOfXY.y).withValue(
            memory: memory, labeller: labeller, asm: (y) => asm(x, y)));
  }
}

class Vector2dProjectionExpressionAsm extends Vector2dExpressionAsm {
  final Vector2dProjectionExpression vector2dProjectionExpression;

  Vector2dProjectionExpressionAsm(this.vector2dProjectionExpression)
      : super(vector2dProjectionExpression);

  @override
  Asm withVector({
    required Memory memory,
    required Asm Function(Address x, Address y) asm,
    Labeller? labeller,
    DirectDataRegister destinationX = d0,
    DirectDataRegister destinationY = d1,
  }) {
    if (vector2dProjectionExpression.known(memory) case var p?) {
      return asm(Longword(0x10000).signedMultiply(p.x).i,
          Longword(0x10000).signedMultiply(p.y).i);
    }

    labeller ??= Labeller();

    // Implements a simple projection where the second vector
    // is only a simple cardinal direction unit vector.
    // This could be generalized to any two vectors but would be complicated.
    return Vector2dExpressionAsm.from(vector2dProjectionExpression.vector)
        .withVector(
            memory: memory,
            labeller: labeller,
            destinationX: destinationX,
            destinationY: destinationY,
            asm: (x, y) {
              var keep = labeller!.withContext('keep').nextLocal();
              var xMove = labeller.withContext('xmove').nextLocal();
              return Asm([
                if (x is! Immediate && x != destinationX)
                  move.l(x, destinationX),
                if (y is! Immediate && y != destinationY)
                  move.l(y, destinationY),
                vector2dProjectionExpression.direction.withDirection(
                    memory: memory,
                    destination: d2,
                    labelSuffix: labeller.suffixLocal(),
                    // We don't care about conflicting loads here,
                    // because the facing value is only used for this computation.
                    asm: (d) => Asm([
                          btst(3.i, d),
                          bne.s(xMove),
                          moveq(0.i, destinationX),
                          if (y is Immediate) move.l(y, destinationY),
                          cmpi.b(FacingDir_Down.i, d),
                          beq.s(keep),
                          neg.l(destinationY),
                          bra.s(keep),
                          label(xMove),
                          if (x is Immediate) move.l(x, destinationX),
                          moveq(0.i, destinationY),
                          cmpi.b(FacingDir_Right.i, d),
                          beq.s(keep),
                          neg.l(destinationX),
                          label(keep),
                          asm(destinationX, destinationY),
                        ]))
              ]);
            });
  }
}

// Double Expression ASM classes
abstract class DoubleExpressionAsm {
  final DoubleExpression expression;

  DoubleExpressionAsm(this.expression);

  factory DoubleExpressionAsm.from(DoubleExpression expression) {
    return switch (expression) {
      Double d => DoubleAsm(d),
    };
  }

  Asm withValue({
    required Memory memory,
    required Asm Function(Address) asm,
    Labeller? labeller,
  });
}

class DoubleAsm extends DoubleExpressionAsm {
  final Double doubleValue;

  DoubleAsm(this.doubleValue) : super(doubleValue);

  @override
  Asm withValue({
    required Memory memory,
    required Asm Function(Address) asm,
    Labeller? labeller,
  }) {
    return asm(Longword(0x10000).signedMultiply(doubleValue.value).i);
  }
}
