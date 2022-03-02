import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  group('==', () {
    test('IndividualMoves', () {
      var moves = IndividualMoves();
      moves.moves[alys] = StepDirection()
        ..direction = Direction.down
        ..distance = 2.steps
        ..delay = 3.steps;

      expect(
          moves,
          equals(IndividualMoves()
            ..moves[alys] = (StepDirection()
              ..direction = Direction.down
              ..distance = 2.steps
              ..delay = 3.steps)));
    });

    test('alys', () {
      expect(alys, equals(alys));
    });

    test('StepDirection', () {
      expect(
          StepDirection()
            ..direction = Direction.down
            ..distance = 2.steps
            ..delay = 3.steps,
          equals(StepDirection()
            ..direction = Direction.down
            ..distance = 2.steps
            ..delay = 3.steps));
    });

    test('StepDirections', () {
      expect(
          StepDirections()
            ..step(StepDirection()
              ..direction = Direction.down
              ..distance = 2.steps
              ..delay = 3.steps),
          equals(StepDirections()
            ..step(StepDirection()
              ..direction = Direction.down
              ..distance = 2.steps
              ..delay = 3.steps)));
    });
  });

  group('2d math', () {
    test('steps along x returns x steps of positive x position', () {
      expect(Position.fromSteps(5.steps, 10.steps).stepsAlong(Axis.x),
          Vector(5.steps, Direction.right));
    });
    test('steps along x returns x steps of negative x position', () {
      expect(Position.fromSteps(-5.steps, 10.steps).stepsAlong(Axis.x),
          Vector(5.steps, Direction.left));
    });
    test('steps along y returns y steps of positive y position', () {
      expect(Position.fromSteps(-5.steps, 10.steps).stepsAlong(Axis.y),
          Vector(10.steps, Direction.down));
    });
    test('steps along y returns y steps of negative y position', () {
      expect(Position.fromSteps(-5.steps, -10.steps).stepsAlong(Axis.y),
          Vector(10.steps, Direction.up));
    });
  });

  group('step to point', () {
    test('if start axis is x moves along x then y', () {
      var movement = StepToPoint()
        ..to = Position(1.steps.toPixels, 2.steps.toPixels)
        ..firstAxis = Axis.x;
      expect(movement.continuousMovements,
          equals([Vector(1.steps, right), Vector(2.steps, down)]));
    });
    test('if start axis is y moves along x then y', () {
      var movement = StepToPoint()
        ..to = Position.fromSteps(1.steps, 2.steps)
        ..firstAxis = Axis.y;
      expect(movement.continuousMovements,
          equals([Vector(2.steps, down), Vector(1.steps, right)]));
    });
    group('less steps', () {
      test('subtracts from delay first', () {
        var movement = StepToPoint()
          ..to = Position.fromSteps(1.steps, 2.steps)
          ..firstAxis = Axis.x
          ..delay = 2.steps;

        expect(
            movement.less(3.steps),
            StepToPoint()
              ..to = Position.fromSteps(1.steps, 2.steps)
              ..from = Position.fromSteps(1.steps, 0.steps));
      });
    });
  });

  group('step direction', () {
    test('less steps subtracts from distance', () {
      var step = StepDirection()..distance = 5.steps;
      expect(step.less(2.steps), StepDirection()..distance = 3.steps);
    });
  });

  group('step directions', () {
    test('combines consecutive steps in the same direction', () {
      var move = StepDirections();
      move.step(StepDirection()
        ..direction = right
        ..distance = 3.steps);
      move.step(StepDirection()
        ..direction = right
        ..distance = 2.steps);

      expect(move.continuousMovements, hasLength(1));
    });
    test('combines consecutive delays', () {
      var move = StepDirections();
      move.step(StepDirection()..delay = 1.steps);
      move.step(StepDirection()..delay = 2.steps);

      expect(move.delay, 3.steps);
    });
    test('combines delay with delayed movement', () {
      var move = StepDirections();
      move.step(StepDirection()..delay = 1.steps);
      move.step(StepDirection()
        ..delay = 2.steps
        ..distance = 4.steps);

      expect(move.delay, 3.steps);
      expect(move.less(3.steps).continuousMovements, hasLength(1));
      expect(move.distance, 4.steps);
    });
  });

  group('party move', () {
    test('characters follow leader in straight line', () {
      var ctx = EventContext()
        ..addCharacter(alys,
            slot: 1,
            position: Position(1.steps.toPixels, 2.steps.toPixels),
            facing: right)
        ..addCharacter(shay,
            slot: 2, position: Position(0, 2.steps.toPixels), facing: right);

      var move = PartyMove(StepDirection()
        ..direction = right
        ..distance = 3.steps);

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepDirection()
              ..direction = right
              ..distance = 3.steps)
            ..moves[Slot(2)] = (StepDirection()
              ..direction = right
              ..distance = 3.steps));
    });

    test('characters follow leader in multiple directions', () {
      var ctx = EventContext()
        ..addCharacter(alys,
            slot: 1,
            position: Position.fromSteps(1.step, 2.steps),
            facing: right)
        ..addCharacter(shay,
            slot: 2,
            position: Position.fromSteps(0.step, 2.steps),
            facing: right);

      var move = PartyMove(StepDirections()
        ..step(StepDirection()
          ..direction = right
          ..distance = 3.steps)
        ..step(StepDirection()
          ..direction = down
          ..distance = 5.steps));

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepDirections()
              ..step(StepDirection()
                ..direction = right
                ..distance = 3.steps)
              ..step(StepDirection()
                ..direction = down
                ..distance = 5.steps))
            ..moves[Slot(2)] = (StepDirections()
              ..step(StepDirection()
                ..direction = right
                ..distance = 4.steps)
              ..step(StepDirection()
                ..direction = down
                ..distance = 4.steps)));
    });

    test('characters follow leader in multiple directions starting along x',
        () {
      var ctx = EventContext()
        ..addCharacter(alys,
            slot: 1,
            position: Position.fromSteps(1.step, 3.steps),
            facing: right)
        ..addCharacter(shay,
            slot: 2,
            position: Position.fromSteps(0.step, 2.steps),
            facing: right);

      var move = PartyMove(StepDirections()
        ..step(StepDirection()
          ..direction = right
          ..distance = 3.steps)
        ..step(StepDirection()
          ..direction = down
          ..distance = 5.steps))
        ..startingAxis = Axis.x;

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepDirections()
              ..step(StepDirection()
                ..direction = right
                ..distance = 3.steps)
              ..step(StepDirection()
                ..direction = down
                ..distance = 5.steps))
            ..moves[Slot(2)] = (StepDirections()
              ..step(StepDirection()
                ..direction = right
                ..distance = 4.steps)
              ..step(StepDirection()
                ..direction = down
                ..distance = 4.steps)));
    });

    test('characters follow leader in multiple directions starting along y',
        () {
      var ctx = EventContext()
        ..addCharacter(alys,
            slot: 1,
            position: Position.fromSteps(1.step, 3.steps),
            facing: right)
        ..addCharacter(shay,
            slot: 2,
            position: Position.fromSteps(0.step, 2.steps),
            facing: right);

      var move = PartyMove(StepDirections()
        ..step(StepDirection()
          ..direction = right
          ..distance = 3.steps)
        ..step(StepDirection()
          ..direction = down
          ..distance = 5.steps))
        ..startingAxis = Axis.y;

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepDirections()
              ..step(StepDirection()
                ..direction = right
                ..distance = 3.steps)
              ..step(StepDirection()
                ..direction = down
                ..distance = 5.steps))
            ..moves[Slot(2)] = (StepDirections()
              ..step(StepDirection()
                ..direction = down
                ..distance = 1.steps)
              ..step(StepDirection()
                ..direction = right
                ..distance = 2.steps)
              ..step(StepDirection()
                ..direction = down
                ..distance = 5.steps)));
    });

    // The party moves 5 steps down, 6 steps right, and 3 steps down.

    test('bug', () {
      var ctx = EventContext()
        ..addCharacter(alys,
            slot: 1, position: Position(10 * 16, 10 * 16), facing: down)
        ..addCharacter(shay,
            slot: 2, position: Position(13 * 16, 10 * 16), facing: left);

      var move = PartyMove(StepDirections()
        ..step(StepDirection()
          ..direction = down
          ..distance = 5.steps)
        ..step(StepDirection()
          ..direction = right
          ..distance = 6.steps)
        ..step(StepDirection()
          ..direction = down
          ..distance = 3.steps));

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves.moves[Slot(2)],
          StepDirections()
            ..step(StepDirection()
              ..direction = left
              ..distance = 3.steps)
            ..step(StepDirection()
              ..direction = down
              ..distance = 2.steps)
            ..step(StepDirection()
              ..direction = right
              ..distance = 6.steps)
            ..step(StepDirection()
              ..direction = down
              ..distance = 3.steps));

      print(moves.generateAsm(AsmGenerator(), ctx));
    });
  });
}
