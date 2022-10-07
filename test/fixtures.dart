import 'package:rune/asm/asm.dart';
import 'package:rune/generator/generator.dart';

class TestEventRoutines extends EventRoutines {
  final eventRoutines = <Label>[];
  final cutsceneRoutines = <Label>[];

  @override
  Word addEvent(Label name) {
    eventRoutines.add(name);
    return Word(eventRoutines.length - 1);
  }

  @override
  Word addCutscene(Label name) {
    cutsceneRoutines.add(name);
    return Word(cutsceneRoutines.length - 1);
  }
}
