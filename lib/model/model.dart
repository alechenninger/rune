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

// coordinates here
// we could potentially support arbitrary x/y order rather than relying on the
// char move flag by simply moving one direction at a time in the generated
// code
}

class Dialog {
  Portrait? speaker;
  final String markup;

  Dialog({this.speaker, required this.markup});
}

abstract class Portrait {}

class Alys extends Portrait {}

class Shay extends Portrait {}
