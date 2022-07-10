import 'dart:math';

import 'package:rune/asm/asm.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/scene.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  late GameMap testMap;
  var generator = AsmGenerator();

  setUp(() {
    testMap = GameMap(MapId.Test);
  });

  test('map model generates asm', () {
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [DialogSpan('Hello world!')])
        ]));

    testMap.addObject(obj);

    var mapAsm = generator.mapToAsm(testMap, AsmContext.fresh());

    expect(
        mapAsm.objects.trim().withoutComments(),
        Asm([
          dc.w(['38'.hex.word]),
          dc.b([Constant('FacingDir_Down'), 0.byte]),
          dc.w(['2D0'.hex.word]),
          dc.w([
            '3c'.hex.word,
            '5c'.hex.word,
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

    var mapAsm = generator.mapToAsm(testMap, AsmContext.fresh());

    expect(
        mapAsm.objects.withoutComments().first,
        Asm([
          dc.w(['38'.hex.word])
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

    var mapAsm = generator.mapToAsm(testMap, AsmContext.fresh());

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.word]),
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

    var mapAsm = generator.mapToAsm(testMap, AsmContext.fresh());

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.word]),
          dc.l([Constant('Art_PalmanMan1')]),
          dc.w(['318'.hex.word]),
          dc.l([Constant('Art_PalmanWoman1')]),
          dc.w(['360'.hex.word]),
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

    var mapAsm = generator.mapToAsm(testMap, AsmContext.fresh());
    var objectsAsm = mapAsm.objects.withoutComments();
    // todo: this is kind of brittle
    expect(objectsAsm[2], dc.w(['2d0'.hex.word]));
    expect(objectsAsm[7], dc.w(['318'.hex.word]));
    expect(objectsAsm[12], dc.w(['360'.hex.word]));
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

    var mapAsm = generator.mapToAsm(testMap, AsmContext.fresh());

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.word]),
          dc.l([Constant('Art_PalmanMan1')]),
        ]));

    // todo: this is kind of brittle
    var objectsAsm = mapAsm.objects.withoutComments();
    expect(objectsAsm[2], dc.w(['2d0'.hex.word]));
    expect(objectsAsm[7], dc.w(['2d0'.hex.word]));
    expect(objectsAsm[12], dc.w(['2d0'.hex.word]));
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
      var mapAsm = generator.mapToAsm(testMap, AsmContext.fresh());

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
      var mapAsm = generator.mapToAsm(testMap, AsmContext.fresh());

      expect(
          mapAsm.objects.withoutComments()[1],
          Asm([
            dc.b([Constant('FacingDir_Down'), 0.byte]),
          ]));
      expect(
          mapAsm.objects.withoutComments()[6],
          Asm([
            dc.b([Constant('FacingDir_Down'), 1.byte]),
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

      var mapAsm = generator.mapToAsm(testMap, AsmContext.fresh());

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

    test('produce event code with npc facing player', () {
      var mapAsm = generator.mapToAsm(testMap, AsmContext.fresh());

      var comparisonCtx = AsmContext.forDialog(EventState());
      var comparisonDialogTree = DialogTree();

      comparisonCtx.startDialogInteractionWith(npc1);
      var scene1Asm = npc1.onInteract.toAsm(generator, comparisonCtx,
          dialogTree: comparisonDialogTree, id: SceneId('Test_npc1'));

      comparisonCtx.startDialogInteractionWith(npc2);
      var scene2Asm = npc2.onInteract.toAsm(generator, comparisonCtx,
          dialogTree: comparisonDialogTree, id: SceneId('Test_npc2'));

      expect(mapAsm.events,
          Asm([scene1Asm.event, newLine(), scene2Asm.event, newLine()]));
    });

    test('produce event pointers', () {
      var ctx = AsmContext.fresh();
      generator.mapToAsm(testMap, ctx);

      var comparisonCtx = AsmContext.forDialog(EventState());
      var comparisonDialogTree = DialogTree();

      comparisonCtx.startDialogInteractionWith(npc1);
      npc1Scene.toAsm(generator, comparisonCtx,
          dialogTree: comparisonDialogTree, id: SceneId('Test_npc1'));
      comparisonCtx.startDialogInteractionWith(npc2);
      npc2Scene.toAsm(generator, comparisonCtx,
          dialogTree: comparisonDialogTree, id: SceneId('Test_npc2'));

      print(ctx.eventPointers);

      expect(ctx.eventPointers, comparisonCtx.eventPointers);
    });
  });
}
