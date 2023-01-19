import 'package:rune/asm/asm.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/conditional.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

main() {
  late GameMap map;
  late GameMap map2;

  setUp(() {
    map = GameMap(MapId.Test);
    map2 = GameMap(MapId.Test_Part2);
  });

  test('cutscene pointers are offset by 0x8000', () {
    var program = Program(cutsceneIndexOffset: Word(0));
    var obj = MapObject(startPosition: Position(0, 0), spec: AlysWaiting());
    obj.onInteract = Scene.forNpcInteraction([
      FadeOut(),
      Dialog(spans: DialogSpan.parse('Hello world')),
      FadeInField(),
    ]);
    map.addObject(obj);
    program.addMap(map);
    var mapAsm = program.maps[MapId.Test];
    expect(
        mapAsm?.dialog.withoutComments().head(3),
        Asm([
          dc.b([Byte(0xf6)]),
          dc.w([Word(0x8000)]),
          dc.b([Byte(0xff)])
        ]));
  });

  test('after fading out, fades in automatically before dialog', () {
    var scene = Scene([
      FadeOut(),
      Dialog(speaker: alys, spans: [DialogSpan('Hi')])
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().head(2),
        Asm([
          jsr(Label('InitVRAMAndCRAM').l),
          jsr(Label('Pal_FadeIn').l),
          // get and run dialog
        ]));
  });

  test('after fading out, fades in automatically before panel', () {
    var scene = Scene([FadeOut(), ShowPanel(PrincipalPanel.shayAndAlys)]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().head(2),
        Asm([
          jsr(Label('InitVRAMAndCRAM').l),
          jsr(Label('Pal_FadeIn').l),
          // show panel
        ]));
  });

  test('after fading out, does not fade in before map change', () {
    var scene = Scene([
      FadeOut(),
      LoadMap(
          map: map2,
          startingPosition: Position(0x220, 0x1C0),
          facing: Direction.down)
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().head(9),
        Asm([
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          move.w(Constant('MapID_Test_Part2').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Test').i, (Field_Map_Index_2).w),
          move.w(0x44.i, (Map_Start_X_Pos).w),
          move.w(0x38.i, (Map_Start_Y_Pos).w),
          move.w(Constant('FacingDir_Down').i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          jsr(Label('RefreshMap').l),
        ]));
  });

  test('after fading out, fade in field needs to refreshmap', () {
    var scene = Scene([FadeOut(), FadeInField()]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene);

    expect(
        asm.event.withoutComments().withoutEmptyLines(),
        Asm([
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          bset(3.i, (Map_Load_Flags).w),
          jsr(Label('RefreshMap').l),
          jsr(Label('Pal_FadeIn').l),
        ]));
  });

  test('fades in before map change if showField: true', () {
    // this is used for example in Event_MissingStudentInBed
    // however our model wouldn't let you mix in setting an event flag
    // after the fade in,
    // unless we added that as an option in ChangeMap
    // but you could do that after the fade out event I think
    var scene = Scene([
      FadeOut(),
      LoadMap(
          map: map2,
          startingPosition: Position(0x200, 0x200),
          facing: Direction.down,
          showField: true),
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().head(11),
        Asm([
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          // not sure if this is needed here?
          // moveq	#$E, d0
          // jsr	(DoMapUpdateLoop).l
          // i think this was just to have a little delay for music to play
          // i wonder why this didnt do vintprepareloop
          jsr(Label('Pal_FadeIn').l),
          jsr(Label('VInt_Prepare').l),
          move.w(Constant('MapID_Test_Part2').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Test').i, (Field_Map_Index_2).w),
          move.w(0x40.i, (Map_Start_X_Pos).w),
          move.w(0x40.i, (Map_Start_Y_Pos).w),
          move.w(Constant('FacingDir_Down').i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          jsr(Label('RefreshMap').l),
        ]));
  });

  test('fades in field after map if scene ends', () {
    var scene = Scene([
      FadeOut(),
      LoadMap(
          map: map2,
          startingPosition: Position(0x200, 0x200),
          facing: Direction.down)
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().trim(),
        Asm([
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          move.w(Constant('MapID_Test_Part2').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Test').i, (Field_Map_Index_2).w),
          move.w(0x40.i, (Map_Start_X_Pos).w),
          move.w(0x40.i, (Map_Start_Y_Pos).w),
          move.w(Constant('FacingDir_Down').i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          jsr(Label('RefreshMap').l),
          jsr(Label('Pal_FadeIn').l),
        ]));
  });

  test('fades in field does not additionally refresh map after change map', () {
    var scene = Scene([
      FadeOut(),
      LoadMap(
          map: map2,
          startingPosition: Position(0x200, 0x200),
          facing: Direction.down),
      FadeInField(),
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().trim(),
        Asm([
          // this clears palette
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          move.w(Constant('MapID_Test_Part2').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Test').i, (Field_Map_Index_2).w),
          move.w(0x40.i, (Map_Start_X_Pos).w),
          move.w(0x40.i, (Map_Start_Y_Pos).w),
          move.w(Constant('FacingDir_Down').i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          // this loads the map palette
          jsr(Label('RefreshMap').l),
          // this fades it in somehow
          jsr(Label('Pal_FadeIn').l),
        ]));
  });

  test('changes dialog tree after changing map', () {
    var dialog1 = Dialog(speaker: alys, spans: [DialogSpan('map 1')]);
    var dialog2 = Dialog(speaker: alys, spans: [DialogSpan('map 2')]);

    var scene = Scene([
      dialog1,
      FadeOut(),
      LoadMap(
          map: map2,
          startingPosition: Position(0x200, 0x200),
          facing: Direction.down),
      FadeInField(),
      dialog2,
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().trim(),
        Asm([
          getAndRunDialog3(Byte.zero.i),
          // this clears palette
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          move.w(Constant('MapID_Test_Part2').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Test').i, (Field_Map_Index_2).w),
          move.w(0x40.i, (Map_Start_X_Pos).w),
          move.w(0x40.i, (Map_Start_Y_Pos).w),
          move.w(Constant('FacingDir_Down').i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          // this loads the map palette
          jsr(Label('RefreshMap').l),
          // this fades it in somehow
          jsr(Label('Pal_FadeIn').l),
          getAndRunDialog3(Byte.zero.i),
        ]));

    var expectedTrees = DialogTrees();
    expectedTrees.forMap(MapId.Test).add(DialogAsm([
          dc.b(Bytes.list([0xf4, 0x2])),
          dc.b(Bytes.ascii('map 1')),
          dc.b([Byte(0xff)]),
        ]));
    expectedTrees.forMap(MapId.Test_Part2).add(DialogAsm([
          dc.b(Bytes.list([0xf4, 0x2])),
          dc.b(Bytes.ascii('map 2')),
          dc.b([Byte(0xff)]),
        ]));
    expect(program.dialogTrees.withoutComments(), expectedTrees);
  });

  test('custom event flags produce constants', () {
    var program = Program();
    program.addScene(SceneId('test'), Scene([SetFlag(EventFlag('Test000'))]),
        startingMap: map);
    program.addMap(map
      ..addObject(MapObject(
          startPosition: Position(0x100, 0x100),
          spec: Npc(
              Sprite.PalmanWoman1,
              FaceDown(
                  onInteract: Scene([
                IfFlag(EventFlag('Test001'),
                    isSet: [Pause(Duration(seconds: 1))])
              ]))))));

    expect(program.extraConstants(), Asm.fromRaw(r'''EventFlag_Test000 = $00 
EventFlag_Test001 = $01'''));
  });
}
