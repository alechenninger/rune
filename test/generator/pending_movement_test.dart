import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/labels.dart';
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

// Expected direction calculation after loading the X/Y deltas into d2/d3.
// Callers spell out coordinate reads, zero-vector fallback, and facing update.
Asm vectorDirection(String suffix) => Asm([
      move.w(d2, d4),
      bpl.s(Label('.positive_dx$suffix')),
      neg.w(d4),
      label(Label('.positive_dx$suffix')),
      move.w(d3, d5),
      bpl.s(Label('.positive_dy$suffix')),
      neg.w(d5),
      label(Label('.positive_dy$suffix')),
      cmp.w(d4, d5),
      bgt.s(Label('.checky$suffix')),
      tst.w(d4),
      beq.s(Label('.zerovector$suffix')),
      tst.w(d2),
      bpl.s(Label('.right$suffix')),
      move.w(FacingDir_Left.i, d0),
      bra.s(Label('.keep$suffix')),
      label(Label('.right$suffix')),
      move.w(FacingDir_Right.i, d0),
      bra.s(Label('.keep$suffix')),
      label(Label('.checky$suffix')),
      tst.w(d3),
      bpl.s(Label('.down$suffix')),
      move.w(FacingDir_Up.i, d0),
      bra.s(Label('.keep$suffix')),
      label(Label('.down$suffix')),
      move.w(FacingDir_Down.i, d0),
      bra.s(Label('.keep$suffix')),
      label(Label('.zerovector$suffix')),
    ]);

Asm faceSlotTowardShay(int slot, String suffix) => Asm([
      lea(Constant('Character_2').w, a3),
      move.w(curr_x_pos(a3), d2),
      slotA4(slot),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection(suffix),
      move.w(facing_dir(a4), d0),
      label(Label('.keep$suffix')),
      jsr(Label('Event_UpdateObjFacing').l),
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
  test('self-facing through a slot alias does not wait for movement', () {
    var generated = generateScene([
      moving(),
      Face(BySlot.two.towards(shay)).move(BySlot.two),
      facing(alys),
      WaitForMovements([shay]),
    ]);

    expectGenerated(
        generated, [moveShay(), faceSlot(1), waitForSlot(2), finishMovement()]);
  });

  test('party facing a moving member waits only after facing', () {
    var generated = generateScene([
      moving(),
      IndividualMoves()
        ..moves.addEntries(
            BySlot.all.map((slot) => MapEntry(slot, Face(slot.towards(shay))))),
      WaitForMovements([shay]),
    ]);
    expectGenerated(generated, [
      moveShay(),
      move.w(curr_x_pos(a4), d2),
      slotA4(1),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_2').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_Alys_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_Alys_0_0')),
      slotA4(1),
      jsr(Label('Event_UpdateObjFacing').l),
      for (var slot in [3, 4, 5])
        faceSlotTowardShay(slot, '_2_Slot${slot}_0_${slot - 2}'),
      waitForSlot(2),
      finishMovement(),
    ]);
  });

  test('party self-facing in dialog bytecode leaves movement pending', () {
    var state = Memory()
      ..setSlot(1, alys)
      ..setSlot(2, shay)
      ..startMovement(shay);
    var (asm, routines) = FaceInDialogByteCode({
      for (var slot in BySlot.all) slot: slot.towards(shay),
    }).toAsm(state, labeller: Labeller.localTo('pending'));

    expect(routines, isEmpty);
    expect(state.hasPendingMovement(shay), isTrue);
    expect(
        asm,
        Asm([
          for (var slot in BySlot.all.where((slot) => slot != BySlot.two)) ...[
            dc.b(
                [ControlCodes.action, Byte(0xE), Byte(slot.compactId(state)!)]),
            dc.w([Word(shay.compactId(state)! | 0x100)]),
          ],
        ]));
  });

  test('self-facing in a dialog routine leaves movement pending', () {
    var state = Memory()
      ..setSlot(1, alys)
      ..setSlot(2, shay)
      ..startMovement(shay);
    var moves = IndividualMoves()
      ..moves[BySlot.two] = Face(BySlot.two.towards(shay))
      ..moves[alys] = Face(alys.towards(shay));
    var (asm, routines) = FaceInDialogRoutine(moves).toAsm(state,
        labeller: Labeller.localTo('pending'),
        fieldRoutines: defaultFieldRoutines);

    expect(state.hasPendingMovement(shay), isTrue);
    expect(
        asm,
        Asm([
          dc.b([ControlCodes.action, Byte(0xF)]),
          dc.l([Label('pending_FaceInDialog')]),
        ]));
    expect(routines, [
      Asm([
        label(Label('pending_FaceInDialog')),
        faceSlotTowardShay(1, '_Alys_0_0'),
        rts,
      ]),
    ]);
  });

  test('actual movement with self-facing still waits for pending movement', () {
    var generated = generateScene([
      moving(),
      IndividualMoves()
        ..moves[BySlot.two] = (StepPaths()
          ..step(StepPath()
            ..direction = right
            ..distance = 1.step)
          ..face(BySlot.two.towards(shay))),
    ]);
    expectGenerated(generated, [
      moveShay(),
      waitForSlot(2, load: false),
      move.w(curr_x_pos(a4), d0),
      move.w(curr_y_pos(a4), d1),
      addi.w(0x10.toWord.i, d0),
      jsr(Label('Event_MoveCharacter').l),
      finishMovement(),
    ]);
  });

  test('zero-vector facing with a different fallback still waits', () {
    var generated = generateScene([
      SetContext((state) => state.setFacing(alys, up)),
      moving(),
      Face(DirectionOfVector(
        from: BySlot.two.position(),
        to: shay.position(),
        zeroValue: alys.facing(),
      )).move(BySlot.two),
    ]);

    expectGenerated(generated, [
      moveShay(),
      waitForSlot(2, load: false),
      slotA4(1),
      move.w(facing_dir(a4), -(sp)),
      slotA4(2),
      move.w(sp.postIncrement(), d0),
      jsr(Label('Event_UpdateObjFacing').l),
      finishMovement(),
    ]);
  });

  for (var waitFirst in [false, true]) {
    test('reads a moving target position at runtime with waitFirst=$waitFirst',
        () {
      var generated = generateScene([
        SetContext((state) {
          state.positions[alys] = Position(0x80, 0x100);
          state.positions[shay] = Position(0x100, 0x80);
        }),
        moving(),
        if (waitFirst) WaitForMovements([shay]),
        IndividualMoves()..moves[alys] = Face(alys.towards(shay)),
      ]);
      var suffix = waitFirst ? '_3_Alys_0_0' : '_2_Alys_0_0';
      expectGenerated(generated, [
        moveShay(),
        if (waitFirst) waitForSlot(2, load: false),
        move.w(curr_x_pos(a4), d2),
        subi.w(0x80.toWord.i, d2),
        move.w(curr_y_pos(a4), d3),
        subi.w(0x100.toWord.i, d3),
        vectorDirection(suffix),
        slotA4(1),
        move.w(facing_dir(a4), d0),
        label(Label('.keep$suffix')),
        slotA4(1),
        jsr(Label('Event_UpdateObjFacing').l),
        if (!waitFirst) waitForSlot(2),
        finishMovement(),
      ]);
    });
  }

  test('a wait does not overwrite a newer position', () {
    var position = Position(0x80, 0x80);
    generateScene([
      moving(),
      InstantMoves()..move(shay, to: position),
      WaitForMovements([shay]),
      SetContext((state) => expect(state.positions[shay], position)),
    ]);
  });

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
