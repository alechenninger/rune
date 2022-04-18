import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';

import '../asm/asm.dart' hide MoveMnemonic;
import '../model/model.dart';

extension SceneToAsm on Scene {
  SceneAsm toAsm() {
    var generator = AsmGenerator();
    var ctx = EventContext();

    var eventAsm = EventAsm.empty();
    var dialogAsm = DialogAsm.empty();
    Event? lastEvent;
    var generatingDialog = true;
    var lastEventBreak = -1;
    var eventCounter = 1;

    // TODO: think about handling non "dialog" in dialog asm (other control
    //  codes)

    void addDialog(Dialog dialog) {
      if (!generatingDialog) {
        eventAsm.add(popAndRunDialog());
        eventAsm.addNewline();
        generatingDialog = true;
      } else if (lastEvent is Dialog) {
        // Consecutive dialog, new cursor in between each dialog
        dialogAsm.add(cursor());
      }

      dialogAsm.add(dialog.generateAsm(generator, ctx));
    }

    void addEvent(Event event) {
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

    for (var event in events) {
      // TODO: this is a bit brittle. might be better if an event generated both
      // DialogAsm and EventAsm
      if (event is Dialog) {
        addDialog(event);
      } else {
        addEvent(event);
      }

      lastEvent = event;
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
