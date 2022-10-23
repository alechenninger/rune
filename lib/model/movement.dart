import 'dart:math';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/movement.dart';

import 'model.dart';

class Steps implements Comparable<Steps> {
  final int toInt;

  Steps(this.toInt);

  @override
  int compareTo(Steps other) {
    return toInt.compareTo(other.toInt);
  }

  int get toPixels => toInt * unitsPerStep;

  Steps min(Steps other) => math.min(toInt, other.toInt).steps;
  Steps max(Steps other) => math.max(toInt, other.toInt).steps;

  Steps operator +(Steps other) => Steps(toInt + other.toInt);
  Steps operator -(Steps other) => Steps(toInt - other.toInt);
  Steps operator -() => Steps(-toInt);
  Steps operator *(int other) => Steps(toInt * other);
  Steps operator %(int other) => Steps(toInt % other);
  Steps operator ~/(int other) => Steps(toInt ~/ other);
  bool operator <(Steps other) => toInt < other.toInt;
  bool operator <=(Steps other) => toInt <= other.toInt;
  bool operator >(Steps other) => toInt > other.toInt;
  bool operator >=(Steps other) => toInt >= other.toInt;

  @override
  String toString() => '$toInt';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Steps &&
          runtimeType == other.runtimeType &&
          toInt == other.toInt;

  @override
  int get hashCode => toInt.hashCode;
}

extension IntToSteps on int {
  Steps get step => Steps(this);
  Steps get steps => Steps(this);
  Steps get pixelsToSteps => Steps(this ~/ unitsPerStep);
}

/// A walkable path in a single direction.
class Path {
  final Steps length;
  final Direction direction;

  Path(this.length, this.direction);

  Position get asPosition => direction.normal * length.toPixels;

  Path less(Steps length) => Path(this.length - length, direction);

  Path max(Steps length) =>
      Path(math.max(this.length.toInt, length.toInt).steps, direction);

  Path min(Steps length) =>
      Path(math.min(this.length.toInt, length.toInt).steps, direction);

  Path operator ~/(int i) => Path(length ~/ i, direction);

  @override
  String toString() {
    return '$direction * $length';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Path &&
          runtimeType == other.runtimeType &&
          length == other.length &&
          direction == other.direction;

  @override
  int get hashCode => length.hashCode ^ direction.hashCode;
}

/// A fork of [Point] for our domain model.
class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  Position.fromSteps(Steps x, Steps y)
      : x = x.toPixels,
        y = y.toPixels;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  int get distance => (x.abs() + y.abs());

  Path pathAlong(Axis a) {
    var product = a * this;

    if (product.distance == 0) {
      return Path(0.steps, a.direction);
    }

    return Direction.ofPosition(product) * product.steps;
  }

  Steps get steps => (distance ~/ unitsPerStep).steps;

  /// Add [other] to `this`, as if both points were vectors.
  ///
  /// Returns the resulting "vector" as a Position.
  Position operator +(Position other) {
    return Position((x + other.x), (y + other.y));
  }

  /// Subtract [other] from `this`, as if both positions were vectors.
  ///
  /// Returns the resulting "vector" as a Position.
  Position operator -(Position other) {
    return Position((x - other.x), (y - other.y));
  }

  /// Scale this point by [factor] as if it were a vector.
  ///
  /// *Important* *Note*: This function accepts a `num` as its argument only so
  /// that you can scale `Position<double>` objects by an `int` factor. Because
  /// the `*` operator always returns the same type of `Point` as it is called
  /// on, passing in a double [factor] on a `Position` _causes_ _a_
  /// _runtime_ _error_.
  Position operator *(int factor) {
    return Position((x * factor), (y * factor));
  }

  @override
  String toString() {
    return 'Position{$x, $y}';
  }
}

const up = Direction.up;
const down = Direction.down;
const left = Direction.left;
const right = Direction.right;

