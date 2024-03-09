import 'package:collection/collection.dart';

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
  final SpecModel routine;

  ChangeObjectRoutine(this.object, this.routine);

  @override
  void visit(EventVisitor visitor) {
    visitor.changeObjectRoutine(this);
  }

  @override
  String toString() {
    return 'ChangeObjectRoutine{object: $object, routine: $routine}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangeObjectRoutine &&
          runtimeType == other.runtimeType &&
          object == other.object &&
          routine == other.routine;

  @override
  int get hashCode => object.hashCode ^ routine.hashCode;
}

sealed class SpecModel {}

class NpcRoutineModel extends SpecModel {
  final Type behaviorType;

  NpcRoutineModel(this.behaviorType);

  @override
  String toString() {
    return 'NpcRoutineModel{$behaviorType}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NpcRoutineModel &&
          runtimeType == other.runtimeType &&
          behaviorType == other.behaviorType;

  @override
  int get hashCode => behaviorType.hashCode;
}

class SpecRoutineModel extends SpecModel {
  final Type specType;

  SpecRoutineModel(this.specType);

  @override
  String toString() {
    return 'SpecRoutineModel{$specType}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpecRoutineModel &&
          runtimeType == other.runtimeType &&
          specType == other.specType;

  @override
  int get hashCode => specType.hashCode;
}

class AsmRoutineModel extends SpecModel {
  final Word index;

  AsmRoutineModel(this.index);

  @override
  String toString() {
    return 'AsmRoutineModel{index: $index}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsmRoutineModel && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Updates the next interaction for some map elements, which are reset back
/// to their original interaction when the map is reloaded.`
class OnNextInteraction extends Event {
  final List<MapObjectId> withObjects;
  final Scene onInteract;

  OnNextInteraction(
      {required this.withObjects, this.onInteract = const Scene.none()});

  OnNextInteraction withoutSetContext() {
    return OnNextInteraction(
        withObjects: withObjects, onInteract: onInteract.withoutSetContext());
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.onNextInteraction(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnNextInteraction &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(withObjects, other.withObjects) &&
          onInteract == other.onInteract;

  @override
  int get hashCode =>
      const ListEquality().hash(withObjects) ^ onInteract.hashCode;

  @override
  String toString() {
    return 'OnNextInteractionInMap{$withObjects, onInteract: $onInteract}';
  }
}
