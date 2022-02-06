/*
pattern matching based on context

instruction
 */

import 'dart:math';

import 'package:logger/logger.dart';
import 'package:rune/numbers.dart';

import '../model/model.dart';

// todo: see ParseContext idea
var log = Logger();

final topLevelExpressions = <EventExpression>[
  MoveableStartsAtExpression(),
  MoveableSlotExpression(),
  LockCameraExpression(),
  IndividualMovesExpression(),
];
final moveExpressions = <MoveExpression>[RelativeMoveExpression()];

// todo: probably want a ParseContext as input or something
// do not assume buffered entire script
// methods to lookahead which do some buffering until that part is parsed by
// something successfully
// it would be easier to track unparsed if i did this

Event parseEvent(String script) {
  var toParse = script;
  var events = <Event>[];
  while (toParse.isNotEmpty) {
    var parseable = false;

    for (var expression in topLevelExpressions) {
      try {
        var parsed = expression.parse(toParse);
        parseable = true;
        var parsedText =
            toParse.substring(0, toParse.length - parsed.unparsed.length);
        toParse = pEnd.parse(parsed.unparsed).unparsed;
        events.add(parsed.result);
        log.d('<parsed>\n${parsed.result}\n<from>\n$parsedText');
      } on FormatException catch (e) {
        log.v(e);
        continue;
      }
    }

    if (!parseable) {
      if (toParse.isNotEmpty) {
        log.e('unparseable: $toParse');
      }
      break;
    }
  }
  return AggregateEvent(events);
}

abstract class EventExpression {
  bool matches(String expression) {
    try {
      parse(expression);
      return true;
    } on FormatException {
      return false;
    }
  }

  ParseResult<Event> parse(String expression);
}

final pMoveable = RegExp(r'^([Tt]he character in slot (\d+)|\w+) ');
final pEnd = RegExp(r'^[. \n]*');
final pAndThen = RegExp(r',? ?((and|then|and then) )?');

class MoveableStartsAtExpression extends EventExpression {
  static final pStartsAt =
      RegExp(r'^starts at (?<x_hex>#)?(?<x>\d+),? ?(?<y_hex>#)?(?<y>\d+)');

  @override
  ParseResult<Event> parse(String expression) {
    var parseMoveable = _parseMoveable(expression);
    var startsAt = pStartsAt.parseValue(parseMoveable.unparsed, (match) {
      var x = match.namedGroup('x');
      var y = match.namedGroup('y');

      if (x == null) throw FormatException('no x value', expression, 0);
      if (y == null) throw FormatException('no y value', expression, 0);

      var xVal = match.namedGroup('x_hex') == null ? int.parse(x) : x.hex;
      var yVal = match.namedGroup('y_hex') == null ? int.parse(y) : y.hex;

      return Point(xVal, yVal);
    });

    var unparsed = pEnd.parse(startsAt.unparsed).unparsed;

    return ParseResult(SetContext((ctx) {
      ctx.positions[parseMoveable.result] = startsAt.result;
    }), unparsed);
  }
}

class MoveableSlotExpression extends EventExpression {
  static final pInSlot = RegExp(r'^is in slot (?<slot>\d+)');

  @override
  ParseResult<Event> parse(String expression) {
    var parsedMoveable = _parseMoveable(expression);

    var moveable = parsedMoveable.result;
    if (moveable is! Character) {
      throw FormatException(
          'moveable was not a character: $moveable', expression, 0);
    }

    var slot = pInSlot.parseValue(parsedMoveable.unparsed,
        (match) => int.parse(match.namedGroup('slot')!));
    var unparsed = pEnd.parse(slot.unparsed).unparsed;

    return ParseResult(SetContext((ctx) {
      ctx.slots[slot.result] = moveable;
    }), unparsed);
  }
}

class LockCameraExpression extends EventExpression {
  static final pLock = RegExp(r'^The camera (un)?locks(\W|$)');

  @override
  ParseResult<Event> parse(String expression) {
    var parsed = pLock.parse(expression);
    var event = parsed.result.group(1) == null ? LockCamera() : UnlockCamera();
    return ParseResult(event, parsed.unparsed);
  }
}

class IndividualMovesExpression extends EventExpression {
  @override
  bool matches(String expression) {
    return moveExpressions.any((m) => m.matches(expression));
  }

  @override
  ParseResult<Event> parse(String expression) {
    var toParse = expression;
    var moves = IndividualMoves();

    while (toParse.isNotEmpty) {
      var parseable = false;

      for (var expression in moveExpressions) {
        try {
          var parsed = expression.parse(toParse, moves);
          parseable = true;

          var result = parsed.result;

          if (moves.moves.containsKey(result.moveable)) {
            // Another move for same character; abort to be parsed with fresh
            // move
            return ParseResult(moves, toParse);
          }

          toParse = parsed.unparsed;

          moves.moves[result.moveable] = result.movement;
        } on FormatException {
          continue;
        }
      }

      if (!parseable) {
        break;
      }
    }

    if (moves.moves.isEmpty) {
      throw FormatException('not a move', expression, 0);
    }

    return ParseResult(moves, toParse);
  }
}

