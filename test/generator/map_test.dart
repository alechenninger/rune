import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/asm/text.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  late GameMap testMap;
  late Program program;
  late TestEventRoutines testEventRoutines;

  setUp(() {
    testMap = GameMap(MapId.Test);
    program = Program(
        eventPointers: EventPointers.empty(),
        runEvents: JumpTable(
            jump: bra.w, newIndex: Byte.new, labels: [RunEvent_NoEvent]));
    testEventRoutines = TestEventRoutines();
  });

  test('map model generates asm', () {
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ]));

    testMap.addObject(obj);

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.objects.trim().withoutComments(),
        Asm([
          dc.w(['38'.hex.toWord]),
          dc.b([Constant('FacingDir_Down'), 0.toByte]),
          dc.w(['2D0'.hex.toWord]),
          dc.w([
            '3c'.hex.toWord,
            '5c'.hex.toWord,
          ])
        ]));
  });

  test('objects refer to appropriate field obj routine ptr', () {
    // a bit hard to test?

    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ]));

    testMap.addObject(obj);

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.objects.withoutComments().first,
        Asm([
          dc.w(['38'.hex.toWord])
        ]).first);
  });

  test('sprites are defined', () {
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ]));

    testMap.addObject(obj);

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan1')])
        ]));
  });

  test('multiple sprites tile numbers are separated by 0x48', () {
    testMap.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    testMap.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanWoman1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    testMap.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan2, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan1')]),
          dc.w(['318'.hex.toWord]),
          dc.l([Constant('Art_PalmanWoman1')]),
          dc.w(['360'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan2')]),
        ]));
  });

  test('sprites are referred to by their corresponding objects', () {
    testMap.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    testMap.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanWoman1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    testMap.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan2, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    var mapAsm = program.addMap(testMap);
    var objectsAsm = mapAsm.objects.withoutComments();
    // todo: this is kind of brittle
    expect(objectsAsm[2], dc.w(['2d0'.hex.toWord]));
    expect(objectsAsm[7], dc.w(['318'.hex.toWord]));
    expect(objectsAsm[12], dc.w(['360'.hex.toWord]));
  });

  test('objects requiring fewer tiles use fewer tiles', () {
    testMap.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDownOrUpLegsHidden()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    testMap.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanWoman1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    testMap.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan2, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan1')]),
          dc.w(['308'.hex.toWord]),
          dc.l([Constant('Art_PalmanWoman1')]),
          dc.w(['350'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan2')]),
        ]));
  });

  test('sprite uses the max needed vram tile width when reused', () {
    testMap.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDownLegsHiddenNonInteractive())));

    testMap.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown())));

    testMap.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan2, FaceDown())));

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan1')]),
          dc.w(['318'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan2')]),
        ]));
  });

  test(
      'objects requiring fewer tiles use fewer tiles even if specified with asm spec',
      () {
    testMap.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: InteractiveAsmSpec(
            routine: Word(0x108),
            startFacing: down,
            artLabel: Label('Art_PalmanMan1'),
            onInteract: Scene([
              Dialog(spans: [DialogSpan('Hello world!')])
            ]))));

    testMap.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanWoman1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    testMap.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan2, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan1')]),
          dc.w(['308'.hex.toWord]),
          dc.l([Constant('Art_PalmanWoman1')]),
          dc.w(['350'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan2')]),
        ]));
  });

  test('sprites are reused for multiple objects of the same sprite', () {
    testMap.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown())));

    testMap.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown())));

    testMap.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown())));

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan1')]),
        ]));

    // todo: this is kind of brittle
    var objectsAsm = mapAsm.objects.withoutComments();
    expect(objectsAsm[2], dc.w(['2d0'.hex.toWord]));
    expect(objectsAsm[7], dc.w(['2d0'.hex.toWord]));
    expect(objectsAsm[12], dc.w(['2d0'.hex.toWord]));
  });

  test('sprites which need duplicates are duplicated', () {
    testMap.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown())));

    testMap.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.GuildReceptionist, FaceDownOrUpLegsHidden())));

    testMap.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan2, FaceDown())));

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan1')]),
          dc.w(['318'.hex.toWord]),
          dc.l([Constant('Art_GuildReceptionist')]),
          dc.w(['340'.hex.toWord]),
          dc.l([Constant('Art_GuildReceptionist')]),
          dc.w(['350'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan2')]),
        ]));

    // todo: this is kind of brittle
    var objectsAsm = mapAsm.objects.withoutComments();
    expect(objectsAsm[2], dc.w(['2d0'.hex.toWord]));
    expect(objectsAsm[7], dc.w(['318'.hex.toWord]));
    expect(objectsAsm[12], dc.w(['350'.hex.toWord]));
  });

  test('sprites are not duplicated if would exceed routine tiles', () {
    testMap.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown())));

    testMap.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec:
            Npc(Sprite.GuildReceptionist, FaceDownLegsHiddenNonInteractive())));

    testMap.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan2, FaceDown())));

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan1')]),
          dc.w(['318'.hex.toWord]),
          dc.l([Constant('Art_GuildReceptionist')]),
          dc.w(['320'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan2')]),
        ]));

    // todo: this is kind of brittle
    var objectsAsm = mapAsm.objects.withoutComments();
    expect(objectsAsm[2], dc.w([0x2d0.toWord]));
    expect(objectsAsm[7], dc.w([0x318.toWord]));
    expect(objectsAsm[12], dc.w([0x320.toWord]));
  });

  test('treasure chest vram is skipped', () {
    // Need at least 8 full sprites to collide with chest tiles
    testMap.addObject(MapObject(
      startPosition: Position(0x1e0, 0x2e0),
      spec: Npc(Sprite.PalmanMan1, FaceDown()),
    ));
    testMap.addObject(MapObject(
      startPosition: Position(0x1f0, 0x2e0),
      spec: Npc(Sprite.PalmanMan2, FaceDown()),
    ));
    testMap.addObject(MapObject(
      startPosition: Position(0x200, 0x2e0),
      spec: Npc(Sprite.PalmanMan3, FaceDown()),
    ));
    testMap.addObject(MapObject(
      startPosition: Position(0x1e0, 0x2e0),
      spec: Npc(Sprite.PalmanFighter1, FaceDown()),
    ));
    testMap.addObject(MapObject(
      startPosition: Position(0x1f0, 0x2e0),
      spec: Npc(Sprite.PalmanFighter2, FaceDown()),
    ));
    testMap.addObject(MapObject(
      startPosition: Position(0x200, 0x2e0),
      spec: Npc(Sprite.PalmanFighter3, FaceDown()),
    ));
    testMap.addObject(MapObject(
      startPosition: Position(0x1e0, 0x2e0),
      spec: Npc(Sprite.PalmanWoman1, FaceDown()),
    ));
    testMap.addObject(MapObject(
      startPosition: Position(0x1f0, 0x2e0),
      spec: Npc(Sprite.PalmanWoman2, FaceDownOrUpLegsHidden()),
    ));
    testMap.addObject(MapObject(
      startPosition: Position(0x200, 0x2e0),
      spec: Npc(Sprite.Motavian1, FaceDownSimpleSprite()),
    ));

    var mapAsm = program.addMap(testMap);

    expect(
        mapAsm.sprites,
        Asm([
          dc.w([0x2d0.toWord]),
          dc.l([Constant('Art_PalmanMan1')]),
          dc.w([0x318.toWord]),
          dc.l([Constant('Art_PalmanMan2')]),
          dc.w([0x360.toWord]),
          dc.l([Constant('Art_PalmanMan3')]),
          dc.w([0x3a8.toWord]),
          dc.l([Constant('Art_PalmanFighter1')]),
          dc.w([0x3f0.toWord]),
          dc.l([Constant('Art_PalmanFighter2')]),
          dc.w([0x438.toWord]),
          dc.l([Constant('Art_PalmanFighter3')]),
          dc.w([0x480.toWord]),
          dc.l([Constant('Art_PalmanWoman1')]),
          // Goes after chests
          dc.w([0x4ed.toWord]),
          dc.l([Constant('Art_PalmanWoman2')]),
          // Goes at end of main region
          dc.w([0x4c8.toWord]),
          dc.l([Constant('Art_Motavian1')]),
        ]));
  });

  group('arranges vram around fixed built in sprites', () {
    test('which split regions', () {
      program = Program(builtInSprites: {
        MapId.Test: [
          SpriteVramMapping(
              tiles: 0x112,
              art: RomArt(label: Label('Art_PalmanWoman1')),
              requiredVramTile: Word(0x34d)) // 35f-34d
        ]
      });

      // 2d0-318
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
      ));
      // would collide with built in, so goes after
      // 45f-4a7
      testMap.addObject(MapObject(
        startPosition: Position(0x1f0, 0x2e0),
        spec: Npc(Sprite.PalmanMan2, FaceDown()),
      ));
      // would collide with chest so goes after that
      // 4ed
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.PalmanMan3, FaceDownOrUpLegsHidden()),
      ));

      var mapAsm = program.addMap(testMap);

      expect(
          mapAsm.sprites,
          Asm([
            dc.w([0x34d.toWord]),
            dc.l([Constant('Art_PalmanWoman1')]),
            dc.w([0x2d0.toWord]),
            dc.l([Constant('Art_PalmanMan1')]),
            dc.w([0x45f.toWord]),
            dc.l([Constant('Art_PalmanMan2')]),
            dc.w([0x4ed.toWord]),
            dc.l([Constant('Art_PalmanMan3')]),
          ]));

      var objectsAsm = mapAsm.objects.withoutComments();
      expect(objectsAsm[2], dc.w([0x2d0.toWord]));
      expect(objectsAsm[7], dc.w([0x45f.toWord]));
      expect(objectsAsm[12], dc.w([0x4ed.toWord]));
    });

    test('at the start of sprite vram', () {
      program = Program(builtInSprites: {
        MapId.Test: [
          SpriteVramMapping(
              tiles: 0x100,
              art: RomArt(label: Label('Art_PalmanWoman1')),
              requiredVramTile: Word(0x2d0)) // 2d0-3d0
        ]
      });

      // starts after built in, 3d0
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
      ));
      // 418
      testMap.addObject(MapObject(
        startPosition: Position(0x1f0, 0x2e0),
        spec: Npc(Sprite.PalmanMan2, FaceDown()),
      ));
      // 460
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.PalmanMan3, FaceDownOrUpLegsHidden()),
      ));

      var mapAsm = program.addMap(testMap);

      expect(
          mapAsm.sprites,
          Asm([
            dc.w([0x2d0.toWord]),
            dc.l([Constant('Art_PalmanWoman1')]),
            dc.w([0x3d0.toWord]),
            dc.l([Constant('Art_PalmanMan1')]),
            dc.w([0x418.toWord]),
            dc.l([Constant('Art_PalmanMan2')]),
            dc.w([0x460.toWord]),
            dc.l([Constant('Art_PalmanMan3')]),
          ]));

      var objectsAsm = mapAsm.objects.withoutComments();
      expect(objectsAsm[2], dc.w([0x3d0.toWord]));
      expect(objectsAsm[7], dc.w([0x418.toWord]));
      expect(objectsAsm[12], dc.w([0x460.toWord]));
    });
  });

  group('routines which use ram art', () {
    test('set a vram tile but not a sprite', () {
      testMap.addObject(MapObject(
          startPosition: Position('1f0'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanMan1, FaceDown())));

      testMap.addObject(MapObject(
          startPosition: Position('200'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanMan2, FaceDown())));

      testMap.addObject(MapObject(
          startPosition: Position('1e0'.hex, '2e0'.hex),
          spec: AsmSpec(routine: Word(0xf8), startFacing: down)));

      var mapAsm = program.addMap(testMap);

      expect(
          mapAsm.sprites,
          Asm([
            dc.w(['2d0'.hex.toWord]),
            dc.l([Constant('Art_PalmanMan1')]),
            dc.w(['318'.hex.toWord]),
            dc.l([Constant('Art_PalmanMan2')]),
          ]));

      var objectsAsm = mapAsm.objects.withoutComments();
      expect(objectsAsm[2], dc.w([0x2d0.toWord]));
      expect(objectsAsm[7], dc.w([0x318.toWord]));
      expect(objectsAsm[12], dc.w([0x360.toWord]));
    });

    test('only use as much vram as needed', () {
      testMap.addObject(MapObject(
          startPosition: Position('1f0'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanMan1, FaceDownOrUpLegsHidden())));

      testMap.addObject(MapObject(
          startPosition: Position('1e0'.hex, '2e0'.hex),
          spec: AsmSpec(routine: Word(0xf8), startFacing: down)));

      testMap.addObject(MapObject(
          startPosition: Position('200'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanMan2, FaceDown())));

      var mapAsm = program.addMap(testMap);
      expect(
          mapAsm.sprites,
          Asm([
            dc.w([0x2d0.toWord]),
            dc.l([Constant('Art_PalmanMan1')]),
            dc.w([0x30e.toWord]),
            dc.l([Constant('Art_PalmanMan2')]),
          ]));

      var objectsAsm = mapAsm.objects.withoutComments();
      expect(objectsAsm[2], dc.w([0x2d0.toWord]));
      expect(objectsAsm[7], dc.w([0x308.toWord]));
      expect(objectsAsm[12], dc.w([0x30e.toWord]));
    });

    test(
        'do not share the same vram tile if using the same art but animated in vram',
        () {
      // vram tiles are animated based on the object state.
      // so two objects cant share the same vram.
      testMap.addObject(MapObject(
          startPosition: Position('1f0'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanMan1, FaceDown())));

      testMap.addObject(MapObject(
          startPosition: Position('1e0'.hex, '2e0'.hex),
          spec: AsmSpec(routine: Word(0xf8), startFacing: down)));

      testMap.addObject(MapObject(
          startPosition: Position('200'.hex, '2e0'.hex),
          spec: AsmSpec(routine: Word(0xf8), startFacing: down)));

      var mapAsm = program.addMap(testMap);

      expect(
          mapAsm.sprites,
          Asm([
            dc.w([0x2d0.toWord]),
            dc.l([Constant('Art_PalmanMan1')]),
          ]));

      var objectsAsm = mapAsm.objects.withoutComments();
      expect(objectsAsm[2], dc.w([0x2d0.toWord]));
      expect(objectsAsm[7], dc.w([0x318.toWord]));
      expect(objectsAsm[12], dc.w([0x31E.toWord]));
    });

    test('share the same vram tile if using the same art not animated in vram',
        () {},
        skip: "don't have routines like this yet");

    test('do not share the same vram tile if not using the same art', () {},
        skip: "don't have routines like this yet");

    test('may overwrite treasure chest vram if out of space', () {
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1f0, 0x2e0),
        spec: Npc(Sprite.PalmanMan2, FaceDown()),
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.PalmanMan3, FaceDown()),
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanFighter1, FaceDown()),
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1f0, 0x2e0),
        spec: Npc(Sprite.PalmanFighter2, FaceDown()),
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.PalmanFighter3, FaceDown()),
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanWoman1, FaceDown()),
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.Motavian1, FaceDownSimpleSprite()),
      ));
      // Use after chest
      testMap.addObject(MapObject(
        startPosition: Position(0x1f0, 0x2e0),
        spec: Npc(Sprite.PalmanWoman2, FaceDownOrUpLegsHidden()),
      ));
      // Use after chest
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0), spec: AlysWaiting()));
      // Use chest
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: AsmSpec(routine: Word(0xF0), startFacing: down)));
      // Use chest
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: AsmSpec(routine: Word(0xF0), startFacing: down)));

      var mapAsm = program.addMap(testMap);

      expect(
          mapAsm.sprites,
          Asm([
            dc.w([0x2d0.toWord]),
            dc.l([Constant('Art_PalmanMan1')]),
            dc.w([0x318.toWord]),
            dc.l([Constant('Art_PalmanMan2')]),
            dc.w([0x360.toWord]),
            dc.l([Constant('Art_PalmanMan3')]),
            dc.w([0x3a8.toWord]),
            dc.l([Constant('Art_PalmanFighter1')]),
            dc.w([0x3f0.toWord]),
            dc.l([Constant('Art_PalmanFighter2')]),
            dc.w([0x438.toWord]),
            dc.l([Constant('Art_PalmanFighter3')]),
            dc.w([0x480.toWord]),
            dc.l([Constant('Art_PalmanWoman1')]),
            dc.w([0x4c8.toWord]),
            dc.l([Constant('Art_Motavian1')]),
            dc.w([0x4ed.toWord]),
            dc.l([Constant('Art_PalmanWoman2')]),
          ]));

      var objectsAsm = mapAsm.objects.withoutComments();
      expect(objectsAsm[0 * 5 + 2], dc.w([0x2d0.toWord]));
      expect(objectsAsm[1 * 5 + 2], dc.w([0x318.toWord]));
      expect(objectsAsm[2 * 5 + 2], dc.w([0x360.toWord]));
      expect(objectsAsm[3 * 5 + 2], dc.w([0x3a8.toWord]));
      expect(objectsAsm[4 * 5 + 2], dc.w([0x3f0.toWord]));
      expect(objectsAsm[5 * 5 + 2], dc.w([0x438.toWord]));
      expect(objectsAsm[6 * 5 + 2], dc.w([0x480.toWord]));
      expect(objectsAsm[7 * 5 + 2], dc.w([0x4c8.toWord]));
      // Starts after chest
      expect(objectsAsm[8 * 5 + 2], dc.w([0x4ed.toWord]));
      // Fits in after chest
      expect(objectsAsm[9 * 5 + 2], dc.w([0x525.toWord]));
      // Starts overlapping
      expect(objectsAsm[10 * 5 + 2], dc.w([0x4da.toWord]));
    });

    test('may overrun treasure chest vram into after chest to make space', () {
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanMan1, FaceDown()), // 0x2d0-0x318
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1f0, 0x2e0),
        spec: Npc(Sprite.PalmanMan2, FaceDown()), // 0x318-0x360
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.PalmanMan3, FaceDown()), // 0x360-0x3a8
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanFighter1, FaceDown()), // 0x3a8-0x3f0
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1f0, 0x2e0),
        spec: Npc(Sprite.PalmanFighter2, FaceDown()), // 0x3f0-0x438
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.PalmanFighter3, FaceDown()), // 0x438-0x480
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanWoman1, FaceDown()), // 0x480-0x4c8
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.Motavian1, FaceDownSimpleSprite()), // 0x4c8-4da
      ));
      // Should fit in at 4da-4e2
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: AsmSpec(routine: Word(0xF0), startFacing: down)));
      // 4e2-4ea
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: AsmSpec(routine: Word(0xF0), startFacing: down)));
      // 4ea-4f2
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0), spec: AlysWaiting()));
      // 4f2-4fa
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: AsmSpec(routine: Word(0xF0), startFacing: down)));
      // 4fa
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.PalmanWoman2, FaceDownOrUpLegsHidden()),
      ));

      var mapAsm = program.addMap(testMap);

      expect(
          mapAsm.sprites,
          Asm([
            dc.w([0x2d0.toWord]),
            dc.l([Constant('Art_PalmanMan1')]),
            dc.w([0x318.toWord]),
            dc.l([Constant('Art_PalmanMan2')]),
            dc.w([0x360.toWord]),
            dc.l([Constant('Art_PalmanMan3')]),
            dc.w([0x3a8.toWord]),
            dc.l([Constant('Art_PalmanFighter1')]),
            dc.w([0x3f0.toWord]),
            dc.l([Constant('Art_PalmanFighter2')]),
            dc.w([0x438.toWord]),
            dc.l([Constant('Art_PalmanFighter3')]),
            dc.w([0x480.toWord]),
            dc.l([Constant('Art_PalmanWoman1')]),
            dc.w([0x4c8.toWord]),
            dc.l([Constant('Art_Motavian1')]),
            dc.w([0x4fa.toWord]),
            dc.l([Constant('Art_PalmanWoman2')]),
          ]));

      var objectsAsm = mapAsm.objects.withoutComments();
      expect(objectsAsm[0 * 5 + 2], dc.w([0x2d0.toWord]));
      expect(objectsAsm[1 * 5 + 2], dc.w([0x318.toWord]));
      expect(objectsAsm[2 * 5 + 2], dc.w([0x360.toWord]));
      expect(objectsAsm[3 * 5 + 2], dc.w([0x3a8.toWord]));
      expect(objectsAsm[4 * 5 + 2], dc.w([0x3f0.toWord]));
      expect(objectsAsm[5 * 5 + 2], dc.w([0x438.toWord]));
      expect(objectsAsm[6 * 5 + 2], dc.w([0x480.toWord]));
      expect(objectsAsm[7 * 5 + 2], dc.w([0x4c8.toWord]));
      // Start using up chest area into after chest
      expect(objectsAsm[8 * 5 + 2], dc.w([0x4f2.toWord]));
      expect(objectsAsm[9 * 5 + 2], dc.w([0x4da.toWord]));
      expect(objectsAsm[10 * 5 + 2], dc.w([0x4e2.toWord]));
      expect(objectsAsm[11 * 5 + 2], dc.w([0x4ea.toWord]));
      // Start later in after chest due to offset
      expect(objectsAsm[12 * 5 + 2], dc.w([0x4fa.toWord]));
    });

    test('detects when not enough room to place sprites', () {
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanMan1, FaceDown()), // 0x2d0-0x318
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1f0, 0x2e0),
        spec: Npc(Sprite.PalmanMan2, FaceDown()), // 0x318-0x360
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.PalmanMan3, FaceDown()), // 0x360-0x3a8
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanFighter1, FaceDown()), // 0x3a8-0x3f0
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1f0, 0x2e0),
        spec: Npc(Sprite.PalmanFighter2, FaceDown()), // 0x3f0-0x438
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.PalmanFighter3, FaceDown()), // 0x438-0x480
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x1e0, 0x2e0),
        spec: Npc(Sprite.PalmanWoman1, FaceDown()), // 0x480-0x4c8
      ));
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.Motavian1, FaceDownSimpleSprite()), // 0x4c8-4da
      ));
      // Should fit in at 4da-4e2
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: AsmSpec(routine: Word(0xF0), startFacing: down)));
      // 4e2-4ea
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: AsmSpec(routine: Word(0xF0), startFacing: down)));
      // 4ea-4f2
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0), spec: AlysWaiting()));
      // 4f2-4fa
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: AsmSpec(routine: Word(0xF0), startFacing: down)));
      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: AsmSpec(routine: Word(0xF0), startFacing: down)));
      // 4fa
      testMap.addObject(MapObject(
        startPosition: Position(0x200, 0x2e0),
        spec: Npc(Sprite.PalmanWoman2, FaceDownOrUpLegsHidden()),
      ));

      expect(
          () => program.addMap(testMap),
          throwsA(isA<Exception>().having((e) => e.toString(), 'toString',
              contains('cannot fit sprite in vram'))));
    });
  });

  group('routines which use hard coded rom art', () {
    test('set a vram tile but not a sprite', () {
      testMap.addObject(MapObject(
          startPosition: Position(0x1f0, 0x2e0),
          spec: Npc(Sprite.PalmanMan1, FaceDown())));

      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: Npc(Sprite.PalmanMan2, FaceDown())));

      testMap.addObject(MapObject(
          startPosition: Position(0x1e0, 0x2e0), spec: AlysWaiting()));

      var mapAsm = program.addMap(testMap);

      expect(
          mapAsm.sprites,
          Asm([
            dc.w([0x2d0.toWord]),
            dc.l([Constant('Art_PalmanMan1')]),
            dc.w([0x318.toWord]),
            dc.l([Constant('Art_PalmanMan2')]),
          ]));

      var objectsAsm = mapAsm.objects.withoutComments();
      expect(objectsAsm[2], dc.w([0x2d0.toWord]));
      expect(objectsAsm[7], dc.w([0x318.toWord]));
      expect(objectsAsm[12], dc.w([0x360.toWord]));
    });

    test('only use as much vram as needed', () {
      testMap.addObject(MapObject(
          startPosition: Position(0x1f0, 0x2e0),
          spec: Npc(Sprite.PalmanMan1, FaceDown())));

      testMap.addObject(MapObject(
          startPosition: Position(0x1e0, 0x2e0), spec: AlysWaiting()));

      testMap.addObject(MapObject(
          startPosition: Position(0x1e0, 0x2e0), spec: AlysWaiting()));

      testMap.addObject(MapObject(
          startPosition: Position(0x200, 0x2e0),
          spec: Npc(Sprite.PalmanMan2, FaceDown())));

      var mapAsm = program.addMap(testMap);

      expect(
          mapAsm.sprites,
          Asm([
            dc.w([0x2d0.toWord]),
            dc.l([Constant('Art_PalmanMan1')]),
            dc.w([0x328.toWord]),
            dc.l([Constant('Art_PalmanMan2')]),
          ]));

      var objectsAsm = mapAsm.objects.withoutComments();
      expect(objectsAsm[2], dc.w([0x2d0.toWord]));
      expect(objectsAsm[7], dc.w([0x318.toWord]));
      expect(objectsAsm[12], dc.w([0x320.toWord]));
      expect(objectsAsm[17], dc.w([0x328.toWord]));
    });
  });

  test('objects use position divided by 8', () {}, skip: 'todo');

  test('objects use correct facing direction', () {}, skip: 'todo');

  test('objects with no dialog still terminate dialog', () {
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()));
    obj.onInteract = Scene.forNpcInteraction([]);

    testMap.addObject(obj);

    var asm = program.addMap(testMap);

    expect(asm.dialog?.withoutComments().trim().tail(1), dc.b([Byte(0xff)]));
  });

  group('objects with dialog', () {
    late MapAsm mapAsm;

    setUp(() {
      testMap.addObject(MapObject(
          startPosition: Position('1e0'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanMan1, FaceDown()),
          onInteract: Scene([
            Dialog(spans: [DialogSpan('Hello!')])
          ])));

      testMap.addObject(MapObject(
          startPosition: Position('1f0'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanWoman1, FaceDown()),
          onInteract: Scene([
            Dialog(spans: [DialogSpan('Goodbye!')])
          ])));

      mapAsm = program.addMap(testMap);
    });

    test('produce dialog asm', () {
      expect(
          mapAsm.dialog,
          Asm([
            comment(r'$00'),
            Dialog(spans: [DialogSpan('Hello!')]).toAsm(EventState()),
            terminateDialog(),
            newLine(),
            comment(r'$01'),
            Dialog(spans: [DialogSpan('Goodbye!')]).toAsm(EventState()),
            terminateDialog(),
            newLine()
          ]));
    });

    test('refer to correct dialog offset', () {
      expect(
          mapAsm.objects.withoutComments()[1],
          Asm([
            dc.b([Constant('FacingDir_Down'), 0.toByte]),
          ]));
      expect(
          mapAsm.objects.withoutComments()[6],
          Asm([
            dc.b([Constant('FacingDir_Down'), 1.toByte]),
          ]));
    });

    test("when not starting with faceplayer, starts with f3 control code", () {
      var testMap = GameMap(MapId.Test);

      testMap.addObject(MapObject(
          startPosition: Position('1e0'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanMan1, FaceDown()),
          onInteract: Scene([
            Dialog(spans: [DialogSpan('Hello!')])
          ]),
          onInteractFacePlayer: false));

      var mapAsm = Program().addMap(testMap);

      expect(
          mapAsm.dialog,
          Asm([
            comment(r'$00'),
            dc.b(Bytes.of(0xF3)),
            Dialog(spans: [DialogSpan('Hello!')]).toAsm(EventState()),
            terminateDialog(),
            newLine(),
          ]));
    });

    test('does not product event code', () {
      expect(mapAsm.events, Asm.empty());
      expect(program.additionalEventPointers, Asm.empty());
    });
  });

  group('objects with events', () {
    var npc1Scene = Scene([
      Dialog(spans: [DialogSpan('Hello!')]),
      Pause(Duration(seconds: 1)),
    ]);

    var npc2Scene = Scene([
      Dialog(spans: [DialogSpan('Goodbye!')]),
      Pause(Duration(seconds: 2)),
    ]);

    var npc1 = MapObject(
        id: 'npc1',
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: npc1Scene);

    var npc2 = MapObject(
        id: 'npc2',
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanWoman1, FaceDown()),
        onInteract: npc2Scene);

    setUp(() {
      testMap.addObject(npc1);
      testMap.addObject(npc2);
    });

    test('trigger scenes from dialog interactions', () {
      var mapAsm = program.addMap(testMap);

      var comparisonDialogTrees = DialogTrees();
      var comparisonEventAsm = EventAsm.empty();

      SceneAsmGenerator.forInteraction(testMap, SceneId('Test_npc1'),
          comparisonDialogTrees, comparisonEventAsm, testEventRoutines)
        ..runEvent()
        ..scene(npc1.onInteract)
        ..finish(appendNewline: true);

      SceneAsmGenerator.forInteraction(testMap, SceneId('Test_npc2'),
          comparisonDialogTrees, comparisonEventAsm, testEventRoutines)
        ..runEvent()
        ..scene(npc2.onInteract)
        ..finish(appendNewline: true);

      expect(mapAsm.events, comparisonEventAsm);
      expect(program.dialogTrees, comparisonDialogTrees);
    });

    test('produce event pointers', () {
      program.addMap(testMap);

      expect(
          program.additionalEventPointers,
          Asm([
            dc.l([Label('Event_GrandCross_Test_npc1')], comment: r'$0000'),
            dc.l([Label('Event_GrandCross_Test_npc2')], comment: r'$0001')
          ]));
    });

    test('event asm has newline between events and cutscenes', () {
      var cutsceneNpc = MapObject(
          id: 'CutsceneNpc',
          startPosition: Position(0x1d0, 0x2e0),
          spec: AlysWaiting());
      cutsceneNpc.onInteract = Scene.forNpcInteraction([
        FadeOut(),
        Dialog(spans: [DialogSpan('Test!')]),
      ]);

      testMap.addObject(cutsceneNpc);

      var mapAsm = program.addMap(testMap);

      print(mapAsm.events);
      print(program.cutscenesPointers);
      print(program.additionalEventPointers);
    });
  });

  group('npc interaction events', () {
    group('in dialog', () {
      test('plays sound if there is a dialog after', () {
        var obj = MapObject(
            startPosition: Position('1e0'.hex, '2e0'.hex),
            spec: Npc(Sprite.PalmanMan1, FaceDown()),
            onInteract: Scene([
              PlaySound(SoundEffect.surprise),
              Dialog(spans: [DialogSpan('Hiyo!')])
            ]));
        testMap.addObject(obj);

        var asm = program.addMap(testMap);

        expect(
            asm.dialog?.withoutComments().trim(),
            Asm([
              dc.b([Byte(0xf2), Byte(3)]),
              dc.b([Constant('SFXID_Surprise')]),
              dc.b(Bytes.ascii('Hiyo!')),
              dc.b([Byte(0xff)]),
            ]));
      });

      test('sets flag first if set flag is after dialog', () {
        // this is actually a property of the Scene model

        var obj = MapObject(
            startPosition: Position('1e0'.hex, '2e0'.hex),
            spec: Npc(Sprite.PalmanMan1, FaceDown()),
            onInteract: Scene([
              Dialog(spans: [DialogSpan('Hiyo!')]),
              SetFlag(EventFlag('test')),
            ]));
        testMap.addObject(obj);

        var asm = program.addMap(testMap);

        expect(
            asm.dialog?.withoutComments().trim(),
            Asm([
              dc.b([Byte(0xf2), Byte(0xb)]),
              dc.b([Constant('EventFlag_test')]),
              dc.b(Bytes.ascii('Hiyo!')),
              dc.b([Byte(0xff)]),
            ]));
      });
    });

    group('in event', () {
      test('plays sound if there is no dialog after', () {
        var obj = MapObject(
            startPosition: Position('1e0'.hex, '2e0'.hex),
            spec: Npc(Sprite.PalmanMan1, FaceDown()),
            onInteract: Scene([
              Dialog(spans: [DialogSpan('Hiyo!')]),
              PlaySound(SoundEffect.surprise),
            ]));
        testMap.addObject(obj);

        var asm = program.addMap(testMap);

        expect(
            asm.events
                .withoutComments()
                .trim()
                .skipWhile((i) => !'$i'.contains('RunDialog'))
                .skip(1)
                .take(1),
            Asm([
              move.b(SoundEffect.surprise.sfxId.i, Constant('Sound_Index').l)
            ]));
      });
    });

    test('removes panel in dialog if removal preceeds dialog', () {
      var obj = MapObject(
          id: 'test',
          startPosition: Position('1e0'.hex, '2e0'.hex),
          spec: Npc(
              Sprite.PalmanMan1,
              FaceDown(
                  onInteract: Scene([
                FadeOut(),
                ShowPanel(PrincipalPanel.shayAndAlys),
                Dialog(spans: [DialogSpan('Hi')]),
                HideTopPanels(1),
                Dialog(spans: [DialogSpan('Bye')]),
              ]))));
      testMap.addObject(obj);

      var asm = program.addMap(testMap);

      expect(
          program.dialogTrees.forMap(testMap.id)[1].withoutComments(),
          DialogAsm([
            dc.b(Bytes.ascii('Hi')),
            dc.b([Byte(0xfd)]),
            dc.b([Byte(0xf2), Byte.one]),
            dc.b(Bytes.ascii('Bye')),
            dc.b([Byte(0xff)])
          ]));

      expect(
          asm.events
              .withoutComments()
              .skipWhile((line) => !line.toString().contains('RunDialogue'))
              .skip(1)
              .first
              .toString(),
          isNot(contains('Panel_Destroy')));
    });

    test('removes panel in event if removal does not preceed dialog', () {
      var obj = MapObject(
          id: 'test',
          startPosition: Position('1e0'.hex, '2e0'.hex),
          spec: Npc(
              Sprite.PalmanMan1,
              FaceDown(
                  onInteract: Scene([
                SetContext((ctx) {
                  ctx.followLead = false;
                  ctx.slots[1] = alys;
                  ctx.positions[alys] = Position(0, 0);
                }),
                FadeOut(),
                ShowPanel(PrincipalPanel.shayAndAlys),
                Dialog(spans: [DialogSpan('Hi')]),
                HideTopPanels(1),
                RelativePartyMove(StepPaths()..face(Direction.down))
              ]))));
      testMap.addObject(obj);

      var asm = program.addMap(testMap);

      expect(
          program.dialogTrees.forMap(testMap.id)[1].withoutComments(),
          DialogAsm([
            dc.b(Bytes.ascii('Hi')),
            dc.b([Byte(0xff)])
          ]));

      expect(
          asm.events
              .withoutComments()
              .skipWhile((line) => !line.toString().contains('RunDialogue'))
              .skip(1)
              .take(2),
          Asm([jsr('Panel_Destroy'.toLabel.l), dmaPlanesVInt()]));
    });
  });

  group('areas', () {
    test('generate asm for interactive area', () {
      testMap.addArea(MapArea(
          id: MapAreaId('test0'),
          at: Position(0x50, 0x80),
          range: AreaRange.xLower,
          spec: InteractiveAreaSpec(
              onInteract: Scene([
            Dialog(spans: [DialogSpan('Hi')])
          ]))));

      var asm = program.addMap(testMap);

      expect(
          asm.areas.withoutComments().trim(),
          Asm([
            dc.w([Word(0xA), Word(0x10)]),
            dc.w([Word(4)]),
            dc.b(Bytes.list([0, 0, 7, 0])),
          ]));
    });

    test('generate dialog for interactive area', () {
      testMap.addArea(MapArea(
          id: MapAreaId('test0'),
          at: Position(0x50, 0x80),
          range: AreaRange.xyExact,
          spec: InteractiveAreaSpec(
              onInteract: Scene([
            Dialog(spans: [DialogSpan('Hi')])
          ]))));

      program.addMap(testMap);

      var tree = program.dialogTrees.forMap(testMap.id);

      expect(tree.length, 1);
      expect(
          tree[0].withoutComments(),
          DialogAsm([
            dc.b(Bytes.ascii('Hi')),
            dc.b([Byte(0xff)])
          ]));
    });

    test('generates asm for asm area', () {
      testMap.addArea(MapArea(
          id: MapAreaId('test0'),
          at: Position(0x50, 0x80),
          range: AreaRange.xyExact,
          spec: AsmArea(
              eventType: Byte(1),
              eventFlag: Byte(0xA),
              interactionRoutine: Byte(2),
              interactionParameter: Byte(0xBD))));

      var asm = program.addMap(testMap);

      expect(
          asm.areas.withoutComments().trim(),
          Asm([
            dc.w([Word(0xA), Word(0x10)]),
            dc.w([Word(3)]),
            dc.b(Bytes.list([1, 0xA, 2, 0xBD]))
          ]));
    });

    test('generates asm for multiple areas', () {
      testMap.addArea(MapArea(
          id: MapAreaId('test0'),
          at: Position(0x50, 0x80),
          range: AreaRange.xyExact,
          spec: AsmArea(
              eventType: Byte(1),
              eventFlag: Byte(0xA),
              interactionRoutine: Byte(2),
              interactionParameter: Byte(0xBD))));

      testMap.addArea(MapArea(
          id: MapAreaId('test1'),
          at: Position(0x50, 0x80),
          range: AreaRange.xLower,
          spec: InteractiveAreaSpec(
              onInteract: Scene([
            Dialog(spans: [DialogSpan('Hi')])
          ]))));

      var asm = program.addMap(testMap);

      expect(
          asm.areas.withoutComments().trim(),
          Asm([
            dc.w([Word(0xA), Word(0x10)]),
            dc.w([Word(3)]),
            dc.b(Bytes.list([1, 0xA, 2, 0xBD])),
            newLine(),
            dc.w([Word(0xA), Word(0x10)]),
            dc.w([Word(4)]),
            dc.b(Bytes.list([0, 0, 7, 0])),
          ]));
    });

    test('generates dialog for multiple areas', () {
      testMap.addArea(MapArea(
          id: MapAreaId('test0'),
          at: Position(0x50, 0x80),
          range: AreaRange.xyExact,
          spec: InteractiveAreaSpec(
              onInteract: Scene([
            Dialog(spans: [DialogSpan('Hi1')])
          ]))));

      testMap.addArea(MapArea(
          id: MapAreaId('test1'),
          at: Position(0x40, 0x60),
          range: AreaRange.xLower,
          spec: InteractiveAreaSpec(
              onInteract: Scene([
            Dialog(spans: [DialogSpan('Hi2')])
          ]))));

      var asm = program.addMap(testMap);

      expect(
          asm.areas.withoutComments().trim(),
          Asm([
            dc.w([Word(0xA), Word(0x10)]),
            dc.w([Word(3)]),
            dc.b(Bytes.list([0, 0, 7, 0])),
            newLine(),
            dc.w([Word(0x8), Word(0xC)]),
            dc.w([Word(4)]),
            dc.b(Bytes.list([0, 0, 7, 1])),
          ]));

      var tree = program.dialogTrees.forMap(testMap.id);

      expect(tree.length, 2);
      expect(
          tree[0].withoutComments(),
          DialogAsm([
            dc.b(Bytes.ascii('Hi1')),
            dc.b([Byte(0xff)])
          ]));
      expect(
          tree[1].withoutComments(),
          DialogAsm([
            dc.b(Bytes.ascii('Hi2')),
            dc.b([Byte(0xff)])
          ]));
    });
  });

  group('experiments with parsing asm', () {
    test('parses a map', () {
      var asm = Asm.fromRaw(tonoeAsm);
      // TODO
      // var map = asmToMap(Label('Map_Tonoe'), asm);
      // print(map);
    });
  }, skip: 'need to implement for real');

  group('parses map from asm', () {
    // todo: some kind of map asm fixture for generating test map asm
    // would need its own tests

    test('dialog without portraits in npc interactions assumes npc is speaker',
        () async {
      // not sure how much i like this...

      var asm = Asm.fromRaw(testMapAsm);
      var dialog = TestDialogTreeLookup({
        Label('TestDialogTree'): DialogTree()
          ..add(DialogAsm([
            dc.b(Bytes.ascii('Hi there!')),
            dc.b([Byte(0xff)])
          ]))
      });
      var map = await asmToMap(Label('Map_Test'), asm, dialog);

      expect(map.orderedObjects, hasLength(3));

      var obj = map.orderedObjects.first;

      expect(
          obj.onInteract,
          Scene([
            InteractionObject.facePlayer(),
            Dialog(speaker: obj, spans: DialogSpan.parse('Hi there!'))
          ]));
    });

    test(
        'dialog without portraits in conditional npc interactions assumes npc is speaker',
        () async {
      // not sure how much i like this...

      var asm = Asm.fromRaw(testMapAsm);
      var dialog = TestDialogTreeLookup({
        Label('TestDialogTree'): DialogAsm([
          dc.b([Byte(0xfa)]),
          dc.b(Bytes.list([0x0b, 0x01])),
          dc.b(Bytes.ascii('Hi there!')),
          dc.b([Byte(0xff)]),
          dc.b(Bytes.ascii('Bye!')),
          dc.b([Byte(0xff)])
        ]).splitToTree()
      });
      var map = await asmToMap(Label('Map_Test'), asm, dialog);

      expect(map.orderedObjects, hasLength(3));

      var obj = map.orderedObjects.first;

      expect(
          obj.onInteract,
          Scene([
            IfFlag(toEventFlag(Byte(0x0b)), isUnset: [
              InteractionObject.facePlayer(),
              Dialog(speaker: obj, spans: DialogSpan.parse('Hi there!'))
            ], isSet: [
              InteractionObject.facePlayer(),
              Dialog(speaker: obj, spans: DialogSpan.parse('Bye!'))
            ])
          ]));
    });

    test('objects which are not interactive do not parse scenes', () async {
      var asm = Asm.fromRaw(testMapAsm);
      var dialog = TestDialogTreeLookup({
        Label('TestDialogTree'): DialogAsm([
          dc.b(Bytes.ascii('one')),
          dc.b([Byte(0xff)]),
          dc.b(Bytes.ascii('two')),
          dc.b([Byte(0xff)]),
          dc.b(Bytes.ascii('three')),
          dc.b([Byte(0xff)])
        ]).splitToTree()
      });
      var map = await asmToMap(Label('Map_Test'), asm, dialog);

      expect(map.orderedObjects, hasLength(3));

      expect(map.orderedObjects[1].onInteract, Scene.none());
      expect(map.orderedObjects[2].onInteract, Scene.none());
    });

    test('objects which refer to the same scene use identical Scenes',
        () async {
      var asm = (MapAsmFixture()
            ..sprites[0x200] = 'Art_PalmanMan1'
            ..addObject(
                routine: 0x3c,
                direction: 0,
                dialog: 0,
                tileNumber: 0x200,
                x: 0x10,
                y: 0x10)
            ..addObject(
                routine: 0x3c,
                direction: 0,
                dialog: 0,
                tileNumber: 0x200,
                x: 0x10,
                y: 0x12))
          .toAsm();

      var dialog = TestDialogTreeLookup({
        Label('TestDialogTree'): DialogAsm([
          dc.b(Bytes.ascii('one')),
          dc.b([Byte(0xff)]),
        ]).splitToTree()
      });

      var map = await asmToMap(Label('Map_Test'), asm, dialog);

      expect(map.orderedObjects, hasLength(2));
      expect(map.orderedObjects[0].onInteract,
          same(map.orderedObjects[1].onInteract));
    });

    test('parses first sprite vram tile', () async {
      var asm = (MapAsmFixture()
            ..sprites[0x2D0] = 'Art_PalmanMan1'
            ..sprites[0x2d0 + 0x48] = 'Art_PalmanMan2'
            ..sprites[0x2d0 + 0x48 * 2] = 'Art_PalmanMan2')
          .toAsm();

      var tile = await firstSpriteVramTileOfMap(asm);

      expect(tile, Word(0x2d0));
    });

    test('parses first sprite vram tile even if sprites unordered', () async {
      var asm = (MapAsmFixture()
            ..sprites[0x2d0 + 0x48] = 'Art_PalmanMan2'
            ..sprites[0x2D0] = 'Art_PalmanMan1'
            ..sprites[0x2d0 + 0x48 * 2] = 'Art_PalmanMan2')
          .toAsm();

      expect(
          asm,
          containsAllInOrder([
            dc.w([Word(0x318)]).first,
            dc.w([Word(0x2d0)]).first,
          ]),
          reason: 'ensure test setup correctly');

      var tile = await firstSpriteVramTileOfMap(asm);

      expect(tile, Word(0x2d0));
    });

    test('parses interaction areas', () async {
      var dialog = TestDialogTreeLookup({
        Label('TestDialogTree'): DialogTree()
          ..add(DialogAsm([
            dc.b(Bytes.ascii('Hi there!')),
            dc.b([Byte(0xff)])
          ])),
        Label('DialogueTree28'): DialogTree()
          ..addAll([
            DialogAsm([
              dc.b([Byte(0xff)])
            ]),
            DialogAsm([
              dc.b([Byte(0xff)])
            ]),
            DialogAsm([
              dc.b([Byte(0xff)])
            ]),
            DialogAsm([
              dc.b([Byte(0xff)])
            ]),
            DialogAsm([
              dc.b([Byte(0xff)])
            ]),
            DialogAsm([
              dc.b(Bytes.ascii("It's an area")),
              dc.b([Byte(0xff)])
            ]),
          ])
      });

      var asm = (MapAsmFixture()
            ..addArea(
                x: 0x3c, // 1e0
                y: 0x3a, // 1d0
                range: 1,
                flagCheckType: 0,
                flag: 0,
                routine: 0,
                parameter: 5))
          .toAsm();

      var map = await asmToMap(Label('Map_Test'), asm, dialog);

      expect(map.areas, [
        MapArea(
            id: MapAreaId('Test_area_0'),
            at: Position(0x1e0, 0x1d0),
            range: AreaRange.x40y40,
            spec: InteractiveAreaSpec(
                onInteract:
                    Scene([Dialog(spans: DialogSpan.parse("It's an area"))])))
      ]);
    });

    test('motavia dialog ids above 0x7e use tree 29', () async {
      var dialog = TestDialogTreeLookup({
        Label('TestDialogTree'): DialogTree()
          ..add(DialogAsm([
            dc.b(Bytes.ascii('Hi there!')),
            dc.b([Byte(0xff)])
          ])),
        Label('DialogueTree29'): DialogTree()
          ..addAndExtend(
              0x7f,
              DialogAsm([
                dc.b(Bytes.ascii("It's an area")),
                dc.b([Byte(0xff)])
              ]))
      });

      var asm = (MapAsmFixture()
            ..addArea(
                x: 0x3c, // 1e0
                y: 0x3a, // 1d0
                range: 1,
                flagCheckType: 0,
                flag: 0,
                routine: 0,
                parameter: 0x7f))
          .toAsm();

      var map = await asmToMap(Label('Map_Test'), asm, dialog);

      expect(map.areas, [
        MapArea(
            id: MapAreaId('Test_area_0'),
            at: Position(0x1e0, 0x1d0),
            range: AreaRange.x40y40,
            spec: InteractiveAreaSpec(
                onInteract:
                    Scene([Dialog(spans: DialogSpan.parse("It's an area"))])))
      ]);
    });

    test('motavia dialog ids <= 0x7e use tree 28', () async {
      var dialog = TestDialogTreeLookup({
        Label('TestDialogTree'): DialogTree()
          ..add(DialogAsm([
            dc.b(Bytes.ascii('Hi there!')),
            dc.b([Byte(0xff)])
          ])),
        Label('DialogueTree28'): DialogTree()
          ..addAndExtend(
              0x7e,
              DialogAsm([
                dc.b(Bytes.ascii("It's an area")),
                dc.b([Byte(0xff)])
              ]))
      });

      var asm = (MapAsmFixture()
            ..addArea(
                x: 0x3c, // 1e0
                y: 0x3a, // 1d0
                range: 1,
                flagCheckType: 0,
                flag: 0,
                routine: 0,
                parameter: 0x7e))
          .toAsm();

      var map = await asmToMap(Label('Map_Test'), asm, dialog);

      expect(map.areas, [
        MapArea(
            id: MapAreaId('Test_area_0'),
            at: Position(0x1e0, 0x1d0),
            range: AreaRange.x40y40,
            spec: InteractiveAreaSpec(
                onInteract:
                    Scene([Dialog(spans: DialogSpan.parse("It's an area"))])))
      ]);
    });

    test('non motavia dialog ids above 0x7e use tree 30', () async {
      var dialog = TestDialogTreeLookup({
        Label('TestDialogTree'): DialogTree()
          ..add(DialogAsm([
            dc.b(Bytes.ascii('Hi there!')),
            dc.b([Byte(0xff)])
          ])),
        Label('DialogueTree30'): DialogTree()
          ..addAndExtend(
              0x7f,
              DialogAsm([
                dc.b(Bytes.ascii("It's an area")),
                dc.b([Byte(0xff)])
              ]))
      });

      var asm = (MapAsmFixture()
            ..mapName = 'RajaTemple'
            ..addArea(
                x: 0x3c, // 1e0
                y: 0x3a, // 1d0
                range: 1,
                flagCheckType: 0,
                flag: 0,
                routine: 0,
                parameter: 0x7f))
          .toAsm();

      var map = await asmToMap(Label('Map_RajaTemple'), asm, dialog);

      expect(map.areas, [
        MapArea(
            id: MapAreaId('RajaTemple_area_0'),
            at: Position(0x1e0, 0x1d0),
            range: AreaRange.x40y40,
            spec: InteractiveAreaSpec(
                onInteract:
                    Scene([Dialog(spans: DialogSpan.parse("It's an area"))])))
      ]);
    });

    test('non motavia dialog ids <= 0x7e also use tree 30', () async {
      var dialog = TestDialogTreeLookup({
        Label('TestDialogTree'): DialogTree()
          ..add(DialogAsm([
            dc.b(Bytes.ascii('Hi there!')),
            dc.b([Byte(0xff)])
          ])),
        Label('DialogueTree30'): DialogTree()
          ..addAndExtend(
              0x7e,
              DialogAsm([
                dc.b(Bytes.ascii("It's an area")),
                dc.b([Byte(0xff)])
              ]))
      });

      var asm = (MapAsmFixture()
            ..mapName = 'RajaTemple'
            ..addArea(
                x: 0x3c, // 1e0
                y: 0x3a, // 1d0
                range: 1,
                flagCheckType: 0,
                flag: 0,
                routine: 0,
                parameter: 0x7e))
          .toAsm();

      var map = await asmToMap(Label('Map_RajaTemple'), asm, dialog);

      expect(map.areas, [
        MapArea(
            id: MapAreaId('RajaTemple_area_0'),
            at: Position(0x1e0, 0x1d0),
            range: AreaRange.x40y40,
            spec: InteractiveAreaSpec(
                onInteract:
                    Scene([Dialog(spans: DialogSpan.parse("It's an area"))])))
      ]);
    });

    test('parses events', () async {
      var dialog =
          TestDialogTreeLookup({Label('TestDialogTree'): DialogTree()});
      var asm = (MapAsmFixture()
            ..addEvent(6)
            ..addEvent(0x3a)
            ..addEvent(0x3b)
            ..addEvent(0x3c))
          .toAsm();

      var map = await asmToMap(Label('Map_Test'), asm, dialog);

      expect(map.events, isEmpty);
      // Additional padding
      expect(map.asmEvents, Bytes.list([6, 0x3a, 0x3b, 0x3c, 0]));
    });
  });

  test('preprocesses map does not change existing data', () async {
    var asm = (MapAsmFixture()
          ..sprites[0x2d0 + 0x48] = 'Art_PalmanMan2'
          ..sprites[0x2D0] = 'Art_PalmanMan1'
          ..sprites[0x2d0 + 0x48 * 2] = 'Art_PalmanMan2'
          ..addObject(
              routine: 0x3c,
              direction: 0,
              dialog: 0,
              tileNumber: 0x2d0,
              x: 0,
              y: 0))
        .toAsm()
        .withoutComments()
        .withoutEmptyLines();

    var raw = preprocessMapToRaw(asm,
        sprites: '',
        objects: '',
        dialog: Label('Test'),
        fieldRoutines: defaultFieldRoutines);
    var processed = Asm.fromRaw(raw.join('\n'));

    var expected = (MapAsmFixture()..dialogTreeLabel = 'Test')
        .toAsm()
        .withoutComments()
        .withoutEmptyLines();

    var data = ConstantReader.asm(processed)
        .skipThrough(value: Word(0xffff), times: 11);
    var expectedData = ConstantReader.asm(expected)
        .skipThrough(value: Word(0xffff), times: 11);

    expect(data, expectedData);
  });

  test('determines address of objects', () {
    var obj1 =
        MapObject(id: '1', startPosition: Position(0, 0), spec: AlysWaiting());
    var obj2 =
        MapObject(id: '2', startPosition: Position(0, 0), spec: AlysWaiting());
    testMap.addObject(obj1);
    testMap.addObject(obj2);

    expect(testMap.addressOf(obj1), Longword(0xFFFFC300));
    expect(testMap.addressOf(obj2), Longword(0xFFFFC340));
  });

  test('determines address of objects added at indexes', () {
    var obj1 =
        MapObject(id: '1', startPosition: Position(0, 0), spec: AlysWaiting());
    var obj2 =
        MapObject(id: '2', startPosition: Position(0, 0), spec: AlysWaiting());
    testMap.addObject(obj1, at: 1);
    testMap.addObject(obj2, at: 0);

    expect(testMap.addressOf(obj2), Longword(0xFFFFC300));
    expect(testMap.addressOf(obj1), Longword(0xFFFFC340));
  });

  test('determines address of objects added at sparse indexes', () {
    var obj1 =
        MapObject(id: '1', startPosition: Position(0, 0), spec: AlysWaiting());
    var obj2 =
        MapObject(id: '2', startPosition: Position(0, 0), spec: AlysWaiting());
    testMap.addObject(obj1, at: 1);
    testMap.addObject(obj2, at: 3);

    expect(testMap.addressOf(obj1), Longword(0xFFFFC340));
    expect(testMap.addressOf(obj2), Longword(0xFFFFC3C0));
  });

  group('run events compiler', () {
    late MapAsm asm;

    group('with only asm events', () {
      test('generates run event indices', () {
        testMap.addAsmEvent(Byte(0xf));

        asm = program.addMap(testMap);

        expect(asm.runEventIndices.withoutComments(), dc.b([Byte(0xf)]));
      });

      test('word aligns run event indices', () {
        testMap.addAsmEvent(Byte(1));
        testMap.addAsmEvent(Byte(0x3a));

        asm = program.addMap(testMap);

        expect(asm.runEventIndices.withoutComments(),
            dc.b(Bytes.list([1, 0x3a, 0])));
      });
    });

    group('with asm and scene events', () {
      test('includes both in run event indices', () {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfFlag(EventFlag('testflag'), isSet: [
                Dialog(spans: [DialogSpan('Hi')]),
              ])
            ]));
        testMap.addAsmEvent(Byte(0xd));
        testMap.addAsmEvent(Byte(0xe));

        asm = program.addMap(testMap);

        expect(asm.runEventIndices.withoutComments(),
            dc.b(Bytes.list([1, 0xd, 0xe])));
      });

      test('word aligns run event indices', () {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfFlag(EventFlag('testflag'), isSet: [
                Dialog(spans: [DialogSpan('Hi')]),
              ])
            ]));
        testMap.addAsmEvent(Byte(0xd));

        asm = program.addMap(testMap);

        expect(asm.runEventIndices.withoutComments(),
            dc.b(Bytes.list([1, 0xd, 0])));
      });
    });

    group('with event flag check and just dialog generates', () {
      setUp(() {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfFlag(EventFlag('testflag'), isSet: [
                Dialog(spans: [DialogSpan('Hi')]),
              ])
            ]));

        asm = program.addMap(testMap);
      });

      test('run event pointer', () {
        expect(
            program.runEventsJumpTable,
            Asm([
              bra.w(RunEvent_NoEvent, comment: r'$00'),
              bra.w(Label('RunEvent_GrandCross_testrun'), comment: r'$01')
            ]));
      });

      test('optimized run event routine which triggers event', () {
        expect(
            asm.runEventRoutines.withoutComments(),
            Asm([
              label(Label('RunEvent_GrandCross_testrun')),
              moveq(Constant('EventFlag_testflag').i, d0),
              jsr(Label('EventFlag_testflag').l),
              beq.w(Label('RunEvent_NoEvent')),
              move.w(Word(0).i, Constant('Event_Index').w),
              moveq(1.i, d7),
            ]));
      }, skip: 'not optimized yet');

      test('run event routine which triggers event', () {
        expect(
            asm.runEventRoutines.withoutComments(),
            Asm([
              label(Label('RunEvent_GrandCross_testrun')),
              moveq(Constant('EventFlag_testflag').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.testflag_unset1')),
              move.w(Word(0).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
              label(Label('.testflag_unset1')),
              bra.w(Label('RunEvent_NoEvent')),
            ]));
      });

      test('run event indices for map data', () {
        expect(asm.runEventIndices.withoutComments(), dc.b([1.toByte]));
      });

      test('event routine', () {
        expect(
            asm.events.withoutComments(),
            Asm([
              label(Label('Event_GrandCross_testrun2')),
              getAndRunDialog3LowDialogId(0.toByte.i),
              rts,
            ]));
      });
    });

    group('with nested event flag checks generates', () {
      setUp(() {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfFlag(EventFlag('testflag1'), isSet: [
                IfFlag(EventFlag('testflag2'), isSet: [
                  Dialog(spans: [DialogSpan('Hi')]),
                ])
              ])
            ]));

        asm = program.addMap(testMap);
      });

      test('consecutive event flag checks', () {
        expect(
            asm.runEventRoutines.withoutComments(),
            Asm([
              label(Label('RunEvent_GrandCross_testrun')),
              moveq(Constant('EventFlag_testflag1').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.testflag1_unset1')),
              moveq(Constant('EventFlag_testflag2').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.testflag2_unset2')),
              move.w(Word(0).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
              label(Label('.testflag2_unset2')),
              label(Label('.testflag1_unset1')),
              bra.w(Label('RunEvent_NoEvent')),
            ]));
      });
    });

    group('with events in both branches generates', () {
      setUp(() {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfFlag(EventFlag('testflag'), isSet: [
                Dialog(spans: [DialogSpan('Hi')]),
              ], isUnset: [
                Dialog(spans: [DialogSpan('Bye')]),
              ])
            ]));

        asm = program.addMap(testMap);
      });

      test('alternative event branch and no continue label', () {
        expect(
            asm.runEventRoutines.withoutComments(),
            Asm([
              label(Label('RunEvent_GrandCross_testrun')),
              moveq(Constant('EventFlag_testflag').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.testflag_unset1')),
              move.w(Word(0).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
              label(Label('.testflag_unset1')),
              move.w(Word(1).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
            ]));
      });

      test('unique event routines for each branch', () {
        expect(asm.events.withoutComments(), Asm([]));
      });
    });

    group('with both branches of nested event flag checks, generates', () {
      setUp(() {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfFlag(EventFlag('testflag1'), isSet: [
                IfFlag(EventFlag('testflag2'), isSet: [
                  Dialog(spans: [DialogSpan('Hi')]),
                ], isUnset: [
                  Dialog(spans: [DialogSpan('Bye')]),
                ])
              ], isUnset: [
                IfFlag(EventFlag('testflag3'), isSet: [
                  Dialog(spans: [DialogSpan('How are you?')]),
                ], isUnset: [
                  Dialog(spans: [DialogSpan('Goodbye')]),
                ])
              ])
            ]));

        asm = program.addMap(testMap);
      });

      test('consecutive event flag checks', () {
        expect(
            asm.runEventRoutines.withoutComments(),
            Asm([
              label(Label('RunEvent_GrandCross_testrun')),
              moveq(Constant('EventFlag_testflag1').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.testflag1_unset1')),
              moveq(Constant('EventFlag_testflag2').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.testflag2_unset2')),
              move.w(Word(0).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
              label(Label('.testflag2_unset2')),
              move.w(Word(1).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
              label(Label('.testflag1_unset1')),
              moveq(Constant('EventFlag_testflag3').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.testflag3_unset5')),
              move.w(Word(2).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
              label(Label('.testflag3_unset5')),
              move.w(Word(3).i, Constant('Event_Index').w),
              moveq(1.i, d7),
              rts,
            ]));
      });
    });

    group('with branching event, generates', () {
      setUp(() {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfFlag(EventFlag('testflag1'), isSet: [
                Dialog(spans: [DialogSpan('Hi')]),
                IfFlag(EventFlag('testflag2'), isSet: [
                  Dialog(spans: [DialogSpan('How are you?')]),
                ])
              ])
            ]));

        asm = program.addMap(testMap);
      });

      test('branch inside event code', () {
        expect(
            asm.events.withoutComments(),
            Asm([
              label(Label('Event_GrandCross_testrun2')),
              getAndRunDialog3LowDialogId(0.toByte.i),
              moveq(Constant('EventFlag_testflag2').i, d0),
              jsr(Label('EventFlags_Test').l),
              beq.w(Label('.testflag2_unset3')),
              getAndRunDialog3LowDialogId(1.toByte.i),
              label(Label('.testflag2_unset3')),
              rts,
            ]));
      });
    });

    group('with consecutive flag checks', () {
      setUp(() {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfFlag(EventFlag('testflag1'), isSet: [
                SetFlag(EventFlag('testflag1')),
                Dialog(spans: [DialogSpan('Hi')]),
              ]),
              IfFlag(EventFlag('testflag2'), isSet: [
                SetFlag(EventFlag('testflag2')),
                Dialog(spans: [DialogSpan('Hi 2')]),
              ])
            ]));

        asm = program.addMap(testMap);
      });

      test('consecutive flag checks', () {
        expect(asm.runEventRoutines.withoutComments(), Asm([]));
      }, skip: 'TODO');
    });

    group('with consecutive nested flag checks', () {
      setUp(() {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfFlag(EventFlag('testflag1'), isSet: [
                IfFlag(EventFlag('testflag2'), isSet: [
                  SetFlag(EventFlag('testflag1')),
                  SetFlag(EventFlag('testflag2')),
                  Dialog(spans: [DialogSpan('Hi')]),
                ])
              ]),
              IfFlag(EventFlag('testflag3'), isSet: [
                SetFlag(EventFlag('testflag3')),
                Dialog(spans: [DialogSpan('Hi 2')]),
              ])
            ]));

        asm = program.addMap(testMap);
      });

      test('consecutive flag checks', () {
        expect(asm.runEventRoutines.withoutComments(), Asm([]));
      }, skip: 'TODO');
    });

    group('with multiple run events', () {
      // TODO indices + both routines
    });

    group('with flag and value check and just dialog, generates', () {
      setUp(() {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfValue(Slot.one.position().component(Axis.y),
                  comparedTo: PositionComponent(0x200, Axis.y),
                  greaterOrEqual: [
                    IfFlag(EventFlag('testflag'), isSet: [
                      Dialog(spans: [DialogSpan('Hi')]),
                    ])
                  ])
            ]));

        asm = program.addMap(testMap);
      });

      test('checks for flag and value', () {
        expect(asm.runEventRoutines.withoutComments(), Asm([]));
      }, skip: 'TODO');
    });

    group('multiple value check branches, generates', () {
      setUp(() {
        testMap.addEvent(
            SceneId('testrun'),
            Scene([
              IfValue(Slot.one.position().component(Axis.y),
                  comparedTo: PositionComponent(0x200, Axis.y),
                  greaterOrEqual: [
                    Dialog(spans: [DialogSpan('Hi')]),
                  ],
                  less: [
                    Dialog(spans: [DialogSpan('Bye')]),
                  ])
            ]));

        asm = program.addMap(testMap);
      });

      test('both value check branches and no continue label', () {
        expect(asm.runEventRoutines.withoutComments(), Asm([]));
      }, skip: 'TODO');

      test('unique event routines which terminate', () {
        expect(asm.events.withoutComments(), Asm([]));
      });
    });

    group('with cutscenes', () {
      // TODO: ensure cutscenes are run when needed
      // TODO: ensure cutscene pointers are created
    });
  });
}

