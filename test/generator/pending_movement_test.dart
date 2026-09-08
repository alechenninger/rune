import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

AbsoluteMoves moving([FieldObject object = shay]) => AbsoluteMoves()
  ..destinations[object] = Position(0x100, 0x100)
  ..waitForMovements = false;

IndividualMoves facing([FieldObject object = shay]) =>
    IndividualMoves()..moves[object] = Face(up);

typedef GeneratedAssembly = ({Asm event, Asm dialog});

GeneratedAssembly generateScene(List<Event> events,
    {GameMap? map, bool interaction = false}) {
  map ??= GameMap(MapId.Test);
  var dialogs = DialogTrees();
  var event = EventAsm.empty();
  var generator = interaction
      ? SceneAsmGenerator.forInteraction(
          map, SceneId('pending'), dialogs, event, TestEventRoutines(),
          withObject: null)
      : SceneAsmGenerator.forEvent(SceneId('pending'), dialogs, event,
          startingMap: map);

  generator.setContext(SetContext((state) {
    state.setSlot(1, alys);
    state.setSlot(2, shay);
    state.cameraLock = true;
  }));
  generator.scene(Scene(events));
  generator.finish();

  return (
    event: event.withoutComments().trim(),
    dialog: dialogs.forMap(map.id).toAsm().withoutComments().trim(),
  );
}

Asm expectedAssembly(Iterable<Asm> fragments) => Asm(fragments.toList()).trim();

void expectGenerated(GeneratedAssembly generated, List<Asm> event,
    {List<Asm> dialog = const []}) {
  expect(generated.event, expectedAssembly(event), reason: 'event assembly');
  expect(generated.dialog, expectedAssembly(dialog), reason: 'dialog assembly');
}

Asm slotA4(int slot) => lea(Constant('Character_$slot').w, a4);

Asm moveShay() => Asm([
      followLeader(false),
      slotA4(2),
      bset(1.i, priority_flag(a4)),
      setDestination(x: 0x100.toWord.i, y: 0x100.toWord.i),
    ]);

Asm moveAlys() => Asm([
      slotA4(1),
      bset(1.i, priority_flag(a4)),
      setDestination(x: 0x80.toWord.i, y: 0x80.toWord.i),
    ]);

Asm restartShay() => Asm([
      bset(1.i, priority_flag(a4)),
      setDestination(x: 0x100.toWord.i, y: 0x100.toWord.i),
    ]);

Asm waitForSlot(int slot, {bool load = true}) => Asm([
      if (load) slotA4(slot),
      jsr(Label('Event_DoWaitForCharacter').l),
      jsr(Label('Field_UpdateObjects').l),
      moveq(0.i, d0),
      move.l(d0, Camera_X_Step_Counter_FG.w),
      move.l(d0, Camera_Y_Step_Counter_FG.w),
      move.l(d0, Camera_X_Step_Counter_BG.w),
      move.l(d0, Camera_Y_Step_Counter_BG.w),
      slotA4(slot),
      bclr(1.i, priority_flag(a4)),
      move.b(Byte.one.i, FieldObj_Step_Offset.w),
    ]);

Asm faceSlot(int slot, {bool load = true}) => Asm([
      if (load) slotA4(slot),
      updateObjFacing(FacingDir_Up.i),
    ]);

Asm finishMovement() => bclr(Byte(2).i, Char_Move_Flags.w);

Asm synchronousMove() => Asm([
      followLeader(false),
      slotA4(2),
      moveCharacter(x: 0x100.toWord.i, y: 0x100.toWord.i),
    ]);

Asm branchHeader(String flag, String unsetLabel) => Asm([
      moveq(Constant('EventFlag_$flag').i, d0),
      jsr(Label('EventFlags_Test').l),
      beq.w(Label(unsetLabel)),
    ]);

Asm dialogMoveRoutine(Label name, {required bool first}) => Asm([
      label(name),
      if (first)
        moveShay()
      else
        Asm([
          slotA4(2),
          restartShay(),
        ]),
      rts,
    ]);

Asm dialogWaitRoutine(Label name) => Asm([
      label(name),
      waitForSlot(2),
      rts,
    ]);

