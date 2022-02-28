import 'dart:math';

import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  group('==', () {
    test('IndividualMoves', () {
      var moves = IndividualMoves();
      moves.moves[alys] = StepDirection()
        ..direction = Direction.down
        ..distance = 2
        ..delay = 3;

      expect(
          moves,
          equals(IndividualMoves()
            ..moves[alys] = (StepDirection()
              ..direction = Direction.down
              ..distance = 2
              ..delay = 3)));
    });

    test('alys', () {
      expect(alys, equals(alys));
    });

    test('StepDirection', () {
      expect(
          StepDirection()
            ..direction = Direction.down
            ..distance = 2
            ..delay = 3,
          equals(StepDirection()
            ..direction = Direction.down
            ..distance = 2
            ..delay = 3));
    });

    test('StepDirections', () {
      expect(
          StepDirections()
            ..step(StepDirection()
              ..direction = Direction.down
              ..distance = 2
              ..delay = 3),
          equals(StepDirections()
            ..step(StepDirection()
              ..direction = Direction.down
              ..distance = 2
              ..delay = 3)));
    });
  });

  group('2d math', () {
    test('project x returns x part of positive x vector', () {
      expect(Axis.x * Point(5, 10), Vector(5, Direction.right));
    });
    test('project x returns x part of negative x vector', () {
      expect(Axis.x * Point(-5, 10), Vector(5, Direction.left));
    });
    test('project y returns y part of positive y vector', () {
      expect(Axis.y * Point(-5, 10), Vector(10, Direction.down));
    });
    test('project y returns y part of negative y vector', () {
      expect(Axis.y * Point(-5, -10), Vector(10, Direction.up));
    });
  });

  group('step to point', () {
    test('if start axis is x moves along x then y', () {
      var movement = StepToPoint()
        ..to = Point(1, 2)
        ..startAlong = Axis.x;
      expect(movement.continuousMovements,
          equals([Vector(1, right), Vector(2, down)]));
    });
    test('if start axis is y moves along x then y', () {
      var movement = StepToPoint()
        ..to = Point(1, 2)
        ..startAlong = Axis.y;
      expect(movement.continuousMovements,
          equals([Vector(2, down), Vector(1, right)]));
    });
    group('less steps', () {
      test('subtracts from delay first', () {
        var movement = StepToPoint()
          ..to = Point(1, 2)
          ..startAlong = Axis.x
          ..delay = 2;

        expect(
            movement.less(3),
            StepToPoint()
              ..to = Point(1, 2)
              ..from = Point(1, 0));
      });
    });
  });

  group('step directions', () {
    test('combines consecutive steps in the same direction', () {
      var move = StepDirections();
      move.step(StepDirection()
        ..direction = right
        ..distance = 3);
      move.step(StepDirection()
        ..direction = right
        ..distance = 2);

      expect(move.continuousMovements, hasLength(1));
    });
    test('combines consecutive delays', () {
      var move = StepDirections();
      move.step(StepDirection()..delay = 1);
      move.step(StepDirection()..delay = 2);

      expect(move.delay, 3);
    });
    test('combines delay with delayed movement', () {
      var move = StepDirections();
      move.step(StepDirection()..delay = 1);
      move.step(StepDirection()
        ..delay = 2
        ..distance = 4);

      expect(move.delay, 3);
      expect(move.less(3).continuousMovements, hasLength(1));
      expect(move.distance, 4);
    });
  });

  group('party move', () {
    test('characters follow leader in straight line', () {
      var ctx = EventContext()
        ..addCharacter(alys, slot: 1, position: Point(1, 2), facing: right)
        ..addCharacter(shay, slot: 2, position: Point(0, 2), facing: right);

      var move = PartyMove(StepDirection()
        ..direction = right
        ..distance = 3);

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepDirection()
              ..direction = right
              ..distance = 3)
            ..moves[Slot(2)] = (StepDirection()
              ..direction = right
              ..distance = 3));
    });

    test('characters follow leader in multiple directions', () {
      var ctx = EventContext()
        ..addCharacter(alys, slot: 1, position: Point(1, 2), facing: right)
        ..addCharacter(shay, slot: 2, position: Point(0, 2), facing: right);

      var move = PartyMove(StepDirections()
        ..step(StepDirection()
          ..direction = right
          ..distance = 3)
        ..step(StepDirection()
          ..direction = down
          ..distance = 5));

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepDirections()
              ..step(StepDirection()
                ..direction = right
                ..distance = 3)
              ..step(StepDirection()
                ..direction = down
                ..distance = 5))
            ..moves[Slot(2)] = (StepDirections()
              ..step(StepDirection()
                ..direction = right
                ..distance = 4)
              ..step(StepDirection()
                ..direction = down
                ..distance = 4)));
    });

    test('characters follow leader in multiple directions starting along x',
        () {
      var ctx = EventContext()
        ..addCharacter(alys, slot: 1, position: Point(1, 3), facing: right)
        ..addCharacter(shay, slot: 2, position: Point(0, 2), facing: right);

      var move = PartyMove(StepDirections()
        ..step(StepDirection()
          ..direction = right
          ..distance = 3)
        ..step(StepDirection()
          ..direction = down
          ..distance = 5))
        ..startingAxis = Axis.x;

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepDirections()
              ..step(StepDirection()
                ..direction = right
                ..distance = 3)
              ..step(StepDirection()
                ..direction = down
                ..distance = 5))
            ..moves[Slot(2)] = (StepDirections()
              ..step(StepDirection()
                ..direction = right
                ..distance = 4)
              ..step(StepDirection()
                ..direction = down
                ..distance = 4)));
    });

    test('characters follow leader in multiple directions starting along y',
        () {
      var ctx = EventContext()
        ..addCharacter(alys, slot: 1, position: Point(1, 3), facing: right)
        ..addCharacter(shay, slot: 2, position: Point(0, 2), facing: right);

      var move = PartyMove(StepDirections()
        ..step(StepDirection()
          ..direction = right
          ..distance = 3)
        ..step(StepDirection()
          ..direction = down
          ..distance = 5))
        ..startingAxis = Axis.y;

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepDirections()
              ..step(StepDirection()
                ..direction = right
                ..distance = 3)
              ..step(StepDirection()
                ..direction = down
                ..distance = 5))
            ..moves[Slot(2)] = (StepDirections()
              ..step(StepDirection()
                ..direction = down
                ..distance = 1)
              ..step(StepDirection()
                ..direction = right
                ..distance = 2)
              ..step(StepDirection()
                ..direction = down
                ..distance = 5)));
    });
  });
}
