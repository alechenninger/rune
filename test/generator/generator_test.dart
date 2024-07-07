import 'package:rune/asm/events.dart';
import 'package:rune/asm/text.dart';
import 'package:rune/generator/cutscenes.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

main() {
  late GameMap map;
  late GameMap map2;

  setUp(() {
    map = GameMap(MapId.Test);
    map2 = GameMap(MapId.Test_Part2);
  });

  test('cutscene pointers are offset by 0x8000', () {
    var program = Program(cutscenePointers: EventPointers.empty());
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
        mapAsm?.dialog?.withoutComments().head(3),
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

  test('cutscene scene sets z bit before return when map needs reload', () {
    var scene = Scene([
      FadeOut(),
      Dialog(speaker: alys, spans: [DialogSpan('Hi')])
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().tail(1),
        Asm([
          moveq(0.i, d0),
        ]));
  });

  test('cutscene scene unsets z bit before return when map should not reload',
      () {
    var scene = Scene([
      FadeOut(),
      Dialog(speaker: alys, spans: [DialogSpan('Hi')]),
      FadeInField()
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().tail(1),
        Asm([
          moveq(1.i, d0),
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

  test('fade during cutscene then panel fades in automatically', () {
    var scene = Scene([
      FadeOut(),
      ShowPanel(PrincipalPanel.shayAndAlys),
      FadeOut(),
      ShowPanel(PrincipalPanel.alysGrabsPrincipal),
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().trim().head(10),
        Asm([
          jsr(Label('InitVRAMAndCRAM').l),
          jsr(Label('Pal_FadeIn').l),
          move.w(0x1.toWord.i, d0),
          jsr(Label('Panel_Create').l),
          dmaPlanesVInt(),
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          jsr(Label('Panel_DestroyAll').l),
          jsr(Label('Pal_FadeIn').l),
          move.w(0x6.toWord.i, d0),
          jsr(Label('Panel_Create').l),
        ]));
  });

  test('fade during cutscene then dialog fades in automatically with cram init',
      () {
    var scene = Scene([
      FadeOut(),
      ShowPanel(PrincipalPanel.shayAndAlys),
      FadeOut(),
      Dialog.parse('Hi', speaker: alys),
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().trim().head(12),
        Asm([
          jsr(Label('InitVRAMAndCRAM').l),
          jsr(Label('Pal_FadeIn').l),
          move.w(0x1.toWord.i, d0),
          jsr(Label('Panel_Create').l),
          dmaPlanesVInt(),
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          jsr(Label('Panel_DestroyAll').l),
          jsr(Label('InitVRAMAndCRAMAfterFadeOut').l),
          jsr(Label('Pal_FadeIn').l),
          move.b(1.i, Constant('Render_Sprites_In_Cutscenes').w),
          moveq(0.toByte.i, d0),
          jsr(Label('Event_GetAndRunDialogue3').l),
        ]));
  });

  test('fade during cutscene then panel then dialog adjusts palette', () {
    var scene = Scene([
      FadeOut(),
      ShowPanel(PrincipalPanel.shayAndAlys),
      FadeOut(),
      ShowPanel(PrincipalPanel.alysGrabsPrincipal),
      Dialog.parse('Hi', speaker: alys),
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().trim().head(18),
        Asm([
          jsr(Label('InitVRAMAndCRAM').l),
          jsr(Label('Pal_FadeIn').l),
          move.w(0x1.toWord.i, d0),
          jsr(Label('Panel_Create').l),
          dmaPlanesVInt(),
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          jsr(Label('Panel_DestroyAll').l),
          jsr(Label('Pal_FadeIn').l),
          move.w(0x6.toWord.i, d0),
          jsr(Label('Panel_Create').l),
          dmaPlanesVInt(),
          lea(Label('Pal_Init_Line_3').l, a0),
          lea(Label('Palette_Line_3').w, a1),
          move.w(0xf.i, d7),
          trap(1.i),
          move.b(1.i, Constant('Render_Sprites_In_Cutscenes').w),
          moveq(0.toByte.i, d0),
          jsr(Label('Event_GetAndRunDialogue3').l),
        ]));
  });

  test('fade during cutscene then panel then dialog adjusts palette only once',
      () {
    var scene = Scene([
      FadeOut(),
      ShowPanel(PrincipalPanel.shayAndAlys),
      FadeOut(),
      ShowPanel(PrincipalPanel.alysGrabsPrincipal),
      Dialog.parse('Hi', speaker: alys),
      Pause(1.second),
      Dialog.parse('Bye', speaker: alys),
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().trim().head(23),
        Asm([
          jsr(Label('InitVRAMAndCRAM').l),
          jsr(Label('Pal_FadeIn').l),
          move.w(0x1.toWord.i, d0),
          jsr(Label('Panel_Create').l),
          dmaPlanesVInt(),
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          jsr(Label('Panel_DestroyAll').l),
          jsr(Label('Pal_FadeIn').l),
          move.w(0x6.toWord.i, d0),
          jsr(Label('Panel_Create').l),
          dmaPlanesVInt(),
          lea(Label('Pal_Init_Line_3').l, a0),
          lea(Label('Palette_Line_3').w, a1),
          move.w(0xf.i, d7),
          trap(1.i),
          move.b(1.i, Constant('Render_Sprites_In_Cutscenes').w),
          moveq(0.toByte.i, d0),
          jsr(Label('Event_GetAndRunDialogue3').l),
          vIntPrepareLoop(59.toWord),
          move.b(1.i, Constant('Render_Sprites_In_Cutscenes').w),
          popdlg,
          jsr(Label('Event_RunDialogue3').l),
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
          move.w(0x44.toWord.i, (Map_Start_X_Pos).w),
          move.w(0x38.toWord.i, (Map_Start_Y_Pos).w),
          move.w(Constant('FacingDir_Down').i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          jsr(Label('RefreshMap').l),
        ]));
  });

  test(
      'if no panels, fade in field only needs to reload map palette (not refreshmap)',
      () {
    var scene = Scene([FadeOut(), FadeInField()]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene);

    expect(
        asm.event.withoutComments().withoutEmptyLines(),
        Asm([
          jsr('PalFadeOut_ClrSpriteTbl'.l),
          // This avoids moving the camera.
          movea.l('Map_Palettes_Addr'.w, a0),
          jsr('LoadMapPalette'.l),
          jsr('Pal_FadeIn'.l),
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
          move.w(0x40.toWord.i, (Map_Start_X_Pos).w),
          move.w(0x40.toWord.i, (Map_Start_Y_Pos).w),
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
          move.w(0x40.toWord.i, (Map_Start_X_Pos).w),
          move.w(0x40.toWord.i, (Map_Start_Y_Pos).w),
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
          move.w(0x40.toWord.i, (Map_Start_X_Pos).w),
          move.w(0x40.toWord.i, (Map_Start_Y_Pos).w),
          move.w(Constant('FacingDir_Down').i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          // this loads the map palette
          jsr(Label('RefreshMap').l),
          // this fades it in somehow
          jsr(Label('Pal_FadeIn').l),
        ]));
  });

  test('fade in field instantly after map reload just calls enable display',
      () {
    var scene = Scene([
      FadeOut(),
      LoadMap(
          map: map2,
          startingPosition: Position(0x200, 0x200),
          facing: Direction.down),
      FadeInField(instantly: true),
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
          move.w(0x40.toWord.i, (Map_Start_X_Pos).w),
          move.w(0x40.toWord.i, (Map_Start_Y_Pos).w),
          move.w(Constant('FacingDir_Down').i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          // this loads the map palette
          jsr(Label('RefreshMap').l),
          jsr(Label('VDP_EnableDisplay').l),
        ]));
  });

  test('does not fade in again after fade in', () {
    var scene = Scene([
      FadeOut(),
      LoadMap(
          map: map2,
          startingPosition: Position(0x200, 0x200),
          facing: Direction.down),
      FadeInField(instantly: true),
      ShowPanel(PanelByIndex(0x2b)),
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
          move.w(0x40.toWord.i, (Map_Start_X_Pos).w),
          move.w(0x40.toWord.i, (Map_Start_Y_Pos).w),
          move.w(Constant('FacingDir_Down').i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          // this loads the map palette
          jsr(Label('RefreshMap').l),
          jsr(Label('VDP_EnableDisplay').l),
          move.w(0x2b.toWord.i, d0),
          jsr(Label('Panel_Create').l),
          dmaPlanesVInt(),
          jsr(Label('Panel_Destroy').l),
          dmaPlanesVInt(),
        ]));
  });

  test('fade out destroys panels', () {
    var scene = Scene([
      ShowPanel(PrincipalPanel.shayAndAlys),
      FadeOut(),
      ShowPanel(PrincipalPanel.alysGrabsPrincipal)
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().trim(),
        containsAllInOrder(Asm([
          jsr('Panel_Create'.toLabel.l),
          jsr('Panel_DestroyAll'.toLabel.l),
          jsr('Panel_Create'.toLabel.l),
        ])));
  });

  test('fade out with speed uses alternate routine', () {
    var scene = Scene([FadeOut.withSpeed(2)]);

    var program = Program();
    var asm = program.addScene(SceneId('id'), scene, startingMap: map);

    expect(
        asm.event.withoutComments().withoutEmptyLines().trim().head(2),
        Asm([
          move.b(2.i, (0xFFFFED52).w),
          jsr((Label('Pal_VariableFadeOut')).l)
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
          getAndRunDialog3LowDialogId(Byte.zero.i),
          // this clears palette
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          move.w(Constant('MapID_Test_Part2').i, (Field_Map_Index).w),
          move.w(Constant('MapID_Test').i, (Field_Map_Index_2).w),
          move.w(0x40.toWord.i, (Map_Start_X_Pos).w),
          move.w(0x40.toWord.i, (Map_Start_Y_Pos).w),
          move.w(Constant('FacingDir_Down').i, (Map_Start_Facing_Dir).w),
          move.w(0.i, (Map_Start_Char_Align).w),
          bclr(3.i, (Map_Load_Flags).w),
          // this loads the map palette
          jsr(Label('RefreshMap').l),
          // this fades it in somehow
          jsr(Label('Pal_FadeIn').l),
          getAndRunDialog3LowDialogId(Byte.zero.i),
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

    expect(program.extraConstants(), Asm.fromRaw(r'''EventFlag_Test000 = $0000
EventFlag_Test001 = $0001'''));
  });

  test(
      'custom event flags produce constants beyond normal event flag range, but not including 0xFF bytes',
      () {
    var program = Program();
    // Max is extended total minus how many are already defined in the game
    // 2 are additionally excluded
    // due to conflicting with dialog terminator byte (0xff)
    var maxCustom = 0x1ff - eventFlags.length - 2;
    for (var i = 0; i < maxCustom; i++) {
      program.addScene(SceneId('test$i'), Scene([SetFlag(EventFlag('Test$i'))]),
          startingMap: map);
    }
    // Now iterate through constants, parse out word values,
    // and ensure neither byte is 0xFF
    var constants = program.extraConstants();
    var bytes = constants
        .map((line) => '$line'.split('=').last.trim())
        .map((word) => Expression.parseSingleExpression(word, size: Size.w))
        .cast<Word>()
        .expand((word) => word.splitToBytes());
    expect(bytes, isNot(contains(Byte(0xff))));
  });

  test('same speaker dialog after show panel shows portrait', () {
    var scene = Scene([
      Dialog(speaker: alys, spans: DialogSpan.parse('Hello')),
      ShowPanel(PrincipalPanel.alysGrabsPrincipal, showDialogBox: true),
      Dialog(speaker: alys, spans: DialogSpan.parse('Bye')),
    ]);

    var program = Program();
    program.addScene(SceneId('testscene'), scene, startingMap: map);

    expect(
        program.dialogTrees.forMap(map.id).toAsm().withoutComments().trim(),
        Asm([
          dc.b([Byte(0xf4), toPortraitCode(alys.portrait)]),
          dc.b(Bytes.ascii('Hello')),
          dc.b([Byte(0xfd)]),
          dc.b([Byte(0xf4), toPortraitCode(null)]),
          dc.b([Byte(0xf2), Byte.zero]),
          dc.w([PrincipalPanel.alysGrabsPrincipal.panelIndex.toWord]),
          dc.b([Byte(0xf4), toPortraitCode(alys.portrait)]),
          dc.b(Bytes.ascii('Bye')),
          dc.b([Byte(0xff)])
        ]));
  });

  test('play music sets sound index and saved sound index', () {
    var scene = Scene([
      PlayMusic(Music.motaviaTown),
    ]);

    var program = Program();
    var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

    expect(
        asm.event.withoutComments(),
        Asm([
          move.b(Music.motaviaTown.musicId.i, Constant('Sound_Index').l),
          move.b(Music.motaviaTown.musicId.i, Constant('Saved_Sound_Index').w)
        ]));
  });

  test('events runnable in dialog or event run in event with no continue arrow',
      () {
    // events that are ambiguous should wait until there is a an upcoming
    // dialog event before running in dialog
    // otherwise they cause an additional dialog window to display
    var scene = Scene([
      Dialog(speaker: alys, spans: DialogSpan.parse('Hello')),
      ShowPanel(MolcumPanel.alysSurprised, showDialogBox: true),
      PlaySound(SoundEffect.surprise),
      HideAllPanels(),
      Pause(Duration(seconds: 1)),
      Dialog(speaker: alys, spans: DialogSpan.parse('Bye')),
    ]);

    var asm = Program().addScene(SceneId('testscene'), scene, startingMap: map);
    expect(
        asm.event.withoutComments(),
        Asm([
          moveq(Byte.zero.i, d0),
          jsr(Label('Event_GetAndRunDialogue3').l),
          move.b(Constant('SFXID_Surprise').i, (Sound_Index).l),
          jsr(Label('Panel_Destroy').l),
          dmaPlanesVInt(),
          doMapUpdateLoop(Word(0x3b)),
          popAndRunDialog3
        ]));
  });

  test('consecutive sounds in event code are interspersed with vint', () {
    // When PlaySound and PlayMusic events are back to back, there must be
    // a vintprepare call to allow the sound index change to be read
    // This happens after every sound in dialog loop.
    var scene = Scene([
      PlayMusic(Music.motaviaTown),
      Pause(1.second),
      PlaySound(SoundEffect.stopAll),
      PlayMusic(Music.suspicion),
      PlaySound(SoundEffect.surprise),
      PlaySound(SoundEffect.megid),
      ShowPanel(MolcumPanel.alysSurprised)
    ]);

    var asm = Program().addScene(SceneId('testscene'), scene, startingMap: map);

    expect(
        asm.event.withoutComments(),
        Asm([
          move.b(Music.motaviaTown.musicId.i, Constant('Sound_Index').l),
          move.b(Music.motaviaTown.musicId.i, Constant('Saved_Sound_Index').w),
          doMapUpdateLoop(Word(0x3b)),
          move.b(SoundEffect.stopAll.sfxId.i, Constant('Sound_Index').l),
          doMapUpdateLoop(Word(0)),
          move.b(Music.suspicion.musicId.i, Constant('Sound_Index').l),
          move.b(Music.suspicion.musicId.i, Constant('Saved_Sound_Index').w),
          doMapUpdateLoop(Word(0)),
          move.b(SoundEffect.surprise.sfxId.i, Constant('Sound_Index').l),
          doMapUpdateLoop(Word(0)),
          move.b(SoundEffect.megid.sfxId.i, Constant('Sound_Index').l),
          move.w(MolcumPanel.alysSurprised.panelIndex.toWord.i, d0),
          jsr(Label('Panel_Create').l),
          dmaPlanesVInt(),
          jsr(Label('Panel_Destroy').l),
          dmaPlanesVInt(),
        ]));
  });

  group('step object', () {
    test('with fractional negative step', () {
      var scene =
          Scene([StepObject(alys, stepPerFrame: Point(0, -0.5), frames: 7)]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            alys.toA4(Memory()),
            moveq(0.toByte.i, d0),
            move.l(0xffff8000.toLongword.i, d1),
            moveq(6.toByte.i, d2),
            jsr(Label('Event_StepObject').l),
            move.w(curr_x_pos(a4), dest_x_pos(a4)),
            move.w(curr_y_pos(a4), dest_y_pos(a4)),
          ]));
    });

    test('with fractional step', () {
      var scene =
          Scene([StepObject(alys, stepPerFrame: Point(0, 0.5), frames: 7)]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            alys.toA4(Memory()),
            moveq(0.toByte.i, d0),
            move.l(0x00008000.toLongword.i, d1),
            moveq(6.toByte.i, d2),
            jsr(Label('Event_StepObject').l),
            move.w(curr_x_pos(a4), dest_x_pos(a4)),
            move.w(curr_y_pos(a4), dest_y_pos(a4)),
          ]));
    });

    test('with integer step 2 directions', () {
      var scene =
          Scene([StepObject(alys, stepPerFrame: Point(1, 1), frames: 7)]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            alys.toA4(Memory()),
            move.l(0x00010000.toLongword.i, d0),
            move.l(0x00010000.toLongword.i, d1),
            moveq(6.toByte.i, d2),
            jsr(Label('Event_StepObject').l),
            move.w(curr_x_pos(a4), dest_x_pos(a4)),
            move.w(curr_y_pos(a4), dest_y_pos(a4)),
          ]));
    });

    test('sets new position of object if known', () {
      var scene = Scene([
        SetContext((ctx) => ctx.positions[shay] = Position(0x100, 0x100)),
        StepObject(shay, stepPerFrame: Point(0x1, 0), frames: 0x10),
        // Shay should now be at 0x110, 0x100
        IndividualMoves()
          ..moves[shay] = (StepPath()
            ..distance = 2.step
            ..direction = down)
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(asm.event.withoutComments().tail(3).head(2),
          Asm([move.w(0x110.toWord.i, d0), move.w(0x120.toWord.i, d1)]));
    });

    test('does not set position for object if not known', () {
      var scene = Scene([
        StepObject(alys, stepPerFrame: Point(0x1, 0), frames: 0x10),
        IndividualMoves()
          ..moves[alys] = (StepPath()
            ..distance = 1.step
            ..direction = down)
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments().tail(4),
          Asm([
            move.w(curr_x_pos(a4), d0),
            move.w(curr_y_pos(a4), d1),
            addi.w(0x0010.toWord.i, d1),
            jsr(Label('Event_MoveCharacter').l)
          ]));
    });
  });

  group('move camera', () {
    test('to absolute position', () {
      var scene = Scene([
        MoveCamera(Position(0x1b0, 0x2a0)),
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            move.w(0x1b0.toWord.i, d0),
            move.w(0x2a0.toWord.i, d1),
            move.w(1.i, d2),
            jsr(Label('Event_MoveCamera').l),
          ]));
    });

    test('if locked, unlocks then relocks before next event', () {
      var scene = Scene([
        LockCamera(),
        MoveCamera(Position(0x1b0, 0x2a0)),
        Pause(1.second),
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      var expected = Asm([
        lockCamera(true),
        lockCamera(false),
        move.w(0x1b0.toWord.i, d0),
        move.w(0x2a0.toWord.i, d1),
        move.w(1.i, d2),
        jsr(Label('Event_MoveCamera').l),
        lockCamera(true),
        generateEventAsm([Pause(1.second)]),
      ]);
      expect(asm.event.withoutComments().head(expected.length), expected);
    });

    test('if locked, unlocks on scene end', () {
      var scene = Scene([
        LockCamera(),
        Pause(1.second),
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            lockCamera(true),
            generateEventAsm([Pause(1.second)]),
            lockCamera(false),
          ]));
    });

    test('requries reloading address registers after', () {
      var scene = Scene([
        MoveCamera(Position(0x1b0, 0x2a0)),
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            move.w(0x1b0.toWord.i, d0),
            move.w(0x2a0.toWord.i, d1),
            move.w(1.i, d2),
            jsr(Label('Event_MoveCamera').l),
          ]));
    }, skip: 'TODO');
  });

  group('if value', () {
    test('eq, gt, lt with expression and scalar', () {
      var scene = Scene([
        IfValue(rune.position().component(Axis.y),
            comparedTo: PositionComponent(0x200, Axis.y),
            equal: [Face(up).move(rune)],
            greater: [Face(down).move(rune)],
            less: [Face(right).move(rune)])
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            beq(Label('.1_eq')),
            bhi(Label('.1_gt')),
            // lt branch
            updateObjFacing(right.address),
            bra(Label('.1_continue')),

            // eq branch
            label(Label('.1_eq')),
            updateObjFacing(up.address),
            bra(Label('.1_continue')),

            // gt branch
            label(Label('.1_gt')),
            updateObjFacing(down.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('gte, lt with expression and scalar', () {
      var scene = Scene([
        IfValue(rune.position().component(Axis.y),
            comparedTo: PositionComponent(0x200, Axis.y),
            greaterOrEqual: [Face(down).move(rune)],
            less: [Face(right).move(rune)])
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            bcc(Label('.1_gte')),

            // lt branch
            updateObjFacing(right.address),
            bra(Label('.1_continue')),

            // gte branch
            label(Label('.1_gte')),
            updateObjFacing(down.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('gte with expression and scalar', () {
      var scene = Scene([
        IfValue(
          rune.position().component(Axis.y),
          greaterOrEqual: [Face(down).move(rune)],
          comparedTo: PositionComponent(0x200, Axis.y),
        )
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            bcs(Label('.1_continue')),
            // gte branch
            updateObjFacing(down.address),
            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('gt, lte with expression and scalar', () {
      var scene = Scene([
        IfValue(rune.position().component(Axis.y),
            greater: [Face(down).move(rune)],
            lessOrEqual: [Face(right).move(rune)],
            comparedTo: PositionComponent(0x200, Axis.y))
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            bhi(Label('.1_gt')),
            // lte branch
            updateObjFacing(right.address),
            bra(Label('.1_continue')),

            // gt branch
            label(Label('.1_gt')),
            updateObjFacing(down.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('gt, lt with expression and scalar', () {
      var scene = Scene([
        IfValue(rune.position().component(Axis.y),
            comparedTo: PositionComponent(0x200, Axis.y),
            greater: [Face(down).move(rune)],
            less: [Face(right).move(rune)])
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            beq(Label('.1_continue')),
            bhi(Label('.1_gt')),
            // lt branch
            updateObjFacing(right.address),
            bra(Label('.1_continue')),

            // gt branch
            label(Label('.1_gt')),
            updateObjFacing(down.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('gt with expression and scalar', () {
      var scene = Scene([
        IfValue(rune.position().component(Axis.y),
            comparedTo: PositionComponent(0x200, Axis.y),
            greater: [Face(down).move(rune)])
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            bls(Label('.1_continue')),

            // gt branch
            updateObjFacing(down.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('gt with scalar and expression', () {
      var scene = Scene([
        IfValue(PositionComponent(0x200, Axis.y),
            comparedTo: rune.position().component(Axis.y),
            greater: [Face(down).move(rune)])
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            move.w(0x200.toWord.i, d0),
            cmp.w(curr_y_pos(a4), d0),
            bls(Label('.1_continue')),

            // gt branch
            updateObjFacing(down.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('gt with expressions', () {
      var scene = Scene([
        IfValue(alys.position().component(Axis.y),
            comparedTo: rune.position().component(Axis.y),
            greater: [Face(down).move(rune)])
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            lea(a4.indirect, a3),
            characterByIdToA4(alys.charIdAddress),
            move.w(curr_y_pos(a4), d0),
            cmp.w(curr_y_pos(a3), d0),
            bls(Label('.1_continue')),

            // gt branch
            characterByIdToA4(rune.charIdAddress),
            updateObjFacing(down.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('terminates dialog', () {
      var scene = Scene([
        IfValue(PositionComponent(0x200, Axis.y),
            comparedTo: rune.position().component(Axis.y),
            greater: [Dialog.parse('howdy')],
            less: [Dialog.parse('ho')])
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            move.w(0x200.toWord.i, d0),
            cmp.w(curr_y_pos(a4), d0),
            beq(Label('.1_continue')),
            bhi(Label('.1_gt')),

            // lt branch
            getAndRunDialog3LowDialogId(Byte.zero.i),
            bra(Label('.1_continue')),

            label(Label('.1_gt')),
            // gt branch
            getAndRunDialog3LowDialogId(Byte.one.i),

            // continue
            label(Label('.1_continue')),
          ]));

      expect(
          program.dialogTrees.forMap(map.id),
          DialogTree()
            ..add(DialogAsm([
              dc.b(Bytes.ascii('ho')),
              dc.b([Byte(0xff)])
            ]))
            ..add(DialogAsm([
              dc.b(Bytes.ascii('howdy')),
              dc.b([Byte(0xff)])
            ])));
    });

    test('makes state ambiguous in outer branch', () {
      var scene = Scene([
        AbsoluteMoves()..destinations[rune] = Position(0x100, 0x200),
        IfValue(alys.position().component(Axis.x),
            comparedTo: PositionComponent(0x100, Axis.x),
            greaterOrEqual: [
              AbsoluteMoves()..destinations[rune] = Position(0x110, 0x200)
            ]),
        IndividualMoves()
          ..moves[rune] = (StepPath()
            ..direction = down
            ..distance = 2.steps)
      ]);

      var asm = Program().addScene(SceneId('test'), scene, startingMap: map);

      print(asm);

      expect(
        asm.event.withoutComments().tail(6),
        Asm([
          moveq(Constant('CharID_Rune').i, d0),
          jsr(Label('Event_GetCharacter').l),
          move.w(curr_x_pos(a4), d0),
          move.w(curr_y_pos(a4), d1),
          addi.w(0x0020.toWord.i, d1),
          jsr(Label('Event_MoveCharacter').l),
        ]),
      );
    });

    test('makes state ambiguous in parent branches', () {
      // Add an IfFlag branch, an within that add IfValue branch
      // The outter most branch should also have ambiguous state.

      var scene = Scene([
        AbsoluteMoves()..destinations[rune] = Position(0x100, 0x200),
        IfFlag(EventFlag('test'), isSet: [
          IfValue(alys.position().component(Axis.x),
              comparedTo: PositionComponent(0x100, Axis.x),
              greaterOrEqual: [
                AbsoluteMoves()..destinations[rune] = Position(0x110, 0x200)
              ]),
        ]),
        IndividualMoves()
          ..moves[rune] = (StepPath()
            ..direction = down
            ..distance = 2.steps)
      ]);

      var asm = Program().addScene(SceneId('test'), scene, startingMap: map);

      print(asm);

      expect(
        asm.event.withoutComments().tail(6),
        Asm([
          moveq(Constant('CharID_Rune').i, d0),
          jsr(Label('Event_GetCharacter').l),
          move.w(curr_x_pos(a4), d0),
          move.w(curr_y_pos(a4), d1),
          addi.w(0x0020.toWord.i, d1),
          jsr(Label('Event_MoveCharacter').l),
        ]),
      );
    });

    test('makes state ambiguous in child branches', () {
      var scene = Scene([
        IfFlag(EventFlag('testflag'), isSet: [
          AbsoluteMoves()..destinations[rune] = Position(0x100, 0x200),
        ]),
        IfValue(alys.position().component(Axis.x),
            comparedTo: PositionComponent(0x100, Axis.x),
            greaterOrEqual: [
              AbsoluteMoves()..destinations[rune] = Position(0x110, 0x200)
            ]),
        IfFlag(EventFlag('testflag'), isSet: [
          IndividualMoves()
            ..moves[rune] = (StepPath()
              ..direction = down
              ..distance = 2.steps)
        ]),
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      print(asm);

      expect(
        asm.event.withoutComments().tail(7),
        Asm([
          moveq(Constant('CharID_Rune').i, d0),
          jsr(Label('Event_GetCharacter').l),
          move.w(curr_x_pos(a4), d0),
          move.w(curr_y_pos(a4), d1),
          addi.w(0x0020.toWord.i, d1),
          jsr(Label('Event_MoveCharacter').l),
          label(Label('.testflag_unset5')),
        ]),
      );
    });

    test('makes state ambiguous in reachable peer branches', () {
      var scene = Scene([
        IfFlag(EventFlag('testflag'), isSet: [
          AbsoluteMoves()..destinations[rune] = Position(0x100, 0x200),
        ]),
        IfFlag(EventFlag('peerflag'), isSet: [
          IfValue(alys.position().component(Axis.x),
              comparedTo: PositionComponent(0x100, Axis.x),
              greaterOrEqual: [
                AbsoluteMoves()..destinations[rune] = Position(0x110, 0x200)
              ]),
        ]),
        IfFlag(EventFlag('testflag'), isSet: [
          IndividualMoves()
            ..moves[rune] = (StepPath()
              ..direction = down
              ..distance = 2.steps)
        ]),
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
        asm.event.withoutComments().tail(7),
        Asm([
          moveq(Constant('CharID_Rune').i, d0),
          jsr(Label('Event_GetCharacter').l),
          move.w(curr_x_pos(a4), d0),
          move.w(curr_y_pos(a4), d1),
          addi.w(0x0020.toWord.i, d1),
          jsr(Label('Event_MoveCharacter').l),
          label(Label('.testflag_unset6')),
        ]),
      );
    });

    test('does not make state ambiguous in unreachable peer branches', () {
      var scene = Scene([
        IfFlag(EventFlag('testflag'), isSet: [
          AbsoluteMoves()..destinations[rune] = Position(0x100, 0x200),
        ], isUnset: [
          IfValue(alys.position().component(Axis.x),
              comparedTo: PositionComponent(0x100, Axis.x),
              greaterOrEqual: [
                AbsoluteMoves()..destinations[rune] = Position(0x110, 0x200)
              ]),
        ]),
        // Unconditional pause is necessary to avoid branch normalization
        Pause(1.second),
        IfFlag(EventFlag('testflag'), isSet: [
          IndividualMoves()
            ..moves[rune] = (StepPath()
              ..direction = down
              ..distance = 2.steps)
        ]),
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
        asm.event.withoutComments().tail(4),
        Asm([
          move.w(0x100.toWord.i, d0),
          move.w(0x220.toWord.i, d1),
          jsr(Label('Event_MoveCharacter').l),
          label(Label('.testflag_unset6')),
        ]),
      );
    });

    test('character slot compared to slot constant', () {
      var scene = Scene([
        IfValue(rune.slot(),
            comparedTo: Slot(1),
            equal: [Face(up).move(rune)],
            greater: [Face(down).move(rune)],
            less: [Face(right).move(rune)])
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            moveq(rune.charIdAddress, d0),
            jsr(FindCharacterSlot.l),
            cmpi.b(0.i, d1),
            beq(Label('.1_eq')),
            bhi(Label('.1_gt')),
            // lt branch
            characterByIdToA4(rune.charIdAddress),
            updateObjFacing(right.address),
            bra(Label('.1_continue')),

            // eq branch
            label(Label('.1_eq')),
            characterByIdToA4(rune.charIdAddress),
            updateObjFacing(up.address),
            bra(Label('.1_continue')),

            // gt branch
            label(Label('.1_gt')),
            characterByIdToA4(rune.charIdAddress),
            updateObjFacing(down.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('character is in party', () {
      var scene = Scene([
        IfValue(rune.slot(),
            comparedTo: NullSlot(),
            equal: [Face(up).move(rune)],
            notEqual: [Face(down).move(rune)])
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            moveq(rune.charIdAddress, d0),
            jsr(FindCharacterSlot.l),
            cmpi.b(0xFF.i, d1),
            beq(Label('.1_eq')),
            // not equal branch
            characterByIdToA4(rune.charIdAddress),
            updateObjFacing(down.address),

            bra(Label('.1_continue')),
            // eq branch
            label(Label('.1_eq')),
            characterByIdToA4(rune.charIdAddress),
            updateObjFacing(up.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('object is offscreen', () {
      var scene = Scene([
        IfValue(
          IsOffScreen(rune),
          comparedTo: BooleanConstant(true),
          equal: [Face(up).move(rune)],
          notEqual: [Face(down).move(rune)],
        )
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.b(1.i, offscreen_flag(a4)),
            beq(Label('.1_eq')),
            // not equal branch
            updateObjFacing(down.address),
            bra(Label('.1_continue')),

            // eq branch
            label(Label('.1_eq')),
            updateObjFacing(up.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('object is at absolute position', () {
      var scene = Scene([
        IfValue(
          rune.position(),
          comparedTo: Position(0x100, 0x200),
          equal: [Face(up).move(rune)],
          notEqual: [Face(down).move(rune)],
        )
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x100.toWord.i, curr_x_pos(a4)),
            bne(Label('.1_neq')),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            bne(Label('.1_neq')),

            // Equal branch
            updateObjFacing(up.address),
            bra(Label('.1_continue')),

            label(Label('.1_neq')),
            updateObjFacing(down.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('object position is greater than absolute position', () {
      var scene = Scene([
        IfValue(
          rune.position(),
          comparedTo: Position(0x100, 0x200),
          greater: [Face(up).move(rune)],
          lessOrEqual: [Face(down).move(rune)],
        )
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x100.toWord.i, curr_x_pos(a4)),
            bhi(Label('.1_gt')),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            bhi(Label('.1_gt')),

            // Lte branch
            updateObjFacing(down.address),
            bra(Label('.1_continue')),

            label(Label('.1_gt')),
            updateObjFacing(up.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('object is at absolute position with empty branch uses continue', () {
      var scene = Scene([
        IfValue(
          rune.position(),
          comparedTo: Position(0x100, 0x200),
          equal: [Face(up).move(rune)],
        )
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x100.toWord.i, curr_x_pos(a4)),
            bne(Label('.1_continue')),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            bne(Label('.1_continue')),

            // Equal branch
            updateObjFacing(up.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('object is not at absolute position with empty branch uses continue',
        () {
      var scene = Scene([
        IfValue(
          rune.position(),
          comparedTo: Position(0x100, 0x200),
          notEqual: [Face(up).move(rune)],
        )
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x100.toWord.i, curr_x_pos(a4)),
            bne(Label('.1_neq')),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            beq(Label('.1_continue')),

            // Not equal branch
            label(Label('.1_neq')),
            updateObjFacing(up.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('object is greater or less than absolute position', () {
      var scene = Scene([
        IfValue(
          rune.position(),
          comparedTo: Position(0x100, 0x200),
          greater: [Face(up).move(rune)],
          less: [Face(down).move(rune)],
        )
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x100.toWord.i, curr_x_pos(a4)),
            bhi(Label('.1_gt')),
            bcs(Label('.1_lt')),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            beq(Label('.1_continue')),
            bhi(Label('.1_gt')),

            // lt branch
            label(Label('.1_lt')),
            updateObjFacing(down.address),
            bra(Label('.1_continue')),

            // gt branch
            label(Label('.1_gt')),
            updateObjFacing(up.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('object is greater, less, or equal to absolute position', () {
      var scene = Scene([
        IfValue(
          rune.position(),
          comparedTo: Position(0x100, 0x200),
          greater: [Face(up).move(rune)],
          equal: [Face(right).move(rune)],
          less: [Face(down).move(rune)],
        )
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            characterByIdToA4(rune.charIdAddress),
            cmpi.w(0x100.toWord.i, curr_x_pos(a4)),
            bhi(Label('.1_gt')),
            bcs(Label('.1_lt')),
            cmpi.w(0x200.toWord.i, curr_y_pos(a4)),
            beq(Label('.1_eq')),
            bhi(Label('.1_gt')),

            // lt branch
            label(Label('.1_lt')),
            updateObjFacing(down.address),
            bra(Label('.1_continue')),

            // eq branch
            label(Label('.1_eq')),
            updateObjFacing(right.address),
            bra(Label('.1_continue')),

            // gt branch
            label(Label('.1_gt')),
            updateObjFacing(up.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('object position compared to other object position', () {
      var scene = Scene([
        IfValue(
          rune.position(),
          comparedTo: alys.position(),
          greater: [Face(up).move(rune)],
          equal: [Face(right).move(rune)],
          less: [Face(down).move(rune)],
        )
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            alys.toA(a5, Memory()),
            characterByIdToA4(rune.charIdAddress),
            move.w(curr_x_pos(a4), d0),
            cmp.w(curr_x_pos(a5), d0),
            bhi(Label('.1_gt')),
            bcs(Label('.1_lt')),
            move.w(curr_y_pos(a4), d0),
            cmp.w(curr_y_pos(a5), d0),
            beq(Label('.1_eq')),
            bhi(Label('.1_gt')),

            // lt branch
            label(Label('.1_lt')),
            updateObjFacing(down.address),
            bra(Label('.1_continue')),

            // eq branch
            label(Label('.1_eq')),
            updateObjFacing(right.address),
            bra(Label('.1_continue')),

            // gt branch
            label(Label('.1_gt')),
            updateObjFacing(up.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });

    test('slot routine compared to null', () {
      var scene = Scene([
        IfValue(
          RoutineIdOfSlot(5),
          comparedTo: NullObjectRoutineId(),
          equal: [Face(up).move(rune)],
          notEqual: [Face(down).move(BySlot(5))],
        )
      ]);

      var asm =
          Program().addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            move.w('Character_5'.w, d2),
            andi.w(0x7fff.i, d2),
            cmpi.w(Word(0).i, d2),
            beq(Label('.1_eq')),
            // not equal branch
            lea('Character_5'.w, a4),
            updateObjFacing(down.address),
            bra(Label('.1_continue')),
            // eq branch
            label(Label('.1_eq')),
            characterByIdToA4(rune.charIdAddress),
            updateObjFacing(up.address),
            // continue
            label(Label('.1_continue')),
          ]));
    });
  });

  group('hide panels', () {
    group('all', () {
      test('generates nothing if there are no panels', () {
        var scene = Scene([
          HideAllPanels(),
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(asm, Asm.empty());
      });

      test('in event calls subroutine', () {});

      test('in instantly, in event, if number of panels is known', () {
        var scene = Scene([
          ShowPanel(PanelByIndex(1)),
          ShowPanel(PanelByIndex(2)),
          Pause(1.second),
          HideAllPanels(instantly: true),
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();
        /*
  ; Remove all panels instantly
	moveq	#0, d0
	move.b	(Panel_Num).w, d0
	subq.b	#1, d0
loc_742A4:
	jsr	(Panel_Destroy).l
	dbf	d0, loc_742A4
	jsr	(DMAPlanes_VInt).l
  */
        expect(
            asm,
            Asm([
              move.w(Word(1).i, d0),
              jsr(Label('Panel_Create').l),
              jsr(Label('DMAPlanes_VInt').l),
              move.w(Word(2).i, d0),
              jsr(Label('Panel_Create').l),
              jsr(Label('DMAPlanes_VInt').l),
              move.w(Word(0x3b).i, d0),
              // Don't run map updates while panels shown
              jsr(Label('VInt_PrepareLoop').l),
              moveq(1.i, d0),
              label(Label('.4_nextPanel')),
              jsr(Label('Panel_Destroy').l),
              dbf(d0, Label('.4_nextPanel')),
              jsr(Label('DMAPlanes_VInt').l),
            ]));
      });
    });

    group('top N', () {
      test('instantly', () {}, skip: 'TODO');
    });
  });

  group('change party order', () {
    group('during map load', () {
      test('1 slot', () {
        var scene = Scene([
          LoadMap(
              map: map,
              facing: up,
              startingPosition: Position(0x100, 0x100),
              updateParty: ChangePartyOrder([rune], saveCurrentParty: false)),
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(
            asm.head(3),
            Asm([
              Instruction.parse(
                  r'	move.l #CharID_Rune<<24|$FFFFFF, (Current_Party_Slots).w'),
              move.b(Byte.max.i, Current_Party_Slot_5.w),
              move.w(MapId.Test.toAsm.i, (Field_Map_Index).w)
            ]));
      });

      test('2 slots', () {
        var scene = Scene([
          LoadMap(
              map: map,
              facing: up,
              startingPosition: Position(0x100, 0x100),
              updateParty:
                  ChangePartyOrder([rune, alys], saveCurrentParty: false)),
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(
            asm.head(3),
            Asm([
              Instruction.parse(
                  r'	move.l #CharID_Rune<<24|CharID_Alys<<16|$FFFF, (Current_Party_Slots).w'),
              move.b(Byte.max.i, Current_Party_Slot_5.w),
              move.w(MapId.Test.toAsm.i, (Field_Map_Index).w)
            ]));
      });

      test('3 slots', () {
        var scene = Scene([
          LoadMap(
              map: map,
              facing: up,
              startingPosition: Position(0x100, 0x100),
              updateParty: ChangePartyOrder([rune, alys, hahn],
                  saveCurrentParty: false)),
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(
            asm.head(3),
            Asm([
              Instruction.parse(
                  r'	move.l #CharID_Rune<<24|CharID_Alys<<16|CharID_Hahn<<8|$FF, (Current_Party_Slots).w'),
              move.b(Byte.max.i, Current_Party_Slot_5.w),
              move.w(MapId.Test.toAsm.i, (Field_Map_Index).w)
            ]));
      });

      test('4 slots', () {
        var scene = Scene([
          LoadMap(
              map: map,
              facing: up,
              startingPosition: Position(0x100, 0x100),
              updateParty: ChangePartyOrder([rune, alys, hahn, wren],
                  saveCurrentParty: false)),
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(
            asm.head(3),
            Asm([
              Instruction.parse(
                  r'	move.l #CharID_Rune<<24|CharID_Alys<<16|CharID_Hahn<<8|CharID_Wren, (Current_Party_Slots).w'),
              move.b(Byte.max.i, Current_Party_Slot_5.w),
              move.w(MapId.Test.toAsm.i, (Field_Map_Index).w)
            ]));
      });

      test('5th slot requires another byte beyond longword', () {
        var scene = Scene([
          LoadMap(
              map: map,
              facing: up,
              startingPosition: Position(0x100, 0x100),
              updateParty: ChangePartyOrder([rune, alys, hahn, wren, raja],
                  saveCurrentParty: false)),
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(
            asm.head(3),
            Asm([
              Instruction.parse(
                  r'	move.l #CharID_Rune<<24|CharID_Alys<<16|CharID_Hahn<<8|CharID_Wren, (Current_Party_Slots).w'),
              move.b(Constant('CharID_Raja').i, Current_Party_Slot_5.w),
              move.w(MapId.Test.toAsm.i, (Field_Map_Index).w)
            ]));
      });

      test('sets party order memory', () {
        var scene = Scene([
          // Load map reloads objects based on new order
          LoadMap(
              map: map,
              startingPosition: Position(0x100, 0x110),
              facing: up,
              arrangement: PartyArrangement.belowLead,
              updateParty: ChangePartyOrder([rune, alys, hahn, wren, raja],
                  saveCurrentParty: false)),
          IndividualMoves()
            ..moves[BySlot(1)] = (StepPath()
              ..distance = 1.step
              ..direction = up)
            ..moves[BySlot(2)] = (StepPath()
              ..distance = 1.step
              ..direction = up)
            ..moves[BySlot(3)] = (StepPath()
              ..distance = 1.step
              ..direction = up)
            ..moves[BySlot(4)] = (StepPath()
              ..distance = 1.step
              ..direction = up)
            ..moves[BySlot(5)] = (StepPath()
              ..distance = 1.step
              ..direction = up)
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        var expected = Program()
            .addScene(
                SceneId('testscene'),
                Scene([
                  SetContext((ctx) {
                    ctx.positions[BySlot(1)] = Position(0x100, 0x110);
                    ctx.positions[BySlot(2)] = Position(0x100, 0x120);
                    ctx.positions[BySlot(3)] = Position(0x100, 0x130);
                    ctx.positions[BySlot(4)] = Position(0x100, 0x140);
                    ctx.positions[BySlot(5)] = Position(0x100, 0x150);
                  }),
                  IndividualMoves()
                    ..moves[BySlot(1)] = (StepPath()
                      ..distance = 1.step
                      ..direction = up)
                    ..moves[BySlot(2)] = (StepPath()
                      ..distance = 1.step
                      ..direction = up)
                    ..moves[BySlot(3)] = (StepPath()
                      ..distance = 1.step
                      ..direction = up)
                    ..moves[BySlot(4)] = (StepPath()
                      ..distance = 1.step
                      ..direction = up)
                    ..moves[BySlot(5)] = (StepPath()
                      ..distance = 1.step
                      ..direction = up)
                ]))
            .event
            .withoutComments();

        expect(asm.tail(expected.length), expected);
      });

      test('saves before changing if requested', () {
        var scene = Scene([
          LoadMap(
              map: map,
              facing: up,
              startingPosition: Position(0x100, 0x100),
              updateParty: ChangePartyOrder([rune, alys, hahn, wren, raja],
                  saveCurrentParty: true)),
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(
            asm.head(5),
            Asm([
              move.l(Current_Party_Slots.w, Constant('Saved_Char_ID_Mem_1').w),
              move.b(Current_Party_Slot_5.w, Constant('Saved_Char_ID_Mem_5').w),
              Instruction.parse(
                  r'	move.l #CharID_Rune<<24|CharID_Alys<<16|CharID_Hahn<<8|CharID_Wren, (Current_Party_Slots).w'),
              move.b(Constant('CharID_Raja').i, Current_Party_Slot_5.w),
              move.w(MapId.Test.toAsm.i, (Field_Map_Index).w)
            ]));
      });

      test('restore saved party', () {
        var scene = Scene([
          LoadMap(
              map: map,
              facing: up,
              startingPosition: Position(0x100, 0x100),
              updateParty: RestoreSavedPartyOrder())
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(
            asm.head(3),
            Asm([
              move.l(Constant('Saved_Char_ID_Mem_1').w, Current_Party_Slots.w),
              move.b(Constant('Saved_Char_ID_Mem_5').w, Current_Party_Slot_5.w),
              move.w(MapId.Test.toAsm.i, (Field_Map_Index).w)
            ]));
      });
    });

    group('outside of map load', () {
      test('swaps field objects and slots', () {
        var scene = Scene([
          ChangePartyOrder([rune, alys, hahn, wren, raja],
              saveCurrentParty: false)
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(
            asm,
            Asm([
              moveq(Constant('CharID_Rune').i, d0),
              moveq(0.i, d1),
              jsr(Label('Event_SwapCharacter').l),
              moveq(Constant('CharID_Alys').i, d0),
              moveq(1.i, d1),
              jsr(Label('Event_SwapCharacter').l),
              moveq(Constant('CharID_Hahn').i, d0),
              moveq(2.i, d1),
              jsr(Label('Event_SwapCharacter').l),
              moveq(Constant('CharID_Wren').i, d0),
              moveq(3.i, d1),
              jsr(Label('Event_SwapCharacter').l),
            ]));
      });

      test('swaps sparse update', () {
        var scene = Scene([
          ChangePartyOrder([rune], saveCurrentParty: false)
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(
            asm,
            Asm([
              moveq(Constant('CharID_Rune').i, d0),
              moveq(0.i, d1),
              jsr(Label('Event_SwapCharacter').l),
            ]));
      });

      test('restore saved party swaps only necessary members when known', () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.slots[1] = rune;
            ctx.slots[2] = alys;
            ctx.slots[3] = hahn;
            ctx.slots[4] = wren;
            ctx.slots[5] = raja;
            ctx.slots.setPartyOrder([alys, hahn, rune, wren, raja],
                saveCurrent: true);
          }),
          RestoreSavedPartyOrder()
        ]);

        var asm = Program()
            .addScene(SceneId('testscene'), scene, startingMap: map)
            .event
            .withoutComments();

        expect(
            asm,
            Asm([
              move.b(Constant('Saved_Char_ID_Mem_1').w, d0),
              moveq(0.i, d1),
              jsr(Label('Event_SwapCharacter').l),
              move.b(Constant('Saved_Char_ID_Mem_2').w, d0),
              moveq(1.i, d1),
              jsr(Label('Event_SwapCharacter').l),
              move.b(Constant('Saved_Char_ID_Mem_3').w, d0),
              moveq(2.i, d1),
              jsr(Label('Event_SwapCharacter').l),
            ]));
      });
    });
  });

  group('run battle on exit', () {
    test('run battle then exit to cutscene with music', () {
      var scene = Scene([
        OnExitRunBattle(
            battleIndex: 0x10,
            postBattleFadeInMap: false,
            postBattleSound: Music.redAlert,
            postBattleReloadObjects: false)
      ]);

      var asm = Program()
          .addScene(SceneId('testscene'), scene, startingMap: map)
          .event
          .withoutComments();

      expect(
          asm,
          Asm([
            moveq(0.i, d0),
            move.b(d0, (Panel_Num).w),
            move.b(Constant('MusicID_RedAlert').i,
                Constant('Saved_Sound_Index').w),
            bset(7.i, Map_Load_Flags.w),
            bset(3.i, Map_Load_Flags.w),
            move.b(0x10.toByte.i, Constant('Event_Battle_Index').w),
            bset(3.i, Constant('Routine_Exit_Flags').w),
          ]));
    });

    test('run battle then exit to map but cut sound', () {
      var scene = Scene([
        OnExitRunBattle(
            battleIndex: 0x11,
            postBattleFadeInMap: true,
            postBattleSound: SoundEffect.stopAll,
            postBattleReloadObjects: false)
      ]);

      var asm = Program()
          .addScene(SceneId('testscene'), scene, startingMap: map)
          .event
          .withoutComments();

      expect(
          asm,
          Asm([
            moveq(0.i, d0),
            move.b(d0, (Panel_Num).w),
            move.b(
                Constant('Sound_StopAll').i, Constant('Saved_Sound_Index').w),
            bclr(7.i, Map_Load_Flags.w),
            bset(3.i, Map_Load_Flags.w),
            move.b(0x11.toByte.i, Constant('Event_Battle_Index').w),
            bset(3.i, Constant('Routine_Exit_Flags').w),
          ]));
    });

    test('run battle then exit to map but refresh objects', () {
      var scene = Scene([
        OnExitRunBattle(
            battleIndex: 0x12,
            postBattleFadeInMap: true,
            postBattleReloadObjects: true)
      ]);

      var asm = Program()
          .addScene(SceneId('testscene'), scene, startingMap: map)
          .event
          .withoutComments();

      expect(
          asm,
          Asm([
            moveq(0.i, d0),
            move.b(d0, (Panel_Num).w),
            bclr(7.i, Map_Load_Flags.w),
            bclr(3.i, Map_Load_Flags.w),
            move.b(0x12.toByte.i, Constant('Event_Battle_Index').w),
            bset(3.i, Constant('Routine_Exit_Flags').w),
          ]));
    });

    test('does not hide panels when exiting to battle', () {
      var scene = Scene([
        ShowPanel(PanelByIndex(1)),
        OnExitRunBattle(battleIndex: 0x10),
      ]);

      var asm = Program()
          .addScene(SceneId('testscene'), scene, startingMap: map)
          .event
          .withoutComments();

      expect(
          asm,
          Asm([
            move.w(Word(1).i, d0),
            jsr(Label('Panel_Create').l),
            dmaPlanesVInt(),
            moveq(0.i, d0),
            move.b(d0, (Panel_Num).w),
            bclr(7.i, Map_Load_Flags.w),
            bset(3.i, Map_Load_Flags.w),
            move.b(0x10.toByte.i, Constant('Event_Battle_Index').w),
            bset(3.i, Constant('Routine_Exit_Flags').w),
          ]));
    });
  });
}
