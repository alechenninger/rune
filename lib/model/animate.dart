/// Events for "animating" characters.
library;

import 'dart:math';

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

  /// How many frames should the movement last.
  final int frames;

  StepObject(this.object,
      {this.onTop = false,
      this.animate = true,
      required this.stepPerFrame,
      required this.frames});

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

class JumpObject extends Event {
  final FieldObject object;
  final Duration duration;
  // todo: this could be Point movement like above
  // to allow jumping up/down as well.
  // However there is some complexity as actually moving up would potentially
  // mean z ordering would need to change during the jump.
  final int xMovement;
  final int height;

  JumpObject(this.object,
      {required this.duration, required this.height, this.xMovement = 0}) {
    checkArgument(duration > Duration.zero,
        message: 'Duration must be greater than 0.');
    checkArgument(height > 0, message: 'Height must be greater than 0.');
  }

  List<StepObject> toSteps() {
    var totalFrames = duration.toFrames();
    var halfFrames = totalFrames ~/ 2;
    var halfXStep = xMovement / totalFrames / 2;
    var down = Point<double>(halfXStep, height / halfFrames);
    var up = Point<double>(halfXStep, down.y * -1);
    return [
      StepObject(object,
          stepPerFrame: up, frames: halfFrames, onTop: true, animate: false),
      StepObject(object,
          stepPerFrame: down, frames: halfFrames, onTop: true, animate: false)
    ];
  }

  @override
  void visit(EventVisitor visitor) {
    for (var step in toSteps()) {
      visitor.stepObject(step);
    }
  }

  @override
  String toString() {
    return 'JumpObject(object: $object, '
        'duration: $duration, '
        'height: $height, '
        'xMovement: $xMovement)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JumpObject &&
        other.object == object &&
        other.duration == duration &&
        other.xMovement == xMovement &&
        other.height == height;
  }

  @override
  int get hashCode =>
      object.hashCode ^
      duration.hashCode ^
      height.hashCode ^
      xMovement.hashCode;
}

extension TruncatePoint on Point<double> {
  Point<int> truncate() {
    return Point<int>(x.truncate(), y.truncate());
  }
}
