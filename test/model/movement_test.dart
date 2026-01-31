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
            ..moves[BySlot(1)] = (StepPath()
              ..direction = right
              ..distance = 3.steps)
            ..moves[BySlot(2)] = (StepPath()
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
            ..moves[BySlot(1)] = (StepPath()
              ..direction = right
              ..distance = 3.steps)
            ..moves[BySlot(2)] = (StepPath()
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
            ..moves[BySlot(1)] = (StepPaths()
              ..step(StepPath()
                ..direction = right
                ..distance = 3.steps)
              ..step(StepPath()
                ..direction = down
                ..distance = 5.steps))
            ..moves[BySlot(2)] = (StepPaths()
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
            ..moves[BySlot(1)] = (StepPaths()
              ..step(StepPath()
                ..direction = right
                ..distance = 3.steps)
              ..step(StepPath()
                ..direction = down
                ..distance = 5.steps))
            ..moves[BySlot(2)] = (StepPaths()
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
            ..moves[BySlot(1)] = (StepPaths()
              ..step(StepPath()
                ..direction = right
                ..distance = 3.steps)
              ..step(StepPath()
                ..direction = down
                ..distance = 5.steps))
            ..moves[BySlot(2)] = (StepPaths()
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
          moves.moves[BySlot(2)],
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
            ..moves[BySlot(1)] = (StepPath()
              ..direction = up
              ..distance = 9.steps)
            ..moves[BySlot(2)] = (StepPath()
              ..direction = up
              ..distance = 9.steps)
            ..moves[BySlot(3)] = (StepPath()
              ..direction = up
              ..distance = 9.steps)
            ..moves[BySlot(4)] = (StepPath()
              ..direction = up
              ..distance = 9.steps)
            ..moves[BySlot(5)] = (StepPath()
              ..direction = up
              ..distance = 9.steps));
    });
  });

  group('individual moves', () {
    test('just face when there is only facing', () {
      var moves = IndividualMoves()
        ..moves[BySlot(1)] = Face(up)
        ..moves[BySlot(2)] = Face(down);

      expect(moves.justFacing, {BySlot(1): up, BySlot(2): down});
    });

    test('do not just face when there are delays', () {
      var moves = IndividualMoves()
        ..moves[BySlot(1)] = (StepPaths()
          ..face(up)
          ..step(StepPath()
            ..delay = 1.step
            ..direction = right));

      expect(moves.justFacing, isNull);
    });

    test('asAbsoluteAndFacing sets starting axis from first movement axis', () {
      // Movement: 2 steps down, 2 steps left (first axis is y)
      var moves = IndividualMoves()
        ..moves[BySlot(1)] = (StepPaths()
          ..step(StepPath()
            ..direction = down
            ..distance = 2.steps)
          ..step(StepPath()
            ..direction = left
            ..distance = 2.steps));

      var (absolute, _) = moves.asAbsoluteAndFacing;

      expect(absolute, isNotNull);
      expect(absolute!.startingAxis, Axis.y,
          reason: 'First movement is down, so starting axis should be y');
    });

    test(
        'asAbsoluteAndFacing sets starting axis x when first movement is horizontal',
        () {
      // Movement: 3 steps right, 2 steps up (first axis is x)
      var moves = IndividualMoves()
        ..moves[BySlot(1)] = (StepPaths()
          ..step(StepPath()
            ..direction = right
            ..distance = 3.steps)
          ..step(StepPath()
            ..direction = up
            ..distance = 2.steps));

      var (absolute, _) = moves.asAbsoluteAndFacing;

      expect(absolute, isNotNull);
      expect(absolute!.startingAxis, Axis.x,
          reason: 'First movement is right, so starting axis should be x');
    });
  });

  group('AbsoluteMoves.canRunInDialog', () {
    test('allows movement when we know slot 1 contains a different character',
        () {
      // We know Alys is in slot 1, but don't know where Shay is.
      // Camera is not locked.
      // We want to move Shay.
      // This should be allowed because we know Shay is NOT in slot 1
      // (since Alys is in slot 1).
      var state = EventState()
        ..addCharacter(alys, slot: 1, position: Position(100, 100), facing: up);
      // Note: Shay's slot is unknown (not added to state)

      var moves = AbsoluteMoves()
        ..waitForMovements = false
        ..destinations[shay] =
            OffsetPosition(shay.position(), offset: Position(0, -0x10));

      expect(moves.canRunInDialog(state), isTrue,
          reason:
              'Should allow movement of Shay since we know Alys is in slot 1, '
              'therefore Shay cannot be in slot 1 even if we don\'t know Shay\'s exact slot');
    });

    test('disallows movement when character might be in slot 1', () {
      // We don't know what's in any slot, and camera is not locked.
      var state = EventState();

      var moves = AbsoluteMoves()
        ..waitForMovements = false
        ..destinations[shay] =
            OffsetPosition(shay.position(), offset: Position(0, -0x10));

      expect(moves.canRunInDialog(state), isFalse,
          reason:
              'Should not allow movement when we don\'t know if Shay is in slot 1');
    });

    test('allows movement when camera is locked even if slot unknown', () {
      var state = EventState()..cameraLock = true;

      var moves = AbsoluteMoves()
        ..waitForMovements = false
        ..destinations[shay] =
            OffsetPosition(shay.position(), offset: Position(0, -0x10));

      expect(moves.canRunInDialog(state), isTrue,
          reason: 'Should allow movement when camera is locked');
    });

    test('disallows movement when character is known to be in slot 1', () {
      var state = EventState()
        ..addCharacter(alys, slot: 1, position: Position(100, 100), facing: up);

      var moves = AbsoluteMoves()
        ..waitForMovements = false
        ..destinations[alys] =
            OffsetPosition(alys.position(), offset: Position(0, -0x10));

      expect(moves.canRunInDialog(state), isFalse,
          reason:
              'Should not allow movement of slot 1 character without camera lock');
    });

    test(
        'disallows movement of explicit slot 1 even when we don\'t know who\'s in it',
        () {
      // We don't know who's in slot 1, but we're explicitly moving BySlot(1).
      // This should be disallowed because moving slot 1 will move the camera.
      var state = EventState();

      var moves = AbsoluteMoves()
        ..waitForMovements = false
        ..destinations[BySlot(1)] =
            OffsetPosition(BySlot(1).position(), offset: Position(0, -0x10));

      expect(moves.canRunInDialog(state), isFalse,
          reason:
              'Should not allow movement of explicit slot 1 reference without camera lock, '
              'even if we don\'t know which character is in that slot');
    });

    test('allows movement of slot 1 when camera is locked', () {
      // Alys is in slot 1, and camera is locked.
      // This should be allowed because the camera won't move.
      var state = EventState()
        ..addCharacter(alys, slot: 1, position: Position(100, 100), facing: up)
        ..cameraLock = true;

      var moves = AbsoluteMoves()
        ..waitForMovements = false
        ..destinations[alys] =
            OffsetPosition(alys.position(), offset: Position(0, -0x10));

      expect(moves.canRunInDialog(state), isTrue,
          reason:
              'Should allow movement of slot 1 character when camera is locked');
    });
  });
}
