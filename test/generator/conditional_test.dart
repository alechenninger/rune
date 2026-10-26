import 'package:rune/asm/events.dart';
import 'package:rune/generator/conditional.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import 'assembly_fixtures.dart';

void main() {
  Asm compare(DirectionExpression left, DirectionExpression right,
      {Memory? memory}) {
    final condition = IfValue<DirectionExpression>(left,
        comparedTo: right, equal: [Pause(Duration(seconds: 1))]);
    return condition.compare(
        memory: memory ?? Memory(),
        branches: BranchLabels('.test_', condition));
  }

  for (final direction in Direction.values) {
    test('object facing compared to $direction uses a word immediate', () {
      expect(
          compare(BySlot.one.facing(), direction),
          Asm([
            lea(Constant('Character_1').w, a4),
            cmpi.w(direction.address, facing_dir(a4)),
          ]));
    });
  }

  test('constant on the left preserves comparison order', () {
    expect(
        compare(up, BySlot.one.facing()),
        Asm([
          lea(Constant('Character_1').w, a4),
          move.w(FacingDir_Up.i, d4),
          cmp.w(facing_dir(a4), d4),
        ]));
  });

  test('constant destination does not overwrite a computed source', () {
    expect(
        compare(up, BySlot.one.facing().opposite),
        Asm([
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          bchg(2.i, d0),
          move.w(FacingDir_Up.i, d4),
          cmp.w(d0, d4),
        ]));
  });

  test('two fixed object facings need no stack preservation', () {
    expect(
        compare(BySlot.one.facing(), BySlot.two.facing()),
        Asm([
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          lea(Constant('Character_2').w, a4),
          cmp.w(facing_dir(a4), d0),
        ]));
  });

  test('turned facing compared to a constant', () {
    expect(
        compare(BySlot.one.facing().opposite, left),
        Asm([
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          bchg(2.i, d0),
          cmpi.w(FacingDir_Left.i, d0),
        ]));
  });

  test('computed source survives character lookup and destination computation',
      () {
    expect(
        compare(alys.facing().opposite, BySlot.one.facing().opposite),
        Asm([
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          bchg(2.i, d0),
          move.w(d0, -(sp)),
          characterByIdToA4(Constant('CharID_Alys').i),
          move.w(facing_dir(a4), d0),
          bchg(2.i, d0),
          cmp.w(sp.postIncrement(), d0),
        ]));
  });

  test('two quarter turns have separate branch labels', () {
    expect(
        compare(BySlot.one.facing().turn(1), BySlot.two.facing().turn(3)),
        Asm([
          lea(Constant('Character_2').w, a4),
          move.w(facing_dir(a4), d0),
          bchg(3.i, d0),
          beq(Label('.skip_test_operand2')),
          bchg(2.i, d0),
          label(Label('.skip_test_operand2')),
          move.w(d0, -(sp)),
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          bchg(3.i, d0),
          bne(Label('.skip_test_operand1')),
          bchg(2.i, d0),
          label(Label('.skip_test_operand1')),
          cmp.w(sp.postIncrement(), d0),
        ]));
  });

  test('vector source survives a character lookup', () {
    expect(
        compare(alys.facing(), BySlot.one.towards(BySlot.two)),
        Asm([
          lea(Constant('Character_2').w, a3),
          move.w(curr_x_pos(a3), d2),
          lea(Constant('Character_1').w, a4),
          sub.w(curr_x_pos(a4), d2),
          move.w(curr_y_pos(a3), d3),
          sub.w(curr_y_pos(a4), d3),
          vectorDirection('_test_operand2'),
          move.w(facing_dir(a4), d0),
          label(Label('.keep_test_operand2')),
          move.w(d0, -(sp)),
          characterByIdToA4(Constant('CharID_Alys').i),
          move.w(facing_dir(a4), d4),
          cmp.w(sp.postIncrement(), d4),
        ]));
  });

  test('fixed source facing is loaded after the vector destination', () {
    expect(
        compare(BySlot.one.towards(BySlot.two), BySlot(3).facing()),
        Asm([
          lea(Constant('Character_2').w, a3),
          move.w(curr_x_pos(a3), d2),
          lea(Constant('Character_1').w, a4),
          sub.w(curr_x_pos(a4), d2),
          move.w(curr_y_pos(a3), d3),
          sub.w(curr_y_pos(a4), d3),
          vectorDirection('_test_operand1'),
          move.w(facing_dir(a4), d0),
          label(Label('.keep_test_operand1')),
          lea(Constant('Character_3').w, a4),
          cmp.w(facing_dir(a4), d0),
        ]));
  });

  test('fixed destination facing is loaded after the vector source', () {
    expect(
        compare(BySlot(3).facing(), BySlot.one.towards(BySlot.two)),
        Asm([
          lea(Constant('Character_2').w, a3),
          move.w(curr_x_pos(a3), d2),
          lea(Constant('Character_1').w, a4),
          sub.w(curr_x_pos(a4), d2),
          move.w(curr_y_pos(a3), d3),
          sub.w(curr_y_pos(a4), d3),
          vectorDirection('_test_operand2'),
          move.w(facing_dir(a4), d0),
          label(Label('.keep_test_operand2')),
          lea(Constant('Character_3').w, a4),
          move.w(facing_dir(a4), d4),
          cmp.w(d0, d4),
        ]));
  });

  test('known character slot allows deferring its facing load', () {
    expect(
        compare(BySlot.one.facing().opposite, alys.facing(),
            memory: Memory()..setSlot(3, alys)),
        Asm([
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          bchg(2.i, d0),
          lea(Constant('Character_3').w, a4),
          cmp.w(facing_dir(a4), d0),
        ]));
  });

  test('unknown character slot still preserves the computed source', () {
    expect(
        compare(BySlot.one.facing().opposite, alys.facing()),
        Asm([
          characterByIdToA4(Constant('CharID_Alys').i),
          move.w(facing_dir(a4), -(sp)),
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          bchg(2.i, d0),
          cmp.w(sp.postIncrement(), d0),
        ]));
  });

  test('cached character address may be overwritten by the vector calculation',
      () {
    expect(
        compare(alys.facing(), BySlot.one.towards(BySlot.two),
            memory: Memory()..putInAddress(a4, alys)),
        Asm([
          lea(Constant('Character_2').w, a3),
          move.w(curr_x_pos(a3), d2),
          lea(Constant('Character_1').w, a4),
          sub.w(curr_x_pos(a4), d2),
          move.w(curr_y_pos(a3), d3),
          sub.w(curr_y_pos(a4), d3),
          vectorDirection('_test_operand2'),
          move.w(facing_dir(a4), d0),
          label(Label('.keep_test_operand2')),
          move.w(d0, -(sp)),
          characterByIdToA4(Constant('CharID_Alys').i),
          move.w(facing_dir(a4), d4),
          cmp.w(sp.postIncrement(), d4),
        ]));
  });

  test('interaction lookup still preserves its source before computing a turn',
      () {
    expect(
        compare(BySlot.one.facing().opposite,
                const InteractionObject().facing())
            .withoutComments(),
        Asm([
          loadInteractionObject(a4),
          move.w(facing_dir(a4), -(sp)),
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          bchg(2.i, d0),
          cmp.w(sp.postIncrement(), d0),
        ]));
  });

  for (final byId in [false, true]) {
    test('map object facing load can be deferred (byId: $byId)', () {
      final npc = MapObject(
          id: 'testnpc',
          startPosition: Position(0x200, 0x200),
          spec: Npc(Sprite.PalmanMan1, WanderAround(down)));
      final map = GameMap(MapId.Test)..addObject(npc);
      final memory = Memory()..currentMap = map;
      final object = byId ? MapObjectById(npc.id) : npc;

      expect(
          compare(BySlot.one.facing().opposite, object.facing(),
              memory: memory),
          Asm([
            lea(Constant('Character_1').w, a4),
            move.w(facing_dir(a4), d0),
            bchg(2.i, d0),
            lea(Absolute.word(map.addressOf(npc)), a4),
            cmp.w(facing_dir(a4), d0),
          ]));
    });
  }

  test('indirect zero-vector destination is read before deferring the source',
      () {
    expect(
        compare(BySlot.one.towards(BySlot.one), BySlot(3).facing()),
        Asm([
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          lea(Constant('Character_3').w, a4),
          cmp.w(facing_dir(a4), d0),
        ]));
  });

  test('indirect zero-vector source is read before loading the destination',
      () {
    expect(
        compare(BySlot(3).facing(), BySlot.one.towards(BySlot.one)),
        Asm([
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          lea(Constant('Character_3').w, a4),
          move.w(facing_dir(a4), d4),
          cmp.w(d0, d4),
        ]));
  });

  test('two vector directions preserve the source and have distinct labels',
      () {
    expect(
        compare(BySlot(3).towards(BySlot(4)), BySlot.one.towards(BySlot.two)),
        Asm([
          lea(Constant('Character_2').w, a3),
          move.w(curr_x_pos(a3), d2),
          lea(Constant('Character_1').w, a4),
          sub.w(curr_x_pos(a4), d2),
          move.w(curr_y_pos(a3), d3),
          sub.w(curr_y_pos(a4), d3),
          vectorDirection('_test_operand2'),
          move.w(facing_dir(a4), d0),
          label(Label('.keep_test_operand2')),
          move.w(d0, -(sp)),
          lea(Constant('Character_4').w, a3),
          move.w(curr_x_pos(a3), d2),
          lea(Constant('Character_3').w, a4),
          sub.w(curr_x_pos(a4), d2),
          move.w(curr_y_pos(a3), d3),
          sub.w(curr_y_pos(a4), d3),
          vectorDirection('_test_operand1'),
          move.w(facing_dir(a4), d0),
          label(Label('.keep_test_operand1')),
          cmp.w(sp.postIncrement(), d0),
        ]));
  });

  test('zero vector compares its fallback direction', () {
    expect(
        compare(BySlot.one.towards(BySlot.one), right),
        Asm([
          lea(Constant('Character_1').w, a4),
          cmpi.w(FacingDir_Right.i, facing_dir(a4)),
        ]));
  });

  test('known vector is compared as a constant', () {
    expect(
        compare(BySlot.one.towards(BySlot.two), right,
            memory: Memory()
              ..positions[BySlot.one] = Position(0, 0)
              ..positions[BySlot.two] = Position(0, -16)),
        Asm([
          move.w(FacingDir_Up.i, d4),
          cmpi.w(FacingDir_Right.i, d4),
        ]));
  });

  test('scenes branch on direction equality and inequality', () {
    final asm = Program()
        .addScene(
            SceneId('directions'),
            Scene([
              IfValue<DirectionExpression>(BySlot.one.facing(),
                  comparedTo: right, equal: [Face(up).move(BySlot.one)]),
              IfValue<DirectionExpression>(BySlot.two.facing(),
                  comparedTo: left, notEqual: [Face(down).move(BySlot.two)]),
            ]),
            startingMap: GameMap(MapId.Test))
        .event
        .withoutComments();

    expect(
        asm,
        Asm([
          lea(Constant('Character_1').w, a4),
          cmpi.w(FacingDir_Right.i, facing_dir(a4)),
          bne(Label('.1_continue')),
          updateObjFacing(FacingDir_Up.i),
          label(Label('.1_continue')),
          lea(Constant('Character_2').w, a4),
          cmpi.w(FacingDir_Left.i, facing_dir(a4)),
          beq(Label('.3_continue')),
          updateObjFacing(FacingDir_Down.i),
          label(Label('.3_continue')),
        ]));
  });

  test('consecutive computed comparisons have distinct labels', () {
    final asm = Program()
        .addScene(
            SceneId('turns'),
            Scene([
              IfValue<DirectionExpression>(BySlot.one.facing().turn(1),
                  comparedTo: right, equal: [Pause(Duration(seconds: 1))]),
              IfValue<DirectionExpression>(BySlot.two.facing().turn(1),
                  comparedTo: left, equal: [Pause(Duration(seconds: 1))]),
            ]),
            startingMap: GameMap(MapId.Test))
        .event
        .withoutComments();

    expect(
        asm,
        Asm([
          lea(Constant('Character_1').w, a4),
          move.w(facing_dir(a4), d0),
          bchg(3.i, d0),
          bne(Label('.skip_1_operand1')),
          bchg(2.i, d0),
          label(Label('.skip_1_operand1')),
          cmpi.w(FacingDir_Right.i, d0),
          bne(Label('.1_continue')),
          move.w(Word(59).i, d0),
          jsr(Label('DoMapUpdateLoop').l),
          label(Label('.1_continue')),
          lea(Constant('Character_2').w, a4),
          move.w(facing_dir(a4), d0),
          bchg(3.i, d0),
          bne(Label('.skip_3_operand1')),
          bchg(2.i, d0),
          label(Label('.skip_3_operand1')),
          cmpi.w(FacingDir_Left.i, d0),
          bne(Label('.3_continue')),
          move.w(Word(59).i, d0),
          jsr(Label('DoMapUpdateLoop').l),
          label(Label('.3_continue')),
        ]));
  });
}
