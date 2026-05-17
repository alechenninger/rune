import 'package:rune/asm/text.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  late GameMap map;

  setUp(() {
    map = GameMap(MapId.Test);
  });

  group('palette_tone', () {
    test('increase_tone can save the palette before increasing', () {
      var scene = Scene([
        IncreaseTone(percent: 1, savePalette: true),
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            lea(Palette_Table_Buffer.w, a0),
            lea(Palette_Table_Buffer_2.w, a1),
            move.w(0x3F.i, d7),
            trap(1.i),
            moveq(0x1B.toByte.i, d7),
            label(Label('.increase_tone2')),
            jsr(Label('Pal_IncreaseTone').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.increase_tone2')),
          ]));
    });

    test('restore_tone decreases tone back to the saved palette', () {
      var scene = Scene([
        RestoreTone(percent: 0.5, wait: Duration(milliseconds: 500)),
      ]);

      var program = Program();
      var asm = program.addScene(SceneId('testscene'), scene, startingMap: map);

      expect(
          asm.event.withoutComments(),
          Asm([
            moveq(0x0D.toByte.i, d7),
            label(Label('.restore_tone1')),
            jsr(Label('Pal_DecreaseToneToPal2').l),
            move.w(0x0000.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
            dbf(d7, Label('.restore_tone1')),
            move.w(0x1D.toWord.i, d0),
            jsr(Label('DoMapUpdateLoop').l),
          ]));
    });
  });
}
