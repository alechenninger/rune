import 'dart:collection';
import 'dart:math';

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
  Asm generateAsm(AsmGenerator generator, EventContext ctx);
}

class EventContext {
  final positions = <Moveable, Point<int>>{};
  final facing = <Moveable, Direction>{};
  final slots = <Character>[];

  /// Whether or not to follow character at slot[0]
  bool followLead = true;
}

class Scene {
  final List<Event> events = [];

  // consider encoding the transition between events and dialog here?
  // e.g. whether or not using F7 or FF

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
  Map<Moveable, Movement> movements = {};

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

  /// Distance in steps.
  int get distance;
}

class StepDirection extends Movement {
  var direction = Direction.up;
  @override
  var distance = 0;
  @override
  var delay = 0;

  // TODO: may want to define in base
  // TODO: should have bounds check
  StepDirection less(int distance) => StepDirection()
    ..distance = this.distance - distance
    ..delay = delay
    ..direction = direction;

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
  final _directions = <StepDirection>[];

  void step(StepDirection step) {
    _directions.add(step);
  }

  @override
  int get distance => _directions
      .map((e) => e.distance)
      .reduce((value, element) => value + element);
  @override
  var delay = 0;
}

class StepToPoint extends Movement {
  // TODO could be used to inform whether multiple characters movements need
  //   to be split up into multiple movement events
  @override
  int get distance {
    if (destinations.isEmpty) return 0;
    return destinations.map((d) {
      var diff = (d - start);
      // Characters move one axis at a time
      return diff.x.abs() + diff.y.abs();
    }).reduce((d1, d2) => d1 + d2);
  }

  int facing;
  @override
  int delay = 0;
  Point<int> start;
  final List<Point<int>> destinations = [];

  StepToPoint(this.start, {this.facing = 0});

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
  String toString() => 'Alys';
}

class Shay extends Character {
  const Shay();
  String toString() => 'Shay';
}

class Direction {
  final Point<int> normal;
  const Direction._(this.normal);
  static const up = Direction._(Point(0, -1));
  static const left = Direction._(Point(-1, 0));
  static const right = Direction._(Point(1, 0));
  static const down = Direction._(Point(0, 1));

  @override
  String toString() {
    return 'Direction{normal: $normal}';
  }
}
