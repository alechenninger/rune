import 'dart:math';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/src/iterables.dart';

import 'model.dart';

class Steps implements Comparable<Steps> {
  final int toInt;

  const Steps(this.toInt);

  @override
  int compareTo(Steps other) {
    return toInt.compareTo(other.toInt);
  }

  int get toPixels => toInt * unitsPerStep;

  Path get right => Path(this, Direction.right);
  Path get left => Path(this, Direction.left);
  Path get up => Path(this, Direction.up);
  Path get down => Path(this, Direction.down);

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

enum Axis {
  x(Direction.right),
  y(Direction.down);

  final Direction _normal;

  const Axis(this._normal);

  // todo: eh?
  Direction get direction => _normal;
  Axis get perpendicular {
    switch (this) {
      case Axis.x:
        return y;
      case Axis.y:
        return x;
    }
  }

  Position operator *(Position p) {
    return Position(p.x * _normal.normal.x, p.y * _normal.normal.y);
  }
}

class FacePlayer extends Event {
  final FieldObject object;

  FacePlayer(this.object);

  IndividualMoves toMoves() => Face(object.towards(Slot.one)).move(object);

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
class RelativePartyMove extends Event {
  RelativeMovement movement;
  StepSpeed? speed;
  Axis startingAxis = Axis.x;

  RelativePartyMove(this.movement);

  IndividualMoves toIndividualMoves(EventState ctx) {
    var individual = IndividualMoves();
    if (speed case StepSpeed s) {
      individual.speed = s;
    }
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
          var facing = ctx.getFacing(Slot(1));
          var move = StepToPoint()
            ..from = position
            ..to = nextLeaderPosition
            ..firstAxis = startingAxis
            ..direction = facing is Direction ? facing : Direction.up; // fixme

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelativePartyMove &&
          runtimeType == other.runtimeType &&
          movement == other.movement &&
          speed == other.speed &&
          startingAxis == other.startingAxis;

  @override
  int get hashCode =>
      movement.hashCode ^ speed.hashCode ^ startingAxis.hashCode;
}

/// A group of parallel, relative movements
class IndividualMoves extends Event {
  // TODO: what if Slot and Character moveables refer to same Character?
  Map<FieldObject, RelativeMovement> moves = {};
  StepSpeed speed = StepSpeed.fast;

  Map<FieldObject, DirectionExpression>? justFacing() {
    var result = <FieldObject, DirectionExpression>{};
    for (var MapEntry(key: obj, value: move) in moves.entries) {
      var direction = move.facing;
      if (move.continuousPaths.length == 1 &&
          move.distance == 0.steps &&
          direction != null &&
          move.duration == 0.steps) {
        result[obj] = direction;
      } else {
        return null;
      }
    }
    return result;
  }

  bool get isEmpty => moves.isEmpty;

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

class AbsoluteMoves extends Event {
  // Facing can be controlled with individual movements
  // TODO(movement): we could support delays
  // even though we don't know the duration of movements,
  // we can still delay individual movements.
  Map<FieldObject, Position> destinations = {};
  StepSpeed speed = StepSpeed.fast;
  Axis startingAxis = Axis.x;
  bool followLeader = false;

  bool get isNotEmpty => destinations.isNotEmpty;
  bool get isEmpty => destinations.isEmpty;

  @override
  void visit(EventVisitor visitor) {
    visitor.absoluteMoves(this);
  }

  @override
  String toString() {
    return 'AbsoluteMoves{destinations: '
        '$destinations, speed: '
        '$speed, startingAxis: '
        '$startingAxis}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbsoluteMoves &&
          runtimeType == other.runtimeType &&
          const MapEquality().equals(destinations, other.destinations) &&
          speed == other.speed &&
          startingAxis == other.startingAxis &&
          followLeader == other.followLeader;

  @override
  int get hashCode =>
      const MapEquality().hash(destinations) ^
      speed.hashCode ^
      startingAxis.hashCode ^
      followLeader.hashCode;
}

class InstantMoves extends Event {
  Map<FieldObject, (PositionExpression? position, DirectionExpression? facing)>
      destinations = {};

  void move(FieldObject obj,
      {PositionExpression? to, DirectionExpression? face}) {
    destinations[obj] = (to, face);
  }

  void put(FieldObject obj, PositionExpression at) {
    destinations.update(obj, (result) => (at, result.$2),
        ifAbsent: () => (at, null));
  }

  void face(FieldObject obj, DirectionExpression face) {
    destinations.update(obj, (result) => (result.$1, face),
        ifAbsent: () => (null, face));
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.instantMoves(this);
  }