var testMapAsm = (MapAsmFixture()
      ..sprites[0x2a8] = 'Art_PalmanMan1'
      ..addObject(
          routine: 0x3c,
          direction: 0,
          dialog: 0,
          tileNumber: 0x2a8,
          x: 0x2e,
          y: 0x58)
      ..addObject(
          routine: 0x120,
          direction: 0,
          dialog: 1,
          tileNumber: 0,
          x: 0x20,
          y: 0x50)
      ..addObject(
          routine: 0x184,
          direction: 0,
          dialog: 2,
          tileNumber: 0x2a8,
          x: 0x30,
          y: 0x50))
    .toAsm()
    .toString();

class MapAsmFixture {
  var mapName = 'Test';
  var dialogTreeLabel = 'TestDialogTree';
  var sprites = <int, String>{};

  final _objects = <List<int>>[];
  int addObject(
      {required int routine,
      required int direction,
      required int dialog,
      required int tileNumber,
      required int x,
      required int y}) {
    _objects.add([routine, direction, dialog, tileNumber, x, y]);
    return _objects.length - 1;
  }

  final _areas = <List<int>>[];
  int addArea(
      {required int x,
      required int y,
      required int range,
      required int flagCheckType,
      required int flag,
      required int routine,
      required int parameter}) {
    _areas.add([x, y, range, flagCheckType, flag, routine, parameter]);
    return _areas.length - 1;
  }

