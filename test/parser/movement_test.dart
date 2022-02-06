import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:rune/parser/movement.dart';
import 'package:test/test.dart';

void main() {
  test('parses individual moves', () {
    var events = parseEvents(r'''Alys starts at #230, #250
Shay starts at #230, #240
Alys is in slot 1
Shay is in slot 2
Alys walks 7 steps right, 10 steps up.
After 5 steps, Shay walks 7 right, 2 steps up.
The camera locks.
Alys walks 2 steps up and faces up.''');

    var scene = Scene(events);
    var generator = AsmGenerator();

    print(generator.sceneToAsm(scene));
  });
}
