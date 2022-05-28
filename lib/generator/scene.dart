import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';

import '../asm/asm.dart';
import '../model/model.dart';

extension SceneToAsm on Scene {
  /// Generate scene assembly in context of some [dialogTrees].
  ///
  /// When [dialogTrees] are provided, the resulting dialog ASM will be included
  /// in these. When none around provided, the scene has its own trees.
  SceneAsm toAsm(AsmContext ctx, [DialogTree? dialogTrees]) {
    // todo: should this be passed in?
    var generator = AsmGenerator();
    var sceneDialogTrees = dialogTrees ?? DialogTree();

    return _sceneToAsm(this, sceneDialogTrees, ctx, generator);
  }
}

SceneAsm _sceneToAsm(Scene scene, DialogTree dialogTree, AsmContext ctx,
    AsmGenerator generator) {
  var newDialogs = <DialogAsm>[];
  // todo: handle hitting max trees!
  var currentDialogId = dialogTree.nextDialogId!,
      dialogIdOffset = currentDialogId;
  var currentDialog = DialogAsm.empty();
  var lastEventBreak = -1;

  var eventAsm = EventAsm.empty();
  var eventPtrsAsm = Asm.empty();
  Event? lastEvent;
  var eventCounter = 1;

  void terminateCurrentDialogTree({int? at}) {
    // todo: this is probably only ever the last line
    //   so we could remove parameter and just check if last line is an event
    //   break control code and if so replace that?
    if (at != null) {
      currentDialog.replace(at, terminateDialog());
    } else {
      currentDialog.add(terminateDialog());
    }

    newDialogs.add(currentDialog);
    dialogTree.add(currentDialog);
    currentDialog = DialogAsm.empty();
    // todo: handle hitting max trees!
    currentDialogId = dialogTree.nextDialogId!;
    lastEventBreak = -1;
    ctx.hasSavedDialogPosition = false;
  }

  void addDialog(Dialog dialog) {
    if (!ctx.inDialogLoop) {
      _goToDialogFromEvent(eventAsm, ctx, currentDialogId);
    } else if (lastEvent is Dialog) {
      // Consecutive dialog, new cursor in between each dialog
      currentDialog.add(interrupt());
    }

    currentDialog.add(dialog.generateAsm(generator, ctx));
  }

  void addEvent(Event event) {
    if (!ctx.inEvent) {
      throw StateError('cannot run event after dialog has started');
    } else if (ctx.inDialogLoop) {
      // todo: why did we check this before?
      // i think b/c we always assumed in dialog loop to start
      //if (dialogAsm.isNotEmpty) {
      currentDialog.add(comment('scene event $eventCounter'));
      lastEventBreak = currentDialog.add(eventBreak());
      ctx.hasSavedDialogPosition = true;
    }

    var generated = event.generateAsm(generator, ctx);

    if (generated.isNotEmpty) {
      eventAsm.add(comment('scene event $eventCounter'));
      eventAsm.add(comment('generated from type: ${event.runtimeType}'));
      eventAsm.add(generated);
      eventCounter++;
    }
  }

  // todo: event code checks first

  if (!ctx.inEvent && scene.events.any((event) => event is! Dialog)) {
    _startEventFromDialog(ctx, currentDialog, eventPtrsAsm, eventAsm);
    terminateCurrentDialogTree();
  }

  for (var event in scene.events) {
    // TODO: this is a bit brittle. might be better if an event generated both
    // DialogAsm and EventAsm
    if (event is Dialog) {
      addDialog(event);
    } else {
      addEvent(event);
    }

    lastEvent = event;
  }

  if (lastEventBreak >= 0) {
    terminateCurrentDialogTree(at: lastEventBreak);
  } else if (currentDialog.isNotEmpty) {
    terminateCurrentDialogTree();
  }

  return SceneAsm(
      event: eventAsm,
      dialog: newDialogs,
      dialogIdOffset: dialogIdOffset,
      eventPointers: eventPtrsAsm);
}

void _startEventFromDialog(AsmContext ctx, DialogAsm currentDialogTree,
    Asm eventPtrAsm, EventAsm eventAsm) {
  var eventIndex = ctx.nextEventIndex();

  currentDialogTree.add(runEvent(eventIndex));

  // todo: nice event name
  var eventRoutine =
      Label('Event_GrandCross_${eventIndex.value.toRadixString(16)}');
  eventPtrAsm.add(dc.l([eventRoutine], comment: '$eventIndex'));

  eventAsm.add(setLabel(eventRoutine.name));

  ctx.startEvent();
}

void _goToDialogFromEvent(
    EventAsm eventAsm, AsmContext ctx, Byte currentDialogId) {
  if (ctx.hasSavedDialogPosition) {
    eventAsm.add(popAndRunDialog());
    eventAsm.addNewline();
    ctx.gameMode = Mode.dialog;
  } else {
    eventAsm.add(getAndRunDialog(currentDialogId.i));
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
  final Byte dialogIdOffset;
  // could have multiple in case there are multiple branches each with their own
  // event at the top of the dialog
  // this could also be implemented within one event itself, though
  final Asm eventPointers;

  // if empty should just be FF?
  Asm get allDialog {
    var all = Asm.empty();

    for (var i = 0; i < dialog.length; i++) {
      all.add(comment('${dialogIdOffset + i.byte}'));
      all.add(dialog[i]);
      all.addNewline();
    }

    return all;
  }

  SceneAsm(
      {required this.event,
      required this.dialogIdOffset,
      required this.dialog,
      required this.eventPointers});

  @override
  String toString() {
    return '; event:\n$event\n; dialog:\n$allDialog\n; eventPtr:\n$eventPointers';
  }
}
