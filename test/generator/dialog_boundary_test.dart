import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import 'assembly_fixtures.dart';

void main() {
  test('full NPC page flows into conditional Alys dialog with one prompt', () {
    final map = GameMap(MapId.StripClub);
    final program = Program();
    final scene = Scene([
      Dialog.parse('They do this number all the time.'),
      Dialog.parse('It’s called ‘Pao-Pao’.'),
      Dialog.parse('‘Pao’ every last meseta to get a '
          'little closer to these beauties.'),
      IfValue(alys.slot(), comparedTo: NullSlot(), notEqual: [
        Dialog.parse("Come on. Let's leave him to it.", speaker: alys),
      ]),
    ]);

    final generated =
        program.addScene(SceneId('test'), scene, startingMap: map);

    expectGenerated((
      event: generated.event,
      dialog: program.dialogTrees.forMap(map.id).toAsm(),
    ), [
      getAndRunDialog3LowDialogId(Byte.zero.i),
      moveq(alys.charIdAddress, d0),
      jsr(FindCharacterSlot.l),
      cmpi.b(0xff.i, d1),
      beq(Label('.5_continue')),
      popdlg,
      jsr(Label('Event_RunDialogue3').l),
      label(Label('.5_continue')),
      jsr(Label('Event_CloseDialog').l),
    ], dialog: [
      dc.b(Bytes.ascii('They do this number all the')),
      dc.b(ControlCodes.newLine),
      dc.b(Bytes.ascii('time.')),
      interrupt(),
      dc.b(Bytes.ascii("It's called [Pao-Pao'.")),
      interrupt(),
      // RunText's full-page interrupt only coalesces a prompt when the next
      // byte is FD, F7, or FF. F8 must run before the text, not between them.
      keepDialog(),
      dc.b(Bytes.ascii("[Pao' every last meseta to get a")),
      dc.b(ControlCodes.newLine),
      dc.b(Bytes.ascii('little closer to these beauties.')),
      eventBreak(),
      keepDialog(),
      portrait(Byte(2)),
      dc.b(Bytes.ascii("Come on. Let's leave him to it.")),
      terminateDialog(),
    ]);
  });

  test('full page at branch end leaves the terminator next to the text', () {
    final map = GameMap(MapId.Test);
    final program = Program();
    final scene = Scene([
      IfValue(alys.slot(), comparedTo: NullSlot(), notEqual: [
        Dialog.parse('‘Pao’ every last meseta to get a '
            'little closer to these beauties.'),
      ]),
      Dialog.parse('Next page'),
    ]);

    final generated =
        program.addScene(SceneId('test'), scene, startingMap: map);

    expectGenerated((
      event: generated.event,
      dialog: program.dialogTrees.forMap(map.id).toAsm(),
    ), [
      moveq(alys.charIdAddress, d0),
      jsr(FindCharacterSlot.l),
      cmpi.b(0xff.i, d1),
      beq(Label('.1_continue')),
      getAndRunDialog3LowDialogId(Byte.zero.i),
      label(Label('.1_continue')),
      getAndRunDialog3LowDialogId(Byte.one.i),
    ], dialog: [
      keepDialog(),
      dc.b(Bytes.ascii("[Pao' every last meseta to get a")),
      dc.b(ControlCodes.newLine),
      dc.b(Bytes.ascii('little closer to these beauties.')),
      terminateDialog(),
      dc.b(Bytes.ascii('Next page')),
      terminateDialog(),
    ]);
  });
}