class Direction {
  final Position normal;
  const Direction._(this.normal);
  static const up = Direction._(Position(0, -1));
  static const left = Direction._(Position(-1, 0));
  static const right = Direction._(Position(1, 0));
  static const down = Direction._(Position(0, 1));

  static Direction ofPosition(Position p) {
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

  Path operator *(Steps magnitude) => Path(magnitude, this);

  Axis get axis => normal.x == 0 ? Axis.y : Axis.x;

  @override
  String toString() {
    return 'Direction{normal: $normal}';
  }
}

class Axis {
  final Position _normal;

  const Axis._(this._normal);

  static final x = Axis._(Position(1, 0));
  static final y = Axis._(Position(0, 1));

  // todo: eh?
  Direction get direction => Direction._(_normal);
  Axis get perpendicular => Axis._(Position(_normal.y, _normal.x));

  Position operator *(Position p) {
    return Position(p.x * _normal.x, p.y * _normal.y);
  }

  @override
  String toString() {
    return 'Axis.${_normal.x > 0 ? 'x' : 'y'}';
  }
}

class FacePlayer extends Event {
  final FieldObject object;

  FacePlayer(this.object);

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.facePlayerToAsm(this, ctx);
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.facePlayer(this);
  }

  @override
  String toString() {
    return 'FacePlayer{object: $object}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FacePlayer &&
          runtimeType == other.runtimeType &&
          object == other.object;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The party follows the leader
class PartyMove extends Event {
  Movement movement;
  Axis startingAxis = Axis.x;

  PartyMove(this.movement);

  IndividualMoves toIndividualMoves(EventState ctx) {
    var individual = IndividualMoves();
    individual.moves[Slot(1)] = movement;

    var positions = <int, Position>{};
    var followerMovements = <FieldObject, StepPaths>{};

    var leadStartPosition = ctx.positions[Slot(1)];
    if (leadStartPosition == null) {
      throw ArgumentError('ctx does not include slot 1 position');
    }

    Position ctxPositionForSlot(int s) {
      var p = ctx.positions[Slot(s)];
      if (p == null) throw ArgumentError('missing character in slot $s');
      return p;
    }

    for (var steps = 1.step;
        steps <= movement.duration;
        steps = steps + 1.step) {
      var leaderLookahead = movement.lookahead(steps);
      var nextLeaderPosition =
          positions[1] = leadStartPosition + leaderLookahead.relativePosition;

      // TODO: it's possible num characters is variable and not known
      // the assembly appears to be able to query this (e.g. see
      // CalcPartyNumber routine).
      // of course, "just" relying on the follow leader flag would be easier,
      // though it can have slightly different semantics such as how it deals
      // with pauses in movement (i believe the follower leader flag logic would
      // keep characters still while this logic will keep followers moving
      for (var s = 2; s <= ctx.numCharacters; s++) {
        var position = positions[s] ?? ctxPositionForSlot(s);

        StepPath step;

        if ((position - nextLeaderPosition).steps <= 1.step) {
          // fixme facing
          step = StepPath()..delay = 1.step;
        } else {
          var move = StepToPoint()
            ..from = position
            ..to = nextLeaderPosition
            ..firstAxis = startingAxis
            ..direction = ctx.getFacing(Slot(1)) ?? Direction.up; // fixme

          var lookahead = move.lookahead(1.step);
          positions[s] = position + lookahead.relativePosition;
          step = StepPath()
            ..direction = lookahead.facing
            ..distance = 1.step;
        }

        followerMovements.update(Slot(s), (move) => move..step(step),
            ifAbsent: () => StepPaths()..step(step));
      }
    }

    individual.moves.addAll(followerMovements);

    return individual;
  }

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.partyMoveToAsm(this, ctx);
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.partyMove(this);
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
  StepSpeed speed = StepSpeed.fast;

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.individualMovesToAsm(this, ctx);
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.individualMoves(this);
  }

  Steps get duration => moves.values
      .map((m) => m.duration)
      .reduce((longest, m) => longest = max(longest.toInt, m.toInt).steps);

  @override
  String toString() {
    return 'IndividualMoves{moves: $moves, speed: $speed}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndividualMoves &&
          runtimeType == other.runtimeType &&
          const MapEquality().equals(moves, other.moves) &&
          speed == other.speed;

  @override
  int get hashCode => const MapEquality().hash(moves) ^ speed.hashCode;
}

class Party extends Moveable {
  const Party();

  PartyMove move(Movement m) => PartyMove(m);
}

abstract class Moveable {
  const Moveable();

  /// Throws [ResolveException] if cannot resolve.
  Moveable resolve(EventState state) => this;
}

class ResolveException implements Exception {
  final dynamic message;

  ResolveException([this.message]);

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "ResolveException";
    return "ResolveException: $message";
  }
}

// character by name? character by slot? party?
abstract class FieldObject extends Moveable {
  const FieldObject();

