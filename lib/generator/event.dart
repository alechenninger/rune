import 'package:rune/asm/dialog.dart';
import 'package:rune/generator/generator.dart';

import '../asm/asm.dart' hide Move;
import '../model/model.dart';

extension SceneToAsm on Scene {
  SceneAsm toAsm() {
    var generator = AsmGenerator();
    var ctx = EventContext();

    var event = Asm.empty();
    var dialog = Asm.empty();
    var isDialog = true;

    for (var e in events) {
      if (e is Dialog) {
        isDialog = true;
        dialog.add(e.generateAsm(generator, ctx));
        continue;
      }

      if (isDialog) {
        isDialog = false;
        // or enddialog/terminate? FF
        dialog.add(eventBreak());
      }

      event.add(e.generateAsm(generator, ctx));
    }

    return SceneAsm(event, dialog);
  }
}

class SceneAsm {
  final Asm event;
  final Asm dialog;

  SceneAsm(this.event, this.dialog);
}
