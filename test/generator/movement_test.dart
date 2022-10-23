import 'package:rune/asm/asm.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/map.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  // skipped because of update facing at end of each movement
  group('generates asm for individual movements', () {
    group('step in one direction', () {
      test('move right, after previously not following leader', () {
        var ctx = EventState();
        ctx.slots[1] = alys;
        ctx.slots[2] = shay;

        ctx.followLead = false;

        ctx.positions[alys] = Position('230'.hex, '250'.hex);
        ctx.positions[shay] = Position('230'.hex, '240'.hex);

        var moveRight = IndividualMoves();
        moveRight.moves[alys] = StepPath()
          ..distance = 5.steps
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
        var ctx = EventState();
        ctx.slots[1] = alys;
        ctx.slots[2] = shay;

        ctx.followLead = true;

        ctx.positions[alys] = Position('230'.hex, '250'.hex);
        ctx.positions[shay] = Position('230'.hex, '240'.hex);

        var moveRight = IndividualMoves();
        moveRight.moves[alys] = StepPath()
          ..distance = 5.steps
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
        var ctx = EventState();
        ctx.slots[1] = alys;
        ctx.slots[2] = shay;

        ctx.followLead = true;

        ctx.positions[alys] = Position('230'.hex, '250'.hex);
        ctx.positions[shay] = Position('230'.hex, '240'.hex);

        var moves = IndividualMoves();
        moves.moves[alys] = StepPath()
          ..distance = 5.steps
          ..direction = Direction.right;
        moves.moves[shay] = StepPath()
          ..distance = 1.steps
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
        var ctx = EventState();
        ctx.slots[1] = alys;
        ctx.slots[2] = shay;

        ctx.positions[alys] = Position('230'.hex, '250'.hex);
        ctx.positions[shay] = Position('230'.hex, '240'.hex);

        var moves = IndividualMoves();
        moves.moves[alys] = StepPath()
          ..distance = 4.steps
          ..direction = Direction.right;
        moves.moves[shay] = StepPath()
          ..distance = 4.steps
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
        var ctx = EventState();
        ctx.slots[1] = alys;
        ctx.slots[2] = shay;

        ctx.positions[alys] = Position('230'.hex, '250'.hex);
        ctx.positions[shay] = Position('230'.hex, '240'.hex);

        var moves = IndividualMoves();
        moves.moves[alys] = StepPath()
          ..distance = 5.steps
          ..direction = Direction.left;
        moves.moves[shay] = StepPath()
          ..distance = 3.steps
          ..delay = 4.steps
          ..direction = Direction.right;

        var asm = moves.toAsm(ctx);

        print(asm);

        expect(
            asm,
            Asm([
              bset(Byte.zero.i, Char_Move_Flags.w),
              lea(Constant('Character_1').w, a4),
              move.w('1f0'.hex.toWord.i, d0),
              move.w('250'.hex.toWord.i, d1),
              jsr(Label('Event_MoveCharacter').l),
              lea('Character_1'.toConstant.w, a4),
              move.w('1e0'.hex.toWord.i, a4.plus('dest_x_pos'.toConstant)),
              move.w('250'.hex.toWord.i, a4.plus('dest_y_pos'.toConstant)),
              lea(Constant('Character_2').w, a4),
              move.w('240'.hex.toWord.i, d0),
              move.w('240'.hex.toWord.i, d1),
              jsr('Event_MoveCharacter'.toLabel.l),
              lea('Character_2'.toConstant.w, a4),
              move.w('260'.hex.toWord.i, d0),
              move.w('240'.hex.toWord.i, d1),
              jsr('Event_MoveCharacter'.toLabel.l)
            ]));
      });
    });

    group('step in multiple directions', () {
      test('one character right then up', () {
        var ctx = EventState();
        ctx.slots[1] = alys;
        ctx.slots[2] = shay;

        ctx.positions[alys] = Position('230'.hex, '250'.hex);
        ctx.positions[shay] = Position('230'.hex, '240'.hex);

        var moves = IndividualMoves();
        moves.moves[alys] = StepPaths()
          ..step(StepPath()
            ..distance = 5.steps
            ..direction = Direction.right)
          ..step(StepPath()
            ..distance = 5.steps
            ..direction = Direction.up);

        var asm = moves.toAsm(ctx);

        print(asm);

        expect(
            asm,
            Asm([
              bset(Byte.zero.i, Char_Move_Flags.w),
              lea(Constant('Character_1').w, a4),
              move.w('280'.hex.toWord.i, d0),
              move.w('200'.hex.toWord.i, d1),
              jsr(Label('Event_MoveCharacter').l),
            ]));
      });

      test('stress test', () {
        var ctx = EventState();
        ctx.slots[1] = alys;
        ctx.slots[2] = shay;

        ctx.positions[alys] = Position('230'.hex, '250'.hex);
        ctx.positions[shay] = Position('230'.hex, '240'.hex);

        var moves = IndividualMoves();
        moves.moves[alys] = StepPaths()
          ..step(StepPath()
            ..delay = 3.steps
            ..distance = 5.steps
            ..direction = Direction.right)
          ..step(StepPath()
            ..delay = 1.steps
            ..distance = 5.steps
            ..direction = Direction.up)
          ..step(StepPath()
            ..delay = 10.steps
            ..distance = 4.steps
            ..direction = Direction.left)
          ..face(Direction.down);
        moves.moves[shay] = StepPaths()
          ..step(StepPath()
            ..delay = 1.steps
            ..distance = 2.steps
            ..direction = Direction.up)
          ..step(StepPath()
            ..delay = 0.steps
            ..distance = 7.steps
            ..direction = Direction.right)
          ..step(StepPath()
            ..delay = 5.steps
            ..distance = 8.steps
            ..direction = Direction.left);

        var asm = moves.toAsm(ctx);

        print(asm);

        expect(
            asm,
            Asm([
              bset(Byte.zero.i, Char_Move_Flags.w),
              lea(Constant('Character_1').w, a4),
              move.w('280'.hex.toWord.i, d0),
              move.w('200'.hex.toWord.i, d1),
              jsr(Label('Event_MoveCharacter').l),
            ]));
      });
    });
  }, skip: false);

  group('generates asm for FacePlayer', () {
    late AsmGenerator generator;
    late AsmContext ctx;

    setUp(() {
      generator = AsmGenerator();
      ctx = AsmContext.forEvent(EventState());
    });

    test('delegates to Interaction_UpdateObj', () {
      var npc = MapObject(
          startPosition: Position(0x200, 0x200),
          spec: Npc(Sprite.PalmanMan1, FaceDown()));
      var map = GameMap(MapId.Piata)..addObject(npc);
      ctx.state.currentMap = map;

      var asm = generator.facePlayerToAsm(FacePlayer(npc), ctx);

      print(asm);

      expect(
          asm,
          Asm([
            lea(Absolute.long(map.addressOf(npc)), a3),
            jsr('Interaction_UpdateObj'.toLabel.l)
          ]));
    });

    test('reuses a3 in context', () {
      var npc = MapObject(
          startPosition: Position(0x200, 0x200),
          spec: Npc(Sprite.PalmanMan1, FaceDown()));
      var map = GameMap(MapId.Piata)..addObject(npc);
      ctx.state.currentMap = map;
      ctx.putInAddress(a3, npc);

      var asm = generator.facePlayerToAsm(FacePlayer(npc), ctx);

      expect(asm, Asm([jsr('Interaction_UpdateObj'.toLabel.l)]));
    });
  });
}
