import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  late GameMap map;
  late MapObject npc;

  setUp(() {
    npc = MapObject(
        id: 'npc', startPosition: Position(0, 0), spec: AlysWaiting());
    map = GameMap(MapId.Test)..addObject(npc);
  });

  void rememberObjects(EventState state) {
    state.setSlot(1, alys);
    state.setSlot(2, shay);
    state.positions[alys] = Position(0x20, 0x30);
    state.positions[shay] = Position(0x20, 0x40);
    state.positions[npc] = Position(0x40, 0x50);
    state.setFacing(alys, Direction.right);
    state.setFacing(npc, Direction.left);
    state.setFacing(rika, rika.towards(npc));
    state.setRoutine(npc, scriptableObjectRoutine);
  }

  test('preparing a map with object refresh forgets old poses and routines',
      () {
    EventState? after;
    final asm = generateEventAsm([
      SetContext(rememberObjects),
      PrepareMap(refreshObjects: true),
      SetContext((state) => after = state.branch()),
      Face(Direction.right).move(BySlot.one),
    ], inMap: map);

    expect(
        asm.withoutEmptyLines(),
        Asm([
          bclr(3.i, Map_Load_Flags.w),
          jsr(Label('RefreshMap').l),
          lea(Constant('Character_1').w, a4),
          moveq(Constant('FacingDir_Right').i, d0),
          jsr(Label('Event_UpdateObjFacing').l),
        ]));
    expect(after!.positions[alys], isNull);
    expect(after!.positions[npc], isNull);
    expect(after!.getFacing(alys), isNull);
    expect(after!.getFacing(npc), isNull);
    expect(after!.getFacing(rika), isNull);
    expect(after!.getRoutine(npc), isNull);
  });

  test('preparing a map without object refresh preserves poses and routines',
      () {
    EventState? after;
    final asm = generateEventAsm([
      SetContext(rememberObjects),
      PrepareMap(),
      SetContext((state) => after = state.branch()),
      Face(Direction.right).move(BySlot.one),
    ], inMap: map);

    expect(
        asm.withoutEmptyLines(),
        Asm([
          bset(3.i, Map_Load_Flags.w),
          jsr(Label('RefreshMap').l),
        ]));
    expect(after!.positions[alys], Position(0x20, 0x30));
    expect(after!.positions[npc], Position(0x40, 0x50));
    expect(after!.getFacing(alys), Direction.right);
    expect(after!.getFacing(npc), Direction.left);
    expect(after!.getFacing(rika), rika.towards(npc));
    expect(after!.getRoutine(npc), scriptableObjectRoutine);
  });

  test('loading a map clears old facts before recording the new party pose',
      () {
    final destination = GameMap(MapId.Test_Part2);
    EventState? after;
    final asm = generateEventAsm([
      SetContext(rememberObjects),
      LoadMap(
          map: destination,
          startingPosition: Position(0x100, 0x120),
          facing: Direction.down,
          arrangement: PartyArrangement.belowLead),
      SetContext((state) => after = state.branch()),
      Face(Direction.down).move(BySlot.one),
    ], inMap: map);

    expect(
        asm.withoutEmptyLines(),
        Asm([
          move.b(0.i, World_Index.w),
          move.w(Constant('MapID_Test_Part2').i, Field_Map_Index.w),
          move.w(Constant('MapID_Test').i, Field_Map_Index_2.w),
          move.w(0x20.toWord.i, Map_Start_X_Pos.w),
          move.w(0x24.toWord.i, Map_Start_Y_Pos.w),
          move.w(Constant('FacingDir_Down').i, Map_Start_Facing_Dir.w),
          move.w(4.i, Map_Start_Char_Align.w),
          bclr(3.i, Map_Load_Flags.w),
          jsr(Label('RefreshMap').l),
        ]));
    expect(after!.currentMap, destination);
    expect(after!.positions[BySlot.one], Position(0x100, 0x120));
    expect(after!.positions[alys], Position(0x100, 0x120));
    expect(after!.positions[BySlot.two], Position(0x100, 0x130));
    expect(after!.positions[shay], Position(0x100, 0x130));
    expect(after!.getFacing(alys), Direction.down);
    expect(after!.getFacing(shay), Direction.down);
    expect(after!.positions[npc], isNull);
    expect(after!.getFacing(npc), isNull);
    expect(after!.getFacing(rika), isNull);
    expect(after!.getRoutine(npc), isNull);
  });

  test('loading without object refresh preserves poses and routine knowledge',
      () {
    EventState? after;
    final asm = generateEventAsm([
      SetContext(rememberObjects),
      LoadMap(
          map: GameMap(MapId.Test_Part2),
          startingPosition: Position(0x100, 0x120),
          facing: Direction.down,
          arrangement: PartyArrangement.belowLead,
          refreshObjects: false),
      SetContext((state) => after = state.branch()),
      Face(Direction.right).move(BySlot.one),
      (StepPath()
            ..distance = 1.step
            ..direction = Direction.right)
          .move(BySlot.one),
    ], inMap: map);

    expect(
        asm.withoutEmptyLines(),
        Asm([
          move.b(0.i, World_Index.w),
          move.w(Constant('MapID_Test_Part2').i, Field_Map_Index.w),
          move.w(Constant('MapID_Test').i, Field_Map_Index_2.w),
          move.w(0x20.toWord.i, Map_Start_X_Pos.w),
          move.w(0x24.toWord.i, Map_Start_Y_Pos.w),
          move.w(Constant('FacingDir_Down').i, Map_Start_Facing_Dir.w),
          move.w(4.i, Map_Start_Char_Align.w),
          bset(3.i, Map_Load_Flags.w),
          jsr(Label('RefreshMap').l),
          bset(Byte.zero.i, Char_Move_Flags.w),
          lea(Constant('Character_1').w, a4),
          move.w(0x30.toWord.i, d0),
          move.w(0x30.toWord.i, d1),
          jsr(Label('Event_MoveCharacter').l),
        ]));
    expect(after!.positions[alys], Position(0x20, 0x30));
    expect(after!.positions[BySlot.one], Position(0x20, 0x30));
    expect(after!.positions[shay], Position(0x20, 0x40));
    expect(after!.positions[BySlot.two], Position(0x20, 0x40));
    expect(after!.positions[npc], Position(0x40, 0x50));
    expect(after!.getFacing(alys), Direction.right);
    expect(after!.getFacing(npc), Direction.left);
    expect(after!.getFacing(rika), rika.towards(npc));
    expect(after!.getRoutine(npc), scriptableObjectRoutine);
  });
}