  final _events = <int>[];
  void addEvent(int event) {
    _events.add(event);
  }

  Asm toAsm() => Asm.fromRaw('''Map_$mapName:
	dc.b	\$08
	dc.b	MusicID_TonoeDePon
	dc.w	\$0010
	dc.l	loc_129864
	dc.w	\$0110
	dc.l	loc_12AAF4
	dc.w	\$0210
	dc.l	loc_12BE54
	dc.w	\$0310
	dc.l	loc_12D344
	dc.w	\$FFFF
	${_spritesAsm()}
  dc.l	\$FFFE0000
	dc.l	Art_PalmanShopper1
	dc.l	\$FFFE0048
	dc.l	Art_PalmanShopper2
	dc.w	\$FFFF
	dc.b	\$FF, \$FF, \$1F, \$1F, \$1F, \$1F, \$01, \$00, \$00, \$01, \$00, \$01
	dc.l	loc_122A90
	dc.l	loc_13EECC
	dc.w	\$FFFF

; Map update
	dc.b	\$00
	dc.b	\$FF

; Map transition data
	dc.w	\$FFFF

; Map transition data 2
	dc.w	\$FFFF

; Objects
	${_objectsAsm()}
	dc.w	\$FFFF

; Treasure chests
	dc.w	\$FFFF

; Tile animations
	dc.w	\$FFFF

	dc.l	loc_13F23C
	dc.l	loc_13F3AC
	dc.l	$dialogTreeLabel

; Interaction areas
	${_areasAsm()}
	dc.w	\$FFFF

; Events
  ${_eventsAsm()}
	dc.b	\$FF

; Palettes address
	dc.l	Pal_Tonoe

	dc.b	\$00, \$00, \$00, \$00

; Map data manager
	dc.w	\$FFFF
	''');

