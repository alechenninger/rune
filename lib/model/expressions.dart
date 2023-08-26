import 'model.dart';

sealed class ModelExpression {}

sealed class BooleanExpression extends ModelExpression {}

class Comparison<T extends ModelExpression> {
  final T op1, op2;

  Comparison(this.op1, this.op2);
}

sealed class PositionComponentExpression extends ModelExpression {}

sealed class PositionExpression extends ModelExpression {
  PositionComponentExpression component(Axis axis);
}

extension PositionExpressions on PositionExpression {
  DirectionOfVector towards(PositionExpression other) =>
      DirectionOfVector(from: this, to: other);
}

class PositionOfObject extends PositionExpression {
  final FieldObject obj;

  PositionOfObject(this.obj);

  @override
  PositionComponentOfObject component(Axis axis) =>
      PositionComponentOfObject(obj, axis);

  @override
  String toString() => 'PositionOfObject{obj: $obj}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionOfObject &&
          runtimeType == other.runtimeType &&
          obj == other.obj;

  @override
  int get hashCode => obj.hashCode;
}

class PositionComponentOfObject extends PositionComponentExpression {
  final FieldObject obj;
  final Axis component;

  PositionComponentOfObject(this.obj, this.component);

  @override
  String toString() => 'PositionComponentOfObject{obj: $obj, '
      'component: $component}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionComponentOfObject &&
          runtimeType == other.runtimeType &&
          obj == other.obj &&
          component == other.component;
}

const unitsPerStep = 16;

/// A fork of [Point] for our domain model.
class Position implements PositionExpression {
  final int x;
  final int y;

  const Position(this.x, this.y);

  Position.fromSteps(Steps x, Steps y)
      : x = x.toPixels,
        y = y.toPixels;

  Position.fromPoint(Point<int> point) : this(point.x, point.y);

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

  List<int> get asList => [x, y];

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
  Position operator *(int factor) {
    return Position((x * factor), (y * factor));
  }

  Position operator ~/(int factor) {
    return Position((x ~/ factor), (y ~/ factor));
  }

  @override
  PositionComponent component(Axis axis) =>
      PositionComponent.fromPosition(this, axis);

  @override
  String toString() {
    return '($x, $y)';
  }
}

class PositionComponent extends PositionComponentExpression {
  // todo: maybe remove this
  final Axis axis;
  final int value;

  PositionComponent.fromPosition(Position p, Axis axis)
      : this(switch (axis) { Axis.x => p.x, Axis.y => p.y }, axis);

  PositionComponent(this.value, this.axis);

  @override
  String toString() {
    return 'PositionComponent{$axis: $value}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionComponent &&
          runtimeType == other.runtimeType &&
          axis == other.axis &&
          value == other.value;

  @override
  int get hashCode => axis.hashCode ^ value.hashCode;
}

sealed class DirectionExpression extends ModelExpression {
  DirectionExpression get opposite;
}

class DirectionOfVector extends DirectionExpression {
  final PositionExpression from;
  final PositionExpression to;

  DirectionOfVector({required this.from, required this.to});

  @override
  DirectionExpression get opposite => DirectionOfVector(from: to, to: from);

  @override
  String toString() {
    return 'DirectionOfVector{from: $from, to: $to}';
  }

  @override
  bool operator ==(Object other) =>
      other is DirectionOfVector &&
      runtimeType == other.runtimeType &&
      from == other.from &&
      to == other.to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

const up = Direction.up;
const down = Direction.down;
const left = Direction.left;
const right = Direction.right;

enum Direction implements DirectionExpression {
  up(Position(0, -1)),
  left(Position(-1, 0)),
  right(Position(1, 0)),
  down(Position(0, 1));

  final Position normal;
  const Direction(this.normal);

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

  @override
  Direction get opposite => switch (this) {
        up => down,
        down => up,
        left => right,
        right => left,
      };

  Path operator *(Steps magnitude) => Path(magnitude, this);

  Axis get axis => normal.x == 0 ? Axis.y : Axis.x;
}
