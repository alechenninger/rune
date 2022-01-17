import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';

import '../asm/asm.dart' hide MoveMnemonic;
import '../model/model.dart';

extension SceneToAsm on Scene {
  SceneAsm toAsm() {
    var generator = AsmGenerator();
    var ctx = EventContext();

    var event = Asm.empty();
    var dialog = Asm.empty();
    var dialogMode = true;
    var lastEventBreak = -1;
    var eventCounter = 1;

    for (var e in events) {
      if (e is Dialog) {
        if (!dialogMode) {
          event.add(popAndRunDialog());
          event.addNewline();
        }

        dialogMode = true;
        dialog.add(e.generateAsm(generator, ctx));
        continue;
      }

      if (dialogMode && dialog.isNotEmpty) {
        dialogMode = false;
        // or enddialog/terminate? FF
        // note if use terminate, have to track dialog tree offset
        dialog.add(comment('scene event $eventCounter'));
        lastEventBreak = dialog.add(eventBreak());
      }

      event.add(comment('scene event $eventCounter'));
      event.add(e.generateAsm(generator, ctx));

      eventCounter++;
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