  String _spritesAsm() {
    var asm = Asm.empty();
    for (var sprite in sprites.entries) {
      asm.add(dc.w([Word(sprite.key)]));
      asm.add(dc.l([Label(sprite.value)]));
    }
    return asm.toString();
  }

  String _objectsAsm() {
    var asm = Asm.empty();
    for (var obj in _objects) {
      var routine = obj[0];
      var direction = obj[1];
      var dialog = obj[2];
      var tileNumber = obj[3];
      var x = obj[3];
      var y = obj[4];
      asm.add(dc.w([Word(routine)]));
      asm.add(dc.b(Bytes.list([direction, dialog])));
      asm.add(dc.w([Word(tileNumber)]));
      asm.add(dc.w(Words.list([x, y])));
      asm.addNewline();
    }
    return asm.toString();
  }

  String _areasAsm() {
    var asm = Asm.empty();
    for (var area in _areas) {
      var x = area[0];
      var y = area[1];
      var range = area[2];
      var flagCheckType = area[3];
      var flag = area[4];
      var routine = area[5];
      var parameter = area[6];
      asm.add(dc.w([Word(x), Word(y)]));
      asm.add(dc.w([Word(range)]));
      asm.add(dc.b(Bytes.list([flagCheckType, flag, routine, parameter])));
      asm.addNewline();
    }
    return asm.toString();
  }