  int compareTo(FieldObject other, EventState ctx) {
    var thisSlot = slot(ctx);
    var otherSlot = other.slot(ctx);

    if (thisSlot != null && otherSlot != null) {
      return thisSlot.compareTo(otherSlot);
    }

    return toString().compareTo(other.toString());
  }

  int? slot(EventState c);

  @override
  FieldObject resolve(EventState state) => this;
}

class MapObjectById extends FieldObject {
  final MapObjectId id;

  MapObjectById(this.id);

  MapObject? inMap(GameMap map) => map.object(id);

  @override
  MapObject resolve(EventState state) {
    var map = state.currentMap;
    if (map == null) {
      throw ResolveException('got field obj in map, but map was null');
    }
    var obj = inMap(map);
    if (obj == null) {
      throw ResolveException('got field obj in map, '
          'but <$this> is not in <$map>');
    }
    return obj;
  }

  @override
  int? slot(EventState c) => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapObjectById &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MapObjectById{$id}';
  }
}

// TODO: maybe don't do this
// TODO: maybe instead generalize this as an event wrapper.
// ContextDependentEvent which when processed produces an event based on the
// context and then can generate asm for that instead
// we could replace .resolve() in Moveable with this for example.
abstract class ContextualMovement {
  Movement movementIn(EventState ctx);
}

abstract class Movement extends ContextualMovement {
  /// Delay in steps before movement starts parallel with other movements.
  Steps get delay;

  /// Total duration including all delays and movements
  Steps get duration;

  /// Total distance in steps.
  Steps get distance;

  /// Current facing direction
  /// TODO: rename
  Direction get direction;

  Movement? append(Movement m) => null;

  Movement less(Steps steps);

  /// Movements which are continuous (there is no pause in between) and should
  /// start immediately (delay should == 0).
  // todo: should this just be StepDirection to include delays?
  // todo: should probably be method instead of getter
  List<Path> get continuousPaths;

  @override
  Movement movementIn(EventState ctx) => this;

  // todo: consider returning stepdirections here instead
  MovementLookahead lookahead(Steps steps) {
    if (steps == 0.steps) {
      return MovementLookahead([Path(0.steps, direction)]);
    }

    var stepsTaken = 0.steps;
    var paths = List.of(continuousPaths);
    var pathsWalked = <Path>[];

    while (stepsTaken < steps) {
      for (var i = 0; stepsTaken < steps && i < paths.length; i++) {
        var path = paths[i].min(steps - stepsTaken);
        stepsTaken += path.length;
        pathsWalked.add(path);
      }

      var remaining = steps - stepsTaken;
      if (remaining > 0.steps) {
        var after = less(stepsTaken);
        var delayToTake = min(remaining.toInt, after.delay.toInt).steps;
        after = after.less(delayToTake);
        stepsTaken += delayToTake;
        paths = List.of(after.continuousPaths);
      }
    }

    return MovementLookahead(pathsWalked);
  }

