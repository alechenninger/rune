import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';

import '../asm/asm.dart' hide MoveMnemonic;
import '../model/model.dart';

extension SceneToAsm on Scene {
  SceneAsm toAsm() {
    var generator = AsmGenerator();
    var ctx = EventContext();

    var eventAsm = Asm.empty();
    var dialogAsm = Asm.empty();
    var generatingDialog = true;
    var lastEventBreak = -1;
    var eventCounter = 1;

    for (var event in events) {
      if (event is Dialog) {
        if (!generatingDialog) {
          eventAsm.add(popAndRunDialog());
          eventAsm.addNewline();
        }

        generatingDialog = true;
        dialogAsm.add(event.generateAsm(generator, ctx));
        continue;
      }

      if (generatingDialog && dialogAsm.isNotEmpty) {
        generatingDialog = false;
        // or enddialog/terminate? FF
        // note if use terminate, have to track dialog tree offset
        dialogAsm.add(comment('scene event $eventCounter'));
        lastEventBreak = dialogAsm.add(eventBreak());
      }

      var generated = event.generateAsm(generator, ctx);

      if (generated.isNotEmpty) {
        eventAsm.add(comment('scene event $eventCounter'));
        eventAsm.add(comment('generated from type: ${event.runtimeType}'));
        eventAsm.add(generated);
        eventCounter++;
      }
    }

    if (generatingDialog) {
      dialogAsm.add(endDialog());
    } else if (lastEventBreak >= 0) {
      dialogAsm.replace(lastEventBreak, endDialog());
    }

    return SceneAsm(eventAsm, dialogAsm);
  }
}

class SceneAsm {
  final Asm event;
  final Asm dialog;

  SceneAsm(this.event, this.dialog);

  @override
  String toString() {
    return '; event:\n$event\n; dialog:\n$dialog';
  }
}
