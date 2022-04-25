import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  test('map model generates asm', () {
    var map = Piata();
    var obj = MapObject(
        startPosition: Position('1e0'.hex, '2e0'.hex),
        spec: Npc(Sprite.palmanMan1, FacingDown()),
        onInteract: Dialog(spans: [Span('Hello world!')]));

    map.addObject(obj);

    var generator = AsmGenerator();

    var mapAsm = generator.mapToAsm(map);
  });

  test('objects refer to appropriate field obj routine ptr', () {
    // a bit hard to test?
  });

  test('sprites are defined', () {});

  test(r'sprites tile numbers are separated by $48', () {});

  test('sprites are referred to by their corresponding objects', () {});

  test('objects with dialog refer to correct dialog offset', () {});

  test('objects use position divided by 8', () {});

  test('objects use correct facing direction', () {});

  group('objects with events or cutscenes', () {
    test('produce event code', () {});

    test('refer to events at the right ptr', () {});
  });
}
