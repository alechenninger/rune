import 'package:quiver/check.dart';

import '../asm/data.dart';
import 'model.dart';

class ResetObjectRoutine extends Event {
  final FieldObject object;

  ResetObjectRoutine(this.object);

  @override
  void visit(EventVisitor visitor) {
    visitor.resetObjectRoutine(this);
  }

  @override
  String toString() => 'ResetObjectRoutine{object: $object}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResetObjectRoutine &&
          runtimeType == other.runtimeType &&
          object == other.object;

  @override
  int get hashCode => object.hashCode;
}

class ChangeObjectRoutine extends Event {
  final FieldObject object;

  /// A routine can either be an index,
  /// map object spec type, or
  /// npc behavior type
  final RoutineRef routineRef;

  ChangeObjectRoutine(this.object, this.routineRef);

  @override
  void visit(EventVisitor visitor) {
    // TODO: implement visit
  }
}

sealed class RoutineRef {}

class AsmRoutineRef extends RoutineRef {
  final Word index;

  AsmRoutineRef(this.index) {
    checkArgument(index.value & 0x7ffc == index.value,
        message: 'not a valid field object routine: $index');
  }

  @override
  String toString() => 'AsmRoutineRef{index: $index}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AsmRoutineRef && index == other.index;

  @override
  int get hashCode => index.hashCode;
}

class TypeRoutineRef extends RoutineRef {
  final Type type;

  TypeRoutineRef(this.type);
  TypeRoutineRef.fromSpec(MapObjectSpec spec)
      : type = spec is Npc ? spec.behavior.runtimeType : spec.runtimeType;
}
