import 'package:rune/asm/asm.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/labels.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/generator/step_object.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../fixtures.dart';
import 'assembly_fixtures.dart';

const interactionObject = InteractionObject();

IndividualMoves facePlayer() =>
    Face(interactionObject.towards(BySlot.one)).move(interactionObject);

GeneratedAssembly generateInteraction(List<Event> events,
    {bool withObject = true, GameMap? map}) {
  map ??= GameMap(MapId.Test);
  final asm = EventAsm.empty();
  final dialogs = DialogTrees();
  final generator = SceneAsmGenerator.forInteraction(
      map, SceneId('facing'), dialogs, asm, TestEventRoutines(),
      withObject: withObject ? interactionObject : null)
    ..runEvent();
  for (final event in events) {
    event.visit(generator);
  }
  generator.finish();
  return (event: asm, dialog: dialogs.forMap(map.id).toAsm());
}

// Includes the event entry, interaction return, and dialogue entry in every
// expectation; individual tests spell out the event body and additional dialogue.
void expectInteraction(GeneratedAssembly generated, List<Asm> body,
    {List<Asm> dialog = const []}) {
  expectGenerated(generated, [
    label(Label('Event_GrandCross_facing')),
    ...body,
    move.w(Word(0).i, Constant('Game_Mode_Routine').w),
    movea.l(Constant('Map_Chunk_Addr').w, a0),
    jmp(Label('Map_LoadChunks').l),
  ], dialog: [
    dc.b([Byte(0xf6)]),
    dc.w([Word(0)]),
    dc.b([Byte(0xff)]),
    ...dialog,
  ]);
}

