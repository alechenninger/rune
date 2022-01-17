import 'dart:math';

import 'package:rune/asm/asm.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  group('generates asm', () {
    test(
        'move right, not following leader, after previously not following leader',
        () {
      var ctx = EventContext();
      ctx.slots.insert(0, alys);
      ctx.slots.insert(1, shay);

      ctx.followLead = false;

      ctx.positions[alys] = Point('230'.hex, '250'.hex);
      ctx.positions[shay] = Point('230'.hex, '240'.hex);

      var moveRight = Move();
      moveRight.movements[alys] = StepDirection()
        ..distance = 5
        ..direction = Direction.right;

      var asm = moveRight.toAsm(ctx);

      print(asm);

      expect(
          asm,
          Asm([
            lea(Constant('Character_1').w, a4),
            move.w(Word('280'.hex).i, d0),
            move.w(Word('250'.hex).i, d1),
            jsr(Label('Event_MoveCharacter').l)
          ]));
    });

    test('move right, not following leader, after previously following leader',
        () {
      var ctx = EventContext();
      ctx.slots.insert(0, alys);
      ctx.slots.insert(1, shay);

      ctx.followLead = true;

      ctx.positions[alys] = Point('230'.hex, '250'.hex);
      ctx.positions[shay] = Point('230'.hex, '240'.hex);

      var moveRight = Move();
      moveRight.movements[alys] = StepDirection()
        ..distance = 5
        ..direction = Direction.right;

      var asm = moveRight.toAsm(ctx);

      print(asm);

      expect(
          asm,
          Asm([
            bset(Byte.zero.i, Char_Move_Flags.w),
            lea(Constant('Character_1').w, a4),
            move.w(Word('280'.hex).i, d0),
            move.w(Word('250'.hex).i, d1),
            jsr(Label('Event_MoveCharacter').l)
          ]));
    });

    test('multiple moves same distance', () {
      var ctx = EventContext();
      ctx.slots.insert(0, alys);
      ctx.slots.insert(1, shay);

      ctx.positions[alys] = Point('230'.hex, '250'.hex);
      ctx.positions[shay] = Point('230'.hex, '240'.hex);

      var move = Move();
      move.movements[alys] = StepDirection()
        ..distance = 5
        ..direction = Direction.right;
      move.movements[shay] = StepDirection()
        ..distance = 1
        ..direction = Direction.down;

      var asm = move.toAsm(ctx);

      print(asm);

      expect(asm, Asm([]));
    });

    test('multiple moves different distance', () {
      var ctx = EventContext();
      ctx.slots.insert(0, alys);
      ctx.slots.insert(1, shay);

      ctx.positions[alys] = Point('230'.hex, '240'.hex);
      ctx.positions[shay] = Point('230'.hex, '250'.hex);

      var move = Move();
      move.movements[alys] = StepDirection()
        ..distance = 4
        ..direction = Direction.left;
      move.movements[shay] = StepDirection()
        ..distance = 2
        ..direction = Direction.down;

      var asm = move.toAsm(ctx);

      print(asm);

      expect(asm, Asm([]));
    });

    test('multiple moves with some delayed', () {
      var ctx = EventContext();
      ctx.slots.insert(0, alys);
      ctx.slots.insert(1, shay);

      ctx.positions[alys] = Point('2A0'.hex, '250'.hex);
      ctx.positions[shay] = Point('230'.hex, '1F0'.hex);

      var move = Move();
      move.movements[alys] = StepDirection()
        ..distance = 5
        ..direction = Direction.left;
      move.movements[shay] = StepDirection()
        ..distance = 5
        ..delay = 2
        ..direction = Direction.down;

      var asm = move.toAsm(ctx);

      print(asm);

      expect(asm, Asm([]));
    });
  });
}
