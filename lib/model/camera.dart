import '../generator/deprecated.dart';
import 'model.dart';

class MoveCamera extends Event {
  final PositionExpression to;
  final CameraSpeed speed;

  MoveCamera(this.to, {this.speed = CameraSpeed.one});

  @override
  operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoveCamera && other.to == to;
  }

  @override
  int get hashCode => to.hashCode;

  @override
  String toString() => 'MoveCamera{to: $to}';

  @override
  void visit(EventVisitor visitor) {
    visitor.moveCamera(this);
  }
}

enum CameraSpeed { one, two, four, eight }

class LockCamera extends Event {
  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.lockCameraToAsm(ctx);
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.lockCamera(this);
  }

  @override
  String toString() {
    return 'LockCamera{}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LockCamera;
  }

  @override
  int get hashCode => true.hashCode;
}

class UnlockCamera extends Event {
  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.unlockCameraToAsm(ctx);
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.unlockCamera(this);
  }

  @override
  String toString() {
    return 'UnlockCamera{}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnlockCamera;
  }

  @override
  int get hashCode => false.hashCode;
}
