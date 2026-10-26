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
import 'assembly_fixtures.dart';

AbsoluteMoves moving([FieldObject object = shay]) => AbsoluteMoves()
  ..destinations[object] = Position(0x100, 0x100)
  ..waitForMovements = false;

IndividualMoves facing([FieldObject object = shay]) =>
    IndividualMoves()..moves[object] = Face(up);

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
  test('ordinary pause invalidates facing toward a pending movement', () {
    final generated = generateScene([
      moving(),
      Face(alys.towards(shay)).move(alys),
      Pause(const Duration(seconds: 1)),
      SetContext((state) {
        expect(state.getFacing(alys), isNull);
        expect(state.hasPendingMovement(shay), isTrue);
      }),
      Face(alys.towards(shay)).move(alys),
    ]);

    expectGenerated(generated, [
      moveShay(),
      move.w(curr_x_pos(a4), d2),
      lea(Constant('Character_1').w, a4),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_2').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_Alys_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_Alys_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
      move.w(Word(0x003b).i, d0),
      jsr(Label('DoMapUpdateLoop').l),
      lea(Constant('Character_2').w, a3),
      move.w(curr_x_pos(a3), d2),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_4_Alys_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_4_Alys_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
      waitForSlot(2),
      finishMovement(),
    ]);
  });

  test('movement delay invalidates facing toward a pending movement', () {
    final generated = generateScene([
      moving(),
      Face(alys.towards(shay)).move(alys),
      (StepPath()..delay = 1.step).move(rune),
      SetContext((state) {
        expect(state.getFacing(alys), isNull);
        expect(state.hasPendingMovement(shay), isTrue);
      }),
      Face(alys.towards(shay)).move(alys),
    ]);

    expectGenerated(generated, [
      moveShay(),
      move.w(curr_x_pos(a4), d2),
      lea(Constant('Character_1').w, a4),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_2').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_Alys_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_Alys_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
      move.w(Word(0x0007).i, d0),
      jsr(Label('DoMapUpdateLoop').l),
      lea(Constant('Character_2').w, a3),
      move.w(curr_x_pos(a3), d2),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_4_Alys_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_4_Alys_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
      waitForSlot(2),
      finishMovement(),
    ]);
  });

  test('single-object step invalidates facing toward a pending movement', () {
    final generated = generateScene([
      moving(),
      Face(alys.towards(shay)).move(alys),
      StepObject.constantStep(rune, stepPerFrame: const Point(1, 0), frames: 2),
      SetContext((state) {
        expect(state.getFacing(alys), isNull);
        expect(state.hasPendingMovement(shay), isTrue);
      }),
      Face(alys.towards(shay)).move(alys),
    ]);

    expectGenerated(generated, [
      moveShay(),
      move.w(curr_x_pos(a4), d2),
      lea(Constant('Character_1').w, a4),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_2').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_Alys_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_Alys_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
      moveq(Constant('CharID_Rune').i, d0),
      jsr(Label('Event_GetCharacter').l),
      move.l(Longword(0x00010000).i, d0),
      moveq(0.i, d1),
      moveq(Byte(0x01).i, d2),
      jsr(Label('Event_StepObject').l),
      move.w(curr_x_pos(a4), dest_x_pos(a4)),
      move.w(curr_y_pos(a4), dest_y_pos(a4)),
      lea(Constant('Character_2').w, a3),
      move.w(curr_x_pos(a3), d2),
      lea(Constant('Character_1').w, a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_4_Alys_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_4_Alys_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
      waitForSlot(2),
      finishMovement(),
    ]);
  });

  test('a conditional pause invalidates facing after branches merge', () {
    final generated = generateScene([
      moving(),
      Face(alys.towards(shay)).move(alys),
      IfValue(SlotOfCharacter(rune), comparedTo: NullSlot(), notEqual: [
        Pause(const Duration(seconds: 1)),
      ]),
      Face(alys.towards(shay)).move(alys),
    ]);

    expectGenerated(generated, [
      moveShay(),
      move.w(curr_x_pos(a4), d2),
      lea(Constant('Character_1').w, a4),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_2').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_Alys_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_Alys_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
      moveq(Constant('CharID_Rune').i, d0),
      jsr(Label('FindCharacterSlot').l),
      cmpi.b(Byte(0xff).i, d1),
      beq(Label('.3_continue')),
      move.w(Word(0x003b).i, d0),
      jsr(Label('DoMapUpdateLoop').l),
      label(Label('.3_continue')),
      lea(Constant('Character_2').w, a3),
      move.w(curr_x_pos(a3), d2),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_5_Alys_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_5_Alys_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
      waitForSlot(2),
      finishMovement(),
    ]);
  });

  test('ordinary pauses preserve facts unrelated to pending movements', () {
    final npc = MapObject(
        id: 'npc', startPosition: Position(0, 0), spec: AlysWaiting());
    final map = GameMap(MapId.Test)..addObject(npc);
    final position = Position(0x80, 0x100);
    generateScene([
      moving(),
      SetContext((state) {
        state.positions[npc] = position;
        state.setFacing(npc, up);
        state.setRoutine(npc, NpcRoutineModel(FaceUp));
        state.positions[alys] = position;
        state.setFacing(alys, alys.towards(rune));
        state.setFacing(rika, rika.towards(shay));
        state.setFacing(wren, rika.facing());
      }),
      Pause(const Duration(seconds: 1)),
      SetContext((state) {
        expect(state.positions[npc], position);
        expect(state.getFacing(npc), up);
        expect(state.getRoutine(npc), NpcRoutineModel(FaceUp));
        expect(state.positions[alys], position);
        expect(state.getFacing(alys), alys.towards(rune));
        expect(state.getFacing(rika), isNull);
        expect(state.getFacing(wren), isNull);
        expect(state.hasPendingMovement(shay), isTrue);
      }),
    ], map: map);
  });

  test('a zero-length pause preserves facing toward a pending movement', () {
    final generated = generateScene([
      moving(),
      Face(alys.towards(shay)).move(alys),
      Pause(Duration.zero),
      Face(alys.towards(shay)).move(alys),
    ]);

    expectGenerated(generated, [
      moveShay(),
      move.w(curr_x_pos(a4), d2),
      lea(Constant('Character_1').w, a4),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_2').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_Alys_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_Alys_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
      waitForSlot(2),
      finishMovement(),
    ]);
  });

  for (final dialog in <String, Dialog>{
    'text': Dialog(spans: [DialogSpan('Hello')]),
    'inline pause': Dialog(spans: [
      DialogSpan('', events: [
        Pause(const Duration(seconds: 1), duringDialog: true),
      ]),
    ]),
    'text after inline facing': Dialog(spans: [
      DialogSpan('', events: [Face(alys.towards(shay)).move(alys)]),
      DialogSpan('Hello'),
    ]),
  }.entries) {
    test('dialog ${dialog.key} invalidates pending movement dependencies', () {
      final memory = Memory()
        ..setSlot(1, alys)
        ..setSlot(2, shay)
        ..startMovement(shay)
        ..setFacing(shay, left)
        ..setFacing(alys, alys.towards(shay))
        ..setFacing(rika, alys.facing())
        ..setFacing(rune, up);

      dialog.value.toGeneratedAsm(memory, InteractionMode.noObject(),
          labeller: Labeller.localTo('pending'),
          fieldRoutines: defaultFieldRoutines);

      expect(memory.getFacing(shay), isNull);
      expect(memory.getFacing(alys), isNull);
      expect(memory.getFacing(rika), isNull);
      expect(memory.getFacing(rune), up);
      expect(memory.hasPendingMovement(shay), isTrue);
    });
  }

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

  test('instant reposition cancels both runtime and tracked pending movement',
      () {
    final generated = generateScene([
      moving(),
      InstantMoves()..move(shay, to: Position(0x80, 0x80)),
      SetContext((state) => expect(state.hasPendingMovement(shay), isFalse)),
    ]);
    expectGenerated(generated, [
      moveShay(),
      move.l(0.i, x_step_constant(a4)),
      move.l(0.i, y_step_constant(a4)),
      move.w(0.i, x_step_duration(a4)),
      move.w(0.i, y_step_duration(a4)),
      move.w(Word(0x0080).i, curr_x_pos(a4)),
      move.w(Word(0x0000).i, (curr_x_pos + 2.toValue)(a4)),
      move.w(Word(0x0080).i, curr_y_pos(a4)),
      move.w(Word(0x0000).i, (curr_y_pos + 2.toValue)(a4)),
      move.w(Word(0x0080).i, dest_x_pos(a4)),
      move.w(Word(0x0080).i, dest_y_pos(a4)),
      move.l(a4, -sp),
      jsr(Label('Field_UpdateObjects').l),
      move.l(sp.postIncrement(), a4),
      finishMovement(),
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
