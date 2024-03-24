import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  group('step to point', () {
    test('if start axis is x moves along x then y', () {
      var movement = StepToPoint()
        ..to = Position(1.steps.toPixels, 2.steps.toPixels)
        ..firstAxis = Axis.x;
      expect(movement.continuousPaths,
          equals([Path(1.steps, right), Path(2.steps, down)]));
    });
    test('if start axis is y moves along x then y', () {
      var movement = StepToPoint()
        ..to = Position.fromSteps(1.steps, 2.steps)
        ..firstAxis = Axis.y;
      expect(movement.continuousPaths,
          equals([Path(2.steps, down), Path(1.steps, right)]));
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
      var step = StepPath()..distance = 5.steps;
      expect(step.less(2.steps), StepPath()..distance = 3.steps);
    });

    test('less total steps leaves facing', () {
      var step = StepPath()
        ..distance = 5.steps
        ..direction = Direction.up
        ..facing = Direction.right;

      expect(
          step.less(5.steps),
          StepPath()
            ..distance = 0.steps
            ..direction = Direction.up
            ..facing = Direction.right);
    });

    test('with only facing, less 0 steps removes facing', () {
      var step = StepPath()..facing = Direction.right;

      step = step.less(0.steps);

      expect(step, StepPath()..facing = null);
      expect(step.still, isTrue);
    });
  });

  group('step directions', () {
    test('combines consecutive steps in the same direction', () {
      var move = StepPaths();
      move.step(StepPath()
        ..direction = right
        ..distance = 3.steps);
      move.step(StepPath()
        ..direction = right
        ..distance = 2.steps);

      expect(move.continuousPaths, hasLength(1));
    });
    test('combines consecutive delays', () {
      var move = StepPaths();
      move.step(StepPath()..delay = 1.steps);
      move.step(StepPath()..delay = 2.steps);

      expect(move.delay, 3.steps);
    });
    test('combines delay with delayed movement', () {
      var move = StepPaths();
      move.step(StepPath()..delay = 1.steps);
      move.step(StepPath()
        ..delay = 2.steps
        ..distance = 4.steps);

      expect(move.delay, 3.steps);
      expect(move.less(3.steps).continuousPaths, hasLength(1));
      expect(move.distance, 4.steps);
    });

    test('continuous steps includes both axis', () {
      var move = StepPaths();
      move.step(StepPath()
        ..direction = right
        ..distance = 3.steps);
      move.step(StepPath()
        ..direction = up
        ..distance = 2.steps);

      expect(move.continuousPathsWithFirstAxis(Axis.x),
          [Path(3.steps, right), Path(2.steps, up)]);
    });

    test('at pause after facing has facing', () {
      var move = StepPaths();
      move.step((Face(right)..delay = 1.step).asStep());
      move.step(StepPath()
        ..delay = 1.step
        ..direction = down
        ..distance = 1.step);

      move = move.less(1.step);

      expect(move.facing, right);
    });

    test('at end has facing', () {
      var move = StepPaths();
      move.step(StepPath()
        ..delay = 1.step
        ..direction = down
        ..distance = 1.step);
      move.step(StepPath()
        ..direction = right
        ..distance = 2.steps
        ..facing = up);

      move = move.less(4.step);

      expect(move.duration, 0.steps);
      expect(move.facing, up);
    });

    test('at end less 0 steps removes facing', () {
      var move = StepPaths();
      move.step(StepPath()
        ..delay = 1.step
        ..direction = down
        ..distance = 1.step);
      move.step(StepPath()
        ..direction = right
        ..distance = 2.steps
        ..facing = up);

      move = move.less(4.step);

      expect(move.still, isFalse);

      move = move.less(0.step);

      expect(move.facing, null);
      expect(move.still, isTrue);
    });
  });

  group('party move', () {
    test('characters follow leader in straight line', () {
      var ctx = EventState()
        ..addCharacter(alys,
            slot: 1,
            position: Position(1.steps.toPixels, 2.steps.toPixels),
            facing: right)
        ..addCharacter(shay,
            slot: 2, position: Position(0, 2.steps.toPixels), facing: right);

      var move = RelativePartyMove(StepPath()
        ..direction = right
        ..distance = 3.steps);

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepPath()
              ..direction = right
              ..distance = 3.steps)
            ..moves[Slot(2)] = (StepPath()
              ..direction = right
              ..distance = 3.steps));
    });

    test('characters follow leader with move speed', () {
      var ctx = EventState()
        ..addCharacter(alys,
            slot: 1,
            position: Position(1.steps.toPixels, 2.steps.toPixels),
            facing: right)
        ..addCharacter(shay,
            slot: 2, position: Position(0, 2.steps.toPixels), facing: right);

      var move = RelativePartyMove(StepPath()
        ..direction = right
        ..distance = 3.steps)
        ..speed = StepSpeed.walk;

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..speed = StepSpeed.walk
            ..moves[Slot(1)] = (StepPath()
              ..direction = right
              ..distance = 3.steps)
            ..moves[Slot(2)] = (StepPath()
              ..direction = right
              ..distance = 3.steps));
    });

    test('characters follow leader in multiple directions', () {
      var ctx = EventState()
        ..addCharacter(alys,
            slot: 1,
            position: Position.fromSteps(1.step, 2.steps),
            facing: right)
        ..addCharacter(shay,
            slot: 2,
            position: Position.fromSteps(0.step, 2.steps),
            facing: right);

      var move = RelativePartyMove(StepPaths()
        ..step(StepPath()
          ..direction = right
          ..distance = 3.steps)
        ..step(StepPath()
          ..direction = down
          ..distance = 5.steps));

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepPaths()
              ..step(StepPath()
                ..direction = right
                ..distance = 3.steps)
              ..step(StepPath()
                ..direction = down
                ..distance = 5.steps))
            ..moves[Slot(2)] = (StepPaths()
              ..step(StepPath()
                ..direction = right
                ..distance = 4.steps)
              ..step(StepPath()
                ..direction = down
                ..distance = 4.steps)));
    });

    test('characters follow leader in multiple directions starting along x',
        () {
      var ctx = EventState()
        ..addCharacter(alys,
            slot: 1,
            position: Position.fromSteps(1.step, 3.steps),
            facing: right)
        ..addCharacter(shay,
            slot: 2,
            position: Position.fromSteps(0.step, 2.steps),
            facing: right);

      var move = RelativePartyMove(StepPaths()
        ..step(StepPath()
          ..direction = right
          ..distance = 3.steps)
        ..step(StepPath()
          ..direction = down
          ..distance = 5.steps))
        ..startingAxis = Axis.x;

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepPaths()
              ..step(StepPath()
                ..direction = right
                ..distance = 3.steps)
              ..step(StepPath()
                ..direction = down
                ..distance = 5.steps))
            ..moves[Slot(2)] = (StepPaths()
              ..step(StepPath()
                ..direction = right
                ..distance = 4.steps)
              ..step(StepPath()
                ..direction = down
                ..distance = 4.steps)));
    });

    test('characters follow leader in multiple directions starting along y',
        () {
      var ctx = EventState()
        ..addCharacter(alys,
            slot: 1,
            position: Position.fromSteps(1.step, 3.steps),
            facing: right)
        ..addCharacter(shay,
            slot: 2,
            position: Position.fromSteps(0.step, 2.steps),
            facing: right);

      var move = RelativePartyMove(StepPaths()
        ..step(StepPath()
          ..direction = right
          ..distance = 3.steps)
        ..step(StepPath()
          ..direction = down
          ..distance = 5.steps))
        ..startingAxis = Axis.y;

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves,
          IndividualMoves()
            ..moves[Slot(1)] = (StepPaths()
              ..step(StepPath()
                ..direction = right
                ..distance = 3.steps)
              ..step(StepPath()
                ..direction = down
                ..distance = 5.steps))
            ..moves[Slot(2)] = (StepPaths()
              ..step(StepPath()
                ..direction = down
                ..distance = 1.steps)
              ..step(StepPath()
                ..direction = right
                ..distance = 2.steps)
              ..step(StepPath()
                ..direction = down
                ..distance = 5.steps)));
    });

    test('complex party move', () {
      var ctx = EventState()
        ..addCharacter(alys,
            slot: 1, position: Position(10 * 16, 10 * 16), facing: down)
        ..addCharacter(shay,
            slot: 2, position: Position(13 * 16, 10 * 16), facing: left);

      var move = RelativePartyMove(StepPaths()
        ..step(StepPath()
          ..direction = down
          ..distance = 5.steps)
        ..step(StepPath()
          ..direction = right
          ..distance = 6.steps)
        ..step(StepPath()
          ..direction = down
          ..distance = 3.steps));

      var moves = move.toIndividualMoves(ctx);

      expect(
          moves.moves[Slot(2)],
          StepPaths()
            ..step(StepPath()
              ..direction = left
              ..distance = 3.steps)
            ..step(StepPath()
              ..direction = down
              ..distance = 2.steps)
            ..step(StepPath()
              ..direction = right
              ..distance = 6.steps)
            ..step(StepPath()
              ..direction = down
              ..distance = 3.steps));

      print(moves.generateAsm(AsmGenerator(), AsmContext.forEvent(ctx)));
    });

    test('all party members', () {
      var move = RelativePartyMove(StepPaths()
        ..step(StepPath()
          ..direction = up
          ..distance = 9.steps));

      var ctx = EventState()
        ..addCharacter(alys,
            slot: 1, position: Position(10 * 16, 10 * 16), facing: up)
        ..addCharacter(shay,
            slot: 2, position: Position(10 * 16, 11 * 16), facing: up)
        ..addCharacter(hahn,
            slot: 3, position: Position(10 * 16, 12 * 16), facing: up)
        ..addCharacter(gryz,
            slot: 4, position: Position(10 * 16, 13 * 16), facing: up)
        ..addCharacter(rune,
            slot: 5, position: Position(10 * 16, 14 * 16), facing: up);

      expect(
          move.toIndividualMoves(ctx),
          IndividualMoves()
            ..moves[Slot(1)] = (StepPath()
              ..direction = up
              ..distance = 9.steps)
            ..moves[Slot(2)] = (StepPath()
              ..direction = up
              ..distance = 9.steps)
            ..moves[Slot(3)] = (StepPath()
              ..direction = up
              ..distance = 9.steps)
            ..moves[Slot(4)] = (StepPath()
              ..direction = up
              ..distance = 9.steps)
            ..moves[Slot(5)] = (StepPath()
              ..direction = up
              ..distance = 9.steps));
    });
  });

  group('individual moves', () {
    test('just face when there is only facing', () {
      var moves = IndividualMoves()
        ..moves[Slot(1)] = Face(up)
        ..moves[Slot(2)] = Face(down);

      expect(moves.justFacing(), {Slot(1): up, Slot(2): down});
    });

    test('do not just face when there are delays', () {
      var moves = IndividualMoves()
        ..moves[Slot(1)] = (StepPaths()
          ..face(up)
          ..step(StepPath()
            ..delay = 1.step
            ..direction = right));

      expect(moves.justFacing(), isNull);
    });
  });
}