  /// Continuous paths walked if one axis is moved at a time, and the first must
  /// be along [axis]
  List<Path> continuousPathsWithFirstAxis(Axis axis) {
    if (continuousPaths.isEmpty) return [];
    var first = continuousPaths[0];
    if (first.direction.axis == axis) {
      return [first, if (continuousPaths.length > 1) continuousPaths[1]];
    }
    return [first];
  }

  /// The amount of steps in continuous paths walked limited to one axis at a
  /// time where the first axis is [axis].
  Steps delayOrContinuousStepsWithFirstAxis(Axis axis) {
    return delay > 0.steps
        ? delay
        : continuousPathsWithFirstAxis(axis)
            .map((m) => m.length)
            .reduce((sum, s) => sum + s);
  }
}

class StepPath extends Movement {
  @override
  var direction = Direction.up;
  @override
  var distance = 0.steps;
  @override
  var delay = 0.steps;

  @override
  Steps get duration => delay + distance;

  Path get asPath => Path(distance, direction);

  @override
  List<Path> get continuousPaths => delay > 0.steps ? [] : [asPath];

  @override
  StepPaths? append(Movement m) {
    if (m is StepPath) {
      return StepPaths()
        ..step(this)
        ..step(m);
    }

    if (m is StepPaths) {
      return StepPaths()
        ..step(this)
        ..append(m);
    }

    return null;
  }

  // TODO: may want to define in base
  // TODO: should have bounds check
  @override
  StepPath less(Steps steps) {
    if (steps > distance + delay) throw StateError('negative distance');

    var answer = StepPath()..direction = direction;

    var lessDelay = min(steps.toInt, delay.toInt).steps;
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
      (other is StepPath &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          distance == other.distance &&
          delay == other.delay) ||
      (other is StepPaths &&
          other._paths.length == 1 &&
          this == other._paths.first);

  @override
  int get hashCode => direction.hashCode ^ distance.hashCode ^ delay.hashCode;
}

class StepPaths extends Movement {
  final _paths = <StepPath>[];

  @override
  StepPaths? append(Movement m) {
    if (m is StepPath) {
      var answer = StepPaths().._paths.addAll(_paths);
      answer.step(m);
      return answer;
    }

    if (m is StepPaths) {
      var answer = StepPaths().._paths.addAll(_paths);
      for (var step in m._paths) {
        answer.step(step);
      }
      return answer;
    }

    return null;
  }

  void step(StepPath step) {
    if (_paths.isEmpty) {
      _paths.add(step);
    } else {
      var last = _paths.last;

      if (last.direction == step.direction) {
        if (step.delay == 0.steps) {
          _paths.removeLast();
          _paths.add(last..distance = last.distance + step.distance);
        } else if (last.delay > 0.steps && last.distance == 0.steps) {
          _paths.removeLast();
          _paths.add(step..delay = last.delay + step.delay);
        } else {
          _paths.add(step);
        }
      } else {
        _paths.add(step);
      }
    }
  }

  // TODO: this probably doesn't work at any arbitrary point, only at the end.
  //  because distance is 0, hard to know it is actually supposed to generate
  //  code.
  void face(Direction direction) {
    step(StepPath()..direction = direction);
  }

  @override
  Steps get distance => _paths.isEmpty
      ? 0.steps
      : _paths.map((e) => e.distance).reduce((sum, d) => sum + d);

  @override
  Steps get delay => _paths.isEmpty ? 0.steps : _paths.first.delay;

  @override
  Steps get duration => _paths.isEmpty
      ? 0.steps
      : _paths.map((s) => s.duration).reduce((sum, d) => sum + d);

  @override
  Direction get direction =>
      // TODO: what to do if no steps?
      _paths.isEmpty ? Direction.down : _paths.first.direction;

  @override
  List<Path> get continuousPaths => _paths
      .takeWhile((step) => step.delay == 0.steps)
      .map((e) => e.asPath)
      .toList();

