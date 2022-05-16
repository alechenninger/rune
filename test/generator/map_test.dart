import 'package:rune/asm/asm.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  var map = Piata();
  var generator = AsmGenerator();

  test('map model generates asm', () {
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.palmanMan1, FacingDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ]));

    map.addObject(obj);

    var mapAsm = generator.mapToAsm(map, AsmContext.fresh());

    expect(
        mapAsm.objects,
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
        spec: Npc(Sprite.palmanMan1, FacingDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ]));

    map.addObject(obj);

    var mapAsm = generator.mapToAsm(map, AsmContext.fresh());

    expect(
        mapAsm.objects.first,
        Asm([
          dc.w(['38'.hex.word])
        ]).first);
  });

  test('sprites are defined', () {
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.palmanMan1, FacingDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ]));

    map.addObject(obj);

    var mapAsm = generator.mapToAsm(map, AsmContext.fresh());

    expect(
        mapAsm.sprites,
        Asm([
          dc.w(['2d0'.hex.word]),
          dc.l([Constant('Art_PalmanMan1')])
        ]));
  });

  test('sprites tile numbers are separated by 0x48', () {
    map.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.palmanMan1, FacingDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    map.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.palmanWoman1, FacingDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    map.addObject(MapObject(
        startPosition: Position('1f0'.hex, '2e0'.hex),
        spec: Npc(Sprite.palmanMan2, FacingDown()),
        onInteract: Scene([
          Dialog(spans: [Span('Hello world!')])
        ])));

    var mapAsm = generator.mapToAsm(map, AsmContext.fresh());

    expect([
      mapAsm.sprites[0],
      mapAsm.sprites[2],
      mapAsm.sprites[4]
    ], [
      dc.w(['2d0'.hex.word]),
      dc.w(['318'.hex.word]),
      dc.w(['360'.hex.word]),
    ]);
  });

  test('sprites are referred to by their corresponding objects', () {});

  test('sprites are reused for multiple objects of the same sprite', () {});

  test('objects use position divided by 8', () {});

  test('objects use correct facing direction', () {});

  group('objects with dialog', () {
    test('objects with dialog produce dialog asm', () {});

    test('objects with dialog refer to correct dialog offset', () {});
  });

  group('objects with events', () {
    test('produce event code', () {});

    test('refer to events at the right ptr', () {});
  });
}
