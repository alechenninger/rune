import 'dart:math';

import 'package:quiver/check.dart';

import 'model.dart';

sealed class ModelExpression {
  int get arity;

  const ModelExpression();
}

sealed class UnaryExpression extends ModelExpression {
  @override
  final arity = 1;
}

sealed class BinaryExpression extends ModelExpression {
  @override
  final arity = 2;

  const BinaryExpression();
}

sealed class PositionComponentExpression extends UnaryExpression {
  int? known(EventState state);
}

sealed class PositionExpression extends BinaryExpression {
  const PositionExpression();
  Position? known(EventState state);
  PositionComponentExpression component(Axis axis);
}

extension PositionExpressions on PositionExpression {
  DirectionOfVector awayFrom(PositionExpression other) =>
      DirectionOfVector(from: other, to: this);
  DirectionOfVector towards(PositionExpression other) =>
      DirectionOfVector(from: this, to: other);
}

class PositionOfObject extends PositionExpression {
  final FieldObject obj;

  PositionOfObject(this.obj);

  @override
  Position? known(EventState state) => state.positions[obj];

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

  @override
  int get hashCode => obj.hashCode ^ component.hashCode;

  @override
  int? known(EventState state) =>
      switch (state.positions[obj]) { null => null, var p => component.of(p) };
}

class PositionOfXY extends PositionExpression {
  final PositionComponentExpression x;
  final PositionComponentExpression y;

  PositionOfXY(this.x, this.y);

  @override
  PositionComponentExpression component(Axis axis) => switch (axis) {
        Axis.x => x,
        Axis.y => y,
      };

  @override
  Position? known(EventState state) =>
      switch ((x.known(state), y.known(state))) {
        (var x?, var y?) => Position(x, y),
        _ => null,
      };

