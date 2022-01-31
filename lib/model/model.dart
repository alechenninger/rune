import 'dart:collection';
import 'dart:math';
import 'dart:math' as math;

import 'package:characters/src/extensions.dart';
import 'package:rune/generator/generator.dart';

/*
Scene: Introduction (Prologue)

Alys: What a time. ...
Fade in
Alys starts at #, #
Shay starts at #, #
Alys moves to #, #, x first, facing up
Shay moves to #, #, x first, facing down
Alys: Our fortune took flight, on swift wings from ‘the desert garden’.
Shay: I’m ready, Alys.
Alys: It must feel exhilarating–your first assignment as a full-on hunter!
Shay: Feels...like it’s meant to be.  Like the pieces are finally coming together.
Alys: Maybe so.

Alys walks 10 steps right, 10 steps up.
After 5 steps, Shay walks 10 right, 5 steps up.
The camera locks.
Alys walks 5 steps up.
Alys faces up.

Shay: Nothing ‘maybe’ about it.
Alys: Let us see how you get on.
Shay: We’ll meet head-on whatever the guild throws our way.  They’ll have to go looking for new cases instead of waiting for the work to come in.

Alys moves 2 steps down

Alys: Steel yourself and do not boast.  The affairs of men weigh heavy on the spirit. And you must heed yours, Shay Ashleigh, lest this world of sand and sorrow pull you under.
Shay: The world...I owe nothing. I owe you everything, Alys.  And, to think...partners with a hunter of your renown.

The camera unlocks.
Alys walks 3 steps down.

Alys: Fame. Trophies. Titles. Grains of sand in a desert with no name. Those who swear by these alone are as easily swept away.
Shay: Hmmm...  But you have to admit— “She’ll make quite the mess, of a beast or any foe, an arm, a leg and every toe, in eight strokes or less.”  —That kind of reputation has a way of opening doors!

Alys walks 1 step down.
Shay is pushed 3 spaces right.
Alys continues 3 steps down.
Alys faces up.
Shay faces down.

Alys: And closing as many more.  You know I loathe that rhyme.
  Ever heard it sung out loud?  It can be quite lovely.

  How flattering.

  ...

  Well, aren’t you curious to know what troubles befall the “budding heads of our desert garden estate”—

  “Come one come all, let not our future garden bloom an hour too late”.  Ah yes...Motavia Academy.

  A well-endowed patron for sure.

  My first guess: they’d like us to ‘cut’ the blooming genius who composed that sickening verse.

  Oh...but have you heard it sung out loud?

  Ah...guess I had that coming.

  But, you are right.  There is a certain pretense about our patron’s words and ways.  It does not always go down easily.

  I’ll say.  More like... ‘butting’ heads.  I hear those dormitory parties can be raucous.  So, uh, what’s this really about?

  I do not know.  They ask that we come at once and are paying handsomely for our haste...and discretion.

Alys and Shay exit the house.

 */

abstract class Event {
  // TODO: should probably not have this here? creates dependency on generator
  // from model
  Asm generateAsm(AsmGenerator generator, EventContext ctx);
}

class EventContext {
  final positions = <Moveable, Point<int>>{};
  final facing = <Moveable, Direction>{};
  final slots = <Character>[];
  var startingAxis = Axis.x;

  /// Whether or not to follow character at slot[0]
  var followLead = true;
}

class Scene {
  final List<Event> events = [];

  void addEvent(Event event) {
    events.add(event);
  }
}

class Pause extends Event {
  final Duration duration;

  Pause(this.duration);

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    return generator.pauseToAsm(this);
  }
}

/// The party follows the leader
class PartyMove extends Event {
  Movement movement;

  PartyMove(this.movement);

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    return generator.partyMoveToAsm(this, ctx);
  }
}

/// A group of parallel movements
class IndividualMoves extends Event {
  // TODO: what if Slot and Character moveables refer to same Character?
  Map<Moveable, Movement> moves = {};

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    return generator.individualMovesToAsm(this, ctx);
  }
}

// character by name? character by slot? party?
abstract class Moveable {
  const Moveable();

  int compareTo(Moveable other, EventContext ctx) {
    var thisSlot = _slotOf(this, ctx);
    var otherSlot = _slotOf(other, ctx);

    if (thisSlot != null && otherSlot != null) {
      return thisSlot.compareTo(otherSlot);
    }

    return toString().compareTo(other.toString());
  }
}

int? _slotOf(Moveable m, EventContext c) {
  if (m is Slot) return m.index;
  if (m is Character) return c.slots.indexOf(m);
  return null;
}

abstract class Movement {
  /// Delay in steps before movement starts parallel with other movements.
  int get delay;

  /// Total duration including all delays and movements
  int get duration;

  /// Total distance in steps.
  int get distance;

  /// Current facing direction
  /// TODO: rename
  Direction get direction;

  Movement less(int steps);

  /// Movements which are continuous (there is no pause in between) and should
  /// start immediately (delay should == 0).
  // todo: should this just be StepDirection to include delays?
  List<Vector> get continuousMovements;

