import 'package:rune/generator/generator.dart';
import 'package:rune/model/animate.dart';
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
  });

  group('animation', () {
    test('jump object computes equivalent step up and step down animations',
        () {
      var jump = JumpObject(alys, duration: 1.second, height: 10);

      expect(jump.toSteps(), [
        StepObject(alys,
            onTop: true,
            animate: false,
            frames: 0.5.seconds.toFrames(),
            stepPerFrame: Point(0, -10 / 0.5.seconds.toFrames())),
        StepObject(alys,
            onTop: true,
            animate: false,
            frames: 0.5.second.toFrames(),
            stepPerFrame: Point(0, 10 / 0.5.seconds.toFrames())),
      ]);
    });

    test('jump object travels total x movement', () {
      var jump =
          JumpObject(alys, duration: 1.second, height: 10, xMovement: -16);

      expect(jump.toSteps(), [
        StepObject(alys,
            onTop: true,
            animate: false,
            frames: 0.5.seconds.toFrames(),
            stepPerFrame: Point(-8 / 30, -10 / 30)),
        StepObject(alys,
            onTop: true,
            animate: false,
            frames: 0.5.second.toFrames(),
            stepPerFrame: Point(-8 / 30, 10 / 30)),
      ]);
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

    test('placeholders are unused to maintain indexes of sparse objects', () {
      var map = GameMap(MapId.Test);
      var alys = MapObject(
          id: 'alys', startPosition: Position(0, 0), spec: AlysWaiting());
      var other = MapObject(
          id: 'other', startPosition: Position(0x10, 0), spec: AlysWaiting());
      map.addObject(other, at: 0);
      map.addObject(alys, at: 2);
      expect(map.orderedObjects, [other, placeholderMapObject(1), alys]);
      expect(map.indexedObjects, hasLength(2));
      expect(map.objects, hasLength(2));
    });
  });

  group('game', () {
    late Game game;

    setUp(() {
      game = Game();
    });

    group('scenes by interaction', () {
      late GameMap map;

      setUp(() {
        map = game.getOrStartMap(MapId.Test);
      });

      test('distinct areas', () {
        var area0 = MapArea(
            id: MapAreaId('0'),
            at: Position(0, 0),
            range: AreaRange.x20y20,
            spec: InteractiveAreaSpec(
                onInteract: Scene([
              Dialog(spans: [DialogSpan('Hello 0')]),
            ])));

        var area1 = MapArea(
            id: MapAreaId('1'),
            at: Position(0x20, 0),
            range: AreaRange.x20y20,
            spec: InteractiveAreaSpec(
                onInteract: Scene([
              Dialog(spans: [DialogSpan('Hello 1')]),
            ])));

        map.addArea(area0);
        map.addArea(area1);

        var scenes = game.byInteraction();

        expect(scenes, hasLength(2));

        expect(scenes[area0.onInteract],
            Game()..getOrStartMap(MapId.Test).addArea(area0));
      });

      test('distinct area and objects', () {
        var area0 = MapArea(
            id: MapAreaId('0'),
            at: Position(0, 0),
            range: AreaRange.x20y20,
            spec: InteractiveAreaSpec(
                onInteract: Scene([
              Dialog(spans: [DialogSpan('Hello 0')]),
            ])));

        var alys = MapObject(
            id: 'alys',
            startPosition: Position(0x20, 0),
            spec: Npc(
                Sprite.PalmanWoman1,
                FaceDown(
                  onInteract: Scene([
                    Dialog(spans: [DialogSpan('Hello 1')]),
                  ]),
                )));

        map.addArea(area0);
        map.addObject(alys);

        var scenes = game.byInteraction();

        expect(scenes, hasLength(2));

        expect(scenes[area0.onInteract],
            Game()..getOrStartMap(MapId.Test).addArea(area0));

        expect(
            scenes[alys.onInteract],
            // Split by interaction, the maps are specific
            // about index in order to retain the original order
            // regardless of whether index was specified up front.
            Game()..getOrStartMap(MapId.Test).addObject(alys, at: 0));
      });

      test('orders by map, then element type objects first', () {
        var area0 = MapArea(
            id: MapAreaId('0'),
            at: Position(0, 0),
            range: AreaRange.x20y20,
            spec: InteractiveAreaSpec(
                onInteract: Scene([
              Dialog(spans: [DialogSpan('Hello a0')]),
            ])));
        var area1 = MapArea(
            id: MapAreaId('1'),
            at: Position(0, 0),
            range: AreaRange.x20y20,
            spec: InteractiveAreaSpec(
                onInteract: Scene([
              Dialog(spans: [DialogSpan('Hello a1')]),
            ])));
        var area2 = MapArea(
            id: MapAreaId('2'),
            at: Position(0, 0),
            range: AreaRange.x20y20,
            spec: InteractiveAreaSpec(
                onInteract: Scene([
              Dialog(spans: [DialogSpan('Hello a2')]),
            ])));

        var obj0 = MapObject(
            id: '0',
            startPosition: Position(0x20, 0),
            spec: Npc(
                Sprite.PalmanWoman1,
                FaceDown(
                  onInteract: Scene([
                    Dialog(spans: [DialogSpan('Hello o0')]),
                  ]),
                )));
        var obj1 = MapObject(
            id: '1',
            startPosition: Position(0x20, 0),
            spec: Npc(
                Sprite.PalmanWoman1,
                FaceDown(
                  onInteract: Scene([
                    Dialog(spans: [DialogSpan('Hello o1')]),
                  ]),
                )));
        var obj2 = MapObject(
            id: '2',
            startPosition: Position(0x20, 0),
            spec: Npc(
                Sprite.PalmanWoman1,
                FaceDown(
                  onInteract: Scene([
                    Dialog(spans: [DialogSpan('Hello o2')]),
                  ]),
                )));

        map.addArea(area0);
        map.addArea(area1);
        map.addObject(obj0);
        map.addObject(obj1);
        game.getOrStartMap(MapId.Test_Part2)
          ..addArea(area2)
          ..addObject(obj2);

        var scenes = game.byInteraction();

        expect(scenes, {
          obj0.onInteract: Game()
            ..getOrStartMap(MapId.Test).addObject(obj0, at: 0),
          obj1.onInteract: Game()
            ..getOrStartMap(MapId.Test).addObject(obj1, at: 1),
          area0.onInteract: Game()..getOrStartMap(MapId.Test).addArea(area0),
          obj2.onInteract: Game()
            ..getOrStartMap(MapId.Test_Part2).addObject(obj2, at: 0),
          area1.onInteract: Game()..getOrStartMap(MapId.Test).addArea(area1),
          area2.onInteract: Game()
            ..getOrStartMap(MapId.Test_Part2).addArea(area2),
        });
      });

      test('same scenes share a game when split', () {
        var scene = Scene([
          Dialog(spans: [DialogSpan('Hello 0')]),
        ]);

        var area0 = MapArea(
            id: MapAreaId('0'),
            at: Position(0, 0),
            range: AreaRange.x20y20,
            spec: InteractiveAreaSpec(onInteract: scene));

        var area1 = MapArea(
            id: MapAreaId('1'),
            at: Position(0x20, 0),
            range: AreaRange.x20y20,
            spec: InteractiveAreaSpec(onInteract: scene));

        map.addArea(area0);
        map.addArea(area1);

        var scenes = game.byInteraction();

        expect(scenes, hasLength(1));
        expect(scenes[scene]?.getOrStartMap(map.id).areas, [area0, area1]);
      });

      test('noninteractive objects should not share scenes', () {
        var obj0 = MapObject(
            id: '0', startPosition: Position(0, 0), spec: Elevator(down));
        var obj1 = MapObject(
            id: '1', startPosition: Position(0, 0), spec: Elevator(down));

        map.addObject(obj0);
        map.addObject(obj1);

        var scenes = game.byInteraction();

        expect(scenes, hasLength(2));
        expect(scenes[obj0.onInteract]?.getOrStartMap(map.id).objects, [obj0]);
        expect(scenes[obj1.onInteract]?.getOrStartMap(map.id).objects, [obj1]);
      });
    });
  });

  group('scene', () {
    test('toString', () {
      var scene = Scene([
        Dialog(spans: [DialogSpan('Hi after Hahn joined')]),
        SetFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1')),
        Pause(Duration(seconds: 1))
      ]);

      expect(scene.toString(), '''Scene{
      SetFlag{EventFlag{Talk_Test_obj_Test_0_PrincipalMeeting_1}}
      Dialog{speaker: Unnamed Speaker, hidePanelsOnClose: false, _spans: [DialogSpan{text: Hi after Hahn joined, italic: false, pause: 0:00:00.000000, panel: null}]}
      Pause{0:00:01.000000}
}''');
    });

    test('toString with IfFlag', () {
      var scene = Scene([
        Dialog(spans: [DialogSpan('Hi')]),
        Pause(Duration(seconds: 1)),
        IfFlag(EventFlag('PrincipalMeeting'), isSet: [
          SetFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1')),
          Dialog(spans: [DialogSpan('Hi after meeting principal')])
        ], isUnset: [
          Dialog(spans: [DialogSpan('Hello world.')])
        ])
      ]);

      print(scene);

      expect(scene.toString(), '''Scene{
      Dialog{speaker: Unnamed Speaker, hidePanelsOnClose: false, _spans: [DialogSpan{text: Hi, italic: false, pause: 0:00:00.000000, panel: null}]}
      Pause{0:00:01.000000}
      IfFlag{EventFlag{PrincipalMeeting}, 
      isSet:
               SetFlag{EventFlag{Talk_Test_obj_Test_0_PrincipalMeeting_1}}
               Dialog{speaker: Unnamed Speaker, hidePanelsOnClose: false, _spans: [DialogSpan{text: Hi after meeting principal, italic: false, pause: 0:00:00.000000, panel: null}]}
      isUnset:
               Dialog{speaker: Unnamed Speaker, hidePanelsOnClose: false, _spans: [DialogSpan{text: Hello world., italic: false, pause: 0:00:00.000000, panel: null}]}
      }
}''');
    });

    test('add event to branches', () {
      var scene = Scene([
        IfFlag(EventFlag('HahnJoined'), isSet: [
          Dialog(spans: [DialogSpan('Hi after Hahn joined')])
        ], isUnset: [
          IfFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1'), isSet: [
            Dialog(spans: [DialogSpan('Hi again')])
          ], isUnset: [
            IfFlag(EventFlag('PrincipalMeeting'), isSet: [
              SetFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1')),
              Dialog(spans: [DialogSpan('Hi after meeting principal')])
            ], isUnset: [
              Dialog(spans: [DialogSpan('Hello world.')])
            ])
          ])
        ])
      ]);

      scene.addEventToBranches(
          SetFlag(EventFlag('test')),
          Condition(
              {EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1'): true}));

      expect(
          scene,
          Scene([
            IfFlag(EventFlag('HahnJoined'), isSet: [
              Dialog(spans: [DialogSpan('Hi after Hahn joined')])
            ], isUnset: [
              IfFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1'),
                  isSet: [
                    SetFlag(EventFlag('test')),
                    Dialog(spans: [DialogSpan('Hi again')])
                  ],
                  isUnset: [
                    IfFlag(EventFlag('PrincipalMeeting'), isSet: [
                      SetFlag(
                          EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1')),
                      Dialog(spans: [DialogSpan('Hi after meeting principal')])
                    ], isUnset: [
                      Dialog(spans: [DialogSpan('Hello world.')])
                    ])
                  ])
            ])
          ]));
    });

    test('adds event to all branches which would be taken under condition',
        () {},
        skip: 'not implemented');

    test('adds branch as of condition', () {
      var scene = Scene([
        IfFlag(EventFlag('HahnJoined'), isSet: [
          Dialog(spans: [DialogSpan('Hi after Hahn joined')])
        ], isUnset: [
          IfFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1'), isSet: [
            Dialog(spans: [DialogSpan('Hi again')])
          ], isUnset: [
            IfFlag(EventFlag('PrincipalMeeting'), isSet: [
              SetFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1')),
              Dialog(spans: [DialogSpan('Hi after meeting principal')])
            ], isUnset: [
              Dialog(spans: [DialogSpan('Hello world.')])
            ])
          ])
        ])
      ]);

      scene.addBranch([
        Dialog(spans: [DialogSpan('This is an optional quest')])
      ],
          whenSet: EventFlag('Quest1'),
          asOf: Condition({EventFlag('HahnJoined'): false}));

      expect(
          scene,
          Scene([
            IfFlag(EventFlag('HahnJoined'), isSet: [
              Dialog(spans: [DialogSpan('Hi after Hahn joined')])
            ], isUnset: [
              IfFlag(EventFlag('Quest1'), isSet: [
                Dialog(spans: [DialogSpan('This is an optional quest')])
              ], isUnset: [
                IfFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1'),
                    isSet: [
                      Dialog(spans: [DialogSpan('Hi again')])
                    ],
                    isUnset: [
                      IfFlag(EventFlag('PrincipalMeeting'), isSet: [
                        SetFlag(EventFlag(
                            'Talk_Test_obj_Test_0_PrincipalMeeting_1')),
                        Dialog(
                            spans: [DialogSpan('Hi after meeting principal')])
                      ], isUnset: [
                        Dialog(spans: [DialogSpan('Hello world.')])
                      ])
                    ])
              ])
            ])
          ]));
    });
  });

  group('condition', () {
    test(
        'conflicts with conditions that set different values for non null flags',
        () {
      var c1 = Condition({EventFlag('a'): true});
      var c2 = Condition({EventFlag('a'): false});

      expect(c1.conflictsWith(c2), isTrue);
      expect(c2.conflictsWith(c1), isTrue);
    });

    test(
        'does not conflict with conditions that set same values for non null flags',
        () {
      var c1 = Condition({EventFlag('a'): true, EventFlag('b'): false});
      var c2 = Condition({EventFlag('a'): true});

      expect(c1.conflictsWith(c2), isFalse);
      expect(c2.conflictsWith(c1), isFalse);
    });

    test('does not conflict with conditions that set additional values', () {
      var c1 = Condition({EventFlag('a'): true});
      var c2 = Condition({EventFlag('a'): true, EventFlag('b'): false});

      expect(c1.conflictsWith(c2), isFalse);
      expect(c2.conflictsWith(c1), isFalse);
    });

    test(
        'is satisfied by conditions that set the same value for non null flags',
        () {
      var c1 = Condition({EventFlag('a'): true, EventFlag('b'): false});
      var c2 = Condition({EventFlag('a'): true});

      expect(c1.isSatisfiedBy(c2), isFalse);
      expect(c2.isSatisfiedBy(c1), isTrue);
    });

    test(
        'is not satisfied by conditions that set different values for non null flags',
        () {
      var c1 = Condition({EventFlag('a'): true, EventFlag('b'): false});
      var c2 = Condition({EventFlag('a'): true, EventFlag('b'): true});

      expect(c1.isSatisfiedBy(c2), isFalse);
      expect(c2.isSatisfiedBy(c1), isFalse);
    });

    test('empty conditions satisfy and do not conflict', () {
      expect(Condition.empty().isSatisfiedBy(Condition.empty()), isTrue);
      expect(Condition.empty().conflictsWith(Condition.empty()), isFalse);
    });
  });
}
