import '../asm/asm.dart';
import '../asm/dialog.dart';
import '../asm/events.dart';
import '../model/model.dart';
import 'dialog.dart';
import 'event.dart';
import 'generator.dart';

extension SceneToAsm on Scene {
  /// Generate scene assembly in context of some [dialogTree].
  ///
  /// When [dialogTree] are provided, the resulting dialog ASM will be included
  /// in these. When none around provided, the scene has its own trees.
  SceneAsm toAsm(AsmGenerator generator, AsmContext ctx,
      {DialogTree? dialogTree, SceneId? id}) {
    var sceneDialogTree = dialogTree ?? DialogTree();

    return _sceneToAsm(id, this, sceneDialogTree, ctx, generator);
  }
}

SceneAsm _sceneToAsm(SceneId? sceneId, Scene scene, DialogTree dialogTree,
    AsmContext ctx, AsmGenerator generator) {
  var newDialogs = <DialogAsm>[];
  // todo: handle hitting max trees!
  var currentDialogId = dialogTree.nextDialogId!;
  var currentDialog = DialogAsm.empty();
  var lastEventBreak = -1;

  var eventAsm = EventAsm.empty();
  Event? lastEvent;
  var eventCounter = 1;
  var startInEvent = ctx.inEvent;

  void _terminateCurrentDialog({int? at}) {
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

  void _addDialog(Dialog dialog) {
    if (!ctx.inDialogLoop) {
      _goToDialogFromEvent(eventAsm, ctx, currentDialogId);
    } else if (lastEvent is Dialog) {
      // Consecutive dialog, new cursor in between each dialog
      currentDialog.add(interrupt());
    }

    currentDialog.add(generator.dialogToAsm(dialog));
  }

  void _addEvent(Event event) {
    if (!ctx.inEvent) {
      throw StateError('cannot run event after dialog has started');
    } else if (ctx.inDialogLoop) {
      // todo: why did we check this before?
      // i think b/c we always assumed in dialog loop to start
      //if (dialogAsm.isNotEmpty) {
      currentDialog.add(comment('scene event $eventCounter'));
      lastEventBreak = currentDialog.add(eventBreak());
      ctx.hasSavedDialogPosition = true;
      ctx.dialogEventBreak();
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

  var events = scene.events;

  if (!ctx.inEvent) {
    if (!_processableInDialogLoop(scene, ctx)) {
      _startEventFromDialog(ctx, currentDialog, eventAsm, sceneId);
      _terminateCurrentDialog();
    } else if (ctx.isProcessingInteraction) {
      // todo: isn't this always true if not in event?
      var first = events.first;
      // because processable, we assume FacePlayer must mean obj being
      // interacted with, which is what dialog normally does. so skip it.
      if (first is FacePlayer) {
        events = events.skip(1).toList(growable: false);
      } else {
        // otherwise, have to tell dialog loop to not face player.
        currentDialog.add(dc.b(Bytes.of(0xf3)));
      }
    }
  }

  for (var event in events) {
    if (event is Dialog) {
      _addDialog(event);
    } else {
      _addEvent(event);
    }

    lastEvent = event;
  }

  // was lastEventBreak >= 0, but i think it should be this?
  if (!ctx.inDialogLoop && lastEventBreak >= 0) {
    _terminateCurrentDialog(at: lastEventBreak);
  } else if (currentDialog.isNotEmpty) {
    _terminateCurrentDialog();
  }

  if (!startInEvent && ctx.inEvent) {
    eventAsm.add(returnFromInteractionEvent());
  }

  return SceneAsm(event: eventAsm);
}

bool _processableInDialogLoop(Scene scene, AsmContext ctx) {
  var first = scene.events.first;
  return (_isInteractionObjFacePlayer(first, ctx) &&
          scene.events.skip(1).every((event) => event is Dialog)) ||
      scene.events.every((event) => event is Dialog);
}

bool _isInteractionObjFacePlayer(Event event, AsmContext ctx) {
  if (!ctx.isProcessingInteraction) return false;
  if (event is! FacePlayer) return false;
  return event.object == ctx.inAddress(a3)?.obj;
}

void _startEventFromDialog(AsmContext ctx, DialogAsm currentDialog,
    EventAsm eventAsm, SceneId? sceneId) {
  var eventName =
      sceneId?.toString() ?? ctx.peekNextEventIndex.value.toRadixString(16);
  var eventRoutine = Label('Event_GrandCross_$eventName');
  var eventIndex = ctx.addEventPointer(eventRoutine);

  currentDialog.add(runEvent(eventIndex));

  eventAsm.add(setLabel(eventRoutine.name));

  ctx.startEvent(ctx.state);
}

void _goToDialogFromEvent(
    EventAsm eventAsm, AsmContext ctx, Byte currentDialogId) {
  // todo: should this be moved to ctx?
  // todo: different dialog routines are used sometimes
  // may depend on context
  // for example Event_GetAndRunDialogue5 might be used in cutscenes?
  if (ctx.hasSavedDialogPosition) {
    eventAsm.add(popAndRunDialog);
    eventAsm.addNewline();
  } else {
    eventAsm.add(getAndRunDialog(currentDialogId.i));
  }
  ctx.runDialog();
}

@Deprecated('just use EventAsm instead at this point I think')
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

  SceneAsm({required this.event});

  @override
  String toString() {
    return '; event:\n$event';
  }
}
