import 'dart:math';

import 'package:rune/asm/asm.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/map.dart';
import 'package:rune/generator/scene.dart';
import 'package:rune/model/conditional.dart';
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
    program = Program(eventIndexOffset: Word(0));
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
        spec: Npc(Sprite.PalmanMan1, FaceDownLegsHiddenNoInteraction()),
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
          dc.w(['2d8'.hex.toWord]),
          dc.l([Constant('Art_PalmanWoman1')]),
          dc.w(['320'.hex.toWord]),
          dc.l([Constant('Art_PalmanMan2')]),
        ]));
  });

  test('sprite uses the max needed vram tile width when reused', () {
    testMap.addObject(MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDownLegsHiddenNoInteraction()),
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
          dc.l([Constant('Art_PalmanMan2')]),
        ]));
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

  test('objects use position divided by 8', () {}, skip: 'todo');

  test('objects use correct facing direction', () {}, skip: 'todo');

  test('objects with no dialog still terminate dialog', () {
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.PalmanMan1, FaceDown()));
    obj.onInteract = Scene.forNpcInteractionWith(obj, []);

    testMap.addObject(obj);

    var asm = program.addMap(testMap);

    expect(asm.dialog.withoutComments().trim().tail(1), dc.b([Byte(0xff)]));
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
            Dialog(spans: [DialogSpan('Hello!')]).toAsm(),
            terminateDialog(),
            newLine(),
            comment(r'$01'),
            Dialog(spans: [DialogSpan('Goodbye!')]).toAsm(),
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

    test('does not product event code', () {
      expect(mapAsm.events, Asm.empty());
      expect(program.eventPointers, Asm.empty());
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

      SceneAsmGenerator.forInteraction(testMap, npc1, SceneId('Test_npc1'),
          comparisonDialogTree, comparisonEventAsm, testEventRoutines)
        ..runEventFromInteraction()
        ..scene(npc1.onInteract)
        ..finish(appendNewline: true);

      SceneAsmGenerator.forInteraction(testMap, npc2, SceneId('Test_npc2'),
          comparisonDialogTree, comparisonEventAsm, testEventRoutines)
        ..runEventFromInteraction()
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

    test('event asm has newline between events and cutscenes', () {
      var cutsceneNpc = MapObject(
          id: 'CutsceneNpc',
          startPosition: Position(0x1d0, 0x2e0),
          spec: AlysWaiting());
      cutsceneNpc.onInteract = Scene.forNpcInteractionWith(cutsceneNpc, [
        FadeOut(),
        Dialog(spans: [DialogSpan('Test!')]),
      ]);

      testMap.addObject(cutsceneNpc);

      var mapAsm = program.addMap(testMap);

      print(mapAsm.events);
      print(program.cutscenesPointers);
      print(program.eventPointers);
    });
  });

  group('npc interaction events', () {
    group('in dialog', () {
      test('plays sound', () {
        var obj = MapObject(
            startPosition: Position('1e0'.hex, '2e0'.hex),
            spec: Npc(Sprite.PalmanMan1, FaceDown()),
            onInteract: Scene([
              PlaySound(Sound.surprise),
            ]));
        testMap.addObject(obj);

        var asm = program.addMap(testMap);

        expect(
            asm.dialog.withoutComments().trim(),
            Asm([
              dc.b([Byte(0xf2), Byte(3)]),
              dc.b([Constant('SFXID_Surprise')]),
              dc.b([Byte(0xff)]),
            ]));
      });
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

      expect(map.objects, hasLength(1));

      var obj = map.objects.first;

      expect(obj.onInteract,
          Scene([Dialog(speaker: obj, spans: DialogSpan.parse('Hi there!'))]));
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

      expect(map.objects, hasLength(1));

      var obj = map.objects.first;

      expect(
          obj.onInteract,
          Scene([
            IfFlag(toEventFlag(Byte(0x0b)), isUnset: [
              Dialog(speaker: obj, spans: DialogSpan.parse('Hi there!'))
            ], isSet: [
              Dialog(speaker: obj, spans: DialogSpan.parse('Bye!'))
            ])
          ]));
    });
  });
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

var testMapAsm = r'''Map_Test:
	dc.b	$08
	dc.b	MusicID_TonoeDePon
	dc.l	$FFFF02A8
	dc.l	Art_PalmanMan1
	dc.w	$FFFF
	dc.b	$FF, $FF, $1F, $1F, $1F, $1F, $01, $00, $00, $01, $00, $01
	dc.l	loc_122A90
	dc.l	loc_13EECC
	dc.w	$FFFF

; Map update
	dc.b	$00
	dc.b	$FF

; Map transition data
	dc.w	$FFFF

; Map transition data 2
	dc.w	$FFFF

; Objects
	dc.w	$3C
	dc.b	$00, $00
	dc.w	$2A8
	dc.w	$2E, $58

	dc.w	$FFFF

; Treasure chests
	dc.w	$FFFF

; Tile animations
	dc.w	$FFFF

	dc.l	loc_13F23C
	dc.l	loc_13F3AC
	dc.l	TestDialogTree

; Interaction areas
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
