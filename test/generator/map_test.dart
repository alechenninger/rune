import 'dart:math';

import 'package:rune/asm/asm.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/scene.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  late GameMap testMap;
  late Program program;

  setUp(() {
    testMap = GameMap(MapId.Test);
    program = Program(eventIndexOffset: Word(0));
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

  test('multiples sprites tile numbers are separated by 0x48', () {
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

  test('sprites are reused for multiple objects of the same sprite', () {
    testMap.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    testMap.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

    testMap.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ])));

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

  test('objects use position divided by 8', () {});

  test('objects use correct facing direction', () {});

  group('objects with dialog', () {
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
    });

    test('objects with dialog produce dialog asm', () {
      var mapAsm = program.addMap(testMap);

      expect(
          mapAsm.dialog,
          Asm([
            comment(r'$00'),
            Dialog(spans: [DialogSpan('Hello!')]).toAsm(),
            terminateDialog(),
            newLine(),
            comment(r'$01'),
            Dialog(spans: [DialogSpan('Goodbye!')]).toAsm(),
            terminateDialog(),
            newLine()
          ]));
    });

    test('objects with interaction refer to correct dialog offset', () {
      var mapAsm = program.addMap(testMap);

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

      var mapAsm = program.addMap(testMap);

      expect(
          mapAsm.dialog,
          Asm([
            comment(r'$00'),
            dc.b(Bytes.of(0xF3)),
            Dialog(spans: [DialogSpan('Hello!')]).toAsm(),
            terminateDialog(),
            newLine(),
          ]));
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

      var comparisonDialogTree = DialogTree();
      var comparisonEventAsm = EventAsm.empty();

      comparisonEventAsm.add(setLabel('Event_GrandCross_Test_npc1'));
      comparisonDialogTree
          .add(DialogAsm([runEvent(Word(0)), terminateDialog()]));

      SceneAsmGenerator.forInteraction(testMap, npc1, SceneId('Test_npc1'),
          comparisonDialogTree, comparisonEventAsm,
          inEvent: true)
        ..scene(npc1.onInteract)
        ..finish();

      comparisonEventAsm.addNewline();

      comparisonEventAsm.add(setLabel('Event_GrandCross_Test_npc2'));
      comparisonDialogTree
          .add(DialogAsm([runEvent(Word(1)), terminateDialog()]));

      SceneAsmGenerator.forInteraction(testMap, npc2, SceneId('Test_npc2'),
          comparisonDialogTree, comparisonEventAsm,
          inEvent: true)
        ..scene(npc2.onInteract)
        ..finish();

      expect(mapAsm.events.trim(), comparisonEventAsm);
      expect(mapAsm.dialog, comparisonDialogTree.toAsm());
    });

    test('produce event pointers', () {
      program.addMap(testMap);

      expect(
          program.eventPointers,
          Asm([
            dc.l([Label('Event_GrandCross_Test_npc1')], comment: r'$0000'),
            dc.l([Label('Event_GrandCross_Test_npc2')], comment: r'$0001')
          ]));
    });
  });
}
