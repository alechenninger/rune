import 'dart:math';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/movement.dart';

import 'model.dart';

/// The party follows the leader
class PartyMove extends Event {
  Movement movement;
  Axis startingAxis = Axis.x;

  PartyMove(this.movement);

  IndividualMoves toIndividualMoves(EventContext ctx) {
    var individual = IndividualMoves();
    individual.moves[Slot(1)] = movement;

    var positions = <int, Point<int>>{};
    var followerMovements = <FieldObject, StepDirections>{};

    var leadStartPosition = ctx.positions[Slot(1)];
    if (leadStartPosition == null) {
      throw ArgumentError('ctx does not include slot 1 position');
    }

    Point<int> ctxPositionForSlot(int s) {
      var p = ctx.positions[Slot(s)];
      if (p == null) throw ArgumentError('missing character in slot $s');
      return p;
    }

    for (var steps = 1; steps <= movement.duration; steps++) {
      var leaderLookahead = movement.lookahead(steps);
      var nextLeaderPosition = positions[1] =
          leadStartPosition + leaderLookahead.relativePosition * unitsPerStep;

      // TODO: it's possible num characters is variable and not known
      // the assembly appears to be able to query this (e.g. see
      // CalcPartyNumber routine).
      // of course, "just" relying on the follow leader flag would be easier,
      // though it can have slightly different semantics such as how it deals
      // with pauses in movement (i believe the follower leader flag logic would
      // keep characters still while this logic will keep followers moving
      for (var s = 2; s <= ctx.numCharacters; s++) {
        var position = positions[s] ?? ctxPositionForSlot(s);

        StepDirection step;

        if ((position - nextLeaderPosition).steps <= 1) {
          // fixme facing
          step = StepDirection()..delay = 1;
        } else {
          var move = StepToPoint()
            ..from = position
            ..to = nextLeaderPosition
            ..startAlong = startingAxis
            ..direction = ctx.facing[Slot(1)] ?? Direction.up; // fixme

          var lookahead = move.lookahead(1);
          positions[s] = position + lookahead.relativePosition * unitsPerStep;
          step = StepDirection()
            ..direction = lookahead.facing
            ..distance = 1;
        }

        followerMovements.update(Slot(s), (move) => move..step(step),
            ifAbsent: () => StepDirections()..step(step));
      }
    }

    individual.moves.addAll(followerMovements);

    return individual;
  }

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    return generator.partyMoveToAsm(this, ctx);
  }

  @override
  String toString() {
    return 'PartyMove{movement: $movement, startingAxis: $startingAxis}';
  }
}

/// A group of parallel movements
class IndividualMoves extends Event {
  // TODO: what if Slot and Character moveables refer to same Character?
  Map<FieldObject, Movement> moves = {};

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    return generator.individualMovesToAsm(this, ctx);
  }

  int get duration => moves.values
      .map((m) => m.duration)
      .reduce((longest, m) => longest = max(longest, m));

  @override
  String toString() {
    return '$moves';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndividualMoves &&
          runtimeType == other.runtimeType &&
          MapEquality().equals(moves, other.moves);

  @override
  int get hashCode => MapEquality().hash(moves);
}

class Party extends Moveable {
  const Party();

  PartyMove move(Movement m) => PartyMove(m);
}

abstract class Moveable {
  const Moveable();
}

// character by name? character by slot? party?
abstract class FieldObject extends Moveable {
  const FieldObject();

  int compareTo(FieldObject other, EventContext ctx) {
    var thisSlot = slot(ctx);
    var otherSlot = other.slot(ctx);

    if (thisSlot != null && otherSlot != null) {
      return thisSlot.compareTo(otherSlot);
    }

    return toString().compareTo(other.toString());
  }

  int? slot(EventContext c);
}

// TODO: maybe don't do this
abstract class ContextualMovement {
  Movement movementIn(EventContext ctx);
}

abstract class Movement extends ContextualMovement {
  /// Delay in steps before movement starts parallel with other movements.
  int get delay;

