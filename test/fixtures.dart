import 'package:rune/asm/asm.dart';
import 'package:rune/generator/generator.dart';

class TestEventRoutines extends EventRoutines {
  final routines = <Label>[];

  @override
  Word addEvent(Label name) {
    routines.add(name);
    return Word(routines.length - 1);
  }
}
