import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  test('Talk dialog around an event pause uses Talk helpers and returns', () {
    var program = Program(eventPointers: EventPointers.empty());
    var before = Dialog(spans: [DialogSpan('Before')]);
    var after = Dialog(spans: [DialogSpan('After')]);
    var asm = program.addTalk(Scene([
      before,
      Pause(Duration(milliseconds: 500)),
      after,
    ]));

    expect(
        asm.withoutComments().trim(),
        Asm([
          setLabel('Event_GrandCross_Talk'),
          move.b(SoundEffect.selection.sfxId.i, Constant('Sound_Index').l),
          moveq(Byte.one.i, d0),
          jsr(Label('Talk_Event_GetAndRunDialogue3').l),
          move.w(Word(29).i, d0),
          jsr(Label('DoMapUpdateLoop').l),
          popdlg,
          jsr(Label('Talk_Event_RunDialogue3').l),
          rts,
        ]));
    expect(program.eventPointers.withoutComments().trim(),
        dc.l([Label('Event_GrandCross_Talk')]));
    expect(
        program.dialogTrees.forTalk().map((d) => d.withoutComments()).toList(),
        [
          DialogAsm([
            dc.b([Byte(0xF6)]),
            dc.w([Word(0)]),
            terminateDialog(),
          ]),
          DialogAsm([
            before.toAsm(),
            eventBreak(),
            after.toAsm(),
            terminateDialog(),
          ]),
        ]);
  });

  test('a leading pause closes the inherited window before waiting', () {
    var program = Program(eventPointers: EventPointers.empty());
    var after = Dialog(spans: [DialogSpan('After')]);
    var asm = program.addTalk(Scene([
      Pause(Duration(milliseconds: 500)),
      after,
    ]));

    expect(
        asm.withoutComments().trim(),
        Asm([
          setLabel('Event_GrandCross_Talk'),
          jsr(Label('Talk_Event_CloseDialog').l),
          move.w(Word(29).i, d0),
          jsr(Label('DoMapUpdateLoop').l),
          move.b(SoundEffect.selection.sfxId.i, Constant('Sound_Index').l),
          moveq(Byte.one.i, d0),
          jsr(Label('Talk_Event_GetAndRunDialogue3').l),
          rts,
        ]));
    expect(program.eventPointers.withoutComments().trim(),
        dc.l([Label('Event_GrandCross_Talk')]));
    expect(
        program.dialogTrees.forTalk().map((d) => d.withoutComments()).toList(),
        [
          DialogAsm([
            dc.b([Byte(0xF6)]),
            dc.w([Word(0)]),
            terminateDialog(),
          ]),
          DialogAsm([
            after.toAsm(),
            terminateDialog(),
          ]),
        ]);
  });

  test('panel disposition remains Talk-specific for new dialog', () {
    var mode = TalkMode().toEventMode(EventType.event).enterDialogLoop();
    expect(
        mode.execution
            .runDialog(resume: false, onClose: DialogOnClose.destroyPanels),
        jsr(Label('Talk_Event_GetAndRunDialogue').l));
    expect(
        () => mode.execution.runDialog(
            resume: false, onClose: DialogOnClose.fadeOutAndDestroyPanels),
        throwsA(isA<UnsupportedError>()));
  });

  test('Talk execution survives dialog transitions and supports resume', () {
    var mode = TalkMode()
        .toEventMode(EventType.event)
        .enterDialogLoop()
        .exitDialogLoop();
    expect(mode.priorMode, isA<TalkMode>());
    expect(
        mode.execution
            .runDialog(resume: true, onClose: DialogOnClose.leavePanels),
        jsr(Label('Talk_Event_RunDialogue3').l));
    expect(
        mode.execution
            .runDialog(resume: true, onClose: DialogOnClose.destroyPanels),
        jsr(Label('Talk_Event_RunDialogue').l));
  });

  test('explicit execution is retained independently of the prior mode', () {
    const execution = TalkEventExecution();
    var mode = EventMode(type: EventType.event, execution: execution);
    var inDialog = mode.enterDialogLoop();
    var afterDialog = inDialog.exitDialogLoop();

    expect(mode.priorMode, isNull);
    expect(mode.execution, same(execution));
    expect(inDialog.execution, same(execution));
    expect(inDialog.isInDialogLoop, isTrue);
    expect(afterDialog.execution, same(execution));
    expect(afterDialog.isInDialogLoop, isFalse);
  });

  test('Talk rejects transitions to cutscene mode', () {
    var routines = TestEventRoutines();
    var asm = EventAsm.empty();
    var generator = SceneAsmGenerator.forTalk(DialogTrees(), asm, routines);

    expect(() => generator.runEvent(type: EventType.cutscene),
        throwsA(isA<UnsupportedError>()));
    expect(() => TalkMode().toEventMode(EventType.cutscene),
        throwsA(isA<UnsupportedError>()));
  });

  test('nested Talk cutscenes report a compilation error', () {
    expect(
        () => Program().addTalk(Scene([
              IfFlag(EventFlag('branch'), isSet: [
                FadeOut(),
                Dialog(spans: [DialogSpan('Unsupported')]),
              ]),
            ])),
        throwsA(isA<GeneratorException>()
            .having((e) => e.cause, 'cause', isA<UnsupportedError>())));
  });
}