  /// Total duration including all delays and movements
  int get duration;

  /// Total distance in steps.
  int get distance;

  /// Current facing direction
  /// TODO: rename
  Direction get direction;

  Movement less(int steps);

  /// Movements which are continuous (there is no pause in between) and should
  /// start immediately (delay should == 0).
  // todo: should this just be StepDirection to include delays?
  List<Vector> get continuousMovements;

  @override
  Movement movementIn(EventContext ctx) => this;

  RelativeMoves lookahead(int steps) {
    if (steps == 0) {
      return RelativeMoves([Vector(0, direction)]);
    }

    var stepsTaken = 0;
    var movements = List.of(continuousMovements);
    var movesMade = <Vector>[];

    while (stepsTaken < steps) {
      for (var i = 0; stepsTaken < steps && i < movements.length; i++) {
        var move = movements[i].min(steps - stepsTaken);
        stepsTaken += move.steps;
        movesMade.add(move);
      }

      var remaining = steps - stepsTaken;
      if (remaining > 0) {
        var after = less(stepsTaken);
        var delayToTake = min(remaining, after.delay);
        after = after.less(delayToTake);
        stepsTaken += delayToTake;
        movements = List.of(after.continuousMovements);
      }
    }

    return RelativeMoves(movesMade);
  }

  /// Continuous movements if one axis is moved at a time, and the first must be
  /// [axis]
  List<Vector> continuousMovementsFirstAxis(Axis axis) {
    if (continuousMovements.isEmpty) return [];
    var first = continuousMovements[0];
    if (first.direction.axis == axis) {
      return continuousMovements.sublist(0, min(2, continuousMovements.length));
    }
    return [first];
  }

  /// The amount of steps in continuous movements limited to one axis at a time
  /// where the first axis is [axis].
  int delayOrContinuousStepsFirstAxis(Axis axis) {
    return delay > 0
        ? delay
        : continuousMovementsFirstAxis(axis)
            .map((m) => m.steps)
            .reduce((sum, s) => sum + s);
  }
}

class StepDirection extends Movement {
  @override
  var direction = Direction.up;
  @override
  var distance = 0;
  @override
  var delay = 0;

  @override
  int get duration => delay + distance;

  Vector get asVector => Vector(distance, direction);

  @override
  List<Vector> get continuousMovements => delay > 0 ? [] : [asVector];

  // TODO: may want to define in base
  // TODO: should have bounds check
  @override
  StepDirection less(int steps) {
    if (steps > distance + delay) throw StateError('negative distance');

    var answer = StepDirection()..direction = direction;

    var lessDelay = min(steps, delay);
    answer.delay = delay - lessDelay;

    var remainingToTravel = steps - lessDelay;
    answer.distance = distance - remainingToTravel;

    return answer;
  }

  @override
  String toString() {
    return 'StepDirection{direction: $direction, distance: $distance, delay: $delay}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepDirection &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          distance == other.distance &&
          delay == other.delay) ||
      (other is StepDirections &&
          other._steps.length == 1 &&
          this == other._steps.first);

  @override
  int get hashCode => direction.hashCode ^ distance.hashCode ^ delay.hashCode;
}

class StepDirections extends Movement {
  final _steps = <StepDirection>[];

  void step(StepDirection step) {
    if (_steps.isEmpty) {
      _steps.add(step);
    } else {
      var last = _steps.last;

      if (last.direction == step.direction) {
        if (step.delay == 0) {
          _steps.removeLast();
          _steps.add(last..distance = last.distance + step.distance);
        } else if (last.delay > 0 && last.distance == 0) {
          _steps.removeLast();
          _steps.add(step..delay = last.delay + step.delay);
        } else {
          _steps.add(step);
        }
      } else {
        _steps.add(step);
      }
    }
  }

  // TODO: this probably doesn't work at any arbitrary point, only at the end.
  //  because distance is 0, hard to know it is actually supposed to generate
  //  code.
  void face(Direction direction) {
    step(StepDirection()..direction = direction);
  }