  @override
  String toString() {
    return 'InstantMoves{$destinations}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstantMoves &&
          runtimeType == other.runtimeType &&
          const MapEquality().equals(destinations, other.destinations);

  @override
  int get hashCode => const MapEquality().hash(destinations);
}

class OverlapCharacters extends Event {
  @override
  void visit(EventVisitor visitor) {
    visitor.overlapCharacters(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlapCharacters && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'OverlapCharacters{}';
}

class Party extends Moveable {
  const Party();

  RelativePartyMove move(RelativeMovement m) => RelativePartyMove(m);
  AbsoluteMoves moveTo(Position destination) => AbsoluteMoves()
    ..destinations[Slot(1)] = destination
    ..followLeader = true;
}

sealed class Moveable {
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

  // TODO(refactor): this api stinks; should not be on same type as "real" thing
  @override
  FieldObject resolve(EventState state) => this;
}

extension ObjectExpressions on FieldObject {
  PositionOfObject position() => PositionOfObject(this);
  DirectionOfVector towards(FieldObject other) =>
      DirectionOfVector(from: position(), to: other.position());
}

class MapObjectById extends FieldObject {
  final MapObjectId id;

  MapObjectById(this.id);

  MapObject? inMap(GameMap map) => map.object(id);

  @override
  MapObject resolve(EventState state) {
    var map = state.currentMap;
    if (map == null) {
      throw ResolveException('got field obj in map, but current map was null');
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

/// Object being interacted with.
class InteractionObject extends FieldObject {
  const InteractionObject();

  static FacePlayer facePlayer() => FacePlayer(const InteractionObject());

  @override
  int? slot(EventState c) => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InteractionObject && runtimeType == other.runtimeType;

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    return 'InteractionObject{}';
  }
}

// TODO: maybe don't do this
// TODO: maybe instead generalize this as an event wrapper.
// ContextDependentEvent which when processed produces an event based on the
// context and then can generate asm for that instead
// we could replace .resolve() in Moveable with this for example.
abstract class ContextualMovement {
  RelativeMovement movementIn(EventState ctx);
}

abstract class RelativeMovement extends ContextualMovement {
  /// Delay in steps before movement starts parallel with other movements.
  Steps get delay;

  /// Total duration including all delays and movements
  Steps get duration;

  /// Total distance in steps.
  Steps get distance;

  /// Current facing direction
  /// TODO: rename
  Direction get direction;

  /// Direction to face after the first continuous movement is traveled
  /// (when either the end or first delay is encountered).
  ///
  /// If `null`, the object will face in the same direction as it last moved.
  DirectionExpression? get facing;

  /// If this movement represents an object standing still (doing nothing).
  bool get still => duration == 0.steps && facing == null;

  RelativeMovement? append(RelativeMovement m) => null;

  /// If [steps] is 0, and the only continuous path is a [facing],
  /// then the [facing] is considered traveled,
  /// and the resulting movement will have no [facing].
  ///
  /// Facing can only be traveled this way; otherwise it will be skipped.
  RelativeMovement less(Steps steps);

  /// Movements which are continuous (there is no pause or facing in between)
  /// and should start immediately (delay should == 0).
  // todo: should this just be StepDirection to include delays?
  // todo: should probably be method instead of getter
  List<Path> get continuousPaths;

  @override
  RelativeMovement movementIn(EventState ctx) => this;

  IndividualMoves move(FieldObject obj) => IndividualMoves()..moves[obj] = this;

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

class StepPath extends RelativeMovement {
  @override
  var direction = Direction.up;
  @override
  var distance = 0.steps;
  @override
  var delay = 0.steps;
  @override
  DirectionExpression? facing;

  @override
  Steps get duration => delay + distance;

  Path get asPath => Path(distance, direction);

  @override
  List<Path> get continuousPaths => delay > 0.steps ? [] : [asPath];

  @override
  StepPaths? append(RelativeMovement m) {
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

    answer.facing =
        answer.duration == 0.steps && steps == 0.steps ? null : facing;

    return answer;
  }

  @override
  String toString() {
    return 'StepPath{direction: $direction, '
        'distance: $distance, '
        'delay: $delay, '
        'facing: $facing}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepPath &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          distance == other.distance &&
          delay == other.delay &&
          facing == other.facing) ||
      (other is StepPaths &&
          other._paths.length == 1 &&
          this == other._paths.first) ||
      (other is Face && this == other.asStep());

  @override
  int get hashCode =>
      direction.hashCode ^ distance.hashCode ^ delay.hashCode ^ facing.hashCode;
}

class StepPaths extends RelativeMovement {
  final _paths = <StepPath>[];

  @override
  StepPaths? append(RelativeMovement m) {
    // TODO(movement); this is missing Face now
    // use sealed type?
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

  void wait(Steps duration) {
    step(StepPath()..delay = duration);
  }

  void step(StepPath step) {
    if (_paths.isEmpty) {
      _paths.add(step);
    } else {
      var last = _paths.last;

      if (last.direction == step.direction) {
        if (step.delay == 0.steps) {
          _paths.removeLast();
          _paths.add(last
            ..distance = last.distance + step.distance
            ..facing = step.facing);
        } else if (last.delay > 0.steps && last.distance == 0.steps) {
          _paths.removeLast();
          _paths.add(step
            ..delay = last.delay + step.delay
            ..facing = step.facing);
        } else {
          _paths.add(step);
        }
      } else {
        _paths.add(step);
      }
    }
  }

  /// Face the object in the direction of [direction].
  ///
  /// Only affects the end of [continuousPaths]. If there is a subsequent step
  /// without delay, the facing will be ignored.
  void face(DirectionExpression direction) {
    step(Face(direction).asStep());
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
  DirectionExpression? get facing {
    if (_paths.isEmpty) {
      return null;
    }

    return _paths.takeWhile((step) => step.delay == 0.steps).lastOrNull?.facing;
  }

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

    Steps? totalSubtracted;
    var answer = StepPaths();
    StepPath? lastStep;

    for (var path in _paths) {
      var canMove = (steps - (totalSubtracted ?? 0.steps)).min(path.duration);

      if (totalSubtracted != steps) {
        lastStep = path.less(canMove);
      } else {
        lastStep = path;
      }

      if (lastStep.duration > 0.steps ||
          lastStep.facing != null ||
          answer._paths.isNotEmpty) {
        answer.step(lastStep);
      }

      if (totalSubtracted == null) {
        totalSubtracted = canMove;
      } else {
        totalSubtracted += canMove;
      }
    }

    if (answer._paths.isEmpty && lastStep != null) {
      answer.step(lastStep);
    }

    return answer;
  }

  @override
  String toString() {
    return 'StepPaths{$_paths}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepPaths &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(_paths, other._paths)) ||
      (other is StepPath && _paths.length == 1 && _paths.first == other) ||
      (other is Face && this == other.asStep());

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
  RelativeMovement movementIn(EventState ctx) {
    return StepToPoint()
      ..direction = direction
      ..delay = delay.steps
      ..to = to
      ..firstAxis = startAlong
      ..from = from(ctx);
  }
}

/// Simple axis-by-axis movement to a point.
class StepToPoint extends RelativeMovement {
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

  @override
  DirectionExpression? facing;

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

    var newFacing = steps == 0.steps && duration == 0.steps ? null : facing;

    return StepToPoint()
      ..delay = newDelay
      ..from = newStart
      ..to = to
      ..firstAxis = firstAxis
      ..facing = newFacing;
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

class RelativeMove<T extends Moveable> {
  final T moveable;
  final RelativeMovement movement;

  RelativeMove(this.moveable, this.movement);

  @override
  String toString() {
    return 'RelativeMove{moveable: $moveable, movement: $movement}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelativeMove &&
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

enum PartyArrangement {
  overlapping([
    Position(0, 0),
    Position(0, 0),
    Position(0, 0),
    Position(0, 0),
    Position(0, 0)
  ]),
  belowLead([
    Position(0, 0),
    Position(0, 1 * unitsPerStep),
    Position(0, 2 * unitsPerStep),
    Position(0, 3 * unitsPerStep),
    Position(0, 4 * unitsPerStep)
  ]),
  aboveLead([
    Position(0, 0),
    Position(0, -1 * unitsPerStep),
    Position(0, -2 * unitsPerStep),
    Position(0, -3 * unitsPerStep),
    Position(0, -4 * unitsPerStep)
  ]),
  leftOfLead([
    Position(0, 0),
    Position(-1 * unitsPerStep, 0),
    Position(-2 * unitsPerStep, 0),
    Position(-3 * unitsPerStep, 0),
    Position(-4 * unitsPerStep, 0)
  ]),
  rightOfLead([
    Position(0, 0),
    Position(1 * unitsPerStep, 0),
    Position(2 * unitsPerStep, 0),
    Position(3 * unitsPerStep, 0),
    Position(4 * unitsPerStep, 0)
  ]);

  static PartyArrangement behind(Direction facing) {
    switch (facing) {
      case up:
        return belowLead;
      case down:
        return aboveLead;
      case left:
        return rightOfLead;
      case right:
        return leftOfLead;
    }
  }

  final List<Position> offsets;

  const PartyArrangement(this.offsets);
}

class Face extends RelativeMovement {
  @override
  List<Path> get continuousPaths =>
      delay > 0.steps ? [] : [Path(0.steps, direction)];

  @override
  var delay = 0.steps;

  /// Meaningless because distance is always 0.
  @override
  final direction = Direction.up;

  @override
  final distance = 0.steps;

  @override
  Steps get duration => delay;

  @override
  DirectionExpression facing;

  Face(this.facing);

  StepPath asStep() => StepPath()
    ..delay = delay
    ..facing = facing;

  @override
  RelativeMovement less(Steps steps) {
    if (steps > duration) throw ArgumentError('negative distance');

    if (duration == 0.steps) {
      // Once faced, then return a still movement.
      return StepPath();
    }

    return Face(facing)..delay = delay - steps;
  }

  @override
  String toString() {
    return 'Face{facing: $facing, delay: $delay}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Face &&
          runtimeType == other.runtimeType &&
          facing == other.facing &&
          delay == other.delay) ||
      (other is RelativeMovement && asStep() == other);

  @override
  int get hashCode => asStep().hashCode;
}