  RelativeMoves lookahead(int steps) {
    var stepsTaken = 0;
    var movements = List.of(continuousMovements);
    var movesMade = <Vector>[];

    while (stepsTaken < steps) {
      for (var i = 0; stepsTaken < steps && i < movements.length; i++) {
        var move = movements[i].min(steps - stepsTaken);
        stepsTaken += move.steps;
        movesMade.add(move);
      }

      var remaining = steps - stepsTaken;
      if (remaining > 0) {
        var after = less(stepsTaken);
        var delayToTake = min(remaining, after.delay);
        after = after.less(delayToTake);
        stepsTaken += delayToTake;
        movements = List.of(after.continuousMovements);
      }
    }

    return RelativeMoves(movesMade);
  }

  /// Continuous movements if one axis is moved at a time, and the first must be
  /// [axis]
  List<Vector> continuousMovementsFirstAxis(Axis axis) {
    if (continuousMovements.isEmpty) return [];
    var first = continuousMovements[0];
    if (first.direction.axis == axis) {
      return continuousMovements.sublist(0, min(2, continuousMovements.length));
    }
    return [first];
  }

  /// The amount of steps in continuous movements limited to one axis at a time
  /// where the first axis is [axis].
  int delayOrContinuousStepsFirstAxis(Axis axis) {
    return delay > 0
        ? delay
        : continuousMovementsFirstAxis(axis)
            .map((m) => m.steps)
            .reduce((sum, s) => sum + s);
  }
}

class StepDirection extends Movement {
  @override
  var direction = Direction.up;
  @override
  var distance = 0;
  @override
  var delay = 0;

  @override
  int get duration => delay + distance;

  Vector get asVector => Vector(distance, direction);

  @override
  List<Vector> get continuousMovements => delay > 0 ? [] : [asVector];

  // TODO: may want to define in base
  // TODO: should have bounds check
  @override
  StepDirection less(int distance) {
    if (distance > this.distance + delay) throw StateError('negative distance');

    var answer = StepDirection()..direction = direction;

    var lessDelay = min(distance, delay);
    answer.delay = delay - lessDelay;

    var remainingToTravel = distance - lessDelay;
    answer.distance = this.distance - remainingToTravel;

    return answer;
  }

  @override
  String toString() {
    return 'StepDirection{direction: $direction, distance: $distance, delay: $delay}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepDirection &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          distance == other.distance &&
          delay == other.delay;

  @override
  int get hashCode => direction.hashCode ^ distance.hashCode ^ delay.hashCode;
}

class StepDirections extends Movement {
  final _steps = <StepDirection>[];

  void step(StepDirection step) {
    _steps.add(step);
  }

  void face(Direction direction) {
    _steps.add(StepDirection()..direction = direction);
  }

  @override
  int get distance => _steps.isEmpty
      ? 0
      : _steps.map((e) => e.distance).reduce((sum, d) => sum + d);

  @override
  int get delay => _steps.isEmpty ? 0 : _steps.first.delay;

  @override
  int get duration => _steps.isEmpty
      ? 0
      : _steps.map((s) => s.duration).reduce((sum, d) => sum + d);

  @override
  Direction get direction =>
      // TODO: what to do if no steps?
      _steps.isEmpty ? Direction.down : _steps.first.direction;

  @override
  List<Vector> get continuousMovements => _steps
      .takeWhile((step) => step.delay == 0)
      .map((e) => e.asVector)
      .toList();

  @override
  StepDirections less(int distance) {
    if (distance > duration) throw StateError('negative distance');
    if (distance == 0) return this;

    var totalSubtracted = 0;
    var answer = StepDirections();
    StepDirection? lastStep;

    for (var step in _steps) {
      var canMove = min(distance - totalSubtracted, step.distance);
      lastStep = step.less(canMove);

      if (lastStep.duration > 0 || answer._steps.isNotEmpty) {
        answer.step(lastStep);
      }

      totalSubtracted += canMove;
    }

    if (answer._steps.isEmpty && lastStep != null) {
      answer.step(lastStep);
    }

    return answer;
  }

  @override
  String toString() {
    return 'StepDirections{$_steps}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepDirections &&
          runtimeType == other.runtimeType &&
          _steps == other._steps;

  @override
  int get hashCode => _steps.hashCode;
}

class StepToPoint extends Movement {
  // TODO could be used to inform whether multiple characters movements need
  //   to be split up into multiple movement events
  @override
  int get distance => movement.steps;

  int facing;
  @override
  int delay = 0;
  Point<int> start;
  Axis startAlong = Axis.x;
  Point<int> destination = Point(0, 0);
  Point<int> get movement => destination - start;

  StepToPoint(this.start, {this.facing = 0});