  @override
  String toString() {
    return 'PositionOfXY{x: $x, y: $y}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionOfXY &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

class OffsetPosition extends PositionExpression {
  final PositionExpression base;
  final Position offset;

  factory OffsetPosition(PositionExpression base, {required Position offset}) {
    return base is OffsetPosition
        ? OffsetPosition._(base.base, base.offset + offset)
        : OffsetPosition._(base, offset);
  }

  OffsetPosition._(this.base, this.offset);

  @override
  PositionComponentExpression component(Axis axis) => switch (axis.of(offset)) {
        0 => base.component(axis),
        var of => OffsetPositionComponent(base.component(axis), offset: of),
      };

  @override
  Position? known(EventState state) => switch (base.known(state)) {
        null => null,
        var p => p + offset,
      };

  @override
  String toString() {
    return 'OffsetPosition{base: $base, offset: $offset}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffsetPosition &&
          runtimeType == other.runtimeType &&
          base == other.base &&
          offset == other.offset;

  @override
  int get hashCode => base.hashCode ^ offset.hashCode;
}

const unitsPerStep = 16;

/// A fork of [Point] for our domain model.
class Position extends PositionExpression {
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

  Position abs() => Position(x.abs(), y.abs());

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

  Position operator -() => Position(-x, -y);

  /// Scale this point by [factor] as if it were a vector.
  Position operator *(int factor) {
    return Position((x * factor), (y * factor));
  }

  Position operator ~/(int factor) {
    return Position((x ~/ factor), (y ~/ factor));
  }

  @override
  Position? known(EventState state) => this;

  @override
  PositionComponent component(Axis axis) =>
      PositionComponent.fromPosition(this, axis);

  @override
  String toString() {
    return '($x, $y)';
  }
}

class OffsetPositionComponent extends PositionComponentExpression {
  final PositionComponentExpression base;
  final int offset;

  OffsetPositionComponent(this.base, {required this.offset});

  @override
  int? known(EventState state) {
    return switch (base.known(state)) {
      null => null,
      var value => value + offset,
    };
  }

  @override
  String toString() {
    return 'OffsetPositionComponent{base: $base, offset: $offset}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffsetPositionComponent &&
          runtimeType == other.runtimeType &&
          base == other.base &&
          offset == other.offset;

  @override
  int get hashCode => base.hashCode ^ offset.hashCode;
}

class PositionComponent extends PositionComponentExpression {
  // todo: maybe remove this
  final Axis axis;
  final int value;

  PositionComponent.fromPosition(Position p, Axis axis)
      : this(switch (axis) { Axis.x => p.x, Axis.y => p.y }, axis);

  PositionComponent(this.value, this.axis);

  @override
  int? known(EventState state) => value;

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

sealed class DirectionExpression extends UnaryExpression {
  Direction? known(EventState memory);
  DirectionExpression get opposite;
  DirectionExpression turn(int times) => OffsetDirection(this, turns: times);
}

class DirectionOfVector extends DirectionExpression {
  final PositionExpression from;
  final PositionExpression to;

  DirectionOfVector({required this.from, required this.to});

  @Deprecated("It's wrong if the player or object has moved")
  bool get playerIsFacingFrom =>
      from == const InteractionObject().position() &&
      to == BySlot.one.position();

  @override
  Direction? known(EventState memory) {
    var knownFrom = from.known(memory);
    var knownTo = to.known(memory);
    if (knownFrom == null || knownTo == null) {
      // If we know the player is facing this object,
      // try using the opposite direction of the player facing.
      if (playerIsFacingFrom) {
        var dir = memory.getFacing(BySlot.one)?.opposite;
        if (dir is Direction) return dir;
      }

      return null;
    }
    var vector = knownTo - knownFrom;
    if (vector.x == 0 && vector.y == 0) return Direction.up;
    var angle = atan2(vector.y, vector.x) * 180 / pi;
    return switch (angle) {
      >= -45 && < 45 => Direction.right,
      >= 45 && < 135 => Direction.down,
      >= -135 && < -45 => Direction.up,
      _ => Direction.left
    };
  }

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

class ObjectFaceDirection extends DirectionExpression {
  final FieldObject obj;

  ObjectFaceDirection(this.obj);

  @override
  DirectionExpression get opposite => OffsetDirection(this, turns: 2);

  @override
  Direction? known(EventState memory) {
    return switch (memory.getFacing(obj)) {
      Direction d => d,
      DirectionExpression d when d != this => d.known(memory),
      _ => null,
    };
  }

  @override
  String toString() {
    return 'ObjectFaceDirection{obj: $obj}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectFaceDirection &&
          runtimeType == other.runtimeType &&
          obj == other.obj;

  @override
  int get hashCode => obj.hashCode;
}

class OffsetDirection extends DirectionExpression {
  final DirectionExpression base;

  /// Number of turns 90 degrees to the right.
  final int turns;

  factory OffsetDirection(DirectionExpression base, {required int turns}) {
    return base is OffsetDirection
        ? OffsetDirection._(base.base, turns: base.turns + turns)
        : OffsetDirection._(base, turns: turns);
  }
  OffsetDirection._(this.base, {required int turns})
      : turns = turns.isNegative ? (turns + 4) % 4 : turns % 4;

  @override
  DirectionExpression get opposite =>
      OffsetDirection(base.opposite, turns: turns);

  @override
  Direction? known(EventState memory) {
    return switch (base.known(memory)) {
      Direction d => d.turn(turns),
      _ => null,
    };
  }

  @override
  String toString() {
    return 'OffsetDirection{base: $base, turns: $turns}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffsetDirection &&
          runtimeType == other.runtimeType &&
          base == other.base &&
          turns == other.turns;

  @override
  int get hashCode => base.hashCode ^ turns.hashCode;
}

const up = Direction.up;
const down = Direction.down;
const left = Direction.left;
const right = Direction.right;

enum Direction implements DirectionExpression {
  // NOTE: maintain this order (consecutive right turns)
  up(Position(0, -1)),
  right(Position(1, 0)),
  down(Position(0, 1)),
  left(Position(-1, 0));

  @override
  final arity = 1;

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

  Direction turn(int times) {
    var normalized = times.isNegative ? (times + 4) % 4 : times % 4;
    return Direction.values[(index + normalized) % 4];
  }

  @override
  Direction? known(EventState memory) => this;

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

sealed class SlotExpression extends UnaryExpression {}

class NotInParty extends SlotExpression {
  NotInParty();

  @override
  String toString() {
    return 'NotInParty{}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NotInParty;

  @override
  int get hashCode => 'NotInParty{}'.hashCode;
}

class Slot extends SlotExpression {
  final int index;
  int get offset => index - 1;

  Slot(this.index) {
    checkArgument(index >= 1 && index <= 5,
        message: 'Slot index must be between 1 and 5');
  }

  BySlot toFieldObject() => BySlot(index);

  @override
  String toString() {
    return 'Slot{index: $index}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Slot && runtimeType == other.runtimeType && index == other.index;

  @override
  int get hashCode => index.hashCode;
}

class SlotOfCharacter extends SlotExpression {
  final Character character;

  SlotOfCharacter(this.character);

  @override
  String toString() {
    return 'SlotOfCharacter{character: $character}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotOfCharacter &&
          runtimeType == other.runtimeType &&
          character == other.character;

  @override
  int get hashCode => character.hashCode;
}

sealed class BooleanExpression extends UnaryExpression {
  bool? known(EventState state);
}

class IsOffScreen extends BooleanExpression {
  final FieldObject object;

  IsOffScreen(this.object);

  @override
  bool? known(EventState state) {
    // TODO: implement known
    // Technically we could figure this out if we tracked camera position
    // and knew object position.
    return null;
  }

  @override
  String toString() {
    return 'IsOffScreen{object: $object}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IsOffScreen &&
          runtimeType == other.runtimeType &&
          object == other.object;

  @override
  int get hashCode => object.hashCode;
}

// class PositionEquals extends BooleanExpression {
//   final PositionExpression left;
//   final PositionExpression right;

//   PositionEquals(this.left, this.right);

//   @override
//   bool? known(EventState state) {
//     // Same expresion; same regardless of state
//     if (left == right) return true;
//     return switch ((left.known(state), right.known(state))) {
//       // Known positions; might not be the same
//       (var l?, var r?) => l == r,
//       _ => null,
//     };
//   }
// }

class BooleanConstant extends BooleanExpression {
  final bool value;

  BooleanConstant(this.value);

  @override
  bool known(EventState state) => value;

  @override
  String toString() {
    return 'BooleanConstant{value: $value}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BooleanConstant &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
