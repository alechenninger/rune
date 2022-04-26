/*
pattern matching based on context

instruction
 */

import 'package:logging/logging.dart';
import 'package:rune/numbers.dart';
import 'package:rune/src/logging.dart';

import '../model/model.dart';

// todo: see ParseContext idea
var log = Logger('parser/movement');

final topLevelExpressions = <EventExpression>[
  FieldObjectPositionExpression(),
  CharacterInSlotExpression(),
  LockCameraExpression(),
  IndividualMovesExpression(),
  PartyMoveExpression(),
];
final moveExpressions = <MoveExpression>[RelativeMoveExpression()];

// todo: probably want a ParseContext as input or something
// do not assume buffered entire script
// methods to lookahead which do some buffering until that part is parsed by
// something successfully
// it would be easier to track unparsed if i did this

List<Event> parseEvents(String script) {
  var toParse = script.trimLeft();
  var events = <Event>[];
  while (toParse.isNotEmpty) {
    var parseable = false;

    for (var expression in topLevelExpressions) {
      try {
        var parsed = expression.parse(toParse);
        parseable = true;
        var parsedText =
            toParse.substring(0, toParse.length - parsed.unparsed.length);
        toParse = _pEnd.parse(parsed.unparsed).unparsed;
        events.add(parsed.result);
        log.f(e(
            'parsed_movement', {'text': parsedText, 'result': parsed.result}));
      } on FormatException catch (err) {
        log.finer(
            e('unmatched_movement_expression', {'exp': expression.runtimeType}),
            err);
        continue;
      }
    }

    if (!parseable) {
      if (toParse.isNotEmpty) {
        log.e(e('unparseable', {'text': toParse}));
      }
      break;
    }
  }

  return events;
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

final _pMoveable = RegExp(r'^(?:(?:[Tt]he character in )?[Ss]lot (?<slot>\d+)|'
    r'(?:[Tt]he )?(?<party>[Pp]arty)|'
    r'(?<character>\w+)) ');
final _pEnd = RegExp(r'^[. \n]*');
final _pAndThen = RegExp(r',? ?((and|then|and then) )?');
final _pPosition = RegExp(r'(?<x_hex>[$#])?(?<x>[A-F\d]+),? ?'
    r'(?<y_hex>[$#])?(?<y>[A-F\d]+)');

class FieldObjectPositionExpression extends EventExpression {
  static final _pStartsAt = RegExp(r'^(starts|is) at ');

  @override
  ParseResult<Event> parse(String expression) {
    var parseMoveable = _parseMoveable<FieldObject>(expression);
    var parseStartsAt = _pStartsAt.parse(parseMoveable.unparsed);
    var parsePoint = _parsePosition(parseStartsAt.unparsed);

    var unparsed = _pEnd.parse(parsePoint.unparsed).unparsed;
    var moveable = parseMoveable.result;

    return ParseResult(SetContext((ctx) {
      ctx.positions[moveable] = parsePoint.result;
    }), unparsed);
  }
}

class CharacterInSlotExpression extends EventExpression {
  static final _pInSlot = RegExp(r'^is in slot (?<slot>\d+)');

  @override
  ParseResult<Event> parse(String expression) {
    var parsedMoveable = _parseMoveable<Character>(expression);

    var moveable = parsedMoveable.result;

    var slot = _pInSlot.parseValue(parsedMoveable.unparsed,
        (match) => int.parse(match.namedGroup('slot')!));
    var unparsed = _pEnd.parse(slot.unparsed).unparsed;

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
    return moveExpressions.any((m) => m.matches<FieldObject>(expression));
  }

  @override
  ParseResult<Event> parse(String expression) {
    var toParse = expression;
    var moves = IndividualMoves();

    while (toParse.isNotEmpty) {
      var parseable = false;

      for (var expression in moveExpressions) {
        try {
          var parsed = expression.parse<FieldObject>(toParse, moves);
          parseable = true;

          var result = parsed.result;

          var existing = moves.moves[result.moveable];
          if (existing != null) {
            // try to append
            var appended = existing.append(result.movement);
            if (appended == null) {
              // Another move for same character and can't append.
              // Abort to be parsed with fresh move
              return ParseResult(moves, toParse);
            }

            moves.moves[result.moveable] = appended;
          } else {
            moves.moves[result.moveable] = result.movement;
          }

          toParse = parsed.unparsed;
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

class PartyMoveExpression extends EventExpression {
  static final _pStartingAxis =
      RegExp(r'^\(followers? move ([XxYy])[- ]first\.?\)');

  @override
  bool matches(String expression) {
    return moveExpressions.any((m) => m.matches<Party>(expression));
  }

  @override
  ParseResult<Event> parse(String expression) {
    var toParse = expression;

    for (var expression in moveExpressions) {
      try {
        var parsed = expression.parse<Party>(toParse);
        var result = parsed.result;

        var parsedAxis =
            _pStartingAxis.parseOptionalValue(parsed.unparsed, (match) {
          var axis = match.group(1);
          switch (axis?.toLowerCase()) {
            case 'x':
              return Axis.x;
            case 'y':
              return Axis.y;
          }
        });

        var unparsed = parsedAxis?.unparsed ?? parsed.unparsed;
        unparsed = _pEnd.parse(unparsed).unparsed;

        var partyMove = result.moveable.move(result.movement);

        var axis = parsedAxis?.result;
        if (axis != null) {
          partyMove.startingAxis = axis;
        }

        return ParseResult(partyMove, unparsed);
      } on FormatException {
        continue;
      }
    }

    throw FormatException('not a party move', expression, 0);
  }
}

abstract class MoveExpression {
  bool matches<T extends Moveable>(String expression) {
    try {
      parse<T>(expression);
      return true;
    } catch (e) {
      return false;
    }
  }

  ParseResult<Move<T>> parse<T extends Moveable>(String expression,
      [IndividualMoves? moves]);
}

class RelativeMoveExpression extends MoveExpression {
  static final pDelay =
      RegExp(r'^([Tt]hen, |[Aa]fter (?<delay>\d+) (steps?|spaces?),? )');
  static final pSteps =
      RegExp(r'^((walks|continues|moves) )?(?<distance>\d+) ((step|space)s? )?'
          r'(?<direction>\w+)');
  static final pFace = RegExp(r'^(faces|turns) (\w+)');

  @override
  ParseResult<Move<T>> parse<T extends Moveable>(String expression,
      [IndividualMoves? moves]) {
    var parsedDelay = pDelay.parseOptionalValue(expression, (match) {
      var delay = match.namedGroup('delay');
      if (delay == null) {
        return moves?.duration ?? 0.steps;
      }
      return int.parse(delay).steps;
    });

    var delay = parsedDelay?.result ?? 0.steps;
    var unparsed = parsedDelay?.unparsed ?? expression;

    var parsedMoveable = _parseMoveable<T>(unparsed);

    var moveable = parsedMoveable.result;
    var movement = StepPaths();
    var parsed = false;
    unparsed = parsedMoveable.unparsed;

    try {
      for (;;) {
        var match = pSteps.parse(unparsed);
        parsed = true;
        unparsed = match.unparsed;

        var distance = match.result.namedGroup('distance');
        var direction = match.result.namedGroup('direction');
        var steps = StepPath()
          ..distance = int.parse(distance!).steps
          ..direction = _parseDirection(direction!);

        if (delay > 0.steps) {
          steps.delay = delay;
          delay = 0.steps;
        }

        movement.step(steps);

        unparsed = _pAndThen.parse(unparsed).unparsed;
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

    unparsed = _pEnd.parse(unparsed).unparsed;

    return ParseResult(Move(moveable, movement), unparsed);
  }
}

// TODO: broken, doesn't set form
// see: ContextualMovement
// another option is to generate ASM as we parse events, which would populate
// the event context so it can be used to inform the model that is parsed.
class AbsoluteMoveExpression extends MoveExpression {
  static final pDelay =
      RegExp(r'^([Tt]hen, |[Aa]fter (?<delay>\d+) (steps?|spaces?),? )');
  static final pSteps = RegExp(r'^((walks|continues|moves) )?to ');

  @override
  ParseResult<Move<T>> parse<T extends Moveable>(String expression,
      [IndividualMoves? moves]) {
    var parsedDelay = pDelay.parseOptionalValue(expression, (match) {
      var delay = match.namedGroup('delay');
      if (delay == null) {
        return moves?.duration ?? 0.steps;
      }
      return int.parse(delay).steps;
    });

    var delay = parsedDelay?.result ?? 0.steps;
    var unparsed = parsedDelay?.unparsed ?? expression;
    var parsedMoveable = _parseMoveable<T>(unparsed);
    unparsed = parsedMoveable.unparsed;
    unparsed = pSteps.parse(unparsed).unparsed;
    var parsedPoint = _parsePosition(unparsed);
    unparsed = _pEnd.parse(unparsed).unparsed;

    var moveable = parsedMoveable.result;
    var movement = StepToPoint()
      ..delay = delay
      ..to = parsedPoint.result;

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
  ParseResult<U> cast<U>() => ParseResult(result as U, unparsed);

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

ParseResult<T> _parseMoveable<T extends Moveable>(String unparsed) {
  var parsedMoveable = _pMoveable.parseValue(unparsed, (match) {
    var slot = match.namedGroup('slot');
    if (slot != null) {
      return Slot(int.parse(slot));
    }

    if (match.namedGroup('party') != null) {
      return Party();
    }

    var char = match.namedGroup('character');
    if (char != null) {
      var character = Character.byName(char);
      if (character == null) {
        throw FormatException('not character', unparsed, 0);
      }
      return character;
    }
  });

  var moveable = parsedMoveable.result;
  if (moveable is! T) {
    throw FormatException(
        'parsed moveable is not a $T. moveable=$moveable', unparsed, 0);
  }

  return parsedMoveable.cast<T>();
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

ParseResult<Position> _parsePosition(String expression) {
  var pos = _pPosition.parseValue(expression, (match) {
    var x = match.namedGroup('x');
    var y = match.namedGroup('y');

    if (x == null) throw FormatException('no x value', expression, 0);
    if (y == null) throw FormatException('no y value', expression, 0);

    var xVal = match.namedGroup('x_hex') == null ? int.parse(x) : x.hex;
    var yVal = match.namedGroup('y_hex') == null ? int.parse(y) : y.hex;

    return Position(xVal, yVal);
  });
  return pos;
}
