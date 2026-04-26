/// Events for "animating" characters.
library;

import 'dart:math';

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
  final Vector2dExpression stepPerFrame;

  /// How many frames should the movement last. > 0.
  final int frames;

  StepObject(this.object,
      {this.onTop = false,
      this.animate = true,
      required this.stepPerFrame,
      required this.frames}) {
    checkArgument(frames > 0, message: 'Frames must be greater than 0.');
  }

  StepObject.constantStep(this.object,
      {this.onTop = false,
      this.animate = true,
      required Point<double> stepPerFrame,
      required this.frames})
      : stepPerFrame =
            Vector2dOfXY(Double(stepPerFrame.x), Double(stepPerFrame.y)) {
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
  final Vector2dExpression stepPerFrame;

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

  StepObjects.constantStep(this.objects,
      {this.onTop = false,
      this.animate = true,
      required Point<double> stepPerFrame,
      required this.frames})
      : stepPerFrame =
            Vector2dOfXY(Double(stepPerFrame.x), Double(stepPerFrame.y)) {
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

enum ShutterStart {
  up(Point(0, -1)),
  down(Point(0, 1));

  final Point<double> step;

  const ShutterStart(this.step);
}

enum TurnTimingPreset { quickToSlow, constant, slowToQuick, easeInOut }

extension TurnTimingPresetValues on TurnTimingPreset {
  Duration get startDelay => switch (this) {
        TurnTimingPreset.quickToSlow => Duration.zero,
        TurnTimingPreset.constant => const Duration(milliseconds: 120),
        TurnTimingPreset.slowToQuick => const Duration(milliseconds: 250),
        TurnTimingPreset.easeInOut => const Duration(milliseconds: 80),
      };

  Duration get endDelay => switch (this) {
        TurnTimingPreset.quickToSlow => const Duration(milliseconds: 250),
        TurnTimingPreset.constant => const Duration(milliseconds: 120),
        TurnTimingPreset.slowToQuick => Duration.zero,
        TurnTimingPreset.easeInOut => const Duration(milliseconds: 160),
      };

  double get curve => switch (this) {
        TurnTimingPreset.quickToSlow => 2,
        TurnTimingPreset.constant => 1,
        TurnTimingPreset.slowToQuick => 2,
        TurnTimingPreset.easeInOut => 0.5,
      };
}

class TurnObject extends Event {
  final FieldObject object;
  final int quarterTurns;

  /// Delay before the first turn.
  final Duration preDelay;

  /// Delay after the last turn.
  final Duration postDelay;

  /// Delay for the first pause between turns.
  final Duration startDelay;

  /// Delay for the last pause between turns.
  final Duration endDelay;

  /// Easing curve used to interpolate delays between turns.
  final double curve;

  TurnObject(this.object,
      {required this.quarterTurns,
      this.preDelay = Duration.zero,
      this.postDelay = Duration.zero,
      required this.startDelay,
      Duration? endDelay,
      this.curve = 1.0})
      : endDelay = endDelay ?? startDelay {
    checkArgument(quarterTurns != 0, message: 'quarterTurns must be non-zero.');
    checkArgument(preDelay >= Duration.zero,
        message: 'preDelay must be non-negative.');
    checkArgument(postDelay >= Duration.zero,
        message: 'postDelay must be non-negative.');
    checkArgument(startDelay >= Duration.zero,
        message: 'startDelay must be non-negative.');
    checkArgument(this.endDelay >= Duration.zero,
        message: 'endDelay must be non-negative.');
    checkArgument(curve > 0, message: 'curve must be greater than 0.');
  }

  TurnObject.preset(this.object,
      {required this.quarterTurns,
      required TurnTimingPreset timingPreset,
      this.preDelay = Duration.zero,
      this.postDelay = Duration.zero})
      : startDelay = timingPreset.startDelay,
        endDelay = timingPreset.endDelay,
        curve = timingPreset.curve {
    checkArgument(quarterTurns != 0, message: 'quarterTurns must be non-zero.');
    checkArgument(preDelay >= Duration.zero,
        message: 'preDelay must be non-negative.');
    checkArgument(postDelay >= Duration.zero,
        message: 'postDelay must be non-negative.');
    checkArgument(startDelay >= Duration.zero,
        message: 'startDelay must be non-negative.');
    checkArgument(endDelay >= Duration.zero,
        message: 'endDelay must be non-negative.');
    checkArgument(curve > 0, message: 'curve must be greater than 0.');
  }

  List<Event> toEvents() {
    var turns = quarterTurns.abs();
    var turnDirection = quarterTurns.isNegative ? -1 : 1;
    var pauses = _betweenTurnDelays(turns);
    var events = <Event>[];

    if (preDelay > Duration.zero) {
      events.add(Pause(preDelay));
    }

    for (var i = 0; i < turns; i++) {
      var movement = StepPath()..facing = object.facing().turn(turnDirection);
      events.add(IndividualMoves()..moves[object] = movement);

      if (i < pauses.length && pauses[i] > Duration.zero) {
        events.add(Pause(pauses[i]));
      }
    }

    if (postDelay > Duration.zero) {
      events.add(Pause(postDelay));
    }

    return events;
  }

  List<Duration> _betweenTurnDelays(int turns) {
    var count = max(0, turns - 1);
    if (count == 0) {
      return const [];
    }

    if (count == 1) {
      return [startDelay];
    }

    return [for (var i = 0; i < count; i++) _delayAt(i, count)];
  }

  Duration _delayAt(int index, int count) {
    var t = index / (count - 1);
    var eased = pow(t, curve).toDouble();
    return _lerpDuration(startDelay, endDelay, eased);
  }

  Duration _lerpDuration(Duration start, Duration end, double t) {
    var microseconds =
        start.inMicroseconds + (end.inMicroseconds - start.inMicroseconds) * t;
    return Duration(microseconds: microseconds.round());
  }

  @override
  void visit(EventVisitor visitor) {
    for (var event in toEvents()) {
      event.visit(visitor);
    }
  }

  @override
  String toString() {
    return 'TurnObject('
        'object: $object, '
        'quarterTurns: $quarterTurns, '
        'preDelay: $preDelay, '
        'startDelay: $startDelay, '
        'endDelay: $endDelay, '
        'postDelay: $postDelay, '
        'curve: $curve)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TurnObject &&
        other.object == object &&
        other.quarterTurns == quarterTurns &&
        other.preDelay == preDelay &&
        other.startDelay == startDelay &&
        other.endDelay == endDelay &&
        other.postDelay == postDelay &&
        other.curve == curve;
  }

  @override
  int get hashCode =>
      object.hashCode ^
      quarterTurns.hashCode ^
      preDelay.hashCode ^
      startDelay.hashCode ^
      endDelay.hashCode ^
      postDelay.hashCode ^
      curve.hashCode;
}

class ShutterObjects extends Event {
  final List<FieldObject> objects;
  final Duration duration;
  final int times;
  final ShutterStart start;

  ShutterObjects(this.objects,
      {required this.duration,
      required this.times,
      this.start = ShutterStart.down}) {
    checkArgument(objects.isNotEmpty, message: 'Objects must not be empty.');
    checkArgument(duration > Duration.zero,
        message: 'Duration must be greater than 0.');
    checkArgument(times > 0, message: 'Times must be greater than 0.');
  }

  @override
  void visit(EventVisitor visitor) {
    for (var event in toEvents()) {
      event.visit(visitor);
    }
  }

  List<Event> toEvents() {
    var framesPerShutter = duration.toFrames();
    var pauseTime = max(0, (framesPerShutter - 2) ~/ 2).framesToDuration();
    var events = <Event>[];
    var addEvents = pauseTime > Duration.zero
        ? (e) => _addEventsWithPause(e, pauseTime)
        : _addEventsWithoutPause;

    for (var i = 0; i < times; i++) {
      addEvents(events);
    }

    return events;
  }

  _addEventsWithPause(List events, Duration pause) {
    events.add(
        StepObjects.constantStep(objects, stepPerFrame: start.step, frames: 1));
    events.add(Pause(pause));
    events.add(StepObjects.constantStep(objects,
        stepPerFrame: start.step * -1, frames: 1));
    events.add(Pause(pause));
  }

  _addEventsWithoutPause(List events) {
    events.add(
        StepObjects.constantStep(objects, stepPerFrame: start.step, frames: 1));
    events.add(StepObjects.constantStep(objects,
        stepPerFrame: start.step * -1, frames: 1));
  }

  @override
  String toString() {
    return 'ShutterObjects(objects: $objects, '
        'duration: $duration, '
        'times: $times)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShutterObjects &&
        const ListEquality<FieldObject>().equals(other.objects, objects) &&
        other.duration == duration &&
        other.times == times;
  }

  @override
  int get hashCode =>
      const ListEquality<FieldObject>().hash(objects) ^
      duration.hashCode ^
      times.hashCode;
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
  final bool animate;

  JumpObject(FieldObject object,
      {required Duration duration,
      required int height,
      int xMovement = 0,
      int yMovement = 0,
      bool animate = false})
      : this.all([object],
            duration: duration,
            height: height,
            xMovement: xMovement,
            yMovement: yMovement,
            animate: animate);

  JumpObject.all(this.objects,
      {required this.duration,
      required this.height,
      this.xMovement = 0,
      this.yMovement = 0,
      this.animate = false}) {
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
      StepObjects.constantStep(objects,
          stepPerFrame: up, frames: framesUp, onTop: true, animate: animate),
      StepObjects.constantStep(objects,
          stepPerFrame: down, frames: framesDown, onTop: true, animate: animate)
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
        'xMovement: $xMovement, '
        'yMovement: $yMovement, '
        'animate: $animate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JumpObject &&
        const ListEquality<FieldObject>().equals(other.objects, objects) &&
        other.duration == duration &&
        other.xMovement == xMovement &&
        other.height == height &&
        other.yMovement == yMovement &&
        other.animate == animate;
  }

  @override
  int get hashCode =>
      const ListEquality<FieldObject>().hash(objects) ^
      duration.hashCode ^
      height.hashCode ^
      xMovement.hashCode ^
      yMovement.hashCode ^
      animate.hashCode;
}

extension TruncatePoint on Point<double> {
  Point<int> truncate() {
    return Point<int>(x.truncate(), y.truncate());
  }
}