abstract class MoveExpression {
  bool matches(String expression) {
    try {
      parse(expression);
      return true;
    } catch (e) {
      return false;
    }
  }

  ParseResult<Move> parse(String expression, [IndividualMoves? moves]);
}

class RelativeMoveExpression extends MoveExpression {
  static final pDelay =
      RegExp(r'^(Then, |After (?<delay>\d+) (steps?|spaces?),? )');
  static final pSteps =
      RegExp(r'^((walks|continues|moves) )?(?<distance>\d+) ((step|space)s? )?'
          r'(?<direction>\w+)');
  static final pFace = RegExp(r'^(faces|turns) (\w+)');

  @override
  ParseResult<Move> parse(String expression, [IndividualMoves? moves]) {
    var parsedDelay = pDelay.parseOptionalValue(expression, (match) {
      var delay = match.namedGroup('delay');
      if (delay == null) {
        return moves == null ? 0 : moves.duration;
      }
      return int.parse(delay);
    });

    var delay = parsedDelay?.result ?? 0;
    var unparsed = parsedDelay?.unparsed ?? expression;

    var parsedMoveable = _parseMoveable(unparsed);

    var moveable = parsedMoveable.result;
    var movement = StepDirections();
    var parsed = false;
    unparsed = parsedMoveable.unparsed;

    try {
      for (;;) {
        var match = pSteps.parse(unparsed);
        parsed = true;
        unparsed = match.unparsed;

        var distance = match.result.namedGroup('distance');
        var direction = match.result.namedGroup('direction');
        var steps = StepDirection()
          ..distance = int.parse(distance!)
          ..direction = _parseDirection(direction!);

        if (delay > 0) {
          steps.delay = delay;
          delay = 0;
        }

        movement.step(steps);

        unparsed = pAndThen.parse(unparsed).unparsed;
      }
    } on FormatException catch (e) {
      // abort; fall through
    }

    var parsedFace = pFace.parseOptionalValue(unparsed, (match) {
      var direction = match.group(2);
      return direction == null ? null : _parseDirection(direction);
    });

    if (parsedFace != null) {
      parsed = true;

      var face = parsedFace.result;
      if (face != null) {
        movement.face(face);
      }
      unparsed = parsedFace.unparsed;
    }

    if (!parsed) {
      throw FormatException('not a relative movement', expression, 0);
    }

    unparsed = pEnd.parse(unparsed).unparsed;

    return ParseResult(Move(moveable, movement), unparsed);
  }
}

extension Parse on RegExp {
  ParseResult<RegExpMatch> parse(String expression) {
    var result = parseOptional(expression);

    if (result == null) {
      throw FormatException('did not match $this', expression, 0);
    }

    return result;
  }

  ParseResult<RegExpMatch>? parseOptional(String expression) {
    var match = firstMatch(expression);

    if (match == null) {
      return null;
    }

    return ParseResult(match, expression.substring(match.end));
  }

  ParseResult<T> parseValue<T>(
      String expression, T Function(RegExpMatch) toValue) {
    var value = parseOptionalValue(expression, toValue);

    if (value == null) {
      throw FormatException('did not match $this', expression, 0);
    }

    return value;
  }

  ParseResult<T>? parseOptionalValue<T>(
      String expression, T Function(RegExpMatch) toValue) {
    var match = firstMatch(expression);

    if (match == null) {
      return null;
    }

    return ParseResult(toValue(match), expression.substring(match.end));
  }
}

class ParseResult<T> {
  T result;
  String unparsed;

  ParseResult(this.result, this.unparsed);

  // String parsed;
  // continue(result, parsed, unparsed) -- cumulative parsed

  @override
  String toString() {
    return '{$result, unparsed: $unparsed}';
  }
}

String _firstLine(String expression) {
  var lineEnd = expression.indexOf('\n');
  var line = lineEnd >= 0 ? expression.substring(0, lineEnd) : expression;
  return line;
}

ParseResult<Moveable> _parseMoveable(String unparsed) {
  var parsedMoveable = pMoveable.parseValue(unparsed, (match) {
    var slot = match.group(2);
    if (slot == null) {
      var character = Character.byName(match.group(1)!);
      if (character == null) {
        throw FormatException('not character', unparsed, 0);
      }
      return character;
    } else {
      return Slot(int.parse(slot));
    }
  });
  return parsedMoveable;
}

Direction _parseDirection(String exp) {
  switch (exp.toLowerCase()) {
    case 'up':
      return Direction.up;
    case 'down':
      return Direction.down;
    case 'left':
      return Direction.left;
    case 'right':
      return Direction.right;
  }
  throw FormatException('not a direction', exp, 0);
}