  /// Just changes starting point because end point is set.
  @override
  StepToPoint less(int distance) {
    if (distance > this.distance) throw StateError('negative distance');

    var newStart = start;

    int subtractXUpTo(int distance) {
      var axisSubtracted = min(movement.x.abs(), distance);
      newStart += Point(movement.x - axisSubtracted * movement.x.sign, 0);
      return axisSubtracted;
    }

    int subtractYUpTo(int distance) {
      var axisSubtracted = min(movement.y.abs(), distance);
      newStart += Point(0, movement.y - axisSubtracted * movement.y.sign);
      return axisSubtracted;
    }

    if (startAlong == Axis.x) {
      var traveled = subtractXUpTo(distance);
      subtractYUpTo(distance - traveled);
    } else {
      var traveled = subtractYUpTo(distance);
      subtractXUpTo(distance - traveled);
    }

    return StepToPoint(newStart, facing: facing)
      ..delay = delay
      ..startAlong = startAlong
      ..destination = destination;
  }

  @override
  // TODO: implement continuousMovements
  List<Vector> get continuousMovements => throw UnimplementedError();

  @override
  // TODO: implement direction
  Direction get direction => throw UnimplementedError();

  @override
  // TODO: implement duration
  int get duration => throw UnimplementedError();

// coordinates here
// we could potentially support arbitrary x/y order rather than relying on the
// char move flag by simply moving one direction at a time in the generated
// code
}

// class Follow extends Movement {
//   Moveable following;
//   @override
//   int distance = 0;
//
//   // or predicate?
//   // probably can't because its not like we're evaluating the
//   // program step by step...
//   // Point? until;
//
//   @override
//   var delay = 0;
//   int? stopAfterDistance;
//   int? stopAfterMovements;
//
//   Follow(this.following, {this.distance = 0});
// }

class Dialog extends Event {
  Character? speaker;
  final List<Span> _spans;
  List<Span> get spans => UnmodifiableListView(_spans);

  Dialog({this.speaker, List<Span> spans = const []}) : _spans = spans {
    if (_spans.isEmpty) {
      throw ArgumentError.value(
          spans, 'spans', 'must contain at least one span');
    }
  }

  @override
  String toString() {
    return 'Dialog{speaker: $speaker, _spans: $_spans}';
  }

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    return generator.dialogToAsm(this);
  }
}

class Span {
  final String text;
  final bool italic;

  Span(this.text, this.italic);

  // TODO: markup parsing belongs in parse layer
  static List<Span> parse(String markup) {
    var _spans = <Span>[];
    var italic = false;
    var text = StringBuffer();

    for (var c in markup.characters) {
      // Note, no escape sequence support, but at the moment not needed because
      // _ not otherwise a supported character in dialog.
      if (c == '_') {
        if (text.isNotEmpty) {
          _spans.add(Span(text.toString(), italic));
          text.clear();
        }
        italic = !italic;
        continue;
      }

      text.write(c);
    }

    if (text.isNotEmpty) {
      _spans.add(Span(text.toString(), italic));
    }

    return _spans;
  }

  @override
  String toString() {
    return 'Span{text: $text, italic: $italic}';
  }
}

class Slot extends Moveable {
  final int index;

  Slot(this.index);
}

// class Party extends Moveable {}

abstract class Character extends Moveable {
  const Character();

  /// throws if no character found by name.
  static Character? byName(String name) {
    switch (name.toLowerCase()) {
      case 'alys':
        return alys;
      case 'shay':
        return shay;
    }
    throw ArgumentError.value(name, 'name', 'does not match known character');
  }
}

const alys = Alys();
const shay = Shay();

class Alys extends Character {
  const Alys();
  @override
  String toString() => 'Alys';
}

class Shay extends Character {
  const Shay();
  @override
  String toString() => 'Shay';
}

class Direction {
  final Point<int> normal;
  const Direction._(this.normal);
  static const up = Direction._(Point(0, -1));
  static const left = Direction._(Point(-1, 0));
  static const right = Direction._(Point(1, 0));
  static const down = Direction._(Point(0, 1));

  Axis get axis => normal.x == 0 ? Axis.y : Axis.x;

  @override
  String toString() {
    return 'Direction{normal: $normal}';
  }
}

enum Axis { x, y }

class Vector {
  final int steps;
  final Direction direction;

  Vector(this.steps, this.direction);

  Point<int> get asPoint => direction.normal * steps;

  Vector less(int steps) => Vector(this.steps - steps, direction);

  Vector max(int steps) => Vector(math.max(this.steps, steps), direction);

  Vector min(int steps) => Vector(math.min(this.steps, steps), direction);

  @override
  String toString() {
    return '$direction * $steps';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector &&
          runtimeType == other.runtimeType &&
          steps == other.steps &&
          direction == other.direction;

  @override
  int get hashCode => steps.hashCode ^ direction.hashCode;
}

extension PointSteps<T extends num> on Point<T> {
  T get steps => (x.abs() + y.abs()) as T;
}

class RelativeMoves {
  final List<Vector> movesMade;
  Point<int> get relativePosition =>
      movesMade.map((m) => m.asPoint).reduce((sum, p) => sum + p);
  Direction get facing => movesMade.last.direction;

  RelativeMoves(this.movesMade);
}
