import 'package:rune/generator/dialog.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  test('map model generates asm', () {
    var map = Piata();
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.palmanMan1, FacingDown()),
        onInteract: Dialog());
  });
}
