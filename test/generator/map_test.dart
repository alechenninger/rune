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
  late GameMap piata;
  var generator = AsmGenerator();

  setUp(() {
    piata = GameMap(MapId.Piata);
  });

  test('map model generates asm', () {
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ]));

    piata.addObject(obj);

    var mapAsm = generator.mapToAsm(piata, AsmContext.fresh());

    expect(
        mapAsm.objects.trim(),
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
          Dialog(spans: [Span('Hello world!')])
        ]));

    piata.addObject(obj);

    var mapAsm = generator.mapToAsm(piata, AsmContext.fresh());

    expect(
        mapAsm.objects.first,
        Asm([
          dc.w(['38'.hex.word])
        ]).first);
  });

  test('sprites are defined', () {
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ]));

    piata.addObject(obj);

    var mapAsm = generator.mapToAsm(piata, AsmContext.fresh());

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.word]),
          dc.l([Constant('Art_PalmanMan1')])
        ]));
  });

  test('multiples sprites tile numbers are separated by 0x48', () {
    piata.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    piata.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanWoman1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    piata.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan2, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    var mapAsm = generator.mapToAsm(piata, AsmContext.fresh());

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
    piata.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    piata.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanWoman1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    piata.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan2, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    var mapAsm = generator.mapToAsm(piata, AsmContext.fresh());

    // todo: this is kind of brittle
    expect(mapAsm.objects[2], dc.w(['2d0'.hex.word]));
    expect(mapAsm.objects[7], dc.w(['318'.hex.word]));
    expect(mapAsm.objects[12], dc.w(['360'.hex.word]));
  });

  test('sprites are reused for multiple objects of the same sprite', () {
    piata.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    piata.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    piata.addObject(MapObject(
        startPosition: Position('200'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    var mapAsm = generator.mapToAsm(piata, AsmContext.fresh());

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.word]),
          dc.l([Constant('Art_PalmanMan1')]),
        ]));

    // todo: this is kind of brittle
    expect(mapAsm.objects[2], dc.w(['2d0'.hex.word]));
    expect(mapAsm.objects[7], dc.w(['2d0'.hex.word]));
    expect(mapAsm.objects[12], dc.w(['2d0'.hex.word]));
  });

  test('objects use position divided by 8', () {});

  test('objects use correct facing direction', () {});

  group('objects with dialog', () {
    setUp(() {
      piata.addObject(MapObject(
          startPosition: Position('1e0'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanMan1, FaceDown()),
          onInteract: Scene([
            Dialog(spans: [Span('Hello!')])
          ])));

      piata.addObject(MapObject(
          startPosition: Position('1f0'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanWoman1, FaceDown()),
          onInteract: Scene([
            Dialog(spans: [Span('Goodbye!')])
          ])));
    });

    test('objects with dialog produce dialog asm', () {
      var mapAsm = generator.mapToAsm(piata, AsmContext.fresh());

      expect(
          mapAsm.dialog,
          Asm([
            comment(r'$00'),
            Dialog(spans: [Span('Hello!')]).toAsm(),
            terminateDialog(),
            newLine(),
            comment(r'$01'),
            Dialog(spans: [Span('Goodbye!')]).toAsm(),
            terminateDialog(),
            newLine()
          ]));
    });

    test('objects with interaction refer to correct dialog offset', () {
      var mapAsm = generator.mapToAsm(piata, AsmContext.fresh());

      expect(
          mapAsm.objects[1],
          Asm([
            dc.b([Constant('FacingDir_Down'), 0.byte]),
          ]));
      expect(
          mapAsm.objects[6],
          Asm([
            dc.b([Constant('FacingDir_Down'), 1.byte]),
          ]));
    });
  });

  group('objects with events', () {
    var npc1Scene = Scene([
      Dialog(spans: [Span('Hello!')]),
      Pause(Duration(seconds: 1)),
    ]);

    var npc2Scene = Scene([
      Dialog(spans: [Span('Goodbye!')]),
      Pause(Duration(seconds: 2)),
    ]);

    setUp(() {
      piata.addObject(MapObject(
          id: 'npc1',
          startPosition: Position('1e0'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanMan1, FaceDown()),
          onInteract: npc1Scene));

      piata.addObject(MapObject(
          id: 'npc2',
          startPosition: Position('1f0'.hex, '2e0'.hex),
          spec: Npc(Sprite.PalmanWoman1, FaceDown()),
          onInteract: npc2Scene));
    });

    test('produce event code', () {
      var mapAsm = generator.mapToAsm(piata, AsmContext.fresh());

      var comparisonCtx = AsmContext.forDialog(EventState());
      var comparisonDialogTree = DialogTree();

      var scene1Asm = npc1Scene.toAsm(generator, comparisonCtx,
          dialogTree: comparisonDialogTree, id: SceneId('Piata_npc1'));
      comparisonCtx.startDialogInteraction();
      var scene2Asm = npc2Scene.toAsm(generator, comparisonCtx,
          dialogTree: comparisonDialogTree, id: SceneId('Piata_npc2'));

      expect(mapAsm.events,
          Asm([scene1Asm.event, newLine(), scene2Asm.event, newLine()]));
    });

    test('produce event pointers', () {
      var mapAsm = generator.mapToAsm(piata, AsmContext.fresh());

      var comparisonCtx = AsmContext.forDialog(EventState());
      var comparisonDialogTree = DialogTree();

      var scene1Asm = npc1Scene.toAsm(generator, comparisonCtx,
          dialogTree: comparisonDialogTree, id: SceneId('Piata_npc1'));
      comparisonCtx.startDialogInteraction();
      var scene2Asm = npc2Scene.toAsm(generator, comparisonCtx,
          dialogTree: comparisonDialogTree, id: SceneId('Piata_npc2'));

      print(mapAsm.eventPointers);

      expect(
          mapAsm.eventPointers,
          Asm([
            scene1Asm.eventPointers,
            scene2Asm.eventPointers,
          ]));
    });
  });
}
