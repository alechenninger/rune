import 'package:rune/asm/text.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  late GameMap map;

  setUp(() {
    map = GameMap(MapId.Test);
  });

  group('flash_screen', () {
    test('generates basic flash with calm duration', () {
      var scene = Scene([
        FlashScreen(calm: Duration(milliseconds: 500)),
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      // 500ms = ~29 frames at 60fps, rounded to 29 frames for calm
      // The flash itself uses 1 frame flashed, then 27 frames to restore (28 total restore frames)
      // plus 29 frames calm = final wait of 29 frames (0x1D)
      expect(
          asm.event.withoutComments(),
          Asm([
            // Copy current palette to buffer 2
            lea(Palette_Table_Buffer.w, a0),
            lea(Palette_Table_Buffer_2.w, a1),
            move.w(0x3F.i, d7),
            trap(1.i),
            // Flash to white
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash1_0')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash1_0')),
            // Restore palette gradually (28 frames total: 1 implicit + 27 in loop)
            move.w(27.i, d7),
            label(Label('.restore_palette1_0')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.restore_palette1_0')),
            // Calm period (29 frames = 0x1D)
            move.w(0x1D.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('generates flash with sound effect', () {
      var scene = Scene([
        FlashScreen(sound: SoundEffect.lightning, calm: Duration(seconds: 1)),
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            // Copy current palette to buffer 2
            lea(Palette_Table_Buffer.w, a0),
            lea(Palette_Table_Buffer_2.w, a1),
            move.w(0x3F.i, d7),
            trap(1.i),
            // Play sound effect
            move.b(Constant('SFXID_Lightning').i, Constant('Sound_Index').l),
            // Flash to white
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash1_0')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash1_0')),
            // Restore palette
            move.w(27.i, d7),
            label(Label('.restore_palette1_0')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.restore_palette1_0')),
            // Calm period (60 frames = 0x3B)
            move.w(0x3B.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('generates partial flashes before final flash', () {
      var scene = Scene([
        FlashScreen(partialFlashes: [0.5], calm: Duration(milliseconds: 300)),
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            // Copy current palette to buffer 2
            lea(Palette_Table_Buffer.w, a0),
            lea(Palette_Table_Buffer_2.w, a1),
            move.w(0x3F.i, d7),
            trap(1.i),
            // First partial flash (50%)
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash1_0')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash1_0')),
            // Restore to 50% (14 frames: 1 implicit + 13 in loop, ceil(0.5 * 28 - 1) = 13)
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            move.w(13.i, d7),
            label(Label('.restore_palette1_0')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.restore_palette1_0')),
            // Final full flash
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash1_1')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash1_1')),
            // Restore palette fully (28 frames: 1 implicit + 27 in loop)
            move.w(27.i, d7),
            label(Label('.restore_palette1_1')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.restore_palette1_1')),
            // Calm period (17 frames = 0x11)
            move.w(0x11.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('generates multiple partial flashes', () {
      var scene = Scene([
        FlashScreen(
            partialFlashes: [0.25, 0.75], calm: Duration(milliseconds: 500)),
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      // ceil(0.25 * 28 - 1) = 6, ceil(0.75 * 28 - 1) = 20
      expect(
          asm.event.withoutComments(),
          Asm([
            // Copy current palette to buffer 2
            lea(Palette_Table_Buffer.w, a0),
            lea(Palette_Table_Buffer_2.w, a1),
            move.w(0x3F.i, d7),
            trap(1.i),
            // First partial flash (25%)
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash1_0')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash1_0')),
            // Restore to 25% (7 frames: 1 implicit + 6 in loop)
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            move.w(6.i, d7),
            label(Label('.restore_palette1_0')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.restore_palette1_0')),
            // Second partial flash (75%)
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash1_1')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash1_1')),
            // Restore to 75% (21 frames: 1 implicit + 20 in loop)
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            move.w(20.i, d7),
            label(Label('.restore_palette1_1')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.restore_palette1_1')),
            // Final full flash
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash1_2')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash1_2')),
            // Restore palette fully (28 frames: 1 implicit + 27 in loop)
            move.w(27.i, d7),
            label(Label('.restore_palette1_2')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.restore_palette1_2')),
            // Calm period (29 frames = 0x1D)
            move.w(0x1D.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });

    test('respects flashed duration', () {
      var scene = Scene([
        FlashScreen(flashed: Duration(milliseconds: 500), calm: Duration.zero),
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      // 500ms = 30 frames, min(1, 30) = 30 for flashed
      expect(
          asm.event.withoutComments(),
          Asm([
            // Copy current palette to buffer 2
            lea(Palette_Table_Buffer.w, a0),
            lea(Palette_Table_Buffer_2.w, a1),
            move.w(0x3F.i, d7),
            trap(1.i),
            // Flash to white
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash1_0')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash1_0')),
            // Wait for flashed duration (29 frames = 0x1D)
            move.w(0x1D.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            // Restore palette gradually (28 frames: 1 implicit + 27 in loop)
            move.w(27.i, d7),
            label(Label('.restore_palette1_0')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.restore_palette1_0')),
            // No calm period (0 frames)
          ]));
    });

    test('generates zero calm duration', () {
      var scene = Scene([
        FlashScreen(calm: Duration.zero),
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            // Copy current palette to buffer 2
            lea(Palette_Table_Buffer.w, a0),
            lea(Palette_Table_Buffer_2.w, a1),
            move.w(0x3F.i, d7),
            trap(1.i),
            // Flash to white
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash1_0')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash1_0')),
            // Restore palette gradually (28 frames: 1 implicit + 27 in loop)
            move.w(27.i, d7),
            label(Label('.restore_palette1_0')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.restore_palette1_0')),
            // No calm period (0 frames)
          ]));
    });

    test('uses VInt_PrepareLoop when field is not shown (after fadeout)', () {
      var scene = Scene([
        FadeOut(),
        FlashScreen(calm: Duration(milliseconds: 500)),
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      // After fadeout, field is not shown, so should use VInt_PrepareLoop
      // instead of DoMapUpdateLoop, and should restore palette after
      expect(
          asm.event.withoutComments(),
          Asm([
            // FadeOut
            jsr(Label('PalFadeOut_ClrSpriteTbl').l),
            // Copy current palette to buffer 2
            lea(Palette_Table_Buffer.w, a0),
            lea(Palette_Table_Buffer_2.w, a1),
            move.w(0x3F.i, d7),
            trap(1.i),
            // Flash to white
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash2_0')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash2_0')),
            // Restore palette gradually using VInt_Prepare (not DoMapUpdateLoop)
            move.w(27.i, d7),
            label(Label('.restore_palette2_0')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            jsr(Label('VInt_Prepare').l),
            dbf(d7, Label('.restore_palette2_0')),
            // Calm period using VInt_PrepareLoop
            move.w(0x1D.toWord.i, d0),
            jsr(Label('VInt_PrepareLoop').l),
            // Restore map palette and fade in
            movea.l(Constant('Map_Palettes_Addr').w, a0),
            jsr(Label('LoadMapPalette').l),
            jsr(Label('Pal_FadeIn').l),
          ]));
    });

    test('uses VInt_PrepareLoop when panel is shown', () {
      var scene = Scene([
        ShowPanel(PrincipalPanel.shayAndAlys),
        FlashScreen(calm: Duration(milliseconds: 500)),
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      // When panel is shown, should use VInt_PrepareLoop instead of DoMapUpdateLoop
      expect(
          asm.event.withoutComments(),
          Asm([
            // ShowPanel
            move.w(0x0001.toWord.i, d0),
            jsr(Label('Panel_Create').l),
            jsr(Label('DMAPlanes_VInt').l),
            // Copy current palette to buffer 2
            lea(Palette_Table_Buffer.w, a0),
            lea(Palette_Table_Buffer_2.w, a1),
            move.w(0x3F.i, d7),
            trap(1.i),
            // Flash to white
            lea(Palette_Table_Buffer.w, a0),
            moveq(0x1F.i, d7),
            label(Label('.flash2_0')),
            move.l(0x0EEE0EEE.i, a0.postIncrement()),
            dbf(d7, Label('.flash2_0')),
            // Restore palette gradually using VInt_Prepare (not DoMapUpdateLoop)
            move.w(27.i, d7),
            label(Label('.restore_palette2_0')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            jsr(Label('VInt_Prepare').l),
            dbf(d7, Label('.restore_palette2_0')),
            // Calm period using VInt_PrepareLoop
            move.w(0x1D.toWord.i, d0),
            jsr(Label('VInt_PrepareLoop').l),
            // Clean up panel
            jsr(Label('Panel_Destroy').l),
            jsr(Label('DMAPlanes_VInt').l),
          ]));
    });
  });
}