  String _eventsAsm() {
    var bytes = [for (var e in _events) Byte(e)];
    if (bytes.length.isEven) {
      // Padding
      bytes.add(Byte.zero);
    }
    return dc.b(bytes).toString();
  }
}

var tonoeAsm = r'''Map_Tonoe:
	dc.b	$08
	dc.b	MusicID_TonoeDePon
	dc.w	$0010
	dc.l	loc_11C808
	dc.w	$0111
	dc.l	loc_11DE68
	dc.w	$0213
	dc.l	loc_13E19C
	dc.l	$FFFF02A8
	dc.l	Art_PalmanMan1 ; edits for testing (temporary)
	dc.w	$02F0
	dc.l	Art_PalmanMan2
	dc.w	$0338
	dc.l	Art_PalmanMan3
	dc.w	$FFFF
	dc.b	$FF, $FF, $1F, $1F, $1F, $1F, $01, $00, $00, $01, $00, $01 ;0x0 (0x0013E048-0x0013E054, Entry count: 0x0000000C) [Unknown data]
	dc.l	loc_122A90
	dc.l	loc_13EECC
	dc.w	$FFFF

; Map update
	dc.b	$00
	dc.b	$FF

; Map transition data
	dc.b	$0A, $00
	dc.w	4
	dc.w	MapID_Motavia
	dc.b	$97, $58, $00, $00

	dc.b	$36, $00
	dc.w	5
	dc.w	MapID_Motavia
	dc.b	$97, $58, $00, $00

	dc.b	$00, $05
	dc.w	6
	dc.w	MapID_Motavia
	dc.b	$97, $58, $00, $00

	dc.b	$00, $37
	dc.w	7
	dc.w	MapID_Motavia
	dc.b	$97, $58, $00, $00

	dc.w	$FFFF

; Map transition data 2
	dc.b	$1F, $0A
	dc.w	9
	dc.w	MapID_TonoeStorageRoom
	dc.b	$1E, $26, $04, $04

	dc.b	$2D, $14
	dc.w	9
	dc.w	MapID_TonoeGryzHouse
	dc.b	$1E, $26, $04, $04

	dc.b	$1D, $26
	dc.w	9
	dc.w	MapID_TonoeHouse1
	dc.b	$1E, $26, $04, $04

	dc.b	$1D, $2C
	dc.w	9
	dc.w	MapID_TonoeHouse2
	dc.b	$1E, $26, $04, $04

	dc.b	$13, $28
	dc.w	9
	dc.w	MapID_TonoeInn
	dc.b	$16, $26, $04, $04

	dc.w	$FFFF

; Objects
	dc.w	$3C
	dc.b	$00, $04
	dc.w	$2A8
	dc.w	$2E, $58

	dc.w	$44
	dc.b	$00, $07
	dc.w	$338
	dc.w	$34, $46

	dc.w	$3C
	dc.b	$00, $09
	dc.w	$2A8
	dc.w	$42, $50

	dc.w	$3C
	dc.b	$00, $0A
	dc.w	$2F0
	dc.w	$54, $5C

	dc.w	$3C
	dc.b	$00, $0B
	dc.w	$2A8
	dc.w	$60, $3E

	dc.w	$60
	dc.b	$00, $0C
	dc.w	$2F0
	dc.w	$50, $4C

	dc.w	$58
	dc.b	$04, $0D
	dc.w	$2A8
	dc.w	$2A, $14

	dc.w	$FFFF

; Treasure chests
	dc.w	$FFFF

; Tile animations
	dc.w	$FFFF

	dc.l	loc_13F23C
	dc.l	loc_13F3AC
	dc.l	DialogueTree7

; Interaction areas
	dc.w	$4C, $48
	dc.w	9
	dc.b	0, 0, 5, 9

	dc.w	$4C, $54
	dc.w	9
	dc.b	0, 0, 5, $A

	dc.w	$54, $54
	dc.w	9
	dc.b	0, 0, 5, $B

	dc.w	$48, $48
	dc.w	9
	dc.b	0, 0, 0, $74

	dc.w	$50, $48
	dc.w	9
	dc.b	0, 0, 0, $75

	dc.w	$54, $48
	dc.w	9
	dc.b	0, 0, 0, $76

	dc.w	$58, $48
	dc.w	9
	dc.b	0, 0, 0, $77

	dc.w	$5C, $48
	dc.w	9
	dc.b	0, 0, 0, $78

	dc.w	$44, $54
	dc.w	9
	dc.b	0, 0, 0, $79

	dc.w	$48, $54
	dc.w	9
	dc.b	0, 0, 0, $7A

	dc.w	$50, $54
	dc.w	9
	dc.b	0, 0, 0, $7B

	dc.w	$58, $54
	dc.w	9
	dc.b	0, 0, 0, $7C

	dc.w	$FFFF

; Events
	dc.b	$00
	dc.b	$FF

; Palettes address
	dc.l	Pal_Tonoe

	dc.b	$00, $00, $00, $00

; Map data manager
	dc.w	$FFFF
	''';
