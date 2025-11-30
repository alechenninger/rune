import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

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

    test('face == steppath', () {
      expect(
          Face(up)..delay = 1.step,
          equals(StepPath()
            ..facing = up
            ..delay = 1.step));
      expect(
          StepPath()
            ..facing = up
            ..delay = 1.step,
          equals(Face(up)..delay = 1.step));
    });

    test('face == steppaths', () {
      expect(
          Face(up)..delay = 1.step,
          equals(StepPaths()
            ..step(StepPath()
              ..facing = up
              ..delay = 1.step)));
      expect(
          StepPaths()
            ..step(StepPath()
              ..facing = up
              ..delay = 1.step),
          equals(Face(up)..delay = 1.step));
    });
  });

  group('step paths', () {
    test('keeps multiple facings with delays', () {
      var step = StepPaths()
        ..step(StepPath()
          ..delay = 1.step
          ..facing = Direction.right)
        ..step(StepPath()
          ..delay = 2.steps
          ..facing = Direction.up)
        ..step(StepPath()
          ..delay = 3.steps
          ..facing = Direction.right);

      expect(step.delay, 1.step);
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

  group('animation', () {
    test('jump object computes equivalent step up and step down animations',
        () {
      var jump = JumpObject(alys, duration: 1.second, height: 10);

      expect(jump.toSteps(), [
        StepObjects.constantStep([alys],
            onTop: true,
            animate: false,
            frames: 0.5.seconds.toFrames(),
            stepPerFrame: Point(0, -10 / 0.5.seconds.toFrames())),
        StepObjects.constantStep([alys],
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
        StepObjects.constantStep([alys],
            onTop: true,
            animate: false,
            frames: 0.5.seconds.toFrames(),
            stepPerFrame: Point(-8 / 30, -10 / 30)),
        StepObjects.constantStep([alys],
            onTop: true,
            animate: false,
            frames: 0.5.second.toFrames(),
            stepPerFrame: Point(-8 / 30, 10 / 30)),
      ]);
    });
  });

  group('dialog', () {
    test('combines spans', () {}, skip: 'test not implemented');

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

      expect(dialog.spans, [
        DialogSpan('', events: [
          Pause(2.seconds, duringDialog: true),
          ShowPanel(PrincipalPanel.principal, showDialogBox: true),
          Pause(1.second, duringDialog: true)
        ]),
      ]);
    });

    test('combines empty span events with previous span', () {
      var dialog = Dialog(spans: [
        DialogSpan('Hello'),
        DialogSpan('', events: [Pause(2.seconds).inDialog()]),
        DialogSpan('',
            events: [ShowPanel(PrincipalPanel.principal).inDialog()]),
        // DialogSpan('', pause: 2.seconds, panel: PrincipalPanel.principal)
      ]);

      expect(dialog.spans.firstOrNull?.events, hasLength(2));
      expect(dialog.spans, [
        DialogSpan('Hello', events: [
          Pause(2.seconds).inDialog(),
          ShowPanel(PrincipalPanel.principal).inDialog()
        ]),
      ]);
    });

    test('pause is equivalent to pause event', () {
      var dialog = Dialog(spans: [DialogSpan('Test', pause: 2.seconds)]);

      expect(
          dialog,
          Dialog(spans: [
            DialogSpan('Test', events: [Pause(2.seconds, duringDialog: true)])
          ]));
    });

    test('panel is equivalent to panel event', () {
      var dialog =
          Dialog(spans: [DialogSpan('Test', panel: PrincipalPanel.principal)]);

      expect(
          dialog,
          Dialog(spans: [
            DialogSpan('Test', events: [
              ShowPanel(PrincipalPanel.principal, showDialogBox: true)
            ])
          ]));
    });

    test('pause and panel are equivalent to pause and panel events', () {
      var dialog = Dialog(spans: [
        DialogSpan('Test', pause: 2.seconds, panel: PrincipalPanel.principal)
      ]);

      expect(
          dialog,
          Dialog(spans: [
            DialogSpan('Test', events: [
              Pause(2.seconds, duringDialog: true),
              ShowPanel(PrincipalPanel.principal, showDialogBox: true)
            ])
          ]));
    });

    test('pause and panel come before other events', () {
      // Include additional events in span and ensure they are added after
      // pause and panel arguments
      var dialog = Dialog(spans: [
        DialogSpan('Test',
            pause: 2.seconds,
            panel: PrincipalPanel.principal,
            events: [
              Pause(1.second, duringDialog: true),
              ShowPanel(PrincipalPanel.principal, showDialogBox: true)
            ])
      ]);

      expect(
          dialog,
          Dialog(spans: [
            DialogSpan('Test', events: [
              Pause(2.seconds, duringDialog: true),
              ShowPanel(PrincipalPanel.principal, showDialogBox: true),
              Pause(1.second, duringDialog: true),
              ShowPanel(PrincipalPanel.principal, showDialogBox: true)
            ])
          ]));
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
      Dialog{speaker: Unnamed Speaker, hidePanelsOnClose: false, spans: [DialogSpan{text: Hi after Hahn joined, italic: false, events: []}]}
      Pause{0:00:01.000000, duringDialog: false, runObjects: false}
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
      Dialog{speaker: Unnamed Speaker, hidePanelsOnClose: false, spans: [DialogSpan{text: Hi, italic: false, events: []}]}
      Pause{0:00:01.000000, duringDialog: false, runObjects: false}
      IfFlag{EventFlag{PrincipalMeeting}, 
      isSet:
               SetFlag{EventFlag{Talk_Test_obj_Test_0_PrincipalMeeting_1}}
               Dialog{speaker: Unnamed Speaker, hidePanelsOnClose: false, spans: [DialogSpan{text: Hi after meeting principal, italic: false, events: []}]}
      isUnset:
               Dialog{speaker: Unnamed Speaker, hidePanelsOnClose: false, spans: [DialogSpan{text: Hello world., italic: false, events: []}]}
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

    test('assumes condition, removing unreachable outer branch', () {
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

      scene.assume(Condition({EventFlag('HahnJoined'): false}));

      expect(
          scene,
          Scene([
            IfFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1'),
                isSet: [
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
          ]));
    });

    test('assumes condition, removing unreachable inner branch', () {
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

      scene.assume(Condition({EventFlag('PrincipalMeeting'): false}));

      expect(
          scene,
          Scene([
            IfFlag(EventFlag('HahnJoined'), isSet: [
              Dialog(spans: [DialogSpan('Hi after Hahn joined')])
            ], isUnset: [
              IfFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1'),
                  isSet: [
                    Dialog(spans: [DialogSpan('Hi again')])
                  ],
                  isUnset: [
                    Dialog(spans: [DialogSpan('Hello world.')])
                  ])
            ])
          ]));
    });

    test('assumes complex condition, removing unreachable branches', () {
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

      scene.assume(Condition({
        EventFlag('PrincipalMeeting'): true,
        EventFlag('HahnJoined'): false
      }));

      expect(
          scene,
          Scene([
            IfFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1'),
                isSet: [
                  Dialog(spans: [DialogSpan('Hi again')])
                ],
                isUnset: [
                  SetFlag(EventFlag('Talk_Test_obj_Test_0_PrincipalMeeting_1')),
                  Dialog(spans: [DialogSpan('Hi after meeting principal')])
                ])
          ]));
    });

    group('branches()', () {
      test('find leaf branches', () {
        // First test with a scene that has only one deeply nested leaf branch with events that aren't just conditional checks
        var scene = Scene([
          IfFlag(EventFlag('flag1'), isUnset: [
            IfFlag(EventFlag('flag2'), isUnset: [
              IfValue(BySlot.one.position().component(Axis.y),
                  comparedTo: PositionComponent(0x100, Axis.y),
                  lessOrEqual: [
                    Dialog(spans: [DialogSpan('Leaf branch 1')]),
                    SetFlag(EventFlag('storyevent')),
                  ])
            ])
          ])
        ]);

        var branches = scene.branches();

        expect(branches, hasLength(1));

        var branch = branches.first;

        expect(
            branch.condition,
            Condition({
              EventFlag('flag1'): false,
              EventFlag('flag2'): false
            }, values: {
              (
                BySlot.one.position().component(Axis.y),
                PositionComponent(0x100, Axis.y)
              ): Comparison.lte
            }));
      });

      test('ignores SetContext', () {
        var scene = Scene([
          IfFlag(EventFlag('flag1'), isUnset: [
            SetContext((s) {}),
            IfFlag(EventFlag('flag2'), isUnset: [
              SetContext((s) {}),
              IfValue(BySlot.one.position().component(Axis.y),
                  comparedTo: PositionComponent(0x100, Axis.y),
                  lessOrEqual: [
                    Dialog(spans: [DialogSpan('Leaf branch 1')]),
                    SetFlag(EventFlag('storyevent')),
                  ])
            ])
          ])
        ]);

        var branches = scene.branches();

        expect(branches, hasLength(1));

        var branch = branches.first;

        expect(
            branch.condition,
            Condition({
              EventFlag('flag1'): false,
              EventFlag('flag2'): false
            }, values: {
              (
                BySlot.one.position().component(Axis.y),
                PositionComponent(0x100, Axis.y)
              ): Comparison.lte
            }));
      });

      test('returns single branch for flat scene with no conditionals', () {
        var scene = Scene([
          Dialog(spans: [DialogSpan('Hello')]),
          SetFlag(EventFlag('test')),
        ]);

        var branches = scene.branches();

        expect(branches, hasLength(1));
        expect(branches.first.condition, Condition.empty());
        // Note: Scene reorders SetFlag before Dialog
        expect(branches.first.events, [
          SetFlag(EventFlag('test')),
          Dialog(spans: [DialogSpan('Hello')]),
        ]);
      });

      test('returns empty for empty scene', () {
        var scene = Scene([]);

        var branches = scene.branches();

        expect(branches, isEmpty);
      });

      test('returns both branches of a simple IfFlag', () {
        var scene = Scene([
          IfFlag(EventFlag('test'), isSet: [
            Dialog(spans: [DialogSpan('Set branch')]),
          ], isUnset: [
            Dialog(spans: [DialogSpan('Unset branch')]),
          ])
        ]);

        var branches = scene.branches().toList();

        expect(branches, hasLength(2));

        expect(branches[0].condition, Condition({EventFlag('test'): true}));
        expect(branches[0].events, [
          Dialog(spans: [DialogSpan('Set branch')])
        ]);

        expect(branches[1].condition, Condition({EventFlag('test'): false}));
        expect(branches[1].events, [
          Dialog(spans: [DialogSpan('Unset branch')])
        ]);
      });

      test('nested IfFlags produce combined conditions', () {
        var scene = Scene([
          IfFlag(EventFlag('outer'), isSet: [
            IfFlag(EventFlag('inner'), isSet: [
              Dialog(spans: [DialogSpan('Both set')]),
            ], isUnset: [
              Dialog(spans: [DialogSpan('Outer set, inner unset')]),
            ])
          ], isUnset: [
            Dialog(spans: [DialogSpan('Outer unset')]),
          ])
        ]);

        var branches = scene.branches().toList();

        expect(branches, hasLength(3));

        expect(branches[0].condition,
            Condition({EventFlag('outer'): true, EventFlag('inner'): true}));

        expect(branches[1].condition,
            Condition({EventFlag('outer'): true, EventFlag('inner'): false}));

        expect(branches[2].condition, Condition({EventFlag('outer'): false}));
      });

      test('stops at first non-conditional event (does not recurse past it)',
          () {
        var scene = Scene([
          IfFlag(EventFlag('outer'), isSet: [
            Dialog(spans: [DialogSpan('Content before nested')]),
            IfFlag(EventFlag('inner'), isSet: [
              Dialog(spans: [DialogSpan('Should not be a separate branch')]),
            ], isUnset: [])
          ], isUnset: [
            Dialog(spans: [DialogSpan('Outer unset')]),
          ])
        ]);

        var branches = scene.branches().toList();

        // Should have 2 branches, not 3 - the nested IfFlag is part of the
        // "outer set" branch, not recursed into separately
        expect(branches, hasLength(2));

        expect(branches[0].condition, Condition({EventFlag('outer'): true}));
        // The branch contains both the dialog and the nested IfFlag
        expect(branches[0].events, hasLength(2));

        expect(branches[1].condition, Condition({EventFlag('outer'): false}));
      });

      test('IfValue branches produce value conditions', () {
        var scene = Scene([
          IfValue(BySlot.one.position().component(Axis.x),
              comparedTo: PositionComponent(0x200, Axis.x),
              greater: [
                Dialog(spans: [DialogSpan('Greater')]),
              ],
              equal: [
                Dialog(spans: [DialogSpan('Equal')]),
              ],
              less: [
                Dialog(spans: [DialogSpan('Less')]),
              ])
        ]);

        var branches = scene.branches().toList();

        expect(branches, hasLength(3));

        var key = (
          BySlot.one.position().component(Axis.x),
          PositionComponent(0x200, Axis.x)
        );

        // Order is: equal, greater, less (based on addBranch order in IfValue)
        expect(branches[0].condition, Condition({}, values: {key: eq}));
        expect(branches[1].condition, Condition({}, values: {key: gt}));
        expect(branches[2].condition, Condition({}, values: {key: lt}));
      });

      test('mixed IfFlag and IfValue produce combined conditions', () {
        var scene = Scene([
          IfFlag(EventFlag('flag'), isSet: [
            IfValue(alys.position().component(Axis.y),
                comparedTo: PositionComponent(0x100, Axis.y),
                lessOrEqual: [
                  Dialog(spans: [DialogSpan('Flag set and y <= 0x100')]),
                ],
                greater: [
                  Dialog(spans: [DialogSpan('Flag set and y > 0x100')]),
                ])
          ], isUnset: [
            Dialog(spans: [DialogSpan('Flag unset')]),
          ])
        ]);

        var branches = scene.branches().toList();

        expect(branches, hasLength(3));

        var valueKey = (
          alys.position().component(Axis.y),
          PositionComponent(0x100, Axis.y)
        );

        // Order: greater added before lessOrEqual in IfValue constructor
        expect(
            branches[0].condition,
            Condition({EventFlag('flag'): true},
                values: {valueKey: Comparison.gt}));

        expect(
            branches[1].condition,
            Condition({EventFlag('flag'): true},
                values: {valueKey: Comparison.lte}));

        expect(branches[2].condition, Condition({EventFlag('flag'): false}));
      });

      test('branch events are filtered by condition via asOf', () {
        // The Branch constructor applies scene.asOf(condition) to the events
        var scene = Scene([
          IfFlag(EventFlag('a'), isSet: [
            IfFlag(EventFlag('b'), isSet: [
              Dialog(spans: [DialogSpan('a and b set')]),
            ], isUnset: [
              Dialog(spans: [DialogSpan('a set, b unset')]),
            ])
          ], isUnset: [
            Dialog(spans: [DialogSpan('a unset')]),
          ])
        ]);

        var branches = scene.branches().toList();

        // Each branch's events should be the simplified view as of its condition
        expect(branches[0].events, [
          Dialog(spans: [DialogSpan('a and b set')])
        ]);
        expect(branches[1].events, [
          Dialog(spans: [DialogSpan('a set, b unset')])
        ]);
        expect(branches[2].events, [
          Dialog(spans: [DialogSpan('a unset')])
        ]);
      });

      test('toScene converts branch back to Scene', () {
        var scene = Scene([
          IfFlag(EventFlag('test'), isSet: [
            Dialog(spans: [DialogSpan('Set')]),
            SetFlag(EventFlag('marker')),
          ], isUnset: [
            Dialog(spans: [DialogSpan('Unset')]),
          ])
        ]);

        var branches = scene.branches().toList();
        var setBranch = branches[0].toScene();

        expect(
            setBranch,
            Scene([
              Dialog(spans: [DialogSpan('Set')]),
              SetFlag(EventFlag('marker')),
            ]));
      });

      test('empty branch in IfFlag is not yielded', () {
        var scene = Scene([
          IfFlag(EventFlag('test'), isSet: [
            Dialog(spans: [DialogSpan('Set')]),
          ], isUnset: [] // Empty branch
              )
        ]);

        var branches = scene.branches().toList();

        // Only the set branch should be yielded
        expect(branches, hasLength(1));
        expect(branches[0].condition, Condition({EventFlag('test'): true}));
      });

      test('scene with only SetContext events returns no branches', () {
        var scene = Scene([
          SetContext((s) {}),
          SetContext((s) {}),
        ]);

        var branches = scene.branches();

        // SetContext is ignored, so effectively empty
        expect(branches, isEmpty);
      });
    });

    group('condense', () {
      test('top level', () {
        var scene = Scene([
          Dialog.parse('test'),
          Dialog.parse('test2'),
        ]);

        scene.fastForward(dialogTo: Span('x'));

        expect(scene, Scene([Dialog.parse('x')]));
      });

      test('in if flag branches', () {
        var scene = Scene([
          Dialog.parse('test'),
          Dialog.parse('test2'),
          IfFlag(EventFlag('test'), isSet: [
            Dialog.parse('test3'),
            Dialog.parse('test4'),
            IfFlag(EventFlag('test2'), isSet: [
              Dialog.parse('test5'),
              Dialog.parse('test6'),
            ], isUnset: [
              Dialog.parse('test7'),
              Dialog.parse('test8'),
            ])
          ], isUnset: [
            Dialog.parse('test5'),
            Dialog.parse('test6'),
          ])
        ]);

        scene.fastForward(dialogTo: Span('x'));

        expect(
            scene,
            Scene([
              Dialog.parse('x'),
              IfFlag(EventFlag('test'), isSet: [
                Dialog.parse('x'),
                IfFlag(EventFlag('test2'), isSet: [
                  Dialog.parse('x'),
                ], isUnset: [
                  Dialog.parse('x'),
                ])
              ], isUnset: [
                Dialog.parse('x'),
              ])
            ]));
      });

      // TODO: condenses some pauses to 1 frame for vint
      test('removes pauses', () {
        var scene = Scene([
          Dialog.parse('test'),
          Dialog.parse('test2'),
          Pause(Duration(seconds: 1)),
          Dialog.parse('test3'),
          Dialog.parse('test4'),
          Pause(Duration(seconds: 1)),
          Dialog.parse('test5'),
          Dialog.parse('test6'),
        ]);

        scene.fastForward(dialogTo: Span('x'));

        expect(
            scene,
            Scene([
              Dialog.parse('x'),
            ]));
      });

      test('removes pauses from dialog spans', () {
        var scene = Scene([
          Dialog.parse('test'),
          Dialog.parse('test2'),
          Dialog(spans: [
            DialogSpan('test3', pause: 1.seconds),
            DialogSpan('test4', pause: 1.seconds),
            DialogSpan('test5', pause: 1.seconds),
            DialogSpan('test6', pause: 1.seconds),
          ]),
          Dialog.parse('test4'),
          Dialog(spans: [
            DialogSpan('test3', pause: 1.seconds),
            DialogSpan('test4', pause: 1.seconds),
            DialogSpan('test5', pause: 1.seconds),
            DialogSpan('test6', pause: 1.seconds),
          ]),
          Dialog.parse('test6'),
        ]);

        scene.fastForward(dialogTo: Span('x'));

        expect(
            scene,
            Scene([
              Dialog.parse('x'),
            ]));
      });

      test('maintains panels in dialog', () {
        var scene = Scene([
          Dialog.parse('test'),
          Dialog.parse('test2'),
          Dialog(spans: [
            DialogSpan('test3', panel: PrincipalPanel.principal),
            DialogSpan('test4', panel: PrincipalPanel.alysGrabsPrincipal),
            DialogSpan('test5', panel: PrincipalPanel.manTurnedToStone),
          ]),
          Dialog.parse('test4'),
          Dialog(spans: [
            DialogSpan('test3', panel: PrincipalPanel.principal),
            DialogSpan('test4', panel: PrincipalPanel.principalScared),
            DialogSpan('test5', panel: PrincipalPanel.alysWhispersToHahn),
          ]),
          Dialog.parse('test6'),
        ]);

        scene.fastForward(dialogTo: Span('x'));

        expect(
            scene,
            Scene([
              Dialog(spans: [
                DialogSpan('x', events: [
                  ShowPanel(PrincipalPanel.principal).inDialog(),
                  ShowPanel(PrincipalPanel.alysGrabsPrincipal).inDialog(),
                  ShowPanel(PrincipalPanel.manTurnedToStone).inDialog(),
                  ShowPanel(PrincipalPanel.principal).inDialog(),
                  ShowPanel(PrincipalPanel.principalScared).inDialog(),
                  ShowPanel(PrincipalPanel.alysWhispersToHahn).inDialog(),
                ]),
              ]),
            ]));
      });

      test('up to event index', () {
        var scene = Scene([
          Dialog.parse('test'),
          Dialog.parse('test2'),
          Dialog.parse('test3'),
          Dialog.parse('test4'),
          Dialog.parse('test5'),
          Dialog.parse('test6'),
        ]);

        scene.fastForward(dialogTo: Span('x'), upTo: 3);

        expect(
            scene,
            Scene([
              Dialog.parse('x'),
              Dialog.parse('test4'),
              Dialog.parse('test5'),
              Dialog.parse('test6'),
            ]));
      });
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

    test('conflicts with conditions that set different branch for values', () {
      var c1 = Condition({}, values: {
        (alys.position().component(Axis.x), rune.position().component(Axis.x)):
            eq
      });
      var c2 = Condition({}, values: {
        (alys.position().component(Axis.x), rune.position().component(Axis.x)):
            gt
      });

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

    test(
        'does not conflict with conditions that set same values for non null flags and same branch for values',
        () {
      var c1 = Condition({
        EventFlag('a'): true,
        EventFlag('b'): false
      }, values: {
        (alys.position(), rune.position()): gt,
        (shay.position().component(Axis.x), PositionComponent(0x100, Axis.y)):
            eq
      });
      var c2 = Condition({
        EventFlag('a'): true
      }, values: {
        (shay.position().component(Axis.x), PositionComponent(0x100, Axis.y)):
            eq
      });

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
        'is satisfied by conditions that set the same value for non null flags and branch for values',
        () {
      var c1 = Condition({
        EventFlag('a'): true,
        EventFlag('b'): false
      }, values: {
        (alys.position(), rune.position()): gt,
        (shay.position().component(Axis.x), PositionComponent(0x100, Axis.y)):
            eq
      });
      var c2 = Condition({
        EventFlag('a'): true
      }, values: {
        (alys.position(), rune.position()): gt,
      });

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

    test(
        'is not satisfied by conditions that have different branches for values',
        () {
      var c1 = Condition({}, values: {
        (alys.position(), rune.position()): gt,
        (shay.position().component(Axis.x), PositionComponent(0x100, Axis.y)):
            lte
      });
      var c2 = Condition({}, values: {
        (alys.position(), rune.position()): gt,
        (shay.position().component(Axis.x), PositionComponent(0x100, Axis.y)):
            eq
      });

      expect(c1.isSatisfiedBy(c2), isFalse);
      expect(c2.isSatisfiedBy(c1), isFalse);
    });

    test('empty conditions satisfy and do not conflict', () {
      expect(Condition.empty().isSatisfiedBy(Condition.empty()), isTrue);
      expect(Condition.empty().conflictsWith(Condition.empty()), isFalse);
    });
  });

  group('shutter objects', () {
    test('starts down by default', () {
      var shutter = ShutterObjects([MapObjectById.of('test')],
          duration: 1.second, times: 2);
      var pause = Pause(((60 - 2) / 2).truncate().framesToDuration());
      expect(shutter.toEvents(), [
        StepObjects.constantStep([MapObjectById.of('test')],
            animate: true, onTop: false, frames: 1, stepPerFrame: Point(0, 1)),
        pause,
        StepObjects.constantStep([MapObjectById.of('test')],
            animate: true, onTop: false, frames: 1, stepPerFrame: Point(0, -1)),
        pause,
        StepObjects.constantStep([MapObjectById.of('test')],
            animate: true, onTop: false, frames: 1, stepPerFrame: Point(0, 1)),
        pause,
        StepObjects.constantStep([MapObjectById.of('test')],
            animate: true, onTop: false, frames: 1, stepPerFrame: Point(0, -1)),
        pause,
      ]);
    });

    test('can start up', () {
      var shutter = ShutterObjects([MapObjectById.of('test')],
          duration: 1.second, times: 2, start: ShutterStart.up);
      var pause = Pause(((60 - 2) / 2).truncate().framesToDuration());
      expect(shutter.toEvents(), [
        StepObjects.constantStep([MapObjectById.of('test')],
            animate: true, onTop: false, frames: 1, stepPerFrame: Point(0, -1)),
        pause,
        StepObjects.constantStep([MapObjectById.of('test')],
            animate: true, onTop: false, frames: 1, stepPerFrame: Point(0, 1)),
        pause,
        StepObjects.constantStep([MapObjectById.of('test')],
            animate: true, onTop: false, frames: 1, stepPerFrame: Point(0, -1)),
        pause,
        StepObjects.constantStep([MapObjectById.of('test')],
            animate: true, onTop: false, frames: 1, stepPerFrame: Point(0, 1)),
        pause,
      ]);
    });
  });

  group('direction expresions', () {
    group('offset directions', () {
      test('1 turn is equivalent to -3 turns', () {
        expect(OffsetDirection(up, turns: 1), OffsetDirection(up, turns: -3));
      });

      test('2 turns is equivalent to -2 turns', () {
        expect(OffsetDirection(up, turns: 2), OffsetDirection(up, turns: -2));
      });

      test('3 turns is equivalent to -1 turns', () {
        expect(OffsetDirection(up, turns: 3), OffsetDirection(up, turns: -1));
      });

      test('4 turns is equivalent to 0 turns', () {
        expect(OffsetDirection(up, turns: 4), OffsetDirection(up, turns: 0));
      });

      test('if direction is known, offset is known', () {
        expect(OffsetDirection(up, turns: 1).known(EventState()), right);
      });
    });
  });
}
