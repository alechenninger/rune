import 'model.dart';

/// A runtime property read by a symbolic expression.
enum ObjectProperty { position, facing }

typedef ObjectDependency = ({FieldObject object, ObjectProperty property});

extension DirectionDependencies on DirectionExpression {
  Iterable<ObjectDependency> get dependencies => switch (this) {
        Direction() => const [],
        ObjectFaceDirection(:final obj) => [
            (object: obj, property: ObjectProperty.facing)
          ],
        OffsetDirection(:final base) => base.dependencies,
        DirectionOfVector(:final from, :final to, :final zeroValue) => [
            ...from.dependencies,
            ...to.dependencies,
            ...zeroValue.dependencies,
          ],
      };
}

extension PositionDependencies on PositionExpression {
  Iterable<ObjectDependency> get dependencies => switch (this) {
        Position() => const [],
        PositionOfObject(:final obj) => [
            (object: obj, property: ObjectProperty.position)
          ],
        PositionOfXY(:final x, :final y) => [
            ...x.dependencies,
            ...y.dependencies
          ],
        OffsetPosition(:final base) => base.dependencies,
      };
}

extension PositionComponentDependencies on PositionComponentExpression {
  Iterable<ObjectDependency> get dependencies => switch (this) {
        PositionComponent() => const [],
        PositionComponentOfObject(:final obj) => [
            (object: obj, property: ObjectProperty.position)
          ],
        OffsetPositionComponent(:final base) => base.dependencies,
      };
}
