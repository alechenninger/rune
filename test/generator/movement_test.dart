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

      test('with different movement speed', () {
        var program = Program();
        var sceneAsm = program.addScene(
            SceneId('testscene'),
            Scene([
              SetContext((ctx) {
                ctx.followLead = false;
                ctx.slots[1] = alys;
                ctx.positions[alys] = Position(0x50, 0x50);
              }),
              IndividualMoves()
                ..speed = StepSpeed.slowWalk
                ..moves[alys] = (StepPath()
                  ..distance = 2.steps
                  ..direction = Direction.right)
            ]));

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              move.b(4.toByte.i, FieldObj_Step_Offset.w),
              lea(Constant('Character_1').w, a4),
              move.w(Word(0x70).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
              move.b(1.i, FieldObj_Step_Offset.w),
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
              move.w('1e0'.hex.toWord.i, a4.plus('dest_x_pos'.toConstant)),
              move.w('250'.hex.toWord.i, a4.plus('dest_y_pos'.toConstant)),
              lea(Constant('Character_2').w, a4),
              move.w('240'.hex.toWord.i, d0),
              move.w('240'.hex.toWord.i, d1),
              jsr('Event_MoveCharacter'.toLabel.l),
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
      });
    });

    group('npcs', () {
      var map = GameMap(MapId.Test);
      var npc = MapObject(
          id: 'testnpc',
          startPosition: Position(0x50, 0x50),
          spec: Npc(Sprite.PalmanOldMan1, WanderAround(Direction.down)));
      map.addObject(npc);

      var program = Program();

      setUp(() {
        program = Program();
      });

      test('moves ncps', () {
        var scene = Scene([
          SetContext((ctx) {
            // todo: follow flag shouldn't matter for moving npc
            ctx.followLead = false;
            ctx.positions[npc] = Position(0x50, 0x50);
            ctx.currentMap = map;
          }),
          IndividualMoves()
            ..moves[MapObjectById(MapObjectId('testnpc'))] = (StepPath()
              ..direction = Direction.right
              ..distance = 2.steps)
        ]);

        var sceneAsm = program.addScene(SceneId('testscene'), scene);

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              lea(0xFFFFC300.toLongword.l, a4),
              move.w(0x8194.toWord.i, a4.indirect),
              move.w(Word(0x70).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
              move.w(npc.routine.index.i, a4.indirect),
              jsr(npc.routine.label.l),
            ]));
      });

      test('multiple moves of the same npc only replaces field routine once',
          () {
        var scene = Scene([
          SetContext((ctx) {
            // todo: follow flag shouldn't matter for moving npc
            ctx.followLead = false;
            ctx.positions[npc] = Position(0x50, 0x50);
            ctx.positions[alys] = Position(0x50, 0x40);
            ctx.currentMap = map;
          }),
          IndividualMoves()
            ..moves[MapObjectById(MapObjectId('testnpc'))] = (StepPaths()
              ..step(StepPath()
                ..direction = Direction.right
                ..distance = 2.steps)
              ..step(StepPath()
                ..delay = 1.step
                ..direction = Direction.right
                ..distance = 2.steps))
        ]);

        var sceneAsm = program.addScene(SceneId('testscene'), scene);

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              lea(0xFFFFC300.toLongword.l, a4),
              move.w(0x8194.toWord.i, a4.indirect),
              move.w(Word(0x70).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
              vIntPrepareLoop(Word(8 /*8 frames per step?*/)),
              move.w(Word(0x90).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
              move.w(npc.routine.index.i, a4.indirect),
              jsr(npc.routine.label.l),
            ]));
      });
    });
  });

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
