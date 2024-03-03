/// Events for "animating" characters.
library;

import 'package:collection/collection.dart';
import 'package:quiver/check.dart';
import 'package:rune/generator/generator.dart';

import 'model.dart';

export 'dart:math' show Point;

class StepObject extends Event {
  /// The object that is being animated.
  final FieldObject object;

  /// Whether the object should appear on top of other objects
  /// for the duration of the movement.
  final bool onTop;

  /// Whether the object's sprite should animate different frames
  /// during the movement.
  final bool animate;

  /// Relative movement per frame in pixels.
  final Point<double> stepPerFrame;

  /// How many frames should the movement last. > 0.
  final int frames;

  StepObject(this.object,
      {this.onTop = false,
      this.animate = true,
      required this.stepPerFrame,
      required this.frames}) {
    checkArgument(frames > 0, message: 'Frames must be greater than 0.');
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.stepObject(this);
  }

  @override
  String toString() {
    return 'StepObject('
        'object: $object, '
        'onTop: $onTop, '
        'animate: $animate, '
        'stepPerFrame: $stepPerFrame, '
        'frames: $frames)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StepObject &&
        other.object == object &&
        other.onTop == onTop &&
        other.animate == animate &&
        other.stepPerFrame == stepPerFrame &&
        other.frames == frames;
  }

  @override
  int get hashCode =>
      object.hashCode ^
      onTop.hashCode ^
      animate.hashCode ^
      stepPerFrame.hashCode ^
      frames;
}

class StepObjects extends Event {
  /// The objects that are being animated.
  final List<FieldObject> objects;

  /// Whether the object should appear on top of other objects
  /// for the duration of the movement.
  final bool onTop;

  /// Whether the object's sprite should animate different frames
  /// during the movement.
  final bool animate;

  /// Relative movement per frame in pixels.
  final Point<double> stepPerFrame;

  /// How many frames should the movement last. > 0.
  final int frames;

  StepObjects(this.objects,
      {this.onTop = false,
      this.animate = true,
      required this.stepPerFrame,
      required this.frames}) {
    checkArgument(objects.isNotEmpty, message: 'Objects must not be empty.');
    checkArgument(frames > 0, message: 'Frames must be greater than 0.');
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.stepObjects(this);
  }

  @override
  String toString() {
    return 'StepObjects('
        'objects: $objects, '
        'onTop: $onTop, '
        'animate: $animate, '
        'stepPerFrame: $stepPerFrame, '
        'frames: $frames)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StepObjects &&
        const ListEquality<FieldObject>().equals(other.objects, objects) &&
        other.onTop == onTop &&
        other.animate == animate &&
        other.stepPerFrame == stepPerFrame &&
        other.frames == frames;
  }

  @override
  int get hashCode =>
      const ListEquality<FieldObject>().hash(objects) ^
      onTop.hashCode ^
      animate.hashCode ^
      stepPerFrame.hashCode ^
      frames;
}

class JumpObject extends Event {
  final List<FieldObject> objects;
  final Duration duration;
  // todo: this could be Point movement like above
  // to allow jumping up/down as well.
  // However there is some complexity as actually moving up would potentially
  // mean z ordering would need to change during the jump.
  final int xMovement;
  // todo: make a point type?
  /// Offsets y-movement after the peak of the jump.
  ///
  /// The [height] of the jump is the only factor in the first "phase" of the
  /// jump (going up). But going down, the amount is `height + yMovement`.
  final int yMovement;
  final int height;

  JumpObject(FieldObject object,
      {required Duration duration,
      required int height,
      int xMovement = 0,
      int yMovement = 0})
      : this.all([object],
            duration: duration,
            height: height,
            xMovement: xMovement,
            yMovement: yMovement);

  JumpObject.all(this.objects,
      {required this.duration,
      required this.height,
      this.xMovement = 0,
      this.yMovement = 0}) {
    checkArgument(objects.isNotEmpty, message: 'Objects must not be empty.');
    checkArgument(duration > Duration.zero,
        message: 'Duration must be greater than 0.');
    checkArgument(height > 0, message: 'Height must be greater than 0.');
  }

  List<StepObjects> toSteps() {
    var totalFrames = duration.toFrames();
    var xPerFrame = xMovement / totalFrames;
    var yMagnitude = height * 2 + yMovement.abs();
    var portionUp = height / yMagnitude;
    var portionDown = (height + yMovement.abs()) / yMagnitude;
    var framesUp = (portionUp * totalFrames).round();
    var framesDown = (portionDown * totalFrames).round();
    var down = Point<double>(xPerFrame, (height + yMovement) / framesDown);
    var up = Point<double>(xPerFrame, -height / framesUp);
    return [
      StepObjects(objects,
          stepPerFrame: up, frames: framesUp, onTop: true, animate: false),
      StepObjects(objects,
          stepPerFrame: down, frames: framesDown, onTop: true, animate: false)
    ];
  }

  @override
  void visit(EventVisitor visitor) {
    for (var step in toSteps()) {
      visitor.stepObjects(step);
    }
  }

  @override
  String toString() {
    return 'JumpObject(objects: $objects, '
        'duration: $duration, '
        'height: $height, '
        'xMovement: $xMovement)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JumpObject &&
        const ListEquality<FieldObject>().equals(other.objects, objects) &&
        other.duration == duration &&
        other.xMovement == xMovement &&
        other.height == height;
  }

  @override
  int get hashCode =>
      const ListEquality<FieldObject>().hash(objects) ^
      duration.hashCode ^
      height.hashCode ^
      xMovement.hashCode;
}

extension TruncatePoint on Point<double> {
  Point<int> truncate() {
    return Point<int>(x.truncate(), y.truncate());
  }
}