  @override
  StepPaths less(Steps steps) {
    if (steps > duration) throw StateError('negative distance');
    if (steps == 0.steps) return this;

    var totalSubtracted = 0.steps;
    var answer = StepPaths();
    StepPath? lastStep;

    for (var path in _paths) {
      var canMove = (steps - totalSubtracted).min(path.duration);
      lastStep = path.less(canMove);

      if (lastStep.duration > 0.steps || answer._paths.isNotEmpty) {
        answer.step(lastStep);
      }

      totalSubtracted += canMove;
    }

    if (answer._paths.isEmpty && lastStep != null) {
      answer.step(lastStep);
    }

    return answer;
  }

  @override
  String toString() {
    return 'StepDirections{$_paths}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepPaths &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(_paths, other._paths)) ||
      (other is StepPath && _paths.length == 1 && _paths.first == other);

  @override
  int get hashCode => _paths.length == 1
      ? _paths.first.hashCode
      : const ListEquality().hash(_paths);
}

class ContextualStepToPoint extends ContextualMovement {
  var direction = Direction.up;

  int delay = 0;

  Position to = Position(0, 0);

  Axis startAlong = Axis.x;

  final Position Function(EventState ctx) from;

  ContextualStepToPoint(this.from);

  @override
  Movement movementIn(EventState ctx) {
    return StepToPoint()
      ..direction = direction
      ..delay = delay.steps
      ..to = to
      ..firstAxis = startAlong
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
  Steps get distance => relativePosition.steps;

  @override
  Steps delay = 0.steps;

  @override
  Steps get duration => delay + distance;

  Position from = Position(0, 0);
  Position to = Position(0, 0);
  Position get relativePosition => to - from;

  Axis firstAxis = Axis.x;
  Axis get secondAxis => firstAxis.perpendicular;

  /// Just changes starting point because end point is set.
  @override
  StepToPoint less(Steps steps) {
    if (steps > duration) throw ArgumentError('negative distance');

    var lessDelay = min(delay.toInt, steps.toInt).steps;
    var remaining = steps - lessDelay;

    var movements = _paths();
    var firstMove = movements[0].min(remaining);

    remaining = remaining - firstMove.length;

    var secondMove = movements[1].min(remaining);

    var newDelay = delay - lessDelay;
    var newStart = from + firstMove.asPosition + secondMove.asPosition;

    return StepToPoint()
      ..delay = newDelay
      ..from = newStart
      ..to = to
      ..firstAxis = firstAxis;
  }

  @override
  List<Path> get continuousPaths {
    if (delay > 0.steps) return [];
    return _paths();
  }

  List<Path> _paths() {
    var first = relativePosition.pathAlong(firstAxis);
    var second = relativePosition.pathAlong(secondAxis);
    return [
      if (first.length > 0.steps) first,
      if (second.length > 0.steps) second
    ];
  }

  @override
  String toString() {
    return 'StepToPoint{direction: $direction, delay: $delay, from: $from, to: $to, startAlong: $firstAxis}';
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
          firstAxis == other.firstAxis;

  @override
  int get hashCode =>
      direction.hashCode ^
      delay.hashCode ^
      from.hashCode ^
      to.hashCode ^
      firstAxis.hashCode;
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

class MovementLookahead {
  final List<Path> pathsWalked;
  Position get relativePosition =>
      pathsWalked.map((m) => m.asPosition).reduce((sum, p) => sum + p);
  Direction get facing => pathsWalked.last.direction;
  Steps get relativeDistance => relativePosition.steps;

  MovementLookahead(this.pathsWalked) {
    if (pathsWalked.isEmpty) {
      throw ArgumentError('must not be empty', 'pathsWalked');
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

enum StepSpeed {
  verySlowWalk, // 080 3
  slowWalk, // 100 0
  walk, // 180 4
  /// Default movement speed.
  fast, // 200 1
  double; // 400 2

  static StepSpeed normal() => fast;
}
