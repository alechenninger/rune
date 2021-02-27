import 'dart:collection';

import 'package:characters/characters.dart';

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
  int get distance => 0;
  int get facing => 0;

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

abstract class Character {}

class Alys extends Character {}

class Shay extends Character {}

class Context {
  final slots = <Character>[];
  // positions?
}