void main() {
  test('initial interaction facing uses the opposite player direction', () {
    final asm = generateInteraction([facePlayer()]);
    expectInteraction(asm, [
      lea(Constant('Character_1').w, a4),
      move.w(facing_dir(a4), d0),
      bchg(2.i, d0),
      lea(a3.indirect, a4),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('flags before facing preserve the initial interaction direction', () {
    final asm = generateInteraction([
      SetFlag(EventFlag('Spoken')),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      moveq(Constant('EventFlag_Spoken').i, d0),
      jsr(Label('EventFlags_Set').l),
      lea(Constant('Character_1').w, a4),
      move.w(facing_dir(a4), d0),
      bchg(2.i, d0),
      lea(a3.indirect, a4),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  // Unknown positions require reading the coordinates, even when a prior turn
  // made the player's facing known to the generator.
  test('a player turn prevents folding NPC facing to the opposite direction',
      () {
    final asm = generateInteraction([
      Face(Direction.up).move(BySlot.one),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      lea(Constant('Character_1').w, a4),
      moveq(Constant('FacingDir_Up').i, d0),
      jsr(Label('Event_UpdateObjFacing').l),
      move.w(curr_x_pos(a4), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_1').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('explicit player facing reestablishes the relationship after a turn',
      () {
    final asm = generateInteraction([
      Face(Direction.up).move(BySlot.one),
      Face(BySlot.one.towards(interactionObject)).move(BySlot.one),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      lea(Constant('Character_1').w, a4),
      moveq(Constant('FacingDir_Up').i, d0),
      jsr(Label('Event_UpdateObjFacing').l),
      loadInteractionObject(a3),
      move.w(curr_x_pos(a3), d2),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_Slot1_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_Slot1_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
      move.w(facing_dir(a4), d0),
      bchg(2.i, d0),
      move.w(d0, -sp),
      loadInteractionObject(a4),
      move.w(sp.postIncrement(), d0),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('repeated symbolic NPC facing needs only one update', () {
    final asm = generateInteraction([facePlayer(), facePlayer()]);
    expectInteraction(asm, [
      lea(Constant('Character_1').w, a4),
      move.w(facing_dir(a4), d0),
      bchg(2.i, d0),
      lea(a3.indirect, a4),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('unrelated targeted stepping preserves the player relationship', () {
    final asm = generateInteraction([
      StepObject.constantStep(BySlot.two,
          stepPerFrame: const Point(1, 0), frames: 2),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      lea(Constant('Character_2').w, a4),
      move.l(Longword(0x00010000).i, d0),
      moveq(0.i, d1),
      moveq(Byte(0x01).i, d2),
      jsr(Label('Event_StepObject').l),
      move.w(curr_x_pos(a4), dest_x_pos(a4)),
      move.w(curr_y_pos(a4), dest_y_pos(a4)),
      lea(Constant('Character_1').w, a4),
      move.w(facing_dir(a4), d0),
      bchg(2.i, d0),
      move.w(d0, -sp),
      loadInteractionObject(a4),
      move.w(sp.postIncrement(), d0),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('instant movement runs objects and invalidates symbolic facing', () {
    final asm = generateInteraction([
      InstantMoves()..move(BySlot.two, to: Position(0x100, 0x100)),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      lea(Constant('Character_2').w, a4),
      move.w(Word(0x0100).i, curr_x_pos(a4)),
      move.w(Word(0x0000).i, (curr_x_pos + 2.toValue)(a4)),
      move.w(Word(0x0100).i, curr_y_pos(a4)),
      move.w(Word(0x0000).i, (curr_y_pos + 2.toValue)(a4)),
      move.w(Word(0x0100).i, dest_x_pos(a4)),
      move.w(Word(0x0100).i, dest_y_pos(a4)),
      move.l(a4, -sp),
      jsr(Label('Field_UpdateObjects').l),
      move.l(sp.postIncrement(), a4),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('raw dialogue actions invalidate symbolic facing', () {
    final asm = generateInteraction([
      DialogCodes(Bytes.list([0xf2, 0x0e, 0x80, 0, 0])),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      move.b(Constant('SFXID_Selection').i, Constant('Sound_Index').l),
      moveq(Byte(0x01).i, d0),
      jsr(Label('Event_GetAndRunDialogue3').l),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_3_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_3_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ], dialog: [
      dc.b([Byte(0xf2), Byte(0x0e), Byte(0x80), Byte(0x00), Byte(0x00)]),
      dc.b([Byte(0xff)]),
    ]);
  });

  group('routine initialization', () {
    for (final initialize in [false, true]) {
      for (final conditional in [false, true]) {
        test(
            'invalidates object facts only when the routine executes '
            '(initialize=$initialize, conditional=$conditional)', () {
          final npc = MapObject(
              id: 'npc',
              startPosition: Position(0, 0),
              spec: Npc(Sprite.PalmanMan1, WanderAround(Direction.down)));
          final map = GameMap(MapId.Test)..addObject(npc);
          final position = Position(16, 32);
          final direction = alys.towards(npc);
          final routine = NpcRoutineModel(FaceUp);
          final change = ChangeObjectRoutine(MapObjectById(npc.id), routine,
              initialize: initialize);
          EventState? after;

          final asm = generateInteraction([
            SetContext((state) {
              state.positions[npc] = position;
              state.setFacing(npc, Direction.left);
              state.setFacing(alys, direction);
              state.setFacing(rune, Direction.right);
            }),
            if (conditional)
              IfValue(SlotOfCharacter(shay),
                  comparedTo: NullSlot(), notEqual: [change])
            else
              change,
            SetContext((state) => after = state.branch()),
          ], map: map);
          expectInteraction(
              asm,
              <(bool, bool), List<Asm>>{
                (false, false): [
                  lea(0xffffc300.w, a4),
                  move.w((Word(0x0058) | Word(0x8000)).i, a4.indirect),
                ],
                (false, true): [
                  moveq(Constant('CharID_Chaz').i, d0),
                  jsr(Label('FindCharacterSlot').l),
                  cmpi.b(Byte(0xff).i, d1),
                  beq(Label('.1_continue')),
                  lea(0xffffc300.w, a4),
                  move.w((Word(0x0058) | Word(0x8000)).i, a4.indirect),
                  label(Label('.1_continue')),
                ],
                (true, false): [
                  lea(0xffffc300.w, a4),
                  move.w(Word(0x0058).i, a4.indirect),
                  jsr(Label('FieldObj_NPCType9').l),
                ],
                (true, true): [
                  moveq(Constant('CharID_Chaz').i, d0),
                  jsr(Label('FindCharacterSlot').l),
                  cmpi.b(Byte(0xff).i, d1),
                  beq(Label('.1_continue')),
                  lea(0xffffc300.w, a4),
                  move.w(Word(0x0058).i, a4.indirect),
                  jsr(Label('FieldObj_NPCType9').l),
                  label(Label('.1_continue')),
                ],
              }[(initialize, conditional)]!);

          expect(after!.positions[npc], initialize ? isNull : position);
          expect(after!.getFacing(npc), initialize ? isNull : Direction.left);
          expect(after!.getFacing(alys), initialize ? isNull : direction);
          expect(after!.getFacing(rune), Direction.right);
          if (!conditional) expect(after!.getRoutine(npc), routine);
        });
      }
    }
  });

  test('a turn in the same movement batch invalidates initial facing', () {
    final asm = generateInteraction([
      IndividualMoves()
        ..moves[BySlot.one] = Face(Direction.up)
        ..moves[interactionObject] =
            Face(interactionObject.towards(BySlot.one)),
    ]);
    expectInteraction(asm, [
      lea(Constant('Character_1').w, a4),
      moveq(Constant('FacingDir_Up').i, d0),
      jsr(Label('Event_UpdateObjFacing').l),
      move.w(curr_x_pos(a4), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_1').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_1_InteractionObject_0_1'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_1_InteractionObject_0_1')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('relative movement from an unknown position invalidates initial facing',
      () {
    final asm = generateInteraction([
      IndividualMoves()
        ..moves[BySlot.two] = (StepPath()
          ..distance = 1.step
          ..direction = Direction.right),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      bset(Byte(0x00).i, Constant('Char_Move_Flags').w),
      lea(Constant('Character_2').w, a4),
      move.w(curr_x_pos(a4), d0),
      move.w(curr_y_pos(a4), d1),
      addi.w(Word(0x0010).i, d0),
      jsr(Label('Event_MoveCharacter').l),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('stepping from an unknown position invalidates initial facing', () {
    final asm = generateInteraction([
      StepObject.constantStep(BySlot.one,
          stepPerFrame: const Point(1, 0), frames: 2),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      lea(Constant('Character_1').w, a4),
      move.l(Longword(0x00010000).i, d0),
      moveq(0.i, d1),
      moveq(Byte(0x01).i, d2),
      jsr(Label('Event_StepObject').l),
      move.w(curr_x_pos(a4), dest_x_pos(a4)),
      move.w(curr_y_pos(a4), dest_y_pos(a4)),
      move.w(curr_x_pos(a4), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_1').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('stepping multiple unknown positions invalidates initial facing', () {
    final asm = generateInteraction([
      StepObjects([BySlot.one, BySlot.two],
          stepPerFrame: Vector2dOfXY(Double(1), Double(0)), frames: 2),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      move.l(Longword(0x00010000).i, d0),
      moveq(0.i, d1),
      moveq(Byte(0x01).i, d2),
      movem.l(d0 - d1, -sp),
      label(Label('.1_stepobjectsloop')),
      lea(Constant('Character_1').w, a4),
      move.l(sp.indirect, d0),
      move.l(Byte(0x04)(sp), d1),
      jsr(Label('Event_StepObjectNoWait').l),
      lea(Constant('Character_2').w, a4),
      move.l(sp.indirect, d0),
      move.l(Byte(0x04)(sp), d1),
      jsr(Label('Event_StepObjectNoWait').l),
      movem.l(d2 / a4, -sp),
      jsr(Label('Field_LoadSprites').l),
      jsr(Label('Field_BuildSprites').l),
      jsr(Label('AnimateTiles').l),
      jsr(Label('RunMapUpdates').l),
      jsr(Label('VInt_Prepare').l),
      movem.l(sp.postIncrement(), d2 / a4),
      dbf(d2, Label('.1_stepobjectsloop')),
      lea(Byte(0x08)(sp), sp),
      moveq(0.i, d0),
      move.l(d0, x_step_constant(a4)),
      move.w(curr_x_pos(a4), dest_x_pos(a4)),
      move.w(curr_y_pos(a4), dest_y_pos(a4)),
      lea(Constant('Character_1').w, a4),
      moveq(0.i, d0),
      move.l(d0, x_step_constant(a4)),
      move.w(curr_x_pos(a4), dest_x_pos(a4)),
      move.w(curr_y_pos(a4), dest_y_pos(a4)),
      move.w(curr_x_pos(a4), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_1').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('overlapping characters invalidates initial facing', () {
    final asm = generateInteraction([
      OverlapCharacters(),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      jsr(Label('Event_OverlapCharacters').l),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('a movement wait invalidates initial facing', () {
    final asm = generateInteraction([
      WaitForMovements([BySlot.two]),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      lea(Constant('Character_2').w, a4),
      jsr(Label('Event_DoWaitForCharacter').l),
      jsr(Label('Field_UpdateObjects').l),
      moveq(0.i, d0),
      move.l(d0, Constant('Camera_X_Step_Counter_FG').w),
      move.l(d0, Constant('Camera_Y_Step_Counter_FG').w),
      move.l(d0, Constant('Camera_X_Step_Counter_BG').w),
      move.l(d0, Constant('Camera_Y_Step_Counter_BG').w),
      lea(Constant('Character_2').w, a4),
      bclr(1.i, priority_flag(a4)),
      move.b(Byte(0x01).i, Constant('FieldObj_Step_Offset').w),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('camera movement invalidates initial facing while objects run', () {
    final asm = generateInteraction([
      MoveCamera(Position(0x100, 0x100)),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      move.w(Word(0x0100).i, d0),
      move.w(Word(0x0100).i, d1),
      move.w(1.i, d2),
      jsr(Label('Event_MoveCamera').l),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('running objects invalidates concrete native NPC positions and facing',
      () {
    final npc = MapObject(
        id: 'wandering',
        startPosition: Position(0, 0),
        spec: Npc(Sprite.PalmanMan1, WanderAround(Direction.down)));
    final map = GameMap(MapId.Test)..addObject(npc);
    EventState? after;
    generateInteraction([
      SetContext((state) {
        state.positions[npc] = Position(16, 32);
        state.setFacing(npc, Direction.up);
      }),
      MoveCamera(Position(0x100, 0x100)),
      SetContext((state) => after = state.branch()),
    ], map: map);

    expect(after!.positions[npc], isNull);
    expect(after!.getFacing(npc), isNull);
  });

  test('a pause running objects invalidates initial facing', () {
    final asm = generateInteraction([
      Pause(const Duration(seconds: 1), runObjects: true, duringDialog: false),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      move.w(Word(0x003b).i, d0),
      jsr(Label('DoMainUpdatesLoop').l),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('arbitrary assembly invalidates initial facing', () {
    final asm = generateInteraction([
      AsmEvent(Asm.fromRaw('\tmove.w\t#FacingDir_Up, (Character_1+6).w')),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      move.w(Constant('FacingDir_Up').i, Constant('Character_1+6').w),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('a later FacePlayer event uses coordinates', () {
    final asm = generateInteraction([
      Face(Direction.up).move(BySlot.one),
      InteractionObject.facePlayer(),
    ]);
    expectInteraction(asm, [
      lea(Constant('Character_1').w, a4),
      moveq(Constant('FacingDir_Up').i, d0),
      jsr(Label('Event_UpdateObjFacing').l),
      move.w(curr_x_pos(a4), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      lea(Constant('Character_1').w, a3),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_2_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_2_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('a possible turn invalidates initial facing after branches merge', () {
    final asm = generateInteraction([
      IfValue(SlotOfCharacter(shay), comparedTo: Slot(1), equal: [
        Face(Direction.up).move(BySlot.one),
      ]),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      moveq(Constant('CharID_Chaz').i, d0),
      jsr(Label('FindCharacterSlot').l),
      cmpi.b(0.i, d1),
      bne(Label('.1_continue')),
      lea(Constant('Character_1').w, a4),
      moveq(Constant('FacingDir_Up').i, d0),
      jsr(Label('Event_UpdateObjFacing').l),
      label(Label('.1_continue')),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_3_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_3_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('NPC facing in flag branches preserves the player facing relationship',
      () {
    final asm = generateInteraction([
      IfFlag(EventFlag('Branch'),
          isSet: [facePlayer()], isUnset: [facePlayer()]),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      moveq(Constant('EventFlag_Branch').i, d0),
      jsr(Label('EventFlags_Test').l),
      beq.w(Label('.Branch_unset1')),
      lea(Constant('Character_1').w, a4),
      move.w(facing_dir(a4), d0),
      bchg(2.i, d0),
      lea(a3.indirect, a4),
      jsr(Label('Event_UpdateObjFacing').l),
      bra.w(Label('.Branch_cont1')),
      label(Label('.Branch_unset1')),
      lea(Constant('Character_1').w, a4),
      move.w(facing_dir(a4), d0),
      bchg(2.i, d0),
      lea(a3.indirect, a4),
      jsr(Label('Event_UpdateObjFacing').l),
      label(Label('.Branch_cont1')),
      lea(Constant('Character_1').w, a4),
      move.w(facing_dir(a4), d0),
      bchg(2.i, d0),
      move.w(d0, -sp),
      loadInteractionObject(a4),
      move.w(sp.postIncrement(), d0),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('queued dialogue facing invalidates the interaction direction', () {
    final asm = generateInteraction([
      Dialog(spans: [DialogSpan('Hello')]),
      Face(Direction.up).move(BySlot.one),
      Dialog(spans: [DialogSpan('Again')]),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      move.b(Constant('SFXID_Selection').i, Constant('Sound_Index').l),
      moveq(Byte(0x01).i, d0),
      jsr(Label('Event_GetAndRunDialogue3').l),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_5_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_5_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ], dialog: [
      dc.b(Bytes.ascii('Hello')),
      dc.b([Byte(0xfd)]),
      dc.b([Byte(0xf2), Byte(0x0e), Byte(0x80)]),
      dc.w([Constant('FacingDir_Up')]),
      dc.b(Bytes.ascii('Again')),
      dc.b([Byte(0xff)]),
    ]);
  });

  test('inline dialogue facing invalidates the interaction direction', () {
    final asm = generateInteraction([
      Dialog(spans: [
        DialogSpan('Hello', events: [Face(Direction.up).move(BySlot.one)]),
      ]),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      move.b(Constant('SFXID_Selection').i, Constant('Sound_Index').l),
      moveq(Byte(0x01).i, d0),
      jsr(Label('Event_GetAndRunDialogue3').l),
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_3_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_3_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ], dialog: [
      dc.b(Bytes.ascii('Hello')),
      dc.b([Byte(0xf2), Byte(0x0e), Byte(0x80)]),
      dc.w([Constant('FacingDir_Up')]),
      dc.b([Byte(0xff)]),
    ]);
  });

  test('implicit NPC facing preserves the player facing relationship', () {
    final asm = generateInteraction([
      InteractionObject.facePlayer(),
      facePlayer(),
    ]);
    expectInteraction(asm, [
      jsr(Label('Interaction_UpdateObj').l),
      lea(Constant('Character_1').w, a4),
      move.w(facing_dir(a4), d0),
      bchg(2.i, d0),
      lea(a3.indirect, a4),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('without an NPC interaction facing uses coordinates', () {
    final asm = generateInteraction([facePlayer()], withObject: false);
    expectInteraction(asm, [
      lea(Constant('Character_1').w, a3),
      move.w(curr_x_pos(a3), d2),
      loadInteractionObject(a4),
      sub.w(curr_x_pos(a4), d2),
      move.w(curr_y_pos(a3), d3),
      sub.w(curr_y_pos(a4), d3),
      vectorDirection('_1_InteractionObject_0_0'),
      move.w(facing_dir(a4), d0),
      label(Label('.keep_1_InteractionObject_0_0')),
      jsr(Label('Event_UpdateObjFacing').l),
    ]);
  });

  test('an unknown leader position discards prior follower coordinates', () {
    EventState? result;
    generateInteraction([
      SetContext((state) {
        state.setSlot(2, shay);
        state.positions[shay] = Position(0x10, 0x20);
        state.setFacing(shay, Direction.right);
      }),
      OverlapCharacters(),
      SetContext((state) => result = state.branch()),
    ]);

    expect(result!.positions[shay], isNull);
    expect(result!.getFacing(shay), isNull);
  });

  for (final knownLeader in [false, true]) {
    test(
        'overlap assigns the leader position to followers and known aliases '
        '(known leader=$knownLeader)', () {
      final position = Position(0x80, 0x100);
      EventState? result;
      generateInteraction([
        SetContext((state) {
          if (knownLeader) state.setSlot(1, alys);
          state.setSlot(2, shay);
          state.positions[BySlot.one] = position;
          state.positions[shay] = Position(0x100, 0x120);
          state.setFacing(BySlot.one, Direction.left);
          state.setFacing(shay, Direction.right);
        }),
        OverlapCharacters(),
        SetContext((state) => result = state.branch()),
      ]);

      for (final slot in BySlot.all) {
        expect(result!.positions[slot], position, reason: '$slot');
      }
      expect(result!.positions[shay], position);
      expect(result!.getFacing(BySlot.one), Direction.left);
      expect(result!.getFacing(shay), isNull);
    });
  }

  test('overlap retains the leader position with entirely unknown party order',
      () {
    final position = Position(0x80, 0x100);
    EventState? result;
    generateInteraction([
      SetContext((state) {
        state.positions[BySlot.one] = position;
        state.positions[BySlot.two] = Position(0x100, 0x120);
        state.setFacing(BySlot.one, Direction.left);
      }),
      OverlapCharacters(),
      SetContext((state) => result = state.branch()),
    ]);

    for (final slot in BySlot.all) {
      expect(result!.positions[slot], position, reason: '$slot');
    }
    expect(result!.getFacing(BySlot.one), Direction.left);
    // Unknown party membership does not establish a named character's position.
    expect(result!.positions[shay], isNull);
  });

  for (final multiple in [false, true]) {
    test(
        'stepping unknown positions invalidates possible named aliases '
        '(multiple=$multiple)', () {
      // With unknown party order, slot 2 could be Shay even though only Shay's
      // coordinates are known. Moving the slot must invalidate that knowledge.
      final memory = Memory()
        ..positions[shay] = Position(0x10, 0x20)
        ..setFacing(BySlot.one, BySlot.one.towards(const InteractionObject()));
      final objects = multiple ? [BySlot.two, BySlot.three] : [BySlot.two];
      stepObjectsToAsm(
          StepObjects.constantStep(objects,
              stepPerFrame: const Point(1, 0), frames: 2),
          memory: memory,
          labeller: Labeller.localTo('step'));

      expect(memory.positions[shay], isNull);
      // Distinct party slots cannot alias the player, even with unknown order.
      expect(memory.playerFacesInteractionObject, isTrue);
    });
  }
}
