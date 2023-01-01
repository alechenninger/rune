import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../generator/scene_test.dart';

void main() {
  group('==', () {
    test('IndividualMoves', () {
      var moves = IndividualMoves();
      moves.moves[alys] = StepPath()
        ..direction = Direction.down
        ..distance = 2.steps
        ..delay = 3.steps;

      expect(
          moves,
          equals(IndividualMoves()
            ..moves[alys] = (StepPath()
              ..direction = Direction.down
              ..distance = 2.steps
              ..delay = 3.steps)));
    });

    test('alys', () {
      expect(alys, equals(alys));
    });

    test('StepDirection', () {
      expect(
          StepPath()
            ..direction = Direction.down
            ..distance = 2.steps
            ..delay = 3.steps,
          equals(StepPath()
            ..direction = Direction.down
            ..distance = 2.steps
            ..delay = 3.steps));
    });

    test('StepDirections', () {
      expect(
          StepPaths()
            ..step(StepPath()
              ..direction = Direction.down
              ..distance = 2.steps
              ..delay = 3.steps),
          equals(StepPaths()
            ..step(StepPath()
              ..direction = Direction.down
              ..distance = 2.steps
              ..delay = 3.steps)));
    });
  });

  group('2d math', () {
    test('steps along x returns x steps of positive x position', () {
      expect(Position.fromSteps(5.steps, 10.steps).pathAlong(Axis.x),
          Path(5.steps, Direction.right));
    });
    test('steps along x returns x steps of negative x position', () {
      expect(Position.fromSteps(-5.steps, 10.steps).pathAlong(Axis.x),
          Path(5.steps, Direction.left));
    });
    test('steps along y returns y steps of positive y position', () {
      expect(Position.fromSteps(-5.steps, 10.steps).pathAlong(Axis.y),
          Path(10.steps, Direction.down));
    });
    test('steps along y returns y steps of negative y position', () {
      expect(Position.fromSteps(-5.steps, -10.steps).pathAlong(Axis.y),
          Path(10.steps, Direction.up));
    });
  });

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

      var move = PartyMove(StepPath()
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

      var move = PartyMove(StepPaths()
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

      var move = PartyMove(StepPaths()
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

      var move = PartyMove(StepPaths()
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

      var move = PartyMove(StepPaths()
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
  });

  group('dialog', () {
    test('combines spans', () {});

    test('combines pause then pause and panel', () {
      var dialog = Dialog(spans: [
        DialogSpan('', pause: 1.second),
        DialogSpan('', pause: 2.seconds, panel: PrincipalPanel.principal)
      ]);

      expect(dialog.spans, hasLength(1));
      expect(dialog.spans,
          [DialogSpan('', pause: 3.seconds, panel: PrincipalPanel.principal)]);
    });

    test('does not combine pause and panel then pause', () {
      var dialog = Dialog(spans: [
        DialogSpan('', pause: 2.seconds, panel: PrincipalPanel.principal),
        DialogSpan('', pause: 1.second),
      ]);

      expect(dialog.spans, hasLength(2));
      expect(dialog.spans, [
        DialogSpan('', pause: 2.seconds, panel: PrincipalPanel.principal),
        DialogSpan('', pause: 1.second),
      ]);
    });
  });

  group('map', () {
    test('adding objects at index', () {
      var map = GameMap(MapId.Test);
      var alys = MapObject(
          id: 'alys', startPosition: Position(0, 0), spec: AlysWaiting());
      var other = MapObject(
          id: 'other', startPosition: Position(0x10, 0), spec: AlysWaiting());
      map.addObject(alys, at: 1);
      map.addObject(other);
      expect(map.orderedObjects, [other, alys]);
    });

    test('indexes are assigned lazily if not explicitly assigned', () {
      var map = GameMap(MapId.Test);
      var alys = MapObject(
          id: 'alys', startPosition: Position(0, 0), spec: AlysWaiting());
      var other = MapObject(
          id: 'other', startPosition: Position(0x10, 0), spec: AlysWaiting());
      var other2 = MapObject(
          id: 'other2', startPosition: Position(0x20, 0), spec: AlysWaiting());
      map.addObject(other);
      map.addObject(other2);
      map.addObject(alys, at: 1);
      expect(map.orderedObjects, [other, alys, other2]);
    });

    test('map object indexes can be retrieved across different map aggregates',
        () {
      var original = GameMap(MapId.Test);
      var alys = MapObject(
          id: 'alys', startPosition: Position(0, 0), spec: AlysWaiting());
      var other = MapObject(
          id: 'other', startPosition: Position(0x10, 0), spec: AlysWaiting());
      var other2 = MapObject(
          id: 'other2', startPosition: Position(0x20, 0), spec: AlysWaiting());
      original.addObject(other);
      original.addObject(other2);
      original.addObject(alys, at: 1);

      var view = GameMap(MapId.Test);

      original.indexedObjects
          .where((obj) => obj.object.id.value.startsWith('other'))
          .forEach(view.addIndexedObject);

      expect(view.indexedObjects,
          [IndexedMapObject(0, other), IndexedMapObject(2, other2)]);
    });
  });
}
