import 'package:rune/asm/asm.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/asm/text.dart';
import 'package:rune/generator/cutscenes.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/animate.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import 'scene_test.dart';

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

  test('events runnable in dialog or event run in event when no continue arrow',
      () {
    // events that are ambiguous should wait until there is a an upcoming
    // dialog event before running in dialog
    // otherwise they cause an additional dialog window to display
    var scene = Scene([
      Dialog(speaker: alys, spans: DialogSpan.parse('Hello')),
      ShowPanel(MolcumPanel.alysSurprised, showDialogBox: true),
      PlaySound(Sound.surprise),
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
          jsr(Label('Panel_DestroyAll').l),
          doMapUpdateLoop(Word(0x3c)),
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
      PlaySound(Sound.stopAll),
      PlayMusic(Music.suspicion),
      PlaySound(Sound.surprise),
      PlaySound(Sound.megid),
      ShowPanel(MolcumPanel.alysSurprised)
    ]);

    var asm = Program().addScene(SceneId('testscene'), scene, startingMap: map);

    expect(
        asm.event.withoutComments(),
        Asm([
          move.b(Music.motaviaTown.musicId.i, Constant('Sound_Index').l),
          move.b(Music.motaviaTown.musicId.i, Constant('Saved_Sound_Index').w),
          doMapUpdateLoop(Word(0x3c)),
          move.b(Sound.stopAll.sfxId.i, Constant('Sound_Index').l),
          vIntPrepare(),
          move.b(Music.suspicion.musicId.i, Constant('Sound_Index').l),
          move.b(Music.suspicion.musicId.i, Constant('Saved_Sound_Index').w),
          vIntPrepare(),
          move.b(Sound.surprise.sfxId.i, Constant('Sound_Index').l),
          vIntPrepare(),
          move.b(Sound.megid.sfxId.i, Constant('Sound_Index').l),
          move.w(MolcumPanel.alysSurprised.panelIndex.toWord.i, d0),
          jsr(Label('Panel_Create').l),
          dmaPlanesVInt()
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
            moveq(7.toByte.i, d2),
            jsr(Label('Event_StepObject').l),
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
            moveq(7.toByte.i, d2),
            jsr(Label('Event_StepObject').l),
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
            moveq(7.toByte.i, d2),
            jsr(Label('Event_StepObject').l),
          ]));
    });

    test('sets new position of object if known', () {
      var scene = Scene([
        SetContext((ctx) => ctx.positions[alys] = Position(0x100, 0x100)),
        StepObject(alys, stepPerFrame: Point(0x1, 0), frames: 0x10),
        // Alys should now be at 0x110, 0x100
        IndividualMoves()
          ..moves[alys] = (StepPath()
            ..distance = 1.step
            ..direction = down)
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(asm.event.withoutComments().tail(3).head(2),
          Asm([move.w(0x110.toWord.i, d0), move.w(0x110.toWord.i, d1)]));
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
            beq.w(Label('.1_eq')),
            bhi.w(Label('.1_gt')),
            // lt branch
            updateObjFacing(right.address),
            bra.w(Label('.1_continue')),

            // eq branch
            label(Label('.1_eq')),
            updateObjFacing(up.address),
            bra.w(Label('.1_continue')),

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
            bcc.w(Label('.1_gte')),

            // lt branch
            updateObjFacing(right.address),
            bra.w(Label('.1_continue')),

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
            bcs.w(Label('.1_continue')),
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
            bhi.w(Label('.1_gt')),
            // lte branch
            updateObjFacing(right.address),
            bra.w(Label('.1_continue')),

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
            beq.w(Label('.1_continue')),
            bhi.w(Label('.1_gt')),
            // lt branch
            updateObjFacing(right.address),
            bra.w(Label('.1_continue')),

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
            bls.w(Label('.1_continue')),

            // gt branch
            updateObjFacing(down.address),

            // continue
            label(Label('.1_continue')),
          ]));
    });
  });
}
