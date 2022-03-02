import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:rune/parser/movement.dart';
import 'package:test/test.dart';

void main() {
  test('parses individual moves on separate lines', () {
    var events = parseEvent(r'''Alys starts at #230, #250
Shay starts at #230, #240
Alys is in slot 1
Shay is in slot 2
Alys walks 7 steps right, 9 steps up.
After 3 steps, Shay walks 1 down, walks 7 right, 5 steps up.
''');

    var scene = Scene([events]);
    var generator = AsmGenerator();
    var testCtx = EventContext()
      ..addCharacter(alys, slot: 1, position: Position('230'.hex, '250'.hex))
      ..addCharacter(shay, slot: 2, position: Position('230'.hex, '240'.hex));
    var expected = IndividualMoves()
      ..moves[alys] = (StepDirections()
        ..step(StepDirection()
          ..direction = right
          ..distance = 7.steps)
        ..step(StepDirection()
          ..direction = up
          ..distance = 9.steps))
      ..moves[shay] = (StepDirections()
        ..step(StepDirection()
          ..delay = 3.steps
          ..direction = down
          ..distance = 1.steps)
        ..step(StepDirection()
          ..direction = right
          ..distance = 7.steps)
        ..step(StepDirection()
          ..direction = up
          ..distance = 5.steps));

    expect(events.generateAsm(generator, EventContext()),
        expected.generateAsm(generator, testCtx));

    print(generator.sceneToAsm(scene));
  });

  test('parses individual moves on one line.', () {
    var events = parseEvent(
        r'''Alys starts at #230, #250. Shay starts at #230, #240. Alys is in slot 1. Shay is in slot 2. Alys walks 17 steps left, 11 steps up, 4 steps right, 1 step up
After 2 steps, Shay walks 2 steps down, 14 steps left, and faces up
After 1 step, Shay walks 6 steps up''');

    var scene = Scene([events]);
    var generator = AsmGenerator();

    print(generator.sceneToAsm(scene));
  });

  test('parses party move', () {
    var events = parseEvent(r'''Alys starts at #230, #250
Shay starts at #230, #240
Alys is in slot 1
Shay is in slot 2
The party moves 3 steps right.''');

    var scene = Scene([events]);
    var generator = AsmGenerator();

    print(generator.sceneToAsm(scene));
  });

  test('parses party move with alt follower axis', () {
    var events = parseEvent(r'''Alys starts at #230, #250
Shay starts at #230, #240
Alys is in slot 1
Shay is in slot 2
The party moves 3 steps right (followers move y-first).''');

    var generator = AsmGenerator();

    var testCtx = EventContext()
      ..addCharacter(alys, slot: 1, position: Position('230'.hex, '250'.hex))
      ..addCharacter(shay, slot: 2, position: Position('230'.hex, '240'.hex));
    var expected = IndividualMoves()
      ..moves[alys] = (StepDirections()
        ..step(StepDirection()
          ..direction = right
          ..distance = 3.steps))
      ..moves[shay] = (StepDirections()
        ..step(StepDirection()
          ..direction = down
          ..distance = 1.steps)
        ..step(StepDirection()
          ..direction = right
          ..distance = 2.steps));

    var actual = events.generateAsm(generator, EventContext());
    expect(actual, expected.generateAsm(generator, testCtx));

    print(actual);
  });

  test('bug', () {
    var events = parseEvent(r'''Alys starts at #230, #250
Shay starts at #230, #240
Alys is in slot 1
Shay is in slot 2
Alys walks 17 steps left, 11 steps up, 4 steps right.
After 2 steps, Shay walks 2 steps down, 14 steps left, 6 steps up''');

    var generator = AsmGenerator();

    var actual = events.generateAsm(generator, EventContext());

    var testCtx = EventContext()
      ..addCharacter(alys, slot: 1, position: Position('230'.hex, '250'.hex))
      ..addCharacter(shay, slot: 2, position: Position('230'.hex, '240'.hex));
    var expected = IndividualMoves()
      ..moves[alys] = (StepDirections()
        ..step(StepDirection()
          ..direction = left
          ..distance = 17.steps)
        ..step(StepDirection()
          ..direction = up
          ..distance = 11.steps)
        ..step(StepDirection()
          ..direction = right
          ..distance = 4.steps))
      ..moves[shay] = (StepDirections()
        ..step(StepDirection()
          ..delay = 2.steps
          ..direction = down
          ..distance = 2.steps)
        ..step(StepDirection()
          ..direction = left
          ..distance = 14.steps)
        ..step(StepDirection()
          ..direction = up
          ..distance = 6.steps));

    expect(actual, expected.generateAsm(generator, testCtx));

    print(actual);
  });
}
