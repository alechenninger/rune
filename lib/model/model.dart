import 'dart:collection';
import 'dart:math';

import 'package:characters/characters.dart';

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

Shay: Nothing ‘maybe’ about it.
Alys: Let us see how you get on.
Shay: We’ll meet head-on whatever the guild throws our way.  They’ll have to go looking for new cases instead of waiting for the work to come in.
Alys: Steel yourself and do not boast.  The affairs of men weigh heavy on the spirit. And you must heed yours, Shay Ashleigh, lest this world of sand and sorrow pull you under.

  The world...I owe nothing. I owe you everything, Alys.  And, to think...partners with a hunter of your renown.

  Fame. Trophies. Titles. Grains of sand in a desert with no name. Those who swear by these alone are as easily swept away.

  Hmmm...  But you have to admit— “She’ll make quite the mess, of a beast or any foe, an arm, a leg and every toe, in eight strokes or less.”  —That kind of reputation has a way of opening doors!

  And closing as many more.  You know I loathe that rhyme.

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

class Event {}

class AggregateEvent extends Event {
  final List<Event> events = [];
}

class Move extends Event {
  Map<Moveable, Movement> movements = {};
}

// character by name? character by slot?
class Moveable {}

class Movement {
  // TODO could be used to inform whether multiple characters movements need
  //   to be split up into multiple movement events
  int get distance {
    // Characters move one axis at a time
    var diff = (destination - current);
    return diff.x.abs() + diff.y.abs();
  }

  // TODO:
  int get facing => 0;

  Point<int> current;
  Point<int> destination;

  Movement(this.current, this.destination, {int? face});

// coordinates here
// we could potentially support arbitrary x/y order rather than relying on the
// char move flag by simply moving one direction at a time in the generated
// code
}

class Dialog {
  Character? speaker;
  final String markup;
  final List<Span> _spans = [];
  List<Span> get spans => UnmodifiableListView(_spans);

  // TODO: markup maybe belongs in parse layer
  Dialog({this.speaker, required this.markup}) {
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
  }
}

class Span {
  final String text;
  final bool italic;

  Span(this.text, this.italic);
}

class Slot extends Moveable {
  final int index;

  Slot(this.index);
}

abstract class Character extends Moveable {}

class Alys extends Character {}

class Shay extends Character {}

class Context {
  final slots = <Character>[];
  // positions?
}
