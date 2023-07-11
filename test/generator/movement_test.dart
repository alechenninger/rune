import 'package:rune/asm/asm.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/map.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  group('generates asm for individual movements', () {
    group('step in one direction', () {
      test('move right, after previously not following leader', () {
        var ctx = Memory();
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
        var ctx = Memory();
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
                ..speed = StepSpeed.walk
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
        var ctx = Memory();
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
        var ctx = Memory();
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
        var ctx = Memory();
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
        var ctx = Memory();
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
        var ctx = Memory();
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

      test('multiple moves with facing', () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.positions[alys] = Position(0x1f0, 0x0a0);
            ctx.positions[shay] = Position(0x1f0, 0x090);
          }),
          IndividualMoves()
            ..moves[alys] = (StepPaths()
              ..step(StepPath()
                ..distance = 2.steps
                ..direction = Direction.down)
              ..step(StepPath()
                ..distance = 4.steps
                ..direction = Direction.left)
              ..face(Direction.right))
            ..moves[shay] = (StepPaths()
              ..step(StepPath()
                ..distance = 3.steps
                ..direction = Direction.down)
              ..step(StepPath()
                ..distance = 3.steps
                ..direction = Direction.left))
        ]);

        var program = Program();
        var sceneAsm = program.addScene(SceneId('testscene'), scene);
        print(sceneAsm);

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              bset(0.toByte.i, Char_Move_Flags.w),
              bset(1.toByte.i, Char_Move_Flags.w),
              moveq(alys.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              move.w(0x1b0.toWord.i, dest_x_pos(a4)),
              move.w(0x0c0.toWord.i, dest_y_pos(a4)),
              moveq(shay.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              move.w(0x1c0.toWord.i, d0),
              move.w(0x0c0.toWord.i, d1),
              jsr(Label('Event_MoveCharacter').l),
              moveq(alys.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              moveq(FacingDir_Right.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
            ]));
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
            ]));
      });

      test(
          'multiple moves of the same npc in same event only replaces field routine once',
          () {
        var scene = Scene([
          SetContext((ctx) {
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
              doMapUpdateLoop(Word(8 /*8 frames per step?*/)),
              move.w(Word(0x90).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
            ]));
      });

      test(
          'multiple moves of the same npc across scene only replaces field routine once',
          () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.positions[npc] = Position(0x50, 0x50);
            ctx.positions[alys] = Position(0x50, 0x40);
            ctx.currentMap = map;
          }),
          IndividualMoves()
            ..moves[MapObjectById(MapObjectId('testnpc'))] = (StepPaths()
              ..step(StepPath()
                ..direction = Direction.right
                ..distance = 2.steps)),
          IndividualMoves()
            ..moves[MapObjectById(MapObjectId('testnpc'))] = (StepPaths()
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
              doMapUpdateLoop(Word(8 /*8 frames per step?*/)),
              move.w(Word(0x90).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
            ]));
      });

      test(
          'multiple moves of the same npc across scene only replaces field routine once unless asm event',
          () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.positions[npc] = Position(0x50, 0x50);
            ctx.positions[alys] = Position(0x50, 0x40);
            ctx.currentMap = map;
          }),
          IndividualMoves()
            ..moves[MapObjectById(MapObjectId('testnpc'))] = (StepPaths()
              ..step(StepPath()
                ..direction = Direction.right
                ..distance = 2.steps)),
          AsmEvent(Asm([
            // Changes a4!
            characterBySlotToA4(1),
          ])),
          IndividualMoves()
            ..moves[MapObjectById(MapObjectId('testnpc'))] = (StepPaths()
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
              characterBySlotToA4(1),
              doMapUpdateLoop(Word(8 /*8 frames per step?*/)),
              lea(0xFFFFC300.toLongword.l, a4),
              move.w(Word(0x90).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
            ]));
      });

      test('faces npcs', () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.positions[npc] = Position(0x50, 0x60);
            ctx.setFacing(npc, Direction.down);
            ctx.currentMap = map;
          }),
          IndividualMoves()
            ..moves[MapObjectById(MapObjectId('testnpc'))] =
                (StepPath()..direction = Direction.right)
        ]);

        var sceneAsm = program.addScene(SceneId('testscene'), scene);

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              lea(0xFFFFC300.toLongword.l, a4),
              move.w(0x8194.toWord.i, a4.indirect),
              move.w(0x50.i, dest_x_pos(a4)),
              move.w(0x60.i, dest_y_pos(a4)),
              moveq(FacingDir_Right.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
            ]));
      });

      test('resets npc routine', () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.positions[npc] = Position(0x50, 0x50);
            ctx.currentMap = map;
          }),
          IndividualMoves()
            ..moves[MapObjectById(MapObjectId('testnpc'))] = (StepPath()
              ..direction = Direction.right
              ..distance = 2.steps),
          ResetObjectRoutine(MapObjectById(MapObjectId('testnpc')))
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

      test('resets npc routine for npc not already in a4', () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.positions[npc] = Position(0x50, 0x50);
            ctx.currentMap = map;
          }),
          IndividualMoves()
            ..moves[MapObjectById(MapObjectId('testnpc'))] = (StepPath()
              ..direction = Direction.right
              ..distance = 2.steps),
          AbsoluteMoves()..destinations[shay] = Position(0x60, 0x60),
          ResetObjectRoutine(MapObjectById(MapObjectId('testnpc')))
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
              followLeader(false),
              characterByNameToA4('Chaz'),
              moveCharacter(x: Word(0x60).i, y: Word(0x60).i),
              lea(0xFFFFC300.toLongword.l, a4),
              move.w(npc.routine.index.i, a4.indirect),
              jsr(npc.routine.label.l),
            ]));
      });
    });

    test('just facing with multiple characters', () {
      var moves = IndividualMoves()
        ..moves[shay] = (StepPath()..direction = right)
        ..moves[alys] = (StepPath()..direction = left);

      var asm = moves.toAsm(Memory()..followLead = false);
      expect(
          asm,
          Asm([
            characterByIdToA4(shay.charIdAddress),
            updateObjFacing(right.address),
            characterByIdToA4(alys.charIdAddress),
            updateObjFacing(left.address),
          ]));
    });

    test('facing and movement adjusts facing then movement', () {
      var moves = IndividualMoves()
        ..moves[hahn] = (StepPath()
          ..direction = up
          ..distance = 1.step)
        ..moves[alys] = (StepPath()..direction = up);

      var asm = moves.toAsm(Memory()
        ..positions[hahn] = Position(0x100, 0x0c0)
        ..followLead = false);

      expect(
          asm,
          Asm([
            characterByIdToA4(alys.charIdAddress),
            updateObjFacing(up.address),
            characterByIdToA4(hahn.charIdAddress),
            moveCharacter(x: Word(0x100).i, y: Word(0xb0).i)
          ]));
    });

    test('movements with delayed facing move then face', () {
      var moves = IndividualMoves()
        ..moves[hahn] = (StepPath()
          ..direction = up
          ..distance = 1.step)
        ..moves[shay] = (StepPaths()
          ..step(StepPath()
            ..delay = 1.step
            ..direction = left
            ..distance = 1.step)
          ..face(down))
        ..moves[alys] = (StepPath()
          ..delay = 2.steps
          ..direction = up);

      var asm = moves.toAsm(Memory()
        ..positions[hahn] = Position(0x100, 0x0c0)
        ..positions[shay] = Position(0x0E0, 0x0c0)
        ..positions[alys] = Position(0x0F0, 0x0c0)
        ..followLead = false);

      print(asm);

      expect(
          asm,
          Asm([
            characterByIdToA4(hahn.charIdAddress),
            moveCharacter(x: Word(0x100).i, y: Word(0xb0).i),
            characterByIdToA4(shay.charIdAddress),
            moveCharacter(x: Word(0x0d0).i, y: Word(0xc0).i),
            updateObjFacing(down.address),
            characterByIdToA4(alys.charIdAddress),
            updateObjFacing(up.address),
          ]));
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

  group('absolute moves', () {
    late Memory state;
    late Memory testState;
    late GameMap map;
    late MapObject npc;

    setUp(() {
      map = GameMap(MapId.Test);
      npc = MapObject(
          id: 'testnpc',
          startPosition: Position(0x200, 0x200),
          spec: Npc(Sprite.PalmanMan1, WanderAround(down)));
      map.addObject(npc);

      state = Memory()..currentMap = map;
      testState = state.branch();
    });

    test('single character', () {
      var event = AbsoluteMoves()..destinations[shay] = Position(0x1a0, 0x1f0);
      var asm = absoluteMovesToAsm(event, state);

      expect(
          asm,
          EventAsm([
            followLeader(false),
            shay.toA4(testState),
            moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i)
          ]));
    });

    test('makes objects scriptable', () {
      var event = AbsoluteMoves()..destinations[npc] = Position(0x1a0, 0x1f0);
      var asm = absoluteMovesToAsm(event, state);

      expect(
          asm,
          EventAsm([
            npc.toA4(state),
            move.w(0x8194.toWord.i, a4.indirect),
            moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i),
          ]));
    });

    test('multiple characters', () {
      var event = AbsoluteMoves()
        ..destinations[shay] = Position(0x1a0, 0x1f0)
        ..destinations[alys] = Position(0x1b0, 0x200);

      var asm = absoluteMovesToAsm(event, state);

      expect(
          asm,
          EventAsm([
            followLeader(false),
            shay.toA4(testState),
            setDestination(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i),
            alys.toA4(testState),
            moveCharacter(x: 0x1b0.toWord.i, y: 0x200.toWord.i)
          ]));
    });

    test('updates context positions', () {
      var event = AbsoluteMoves()
        ..destinations[shay] = Position(0x1a0, 0x1f0)
        ..destinations[alys] = Position(0x1b0, 0x200);

      var _ = absoluteMovesToAsm(event, state);

      expect(state.positions[shay], Position(0x1a0, 0x1f0));
      expect(state.positions[alys], Position(0x1b0, 0x200));
    });

    test('clears context facing', () {
      state.setFacing(shay, up);
      state.setFacing(alys, down);

      var event = AbsoluteMoves()
        ..destinations[shay] = Position(0x1a0, 0x1f0)
        ..destinations[alys] = Position(0x1b0, 0x200);

      var _ = absoluteMovesToAsm(event, state);

      expect(state.getFacing(shay), isNull);
      expect(state.getFacing(alys), isNull);
    });

    test('resolves references', () {
      var event = AbsoluteMoves()
        ..destinations[MapObjectById(MapObjectId('testnpc'))] =
            Position(0x1a0, 0x1f0);

      var asm = absoluteMovesToAsm(event, state);

      expect(
          asm,
          EventAsm([
            npc.toA4(state),
            move.w(0x8194.toWord.i, a4.indirect),
            moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i),
          ]));
      expect(state.positions[npc], Position(0x1a0, 0x1f0));
    });

    test('change speed and reset after', () {
      var event = AbsoluteMoves()
        ..destinations[shay] = Position(0x1a0, 0x1f0)
        ..speed = StepSpeed.slowWalk;

      var asm = absoluteMovesToAsm(event, state);

      expect(
          asm,
          EventAsm([
            followLeader(false),
            move.b(0.toByte.i, FieldObj_Step_Offset.w),
            shay.toA4(testState),
            moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i),
            move.b(1.i, FieldObj_Step_Offset.w)
          ]));
    });

    test('with y axis movement first', () {
      var event = AbsoluteMoves()
        ..destinations[shay] = Position(0x1a0, 0x1f0)
        ..startingAxis = Axis.y;
      var asm = absoluteMovesToAsm(event, state);

      expect(
          asm,
          EventAsm([
            followLeader(false),
            moveAlongXAxisFirst(false),
            shay.toA4(testState),
            moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i)
          ]));
    });

    group('following leader', () {
      test('moving leader by slot', () {
        var event = AbsoluteMoves()
          ..destinations[Slot.one] = Position(0x1a0, 0x1f0)
          ..followLeader = true;
        var asm = absoluteMovesToAsm(event, state);

        expect(
            asm,
            EventAsm([
              Slot.one.toA4(testState),
              moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i)
            ]));
      });

      test('moving leader y first', () {
        var event = AbsoluteMoves()
          ..destinations[Slot.one] = Position(0x1a0, 0x1f0)
          ..startingAxis = Axis.y
          ..followLeader = true;
        var asm = absoluteMovesToAsm(event, state);

        expect(
            asm,
            EventAsm([
              moveAlongXAxisFirst(false),
              Slot.one.toA4(testState),
              moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i)
            ]));
      });

      test('moving slot 2 is error', () {
        var event = AbsoluteMoves()
          ..destinations[Slot.two] = Position(0x1a0, 0x1f0)
          ..followLeader = true;

        expect(() => absoluteMovesToAsm(event, state),
            throwsA(TypeMatcher<StateError>()));
      });

      test('moving leader by character', () {
        state.setSlot(1, shay);

        var event = AbsoluteMoves()
          ..destinations[shay] = Position(0x1a0, 0x1f0)
          ..followLeader = true;

        var asm = absoluteMovesToAsm(event, state);

        expect(
            asm,
            EventAsm([
              Slot.one.toA4(testState),
              moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i)
            ]));
      });

      test('moving character (not leader) is error', () {
        var event = AbsoluteMoves()
          ..destinations[shay] = Position(0x1a0, 0x1f0)
          ..followLeader = true;

        expect(() => absoluteMovesToAsm(event, state),
            throwsA(TypeMatcher<StateError>()));
      });
    });
  });
}
