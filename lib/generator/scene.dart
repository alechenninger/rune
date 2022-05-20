import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';

import '../asm/asm.dart';
import '../model/model.dart';

extension SceneToAsm on Scene {
  SceneAsm toAsm(AsmContext ctx) {
    var generator = AsmGenerator();

    var eventAsm = EventAsm.empty();
    var dialogAsm = DialogAsm.empty();
    var eventPtrAsm = Asm.empty();
    Event? lastEvent;
    var lastEventBreak = -1;
    var eventCounter = 1;

    // TODO: think about handling non "dialog" in dialog asm (other control
    //  codes)

    void addDialog(Dialog dialog) {
      if (!ctx.inDialogLoop) {
        eventAsm.add(popAndRunDialog());
        eventAsm.addNewline();
        ctx.gameMode = Mode.dialog;
      } else if (lastEvent is Dialog) {
        // Consecutive dialog, new cursor in between each dialog
        dialogAsm.add(interrupt());
      }

      dialogAsm.add(dialog.generateAsm(generator, ctx));
    }

    void addEvent(Event event) {
      if (ctx.inDialogLoop) {
        if (!ctx.inEvent) {
          var eventIndex = ctx.nextEventIndex();

          lastEventBreak = dialogAsm.add(runEvent(eventIndex));

          // todo: nice event name
          var eventRoutine = Label('Event_$eventIndex');
          eventPtrAsm.add(dc.l([eventRoutine], comment: '$eventIndex'));

          eventAsm.add(setLabel(eventRoutine.name));
        } else {
          // todo: why did we check this before?
          //if (dialogAsm.isNotEmpty) {

          // or enddialog/terminate? FF
          // note if use terminate, have to track dialog tree offset
          dialogAsm.add(comment('scene event $eventCounter'));
          lastEventBreak = dialogAsm.add(eventBreak());
        }

        ctx.startEvent();
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

    if (ctx.inDialogLoop) {
      dialogAsm.add(terminateDialog());
    } else if (lastEventBreak >= 0) {
      dialogAsm.replace(lastEventBreak, terminateDialog());
    }

    return SceneAsm(
        event: eventAsm, dialog: [dialogAsm], eventPtr: eventPtrAsm);
  }
}

class SceneAsm {
  /*
  should we label this?
  in event mode, no. ... already within an event routine.

  in dialog, and we generate event, it must be labeled and have an event
  pointer.

  in that case where does the output go?

  i guess anywhere in the code. the dialog jump uses jsr which has 16mb of
  range–larger than a normal rom can be.
   */
  final Asm event;
  final List<Asm> dialog;
  final Asm eventPtr;

  // if empty should just be FF?
  Asm get allDialog {
    var all = Asm.empty();

    for (var i = 0; i < dialog.length; i++) {
      // todo: may also want some dialog index offset in the context
      // otherwise this will only be accurate per scene
      all.add(comment('$i'));
      all.add(dialog[i]);
      all.addNewline();
    }

    return all;
  }

  SceneAsm({required this.event, required this.dialog, required this.eventPtr});

  @override
  String toString() {
    return '; event:\n$event\n; dialog:\n$allDialog\n; eventPtr:\n$eventPtr';
  }
}