Asm dialogData() => Asm([
      dc.b(Bytes.ascii('Hello')),
      dc.b(ControlCodes.interrupt),
      dc.b([ControlCodes.action, Byte(0x0f)]),
      dc.l([Label('pending_3_AbsoluteMoves')]),
      dc.b([ControlCodes.action, Byte(0x0f)]),
      dc.l([Label('pending_4_WaitForMovements')]),
      dc.b([ControlCodes.action, Byte(0x0f)]),
      dc.l([Label('pending_4_AbsoluteMoves')]),
      dc.b([ControlCodes.action, Byte(0x0f)]),
      dc.l([Label('pending_finishing_WaitForMovements')]),
      dc.b(ControlCodes.terminate),
    ]);

void main() {
  test('waits before operating on the same object through a slot reference',
      () {
    var generated = generateScene([moving(), facing(BySlot.two)]);

    expectGenerated(generated, [
      moveShay(),
      waitForSlot(2, load: false),
      faceSlot(2, load: false),
      finishMovement()
    ]);
  });

  test('does not wait before operating on an unrelated object', () {
    var generated = generateScene([moving(), facing(alys)]);

    expectGenerated(
        generated, [moveShay(), faceSlot(1), waitForSlot(2), finishMovement()]);
  });

  test('an explicit wait completes only the selected movement', () {
    var generated = generateScene([
      moving()..destinations[alys] = Position(0x80, 0x80),
      WaitForMovements([BySlot.two]),
      facing(shay),
    ]);

    expectGenerated(generated, [
      moveShay(),
      moveAlys(),
      waitForSlot(2),
      faceSlot(2),
      waitForSlot(1),
      finishMovement(),
    ]);
  });

  test('waits before restarting an asynchronous movement', () {
    var generated = generateScene([moving(), moving(BySlot.two)]);

    expectGenerated(generated, [
      moveShay(),
      waitForSlot(2, load: false),
      restartShay(),
      waitForSlot(2, load: false),
      finishMovement(),
    ]);
  });

  test('synchronous and empty moves leave nothing to wait for', () {
    var generated = generateScene([
      moving()..waitForMovements = true,
      AbsoluteMoves()..waitForMovements = false,
    ]);

    expectGenerated(generated, [synchronousMove(), finishMovement()]);
  });

  test('a possible movement from a branch is waited for after the join', () {
    var generated = generateScene([
      IfFlag(EventFlag('moving'), isSet: [moving()]),
      facing(BySlot.two),
    ]);

    expectGenerated(generated, [
      branchHeader('moving', '.moving_unset1'),
      moveShay(),
      setLabel('.moving_unset1'),
      waitForSlot(2),
      faceSlot(2, load: false),
      finishMovement(),
    ]);
  });

  test('a conditional wait does not complete movement on the other path', () {
    var generated = generateScene([
      moving(),
      IfFlag(EventFlag('waiting'), isSet: [
        WaitForMovements([BySlot.two])
      ]),
    ]);

    expectGenerated(generated, [
      moveShay(),
      branchHeader('waiting', '.waiting_unset2'),
      waitForSlot(2, load: false),
      setLabel('.waiting_unset2'),
      waitForSlot(2),
      finishMovement(),
    ]);
  });

  test('dialog-only movements generate unique movement and wait routines', () {
    var generated = generateScene([
      Dialog(spans: [DialogSpan('Hello')]),
      moving(),
      moving(BySlot.two),
    ], interaction: true);

    expectGenerated(generated, [
      dialogMoveRoutine(Label('pending_3_AbsoluteMoves'), first: true),
      newLine(),
      dialogWaitRoutine(Label('pending_4_WaitForMovements')),
      newLine(),
      dialogMoveRoutine(Label('pending_4_AbsoluteMoves'), first: false),
      newLine(),
      dialogWaitRoutine(Label('pending_finishing_WaitForMovements')),
    ], dialog: [
      dialogData()
    ]);
  });

  test('map object references resolve to the same moving object', () {
    var map = GameMap(MapId.Test);
    var npc = MapObject(
        id: 'npc', startPosition: Position(0, 0), spec: AlysWaiting());
    map.addObject(npc);
    var memory = Memory()..currentMap = map;

    var generated =
        generateScene([moving(MapObjectById.of('npc')), facing(npc)], map: map);

    expectGenerated(generated, [
      npc.toA4(memory),
      move.w(0x8194.toWord.i, a4.indirect),
      bset(1.i, priority_flag(a4)),
      setDestination(x: 0x100.toWord.i, y: 0x100.toWord.i),
      moveCharacter(x: dest_x_pos(a4), y: dest_y_pos(a4)),
      bclr(1.i, priority_flag(a4)),
      move.b(Byte.one.i, FieldObj_Step_Offset.w),
      updateObjFacing(FacingDir_Up.i),
      finishMovement(),
    ]);
  });
}
