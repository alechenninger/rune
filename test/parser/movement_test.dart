import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:rune/parser/movement.dart';
import 'package:test/test.dart';

void main() {
  test('parses individual moves', () {
    var events = parseEvents(r'''Alys starts at 100, 100
Shay starts at 100, 110
Alys is in slot 1
Shay is in slot 2
Alys walks 10 steps right, 12 steps up.
After 5 steps, Shay walks 10 right, 5 steps up.''');

    var scene = Scene(events);
    var generator = AsmGenerator();

    print(generator.sceneToAsm(scene));
  });
}
