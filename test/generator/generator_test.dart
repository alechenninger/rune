import 'package:rune/asm/asm.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

main() {
  late GameMap map;

  setUp(() {
    map = GameMap(MapId.Test);
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
      /* ChangeMap() */
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().head(9),
        Asm([
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          move.w(Constant('MapID_ChazHouse').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Aiedo').i, (Field_Map_Index_2).w),
          move.w(0x44.i, (Map_Start_X_Pos).w),
          move.w(0x38.i, (Map_Start_Y_Pos).w),
          move.w(0.i, (Map_Start_Facing_Dir).w),
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
          bclr(3.i, (Map_Load_Flags).w),
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
      /* ChangeMap(showField: true) */
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().head(9),
        Asm([
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          // not sure if this is needed here?
          // moveq	#$E, d0
          // jsr	(DoMapUpdateLoop).l
          // i think this was just to have a little delay for music to play
          // i wonder why this didnt do vintprepareloop
          jsr(Label('Pal_FadeIn').l),
          jsr(Label('VInt_Prepare').l),
          move.w(Constant('MapID_ChazHouse').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Aiedo').i, (Field_Map_Index_2).w),
          move.w(0x44.i, (Map_Start_X_Pos).w),
          move.w(0x38.i, (Map_Start_Y_Pos).w),
          move.w(0.i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          jsr(Label('RefreshMap').l),
        ]));
  });

  test('fades in field after map if scene ends', () {
    var scene = Scene([
      FadeOut(),
      /* ChangeMap() */
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().head(9),
        Asm([
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          move.w(Constant('MapID_ChazHouse').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Aiedo').i, (Field_Map_Index_2).w),
          move.w(0x44.i, (Map_Start_X_Pos).w),
          move.w(0x38.i, (Map_Start_Y_Pos).w),
          move.w(0.i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          jsr(Label('RefreshMap').l),
          jsr(Label('Pal_FadeIn').l),
        ]));
  });

  test('fades in field does not additionally refresh map after change map', () {
    var scene = Scene([
      FadeOut(),
      /* ChangeMap(), */
      FadeInField(),
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().head(9),
        Asm([
          // this clears palette
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          move.w(Constant('MapID_ChazHouse').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Aiedo').i, (Field_Map_Index_2).w),
          move.w(0x44.i, (Map_Start_X_Pos).w),
          move.w(0x38.i, (Map_Start_Y_Pos).w),
          move.w(0.i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          // this loads the map palette
          jsr(Label('RefreshMap').l),
          // this fades it in somehow
          jsr(Label('Pal_FadeIn').l),
        ]));
  });

  test('changes dialog tree after changing map', () {
    var dialog1 = Dialog(spans: [DialogSpan('map 1')]);
    var map2 = GameMap(MapId.Test_Part2);
    var dialog2 = Dialog(spans: [DialogSpan('map 2')]);

    var scene = Scene([
      dialog1,
      FadeOut(),
      /* ChangeMap(), */
      FadeInField(),
      dialog2,
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().head(9),
        Asm([
          getAndRunDialog(0.i),
          // this clears palette
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          move.w(Constant('MapID_ChazHouse').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Aiedo').i, (Field_Map_Index_2).w),
          move.w(0x44.i, (Map_Start_X_Pos).w),
          move.w(0x38.i, (Map_Start_Y_Pos).w),
          move.w(0.i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          // this loads the map palette
          jsr(Label('RefreshMap').l),
          // this fades it in somehow
          jsr(Label('Pal_FadeIn').l),
          getAndRunDialog(0.i),
          rts
        ]));

    var expectedTrees = DialogTrees();
    expectedTrees.forMap(MapId.Test).add(dialog1.toAsm());
    expectedTrees.forMap(MapId.Test_Part2).add(dialog2.toAsm());
    expect(program.dialogTrees, expectedTrees);
  });
}