  @override
  int get distance => _steps.isEmpty
      ? 0
      : _steps.map((e) => e.distance).reduce((sum, d) => sum + d);

  @override
  int get delay => _steps.isEmpty ? 0 : _steps.first.delay;

  @override
  int get duration => _steps.isEmpty
      ? 0
      : _steps.map((s) => s.duration).reduce((sum, d) => sum + d);

  @override
  Direction get direction =>
      // TODO: what to do if no steps?
      _steps.isEmpty ? Direction.down : _steps.first.direction;

  @override
  List<Vector> get continuousMovements => _steps
      .takeWhile((step) => step.delay == 0)
      .map((e) => e.asVector)
      .toList();

  @override
  StepDirections less(int distance) {
    if (distance > duration) throw StateError('negative distance');
    if (distance == 0) return this;

    var totalSubtracted = 0;
    var answer = StepDirections();
    StepDirection? lastStep;

    for (var step in _steps) {
      var canMove = min(distance - totalSubtracted, step.duration);
      lastStep = step.less(canMove);

      if (lastStep.duration > 0 || answer._steps.isNotEmpty) {
        answer.step(lastStep);
      }

      totalSubtracted += canMove;
    }

    if (answer._steps.isEmpty && lastStep != null) {
      answer.step(lastStep);
    }

    return answer;
  }

  @override
  String toString() {
    return 'StepDirections{$_steps}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepDirections &&
          runtimeType == other.runtimeType &&
          ListEquality().equals(_steps, other._steps)) ||
      (other is StepDirection && _steps.length == 1 && _steps.first == other);

  @override
  int get hashCode =>
      _steps.length == 1 ? _steps.first.hashCode : ListEquality().hash(_steps);
}

class ContextualStepToPoint extends ContextualMovement {
  var direction = Direction.up;

  int delay = 0;

  Point<int> to = Point(0, 0);

  Axis startAlong = Axis.x;

  final Point<int> Function(EventContext ctx) from;

  ContextualStepToPoint(this.from);

  @override
  Movement movementIn(EventContext ctx) {
    return StepToPoint()
      ..direction = direction
      ..delay = delay
      ..to = to
      ..startAlong = startAlong
      ..from = from(ctx);
  }
}

/// Simple axis-by-axis movement to a point.
class StepToPoint extends Movement {
  // TODO could be used to inform whether multiple characters movements need
  //   to be split up into multiple movement events
  @override
  var direction = Direction.up;

  @override
  int get distance => movement.steps;

  @override
  int delay = 0;

  @override
  int get duration => delay + distance;

  Point<int> from = Point(0, 0);
  Point<int> to = Point(0, 0);
  Point<int> get movement => to - from;

  Axis startAlong = Axis.x;

  /// Just changes starting point because end point is set.
  @override
  StepToPoint less(int steps) {
    if (steps > duration) throw ArgumentError('negative distance');

    var lessDelay = min(delay, steps);
    var remaining = steps - lessDelay;

    var movements = _movements();
    var firstMove = movements[0].min(remaining);

    remaining = remaining - firstMove.steps;

    var secondMove = movements[1].min(remaining);

    var newDelay = delay - lessDelay;
    var newStart = from + firstMove.asPoint + secondMove.asPoint;

    return StepToPoint()
      ..delay = newDelay
      ..from = newStart
      ..to = to
      ..startAlong = startAlong;
  }

  @override
  List<Vector> get continuousMovements {
    if (delay > 0) return [];
    List<Vector> movesAfterDelay = _movements();
    return movesAfterDelay;
  }

  List<Vector> _movements() {
    var first = (startAlong * movement) ~/ unitsPerStep;
    var second = (startAlong.perpendicular * movement) ~/ unitsPerStep;
    return [if (first.steps > 0) first, if (second.steps > 0) second];
  }

