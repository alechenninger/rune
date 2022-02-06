import 'dart:math';

import 'package:rune/asm/asm.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  group('generates asm for individual movements', () {
    group('step in one direction', () {
      test('move right, after previously not following leader', () {
        var ctx = EventContext();
        ctx.slots[0] = alys;
        ctx.slots[1] = shay;

        ctx.followLead = false;

        ctx.positions[alys] = Point('230'.hex, '250'.hex);
        ctx.positions[shay] = Point('230'.hex, '240'.hex);

        var moveRight = IndividualMoves();
        moveRight.moves[alys] = StepDirection()
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

      test('move right, after previously following leader', () {
        var ctx = EventContext();
        ctx.slots[0] = alys;
        ctx.slots[1] = shay;

        ctx.followLead = true;

        ctx.positions[alys] = Point('230'.hex, '250'.hex);
        ctx.positions[shay] = Point('230'.hex, '240'.hex);

        var moveRight = IndividualMoves();
        moveRight.moves[alys] = StepDirection()
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

      test('move right different distances, previously following lead', () {
        var ctx = EventContext();
        ctx.slots[0] = alys;
        ctx.slots[1] = shay;

        ctx.followLead = true;

        ctx.positions[alys] = Point('230'.hex, '250'.hex);
        ctx.positions[shay] = Point('230'.hex, '240'.hex);

        var moves = IndividualMoves();
        moves.moves[alys] = StepDirection()
          ..distance = 5
          ..direction = Direction.right;
        moves.moves[shay] = StepDirection()
          ..distance = 1
          ..direction = Direction.right;

        var asm = moves.toAsm(ctx);

        print(asm);

        expect(
            asm,
            Asm([
              bset(Byte.zero.i, Char_Move_Flags.w),
              lea(Constant('Character_1').w, a4),
              move.w(
                  Word('240'.hex).i, a4.indirect.plus(Constant('dest_x_pos'))),
              move.w(
                  Word('250'.hex).i, a4.indirect.plus(Constant('dest_y_pos'))),
              lea(Constant('Character_2').w, a4),
              move.w(Word('240'.hex).i, d0),
              move.w(Word('240'.hex).i, d1),
              jsr(Label('Event_MoveCharacter').l),
              lea(Constant('Character_1').w, a4),
              move.w(Word('280'.hex).i, d0),
              move.w(Word('250'.hex).i, d1),
              jsr(Label('Event_MoveCharacter').l),
            ]));
      });

      test('multiple move same distance', () {
        var ctx = EventContext();
        ctx.slots[0] = alys;
        ctx.slots[1] = shay;

        ctx.positions[alys] = Point('230'.hex, '250'.hex);
        ctx.positions[shay] = Point('230'.hex, '240'.hex);

        var moves = IndividualMoves();
        moves.moves[alys] = StepDirection()
          ..distance = 4
          ..direction = Direction.right;
        moves.moves[shay] = StepDirection()
          ..distance = 4
          ..direction = Direction.right;

        var asm = moves.toAsm(ctx);

        print(asm);

        expect(
            asm,
            Asm([
              bset(Byte.zero.i, Char_Move_Flags.w),
              lea(Constant('Character_1').w, a4),
              move.w(Word('270'.hex).i, a4.plus(Constant('dest_x_pos'))),
              move.w(Word('250'.hex).i, a4.plus(Constant('dest_y_pos'))),
              lea(Constant('Character_2').w, a4),
              move.w(Word('270'.hex).i, d0),
              move.w(Word('240'.hex).i, d1),
              jsr(Label('Event_MoveCharacter').l),
            ]));
      });

      test('multiple moves with some delayed', () {
        var ctx = EventContext();
        ctx.slots[0] = alys;
        ctx.slots[1] = shay;

        ctx.positions[alys] = Point('230'.hex, '250'.hex);
        ctx.positions[shay] = Point('230'.hex, '240'.hex);

        var moves = IndividualMoves();
        moves.moves[alys] = StepDirection()
          ..distance = 5
          ..direction = Direction.left;
        moves.moves[shay] = StepDirection()
          ..distance = 3
          ..delay = 4
          ..direction = Direction.right;

        var asm = moves.toAsm(ctx);

        print(asm);

        expect(
            asm,
            Asm([
              bset(Byte.zero.i, Char_Move_Flags.w),
              lea(Constant('Character_1').w, a4),
              move.w('1f0'.hex.word.i, d0),
              move.w('250'.hex.word.i, d1),
              jsr(Label('Event_MoveCharacter').l),
              lea('Character_1'.constant.w, a4),
              move.w('1e0'.hex.word.i, a4.plus('dest_x_pos'.constant)),
              move.w('250'.hex.word.i, a4.plus('dest_y_pos'.constant)),
              lea(Constant('Character_2').w, a4),
              move.w('240'.hex.word.i, d0),
              move.w('240'.hex.word.i, d1),
              jsr('Event_MoveCharacter'.label.l),
              lea('Character_2'.constant.w, a4),
              move.w('260'.hex.word.i, d0),
              move.w('240'.hex.word.i, d1),
              jsr('Event_MoveCharacter'.label.l)
            ]));
      });
    });

    group('step in multiple directions', () {
      test('one character right then up', () {
        var ctx = EventContext();
        ctx.slots[0] = alys;
        ctx.slots[1] = shay;

        ctx.positions[alys] = Point('230'.hex, '250'.hex);
        ctx.positions[shay] = Point('230'.hex, '240'.hex);

        var moves = IndividualMoves();
        moves.moves[alys] = StepDirections()
          ..step(StepDirection()
            ..distance = 5
            ..direction = Direction.right)
          ..step(StepDirection()
            ..distance = 5
            ..direction = Direction.up);

        var asm = moves.toAsm(ctx);

        print(asm);

        expect(
            asm,
            Asm([
              bset(Byte.zero.i, Char_Move_Flags.w),
              lea(Constant('Character_1').w, a4),
              move.w('280'.hex.word.i, d0),
              move.w('200'.hex.word.i, d1),
              jsr(Label('Event_MoveCharacter').l),
            ]));
      });

      test('stress test', () {
        var ctx = EventContext();
        ctx.slots[0] = alys;
        ctx.slots[1] = shay;

        ctx.positions[alys] = Point('230'.hex, '250'.hex);
        ctx.positions[shay] = Point('230'.hex, '240'.hex);

        var moves = IndividualMoves();
        moves.moves[alys] = StepDirections()
          ..step(StepDirection()
            ..delay = 3
            ..distance = 5
            ..direction = Direction.right)
          ..step(StepDirection()
            ..delay = 1
            ..distance = 5
            ..direction = Direction.up)
          ..step(StepDirection()
            ..delay = 10
            ..distance = 4
            ..direction = Direction.left)
          ..face(Direction.down);
        moves.moves[shay] = StepDirections()
          ..step(StepDirection()
            ..delay = 1
            ..distance = 2
            ..direction = Direction.up)
          ..step(StepDirection()
            ..delay = 0
            ..distance = 7
            ..direction = Direction.right)
          ..step(StepDirection()
            ..delay = 5
            ..distance = 8
            ..direction = Direction.left);

        var asm = moves.toAsm(ctx);

        print(asm);

        expect(
            asm,
            Asm([
              bset(Byte.zero.i, Char_Move_Flags.w),
              lea(Constant('Character_1').w, a4),
              move.w('280'.hex.word.i, d0),
              move.w('200'.hex.word.i, d1),
              jsr(Label('Event_MoveCharacter').l),
            ]));
      });
    });
  });
}
