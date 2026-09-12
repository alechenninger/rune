import 'package:rune/asm/dialog.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/generator/labels.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  Asm generate(Memory memory, DialogCapableMode mode,
          {HorizontalAlignment alignment = HorizontalAlignment.left,
          Speaker? speaker}) =>
      Dialog.parse('Hello', speaker: speaker, portraitAlignment: alignment)
          .toGeneratedAsm(memory, mode,
              labeller: Labeller(), fieldRoutines: defaultFieldRoutines)
          .$1;

  test('Talk emits each alignment and preserves encoding through mode changes',
      () {
    var talk = TalkMode();
    var event = talk.toEventMode(EventType.event);
    for (var mode in [
      talk,
      event,
      event.enterDialogLoop(),
      event.exitDialogLoop()
    ]) {
      for (var (alignment, byte) in [
        (HorizontalAlignment.left, 0),
        (HorizontalAlignment.center, 1),
        (HorizontalAlignment.right, 2),
      ]) {
        expect(
            generate(Memory(), mode, speaker: alys, alignment: alignment),
            Asm([
              dc.b([Byte(0xf4), Byte(2), Byte(byte)]),
              dc.b(Bytes.ascii('Hello')),
            ]));
      }
    }
  });

  test(
      'same speaker moving emits a portrait code; unchanged alignment does not',
      () {
    var memory = Memory();
    var mode = TalkMode();
    generate(memory, mode, speaker: alys);
    expect(
        generate(memory, mode,
            speaker: alys, alignment: HorizontalAlignment.right),
        Asm([
          dc.b([Byte(0xf4), Byte(2), Byte(2)]),
          dc.b(Bytes.ascii('Hello')),
        ]));
    expect(
        generate(memory, mode,
            speaker: alys, alignment: HorizontalAlignment.right),
        dc.b(Bytes.ascii('Hello')));
    expect(memory.branch().portraitAlignment, HorizontalAlignment.right);
  });

  test('clearing a Talk portrait includes the position byte', () {
    var memory = Memory();
    var mode = TalkMode();
    generate(memory, mode, speaker: alys);
    expect(
        generate(memory, mode),
        Asm([
          dc.b([Byte(0xf4), Byte.zero, Byte.zero]),
          dc.b(Bytes.ascii('Hello')),
        ]));
  });

  test('field modes reject unsupported alignment even with a cached portrait',
      () {
    var interaction = InteractionMode.noObject();
    for (var mode in [
      interaction,
      interaction.toEventMode(EventType.event),
      RunEventMode().toEventMode(EventType.event)
    ]) {
      var memory = Memory();
      expect(
          generate(memory, mode, speaker: alys),
          Asm([
            dc.b([Byte(0xf4), Byte(2)]),
            dc.b(Bytes.ascii('Hello')),
          ]));
      for (var alignment in [
        HorizontalAlignment.center,
        HorizontalAlignment.right
      ]) {
        expect(
            () => generate(memory, mode, speaker: alys, alignment: alignment),
            throwsArgumentError);
      }
    }
  });

  test('Talk portraits around an event pause retain their menu encoding', () {
    var program = Program(eventPointers: EventPointers.empty());
    program.addTalk(Scene([
      Dialog.parse('Before', speaker: alys),
      Pause(Duration(milliseconds: 500)),
      Dialog.parse('After',
          speaker: alys, portraitAlignment: HorizontalAlignment.right),
    ]));
    expect(
        program.dialogTrees.forTalk().map((d) => d.withoutComments()).toList(),
        [
          DialogAsm([
            dc.b([Byte(0xf6)]),
            dc.w([Word(0)]),
            terminateDialog(),
          ]),
          DialogAsm([
            dc.b([Byte(0xf4), Byte(2), Byte.zero]),
            dc.b(Bytes.ascii('Before')),
            eventBreak(),
            dc.b([Byte(0xf4), Byte(2), Byte(2)]),
            dc.b(Bytes.ascii('After')),
            terminateDialog(),
          ]),
        ]);
  });

  test('dialogue equality includes portrait alignment', () {
    expect(Dialog.parse('Hello', portraitAlignment: HorizontalAlignment.right),
        isNot(Dialog.parse('Hello')));
    expect(
        Dialog.parse('Hello', portraitAlignment: HorizontalAlignment.right),
        Dialog(
            spans: [DialogSpan('Hello')],
            portraitAlignment: HorizontalAlignment.right));
  });

  test('a panel opening a Talk dialog uses the menu portrait format', () {
    var program = Program(eventPointers: EventPointers.empty());
    program.addTalk(Scene([
      ShowPanel(PanelByIndex(1), portrait: alys.portrait),
    ]));
    expect(
        program.dialogTrees.forTalk().map((d) => d.withoutComments()).toList(),
        [
          DialogAsm([
            dc.b([Byte(0xf6)]),
            dc.w([Word(0)]),
            terminateDialog(),
          ]),
          DialogAsm([
            dc.b([Byte(0xf4), Byte(2), Byte.zero]),
            dc.b([Byte(0xf2), Byte.zero]),
            dc.w([Word(1)]),
            terminateDialog(),
          ]),
        ]);
  });
}