  @override
  String toString() {
    return 'StepToPoint{direction: $direction, delay: $delay, from: $from, to: $to, startAlong: $startAlong}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepToPoint &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          delay == other.delay &&
          from == other.from &&
          to == other.to &&
          startAlong == other.startAlong;

  @override
  int get hashCode =>
      direction.hashCode ^
      delay.hashCode ^
      from.hashCode ^
      to.hashCode ^
      startAlong.hashCode;
}

// class Follow extends Movement {
//   Moveable following;
//   @override
//   int distance = 0;
//
//   // or predicate?
//   // probably can't because its not like we're evaluating the
//   // program step by step...
//   // Point? until;
//
//   @override
//   var delay = 0;
//   int? stopAfterDistance;
//   int? stopAfterMovements;
//
//   Follow(this.following, {this.distance = 0});
// }

const up = Direction.up;
const down = Direction.down;
const left = Direction.left;
const right = Direction.right;

class Direction {
  final Point<int> normal;
  const Direction._(this.normal);
  static const up = Direction._(Point(0, -1));
  static const left = Direction._(Point(-1, 0));
  static const right = Direction._(Point(1, 0));
  static const down = Direction._(Point(0, 1));

  static Direction ofPoint(Point<int> p) {
    if (p.x * p.y != 0 || p.x + p.y == 0) {
      throw ArgumentError();
    }
    if (p.x > 0) {
      return right;
    }
    if (p.x < 0) {
      return left;
    }
    if (p.y > 0) {
      return down;
    }
    return up;
  }

  Vector operator *(int magnitude) => Vector(magnitude, this);

  Axis get axis => normal.x == 0 ? Axis.y : Axis.x;

  @override
  String toString() {
    return 'Direction{normal: $normal}';
  }
}

class Axis {
  final Point<int> _normal;

  const Axis._(this._normal);

  static final x = Axis._(Point(1, 0));
  static final y = Axis._(Point(0, 1));

  Axis get perpendicular => Axis._(Point(_normal.y, _normal.x));

  Vector operator *(Point<int> p) {
    var product = Point(p.x * _normal.x, p.y * _normal.y);

    if (product.distance == 0) {
      // todo: eh?
      return Vector(0, Direction.ofPoint(_normal));
    }

    return Direction.ofPoint(product) * product.distance;
  }

  @override
  String toString() {
    return 'Axis.${_normal.x > 0 ? 'x' : 'y'}';
  }
}

class Vector {
  final int steps;
  final Direction direction;

  Vector(this.steps, this.direction);

  Point<int> get asPoint => direction.normal * steps;

  Vector less(int steps) => Vector(this.steps - steps, direction);

  Vector max(int steps) => Vector(math.max(this.steps, steps), direction);

  Vector min(int steps) => Vector(math.min(this.steps, steps), direction);

  Vector operator ~/(int i) => Vector(steps ~/ i, direction);

  @override
  String toString() {
    return '$direction * $steps';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector &&
          runtimeType == other.runtimeType &&
          steps == other.steps &&
          direction == other.direction;

  @override
  int get hashCode => steps.hashCode ^ direction.hashCode;
}

extension PointModel<T extends num> on Point<T> {
  T get distance => (x.abs() + y.abs()) as T;
  int get steps => distance ~/ unitsPerStep;
}

class RelativeMoves {
  final List<Vector> movesMade;
  Point<int> get relativePosition =>
      movesMade.map((m) => m.asPoint).reduce((sum, p) => sum + p);
  Direction get facing => movesMade.last.direction;
  int get relativeDistance => relativePosition.distance;

  RelativeMoves(this.movesMade) {
    if (movesMade.isEmpty) {
      throw ArgumentError('must not be empty', 'movesMade');
    }
  }
}

class Move<T extends Moveable> {
  final T moveable;
  final Movement movement;

  Move(this.moveable, this.movement);

  @override
  String toString() {
    return 'Move{moveable: $moveable, movement: $movement}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Move &&
          runtimeType == other.runtimeType &&
          moveable == other.moveable &&
          movement == other.movement;

  @override
  int get hashCode => moveable.hashCode ^ movement.hashCode;
}
