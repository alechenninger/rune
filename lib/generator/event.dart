import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';

import '../asm/asm.dart' hide Move;
import '../model/model.dart';

extension SceneToAsm on Scene {
  SceneAsm toAsm() {
    var generator = AsmGenerator();
    var ctx = EventContext();

    var event = Asm.empty();
    var dialog = Asm.empty();
    var dialogMode = true;
    var lastEventBreak = -1;

    for (var e in events) {
      if (e is Dialog) {
        if (!dialogMode) {
          event.add(popAndRunDialog());
        }

        dialogMode = true;
        dialog.add(e.generateAsm(generator, ctx));
        continue;
      }

      if (dialogMode && dialog.isNotEmpty) {
        dialogMode = false;
        // or enddialog/terminate? FF
        // note if use terminate, have to track dialog tree offset
        lastEventBreak = dialog.add(eventBreak());
      }

      event.add(e.generateAsm(generator, ctx));
    }

    if (dialogMode) {
      dialog.add(endDialog());
    } else if (lastEventBreak >= 0) {
      dialog.replace(lastEventBreak, endDialog());
    }

    return SceneAsm(event, dialog);
  }
}

class SceneAsm {
  final Asm event;
  final Asm dialog;

  SceneAsm(this.event, this.dialog);
}
