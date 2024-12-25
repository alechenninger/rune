import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/labels.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  late GameMap testMap;

  setUp(() {
    testMap = GameMap(MapId.Test);
  });

  @Deprecated('use generateEventAsm from fixtures')
  Asm generate(List<Event> events, {GameMap? inMap, EventState? context}) {
    return generateEventAsm(events, inMap: inMap, context: context);
  }

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

      test('move without context computes destination at runtime', () {
        var ctx = Memory();
        ctx.slots[1] = alys;
        ctx.followLead = false;

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
              move.w(curr_x_pos(a4), d0),
              move.w(curr_y_pos(a4), d1),
              addi.w(0x50.toWord.i, d0),
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
              move.b(Byte.one.i, FieldObj_Step_Offset.w),
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

      test('moves without context compute destination at runtime', () {
        var ctx = Memory();
        ctx.slots[1] = alys;

        var moves = IndividualMoves();
        moves.moves[alys] = StepPaths()
          ..step(StepPath()
            ..distance = 5.steps
            ..direction = Direction.right)
          ..step(StepPath()
            ..distance = 4.steps
            ..direction = Direction.up);

        var asm = moves.toAsm(ctx);

        print(asm);

        expect(
            asm,
            Asm([
              bset(Byte.zero.i, Char_Move_Flags.w),
              lea(Constant('Character_1').w, a4),
              move.w(curr_x_pos(a4), d0),
              move.w(curr_y_pos(a4), d1),
              addi.w(0x50.toWord.i, d0),
              subi.w(0x40.toWord.i, d1),
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

      test('facing while others move then face', () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.positions[alys] = Position(0x1f0, 0x0a0);
            ctx.positions[shay] = Position(0x1f0, 0x090);
          }),
          IndividualMoves()
            ..moves[rune] = Face(up)
            ..moves[alys] = (StepPaths()
              ..step(StepPath()
                ..distance = 2.steps
                ..direction = Direction.down)
              ..face(Direction.right))
            ..moves[shay] = (StepPaths()
              ..step(StepPath()
                ..distance = 2.steps
                ..direction = Direction.down)
              ..face(right))
        ]);

        var program = Program();
        var sceneAsm = program.addScene(SceneId('testscene'), scene);

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              bset(0.toByte.i, Char_Move_Flags.w),
              moveq(rune.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              moveq(FacingDir_Up.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
              moveq(alys.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              move.w(0x1f0.toWord.i, dest_x_pos(a4)),
              move.w(0x0c0.toWord.i, dest_y_pos(a4)),
              moveq(shay.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              move.w(0x1f0.toWord.i, d0),
              move.w(0x0b0.toWord.i, d1),
              jsr(Label('Event_MoveCharacter').l),
              moveq(alys.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              moveq(FacingDir_Right.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
              moveq(shay.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              moveq(FacingDir_Right.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
            ]));
      });

      test('facing while others move then face while others still move', () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.positions[alys] = Position(0x1f0, 0x0a0);
            ctx.positions[shay] = Position(0x1f0, 0x090);
            ctx.positions[hahn] = Position(0x200, 0x090);
          }),
          IndividualMoves()
            ..moves[rune] = Face(up)
            ..moves[alys] = (StepPaths()
              ..step(StepPath()
                ..distance = 2.steps
                ..direction = Direction.down)
              ..face(Direction.right))
            ..moves[shay] = (StepPaths()
              ..step(StepPath()
                ..distance = 2.steps
                ..direction = Direction.down)
              ..face(right))
            ..moves[hahn] = (StepPaths()
              ..step(StepPath()
                ..distance = 1.steps
                ..direction = Direction.down)
              ..face(right))
        ]);

        var program = Program();
        var sceneAsm = program.addScene(SceneId('testscene'), scene);

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              bset(0.toByte.i, Char_Move_Flags.w),
              moveq(rune.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              moveq(FacingDir_Up.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
              moveq(alys.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              move.w(0x1f0.toWord.i, dest_x_pos(a4)),
              move.w(0x0b0.toWord.i, dest_y_pos(a4)),
              moveq(shay.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              move.w(0x1f0.toWord.i, dest_x_pos(a4)),
              move.w(0x0a0.toWord.i, dest_y_pos(a4)),
              moveq(hahn.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              move.w(0x200.toWord.i, d0),
              move.w(0x0a0.toWord.i, d1),
              jsr(Label('Event_MoveCharacter').l),
              moveq(FacingDir_Right.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
              moveq(alys.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              move.w(0x1f0.toWord.i, dest_x_pos(a4)),
              move.w(0x0c0.toWord.i, dest_y_pos(a4)),
              moveq(shay.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              move.w(0x1f0.toWord.i, d0),
              move.w(0x0b0.toWord.i, d1),
              jsr(Label('Event_MoveCharacter').l),
              moveq(alys.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              moveq(FacingDir_Right.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
              moveq(shay.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              moveq(FacingDir_Right.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
            ]));
      });

      test('mix of move, delay, facing single object', () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.positions[rune] = Position(0x100, 0x100);
          }),
          IndividualMoves()
            ..moves[rune] = (StepPaths()
              ..step(StepPath()
                ..distance = 2.steps
                ..direction = Direction.right)
              ..face(Direction.up)
              ..step(StepPath()
                ..delay = 2.steps
                ..distance = 3.steps
                ..direction = Direction.left)
              ..face(Direction.up)
              ..step(StepPath()
                ..delay = 2.steps
                ..distance = 1.step
                ..direction = Direction.right)
              ..face(Direction.up))
        ]);

        var asm =
            Program().addScene(SceneId('test'), scene).event.withoutComments();

        expect(
            asm,
            Asm([
              bset(0.toByte.i, Char_Move_Flags.w),
              moveq(rune.charIdAddress, d0),
              jsr(Label('Event_GetCharacter').l),
              move.w(0x120.toWord.i, d0),
              move.w(0x100.toWord.i, d1),
              jsr(Label('Event_MoveCharacter').l),
              moveq(FacingDir_Up.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
              move.w(0xf.toWord.i, d0),
              jsr(Label('DoMapUpdateLoop').l),
              move.w(0x0F0.toWord.i, d0),
              move.w(0x100.toWord.i, d1),
              jsr(Label('Event_MoveCharacter').l),
              moveq(FacingDir_Up.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
              move.w(0xf.toWord.i, d0),
              jsr(Label('DoMapUpdateLoop').l),
              move.w(0x100.toWord.i, d0),
              move.w(0x100.toWord.i, d1),
              jsr(Label('Event_MoveCharacter').l),
              moveq(FacingDir_Up.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
            ]));
      });

      test('mix of move, facing, delay, multiple objects', () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.positions[rika] = Position(0x280, 0x170);
            ctx.positions[shay] = Position(0x240, 0x160);
            ctx.positions[gryz] = Position(0x250, 0x150);
            ctx.positions[demi] = Position(0x260, 0x190);
          }),
          IndividualMoves()
            ..speed = StepSpeed.walk
            ..moves[gryz] = (StepPaths()
              ..step(StepPath()
                ..distance = 3.steps
                ..direction = Direction.right))
            ..moves[shay] = (StepPaths()
              ..step(StepPath()
                ..distance = 4.steps
                ..direction = Direction.right))
            ..moves[demi] = (StepPaths()
              ..step(StepPath()
                ..delay = 1.step
                ..facing = Direction.right)
              ..step(StepPath()
                ..delay = 2.steps
                ..facing = Direction.up)
              ..step(StepPath()
                ..delay = 3.steps
                ..facing = Direction.right))
        ]);

        var asm =
            Program().addScene(SceneId('test'), scene).event.withoutComments();

        print(asm);

        expect(
            asm,
            Asm([
              bset(0.toByte.i, Char_Move_Flags.w),
              move.b(0x04.toByte.i, (FieldObj_Step_Offset).w),
              characterByIdToA4(gryz.charIdAddress),
              setDestination(x: Word(0x260).i, y: Word(0x150).i),
              characterByIdToA4(shay.charIdAddress),
              moveCharacter(x: Word(0x250).i, y: Word(0x160).i),
              characterByIdToA4(demi.charIdAddress),
              updateObjFacing(right.address),
              characterByIdToA4(gryz.charIdAddress),
              setDestination(x: Word(0x280).i, y: Word(0x150).i),
              characterByIdToA4(shay.charIdAddress),
              moveCharacter(x: Word(0x270).i, y: Word(0x160).i),
              characterByIdToA4(demi.charIdAddress),
              updateObjFacing(up.address),
              characterByIdToA4(shay.charIdAddress),
              moveCharacter(x: Word(0x280).i, y: Word(0x160).i),
              doMapUpdateLoop((2 * 8 - 1).toWord),
              characterByIdToA4(demi.charIdAddress),
              updateObjFacing(right.address),
              move.b(Byte.one.i, (FieldObj_Step_Offset).w),
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
              lea(0xFFFFC300.w, a4),
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
              lea(0xFFFFC300.w, a4),
              move.w(0x8194.toWord.i, a4.indirect),
              move.w(Word(0x70).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
              doMapUpdateLoop(Word(7 /*8 frames per step?*/)),
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
              lea(0xFFFFC300.w, a4),
              move.w(0x8194.toWord.i, a4.indirect),
              move.w(Word(0x70).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
              doMapUpdateLoop(Word(7 /*8 frames per step?*/)),
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
              lea(0xFFFFC300.w, a4),
              move.w(0x8194.toWord.i, a4.indirect),
              move.w(Word(0x70).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
              characterBySlotToA4(1),
              doMapUpdateLoop(Word(7 /*8 frames per step?*/)),
              lea(0xFFFFC300.w, a4),
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
                (StepPath()..facing = Direction.right)
        ]);

        var sceneAsm = program.addScene(SceneId('testscene'), scene);

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              lea(0xFFFFC300.w, a4),
              move.w(0x8194.toWord.i, a4.indirect),
              move.w(0x50.toWord.i, dest_x_pos(a4)),
              move.w(0x60.toWord.i, dest_y_pos(a4)),
              moveq(FacingDir_Right.i, d0),
              jsr(Label('Event_UpdateObjFacing').l),
            ]));
      });

      test('faces npcs without knowing current position', () {
        var scene = Scene([
          SetContext((ctx) {
            ctx.setFacing(npc, Direction.down);
            ctx.currentMap = map;
          }),
          IndividualMoves()
            ..moves[MapObjectById(MapObjectId('testnpc'))] =
                (StepPath()..facing = Direction.right)
        ]);

        var sceneAsm = program.addScene(SceneId('testscene'), scene);

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              label(Label('.wait_for_movement_1_MapObjecttestnpc_0')),
              lea(0xFFFFC300.w, a4),
              jsr(Label('RunSingleObject').l),
              jsr(Label('Field_LoadSprites').l),
              jsr(Label('Field_BuildSprites').l),
              jsr(Label('AnimateTiles').l),
              jsr(Label('RunMapUpdates').l),
              jsr(Label('VInt_Prepare').l),
              lea(0xFFFFC300.w, a4),
              moveq(0.i, d0),
              move.w(x_step_duration(a4), d0),
              or.w(y_step_duration(a4), d0),
              bne.s(Label('.wait_for_movement_1_MapObjecttestnpc_0')),
              move.w(0x8194.toWord.i, a4.indirect),
              move.w(curr_x_pos(a4), dest_x_pos(a4)),
              move.w(curr_y_pos(a4), dest_y_pos(a4)),
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
              lea(0xFFFFC300.w, a4),
              move.w(0x8194.toWord.i, a4.indirect),
              move.w(Word(0x70).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
              move.w(npc.routine(defaultFieldRoutines).index.i, a4.indirect),
              jsr(npc.routine(defaultFieldRoutines).label.l),
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
              lea(0xFFFFC300.w, a4),
              move.w(0x8194.toWord.i, a4.indirect),
              move.w(Word(0x70).i, d0),
              move.w(Word(0x50).i, d1),
              jsr(Label('Event_MoveCharacter').l),
              followLeader(false),
              characterByNameToA4('Chaz'),
              moveCharacter(x: Word(0x60).i, y: Word(0x60).i),
              lea(0xFFFFC300.w, a4),
              move.w(npc.routine(defaultFieldRoutines).index.i, a4.indirect),
              jsr(npc.routine(defaultFieldRoutines).label.l),
            ]));
      });
    });

    test('just facing with multiple characters', () {
      var moves = IndividualMoves()
        ..moves[shay] = Face(right)
        ..moves[alys] = Face(left);

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
        ..moves[alys] = Face(up);

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
        ..moves[alys] = (Face(up)..delay = 2.steps);

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

    group('just facing', () {
      test('generates in event if followed by event', () {
        var scene = Scene([
          Dialog.parse('test'),
          IndividualMoves()..moves[shay] = Face(right),
          Pause(1.second, duringDialog: false)
        ]);

        var program = Program();
        var sceneAsm =
            program.addScene(SceneId('testscene'), scene, startingMap: testMap);

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              getAndRunDialog3LowDialogId(0.toByte.i),
              characterByIdToA4(shay.charIdAddress),
              updateObjFacing(right.address),
              generateEventAsm([Pause(1.second)]),
            ]));
      });

      test('generates in event if followed by event after facing in dialog',
          () {
        var scene = Scene([
          SetContext((ctx) => ctx.setFacing(shay, right)),
          Dialog.parse('test1'),
          IndividualMoves()..moves[shay] = Face(up),
          Dialog.parse('test2'),
          IndividualMoves()..moves[shay] = Face(right),
          Pause(1.second, duringDialog: false),
        ]);

        var program = Program();
        var sceneAsm =
            program.addScene(SceneId('testscene'), scene, startingMap: testMap);

        expect(
            sceneAsm.event.withoutComments().trim(),
            Asm([
              getAndRunDialog3LowDialogId(0.toByte.i),
              characterByIdToA4(shay.charIdAddress),
              updateObjFacing(right.address),
              generateEventAsm([Pause(1.second)]),
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

    // Not sure if this behavior is correct
    test('uses interaction_updateobj if interaction object', () {
      var npc = MapObject(
          startPosition: Position(0x200, 0x200),
          spec: Npc(Sprite.PalmanMan1, FaceDown()));
      var map = GameMap(MapId.Piata)..addObject(npc);
      ctx.state.currentMap = map;

      var asm = EventAsm.empty();
      SceneAsmGenerator.forInteraction(
          map, SceneId('test'), DialogTrees(), asm, TestEventRoutines(),
          withObject: const InteractionObject())
        ..runEvent()
        ..facePlayer(FacePlayer(InteractionObject()))
        ..finish();

      expect(asm.withoutComments().skip(1).take(1),
          Asm([jsr('Interaction_UpdateObj'.toLabel.l)]));
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
            npc.toA4(testState),
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
            setDestination(x: 0x1b0.toWord.i, y: 0x200.toWord.i),
            jsr(Label('Event_MoveCharacters').l),
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
            npc.toA4(testState),
            move.w(0x8194.toWord.i, a4.indirect),
            moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i),
          ]));
      expect(state.positions[npc], Position(0x1a0, 0x1f0));
    });

    test('change speed', () {
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

    group('to expression', () {
      test('single character to position of another', () {
        var event = AbsoluteMoves()..destinations[shay] = alys.position();
        var asm = absoluteMovesToAsm(event, state);

        expect(
            asm,
            EventAsm([
              followLeader(false),
              shay.toA4(testState),
              alys.toA3(testState),
              moveCharacter(x: curr_x_pos(a3), y: curr_y_pos(a3))
            ]));
      });

      test('single character to position of xy of another', () {
        var event = AbsoluteMoves()
          ..destinations[shay] = PositionOfXY(PositionComponent(0x150, Axis.x),
              alys.position().component(Axis.y));

        var asm = absoluteMovesToAsm(event, state);

        print(asm);

        expect(
            asm,
            EventAsm([
              followLeader(false),
              shay.toA4(testState),
              alys.toA(a2, testState),
              moveCharacter(x: 0x150.toWord.i, y: curr_y_pos(a2))
            ]));
      });

      test('single character to position of xy of others', () {
        var event = AbsoluteMoves()
          ..destinations[shay] = PositionOfXY(
            rune.position().component(Axis.x),
            alys.position().component(Axis.y),
          );
        var asm = absoluteMovesToAsm(event, state);

        print(asm);

        expect(
            asm,
            EventAsm([
              followLeader(false),
              shay.toA4(testState),
              rune.toA(a3, testState),
              alys.toA(a2, testState),
              moveCharacter(x: curr_x_pos(a3), y: curr_y_pos(a2))
            ]));
      });

      test('single character to position of xy of self and others', () {
        var event = AbsoluteMoves()
          ..destinations[shay] = PositionOfXY(
            shay.position().component(Axis.x),
            alys.position().component(Axis.y),
          );
        var asm = absoluteMovesToAsm(event, state);

        print(asm);

        expect(
            asm,
            EventAsm([
              followLeader(false),
              shay.toA4(testState),
              alys.toA(a2, testState),
              moveCharacter(x: curr_x_pos(a4), y: curr_y_pos(a2))
            ]));
      });

      test('offset of character position both axis', () {
        var event = AbsoluteMoves()
          ..destinations[shay] =
              OffsetPosition(demi.position(), offset: Position(-0x10, 0x10));
        var asm = absoluteMovesToAsm(event, state);
        print(asm);
        expect(
            asm,
            Asm([
              followLeader(false),
              shay.toA4(testState),
              demi.toA3(testState),
              move.w(curr_x_pos(a3), d0),
              subi.w(0x10.toWord.i, d0),
              move.w(curr_y_pos(a3), d1),
              addi.w(0x10.toWord.i, d1),
              moveCharacter(x: d0, y: d1)
            ]));
      });

      test('offset of character position one axis', () {
        var event = AbsoluteMoves()
          ..destinations[shay] = PositionOfXY(
              OffsetPositionComponent(demi.position().component(Axis.x),
                  offset: -0x10),
              demi.position().component(Axis.y));

        var asm = absoluteMovesToAsm(event, state);

        print(asm);

        expect(
            asm,
            Asm([
              followLeader(false),
              shay.toA4(testState),
              demi.toA3(testState),
              move.w(curr_x_pos(a3), d0),
              subi.w(0x10.toWord.i, d0),
              moveCharacter(x: d0, y: curr_y_pos(a3))
            ]));
      });

      test('offset of character position both axis, one zero offset', () {
        var event = AbsoluteMoves()
          ..destinations[shay] =
              OffsetPosition(demi.position(), offset: Position(-0x10, 0));
        var asm = absoluteMovesToAsm(event, state);
        expect(
            asm,
            Asm([
              followLeader(false),
              shay.toA4(testState),
              demi.toA3(testState),
              move.w(curr_x_pos(a3), d0),
              subi.w(0x10.toWord.i, d0),
              moveCharacter(x: d0, y: curr_y_pos(a3))
            ]));
      });

      test('offset of slot position', () {
        var event = AbsoluteMoves()
          ..destinations[shay] = OffsetPosition(BySlot(1).position(),
              offset: Position(-0x10, 0x10));
        var asm = absoluteMovesToAsm(event, state);
        print(asm);
        expect(
            asm,
            Asm([
              followLeader(false),
              shay.toA4(testState),
              BySlot(1).toA3(testState),
              move.w(curr_x_pos(a3), d0),
              subi.w(0x10.toWord.i, d0),
              move.w(curr_y_pos(a3), d1),
              addi.w(0x10.toWord.i, d1),
              moveCharacter(x: d0, y: d1)
            ]));
      });
    });

    group('following leader', () {
      test('moving leader by slot', () {
        var event = AbsoluteMoves()
          ..destinations[BySlot.one] = Position(0x1a0, 0x1f0)
          ..followLeader = true;
        var asm = absoluteMovesToAsm(event, state);

        expect(
            asm,
            EventAsm([
              BySlot.one.toA4(testState),
              moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i)
            ]));
      });

      test('sets follow leader flag if unset', () {
        var event = AbsoluteMoves()
          ..destinations[BySlot.one] = Position(0x1a0, 0x1f0)
          ..followLeader = true;
        var asm = absoluteMovesToAsm(event, state..followLead = false);

        expect(
            asm,
            EventAsm([
              followLeader(true),
              BySlot.one.toA4(testState),
              moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i)
            ]));
      });

      test('moving leader y first', () {
        var event = AbsoluteMoves()
          ..destinations[BySlot.one] = Position(0x1a0, 0x1f0)
          ..startingAxis = Axis.y
          ..followLeader = true;
        var asm = absoluteMovesToAsm(event, state);

        expect(
            asm,
            EventAsm([
              moveAlongXAxisFirst(false),
              BySlot.one.toA4(testState),
              moveCharacter(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i)
            ]));
      });

      test('moving slot 2 is error', () {
        var event = AbsoluteMoves()
          ..destinations[BySlot.two] = Position(0x1a0, 0x1f0)
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
              BySlot.one.toA4(testState),
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

    group('in dialog', () {
      test('single character', () {
        var event = AbsoluteMoves()
          ..destinations[shay] = Position(0x1a0, 0x1f0)
          ..waitForMovements = false;
        var dialog = Dialog(spans: DialogSpan.parse('hello', events: [event]));

        var (asm, postRoutines) = dialog.toGeneratedAsm(
            state..cameraLock = true,
            labeller: Labeller.localTo('TestScene').withContext(0),
            fieldRoutines: defaultFieldRoutines);

        expect(postRoutines, [
          Asm([
            label(Label('TestScene_0_0_0_AbsoluteMoves')),
            followLeader(false),
            shay.toA4(testState),
            bset(1.i, priority_flag(a4)),
            setDestination(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i),
            rts,
          ])
        ]);

        expect(
            asm,
            Asm([
              dc.b(Bytes.ascii('hello')),
              dc.b([ControlCodes.action, Byte(0xf)]),
              dc.l([Label('TestScene_0_0_0_AbsoluteMoves')])
            ]));
      });

      test('character and npc in the same span', () {
        var event = AbsoluteMoves()
          ..destinations[shay] = Position(0x1a0, 0x1f0)
          ..destinations[npc] = Position(0x1b0, 0x1f0)
          ..waitForMovements = false;
        var dialog = Dialog(spans: DialogSpan.parse('hello', events: [event]));

        var (asm, postRoutines) = dialog.toGeneratedAsm(
            state..cameraLock = true,
            labeller: Labeller.localTo('TestScene').withContext(0),
            fieldRoutines: defaultFieldRoutines);

        expect(postRoutines, [
          Asm([
            label(Label('TestScene_0_0_0_AbsoluteMoves')),
            followLeader(false),
            shay.toA4(testState),
            bset(1.i, priority_flag(a4)),
            setDestination(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i),
            npc.toA4(testState),
            move.w(0x8194.toWord.i, a4.indirect),
            bset(1.i, priority_flag(a4)),
            setDestination(x: 0x1b0.toWord.i, y: 0x1f0.toWord.i),
            rts,
          ])
        ]);

        expect(
            asm,
            Asm([
              dc.b(Bytes.ascii('hello')),
              dc.b([ControlCodes.action, Byte(0xf)]),
              dc.l([Label('TestScene_0_0_0_AbsoluteMoves')])
            ]));
      });

      test('multiple objects across multiple spans', () {
        var event1 = AbsoluteMoves()
          ..destinations[shay] = Position(0x1a0, 0x1f0)
          ..waitForMovements = false;
        var event2 = AbsoluteMoves()
          ..destinations[alys] = Position(0x1b0, 0x1f0)
          ..waitForMovements = false;
        var dialog = Dialog(spans: [
          DialogSpan('hello', events: [event1]),
          DialogSpan(' world', events: [event2])
        ]);

        var (asm, postRoutines) = dialog.toGeneratedAsm(
            state..cameraLock = true,
            labeller: Labeller.localTo('TestScene').withContext(0),
            fieldRoutines: defaultFieldRoutines);

        expect(postRoutines, [
          Asm([
            label(Label('TestScene_0_0_0_AbsoluteMoves')),
            followLeader(false),
            shay.toA4(testState),
            bset(1.i, priority_flag(a4)),
            setDestination(x: 0x1a0.toWord.i, y: 0x1f0.toWord.i),
            rts,
          ]),
          Asm([
            label(Label('TestScene_0_1_0_AbsoluteMoves')),
            alys.toA4(testState),
            bset(1.i, priority_flag(a4)),
            setDestination(x: 0x1b0.toWord.i, y: 0x1f0.toWord.i),
            rts,
          ])
        ]);

        expect(
            asm,
            Asm([
              dc.b(Bytes.ascii('hello')),
              dc.b([ControlCodes.action, Byte(0xf)]),
              dc.l([Label('TestScene_0_0_0_AbsoluteMoves')]),
              dc.b(Bytes.ascii(' world')),
              dc.b([ControlCodes.action, Byte(0xf)]),
              dc.l([Label('TestScene_0_1_0_AbsoluteMoves')]),
            ]));
      });
    });
  });

  group('direction expressions', () {
    late Memory mem;

    setUp(() {
      mem = Memory();
    });

    group('of vector', () {
      group('known', () {
        test('exactly up', () {
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x50, 0x40))
                  .known(mem),
              Direction.up);
        });

        test('exactly down', () {
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x50, 0x60))
                  .known(mem),
              Direction.down);
        });

        test('exactly left', () {
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x40, 0x50))
                  .known(mem),
              Direction.left);
        });

        test('exactly right', () {
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x60, 0x50))
                  .known(mem),
              Direction.right);
        });

        test('approximately up', () {
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x60, 0x30))
                  .known(mem),
              Direction.up);
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x40, 0x30))
                  .known(mem),
              Direction.up);
        });

        test('approximately down', () {
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x60, 0x70))
                  .known(mem),
              Direction.down);
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x40, 0x70))
                  .known(mem),
              Direction.down);
        });

        test('approximately left', () {
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x30, 0x40))
                  .known(mem),
              Direction.left);
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x30, 0x60))
                  .known(mem),
              Direction.left);
        });

        test('approximately right vector', () {
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x70, 0x40))
                  .known(mem),
              Direction.right);
          expect(
              DirectionOfVector(
                      from: Position(0x50, 0x50), to: Position(0x70, 0x60))
                  .known(mem),
              Direction.right);
        });
      });
    });
  });

  group('faces using expressions', () {
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

    test('slot faces slot', () {
      var moves = Face(BySlot.one.towards(BySlot.two)).move(BySlot.one);
      var asm = generate([moves]);
      expect(
          asm,
          Asm([
            BySlot.two.toA3(testState),
            move.w(curr_x_pos(a3), d2),
            BySlot.one.toA4(testState),
            sub.w(curr_x_pos(a4), d2),
            move.w(curr_y_pos(a3), d3),
            sub.w(curr_y_pos(a4), d3),
            move.w(d2, d4),
            bpl.s(Label(r'.positive_dx_1_Slot1_0')),
            neg.w(d4),
            label(Label(r'.positive_dx_1_Slot1_0')),
            move.w(d3, d5),
            bpl.s(Label(r'.positive_dy_1_Slot1_0')),
            neg.w(d5),
            label(Label(r'.positive_dy_1_Slot1_0')),
            cmp.w(d4, d5),
            bgt.s(Label(r'.checky_1_Slot1_0')),
            tst.w(d2),
            bpl.s(Label(r'.right_1_Slot1_0')),
            move.w(FacingDir_Left.i, d0),
            bra.s(Label(r'.keep_1_Slot1_0')),
            label(Label(r'.right_1_Slot1_0')),
            move.w(FacingDir_Right.i, d0),
            bra.s(Label(r'.keep_1_Slot1_0')),
            label(Label(r'.checky_1_Slot1_0')),
            tst.w(d3),
            bpl.s(Label(r'.down_1_Slot1_0')),
            move.w(FacingDir_Up.i, d0),
            bra.s(Label(r'.keep_1_Slot1_0')),
            label(Label(r'.down_1_Slot1_0')),
            move.w(FacingDir_Down.i, d0),
            label(Label(r'.keep_1_Slot1_0')),
            jsr(Label('Event_UpdateObjFacing').l),
          ]));
    });

    test('character faces character', () {
      var moves = Face(alys.towards(rune)).move(alys);
      var asm = generate([moves]);
      expect(
          asm,
          Asm([
            // Note a4 is only loaded once.
            rune.toA3(testState),
            move.w(curr_x_pos(a3), d2),
            alys.toA4(testState),
            sub.w(curr_x_pos(a4), d2),
            move.w(curr_y_pos(a3), d3),
            sub.w(curr_y_pos(a4), d3),
            move.w(d2, d4),
            bpl.s(Label(r'.positive_dx_1_Alys_0')),
            neg.w(d4),
            label(Label(r'.positive_dx_1_Alys_0')),
            move.w(d3, d5),
            bpl.s(Label(r'.positive_dy_1_Alys_0')),
            neg.w(d5),
            label(Label(r'.positive_dy_1_Alys_0')),
            cmp.w(d4, d5),
            bgt.s(Label(r'.checky_1_Alys_0')),
            tst.w(d2),
            bpl.s(Label(r'.right_1_Alys_0')),
            move.w(FacingDir_Left.i, d0),
            bra.s(Label(r'.keep_1_Alys_0')),
            label(Label(r'.right_1_Alys_0')),
            move.w(FacingDir_Right.i, d0),
            bra.s(Label(r'.keep_1_Alys_0')),
            label(Label(r'.checky_1_Alys_0')),
            tst.w(d3),
            bpl.s(Label(r'.down_1_Alys_0')),
            move.w(FacingDir_Up.i, d0),
            bra.s(Label(r'.keep_1_Alys_0')),
            label(Label(r'.down_1_Alys_0')),
            move.w(FacingDir_Down.i, d0),
            label(Label(r'.keep_1_Alys_0')),
            jsr(Label('Event_UpdateObjFacing').l),
          ]));
    });

    test('multiple characters face character', () {
      // TODO(optimization, movement): could technically reuse data registers
      // could also use different address registers
      // to avoid collision with update facing routine
      // or push/pop on stack

      var moves = IndividualMoves()
        ..moves[alys] = Face(alys.towards(rune))
        ..moves[shay] = Face(shay.towards(rune));

      var asm = generate([moves]);
      expect(
          asm,
          Asm([
            rune.toA3(testState),
            move.w(curr_x_pos(a3), d2),
            alys.toA4(testState),
            sub.w(curr_x_pos(a4), d2),
            move.w(curr_y_pos(a3), d3),
            sub.w(curr_y_pos(a4), d3),
            move.w(d2, d4),
            bpl.s(Label(r'.positive_dx_1_Alys_0')),
            neg.w(d4),
            label(Label(r'.positive_dx_1_Alys_0')),
            move.w(d3, d5),
            bpl.s(Label(r'.positive_dy_1_Alys_0')),
            neg.w(d5),
            label(Label(r'.positive_dy_1_Alys_0')),
            cmp.w(d4, d5),
            bgt.s(Label(r'.checky_1_Alys_0')),
            tst.w(d2),
            bpl.s(Label(r'.right_1_Alys_0')),
            move.w(FacingDir_Left.i, d0),
            bra.s(Label(r'.keep_1_Alys_0')),
            label(Label(r'.right_1_Alys_0')),
            move.w(FacingDir_Right.i, d0),
            bra.s(Label(r'.keep_1_Alys_0')),
            label(Label(r'.checky_1_Alys_0')),
            tst.w(d3),
            bpl.s(Label(r'.down_1_Alys_0')),
            move.w(FacingDir_Up.i, d0),
            bra.s(Label(r'.keep_1_Alys_0')),
            label(Label(r'.down_1_Alys_0')),
            move.w(FacingDir_Down.i, d0),
            label(Label(r'.keep_1_Alys_0')),
            jsr(Label('Event_UpdateObjFacing').l),
            // Must be loaded again due to UpdateObjFacing routine
            // see 'todo' above
            rune.toA3(testState..putInAddress(a3, null)),
            move.w(curr_x_pos(a3), d2),
            shay.toA4(testState),
            sub.w(curr_x_pos(a4), d2),
            move.w(curr_y_pos(a3), d3),
            sub.w(curr_y_pos(a4), d3),
            move.w(d2, d4),
            bpl.s(Label(r'.positive_dx_1_Shay_1')),
            neg.w(d4),
            label(Label(r'.positive_dx_1_Shay_1')),
            move.w(d3, d5),
            bpl.s(Label(r'.positive_dy_1_Shay_1')),
            neg.w(d5),
            label(Label(r'.positive_dy_1_Shay_1')),
            cmp.w(d4, d5),
            bgt.s(Label(r'.checky_1_Shay_1')),
            tst.w(d2),
            bpl.s(Label(r'.right_1_Shay_1')),
            move.w(FacingDir_Left.i, d0),
            bra.s(Label(r'.keep_1_Shay_1')),
            label(Label(r'.right_1_Shay_1')),
            move.w(FacingDir_Right.i, d0),
            bra.s(Label(r'.keep_1_Shay_1')),
            label(Label(r'.checky_1_Shay_1')),
            tst.w(d3),
            bpl.s(Label(r'.down_1_Shay_1')),
            move.w(FacingDir_Up.i, d0),
            bra.s(Label(r'.keep_1_Shay_1')),
            label(Label(r'.down_1_Shay_1')),
            move.w(FacingDir_Down.i, d0),
            label(Label(r'.keep_1_Shay_1')),
            jsr(Label('Event_UpdateObjFacing').l),
          ]));
    });

    test('comparisons use constant position if known', () {
      var moves = Face(alys.towards(rune)).move(alys);
      var asm = generateEventAsm([moves],
          context: EventState()
            ..currentMap = map
            ..positions[alys] = Position(0x100, 0x200));
      expect(
          asm,
          Asm([
            rune.toA3(testState),
            move.w(curr_x_pos(a3), d2),
            subi.w(0x100.toWord.i, d2),
            move.w(curr_y_pos(a3), d3),
            subi.w(0x200.toWord.i, d3),
            move.w(d2, d4),
            bpl.s(Label(r'.positive_dx_1_Alys_0')),
            neg.w(d4),
            label(Label(r'.positive_dx_1_Alys_0')),
            move.w(d3, d5),
            bpl.s(Label(r'.positive_dy_1_Alys_0')),
            neg.w(d5),
            label(Label(r'.positive_dy_1_Alys_0')),
            cmp.w(d4, d5),
            bgt.s(Label(r'.checky_1_Alys_0')),
            tst.w(d2),
            bpl.s(Label(r'.right_1_Alys_0')),
            move.w(FacingDir_Left.i, d0),
            bra.s(Label(r'.keep_1_Alys_0')),
            label(Label(r'.right_1_Alys_0')),
            move.w(FacingDir_Right.i, d0),
            bra.s(Label(r'.keep_1_Alys_0')),
            label(Label(r'.checky_1_Alys_0')),
            tst.w(d3),
            bpl.s(Label(r'.down_1_Alys_0')),
            move.w(FacingDir_Up.i, d0),
            bra.s(Label(r'.keep_1_Alys_0')),
            label(Label(r'.down_1_Alys_0')),
            move.w(FacingDir_Down.i, d0),
            label(Label(r'.keep_1_Alys_0')),
            move.b(d0, -sp),
            alys.toA4(testState),
            move.b(sp.postIncrement(), d0),
            jsr(Label('Event_UpdateObjFacing').l),
          ]));
    });

    test('uses constant direction if vector known', () {
      var moves = Face(alys.towards(rune)).move(alys);
      var asm = generateEventAsm([moves],
          context: EventState()
            ..currentMap = map
            ..positions[rune] = Position(0x110, 0x200)
            ..positions[alys] = Position(0x100, 0x200));
      expect(
          asm,
          Asm([
            alys.toA4(testState),
            moveq(FacingDir_Right.i, d0),
            jsr(Label('Event_UpdateObjFacing').l),
          ]));
    });

    test('interaction object faces player optimization', () {
      var moves = Face(InteractionObject().towards(BySlot.one))
          .move(InteractionObject());
      var asm = EventAsm.empty();
      SceneAsmGenerator.forInteraction(
          map, SceneId('test'), DialogTrees(), asm, TestEventRoutines(),
          withObject: const InteractionObject())
        ..runEvent()
        ..individualMoves(moves)
        ..finish();
      expect(
          asm.withoutComments().skip(1).take(5),
          Asm([
            BySlot.one.toA4(testState),
            move.w(facing_dir(a4), d0),
            bchg(2.i, d0),
            // or maybe exg?
            lea(a3.indirect, a4),
            jsr(Label('Event_UpdateObjFacing').l),
          ]));
    });

    test('character 1 facing interaction object is noop', () {
      var moves =
          Face(BySlot.one.towards(InteractionObject())).move(BySlot.one);
      var asm = EventAsm.empty();
      SceneAsmGenerator.forInteraction(
          map, SceneId('test'), DialogTrees(), asm, TestEventRoutines(),
          withObject: const InteractionObject())
        ..runEvent()
        ..individualMoves(moves)
        ..finish();

      expect(asm.withoutComments().head(-3).skip(1), Asm.empty());
    }, skip: 'not done but not very useful');

    test('character 1 by name facing interaction object is noop', () {},
        skip: "i don't think this is possible "
            "unless we know slot one at compile time");
  });

  group('instant moves generate asm', () {
    test('one object position', () {
      var moves = InstantMoves()..move(shay, to: Position(0x100, 0x50));
      var asm = generate([moves]);
      expect(
          asm,
          Asm([
            shay.toA4(Memory()),
            move.w(0x100.toWord.i, curr_x_pos(a4)),
            move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
            move.w(0x50.toWord.i, curr_y_pos(a4)),
            move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
            move.w(0x100.toWord.i, dest_x_pos(a4)),
            move.w(0x50.toWord.i, dest_y_pos(a4)),
            move.l(a4, -sp),
            jsr(Label('Field_UpdateObjects').l),
            jsr(Label('UpdateCameraXPosFG').l),
            jsr(Label('UpdateCameraYPosFG').l),
            jsr(Label('UpdateCameraXPosBG').l),
            jsr(Label('UpdateCameraYPosBG').l),
            move.l(sp.postIncrement(), a4),
          ]));
    });

    test('one object facing', () {
      var moves = InstantMoves()..move(alys, face: up);
      var asm = generate([moves]);
      expect(
          asm,
          Asm([
            alys.toA4(Memory()),
            move.w(FacingDir_Up.i, facing_dir(a4)),
            move.l(a4, -sp),
            jsr(Label('Field_UpdateObjects').l),
            move.l(sp.postIncrement(), a4),
          ]));
    });

    test('one object position and facing', () {
      var moves = InstantMoves()
        ..move(shay, to: Position(0x100, 0x50), face: down);
      var asm = generate([moves]);
      expect(
          asm,
          Asm([
            shay.toA4(Memory()),
            move.w(0x100.toWord.i, curr_x_pos(a4)),
            move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
            move.w(0x50.toWord.i, curr_y_pos(a4)),
            move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
            move.w(0x100.toWord.i, dest_x_pos(a4)),
            move.w(0x50.toWord.i, dest_y_pos(a4)),
            move.w(FacingDir_Down.i, facing_dir(a4)),
            move.l(a4, -sp),
            jsr(Label('Field_UpdateObjects').l),
            jsr(Label('UpdateCameraXPosFG').l),
            jsr(Label('UpdateCameraYPosFG').l),
            jsr(Label('UpdateCameraXPosBG').l),
            jsr(Label('UpdateCameraYPosBG').l),
            move.l(sp.postIncrement(), a4),
          ]));
    });

    group('npcs', () {
      late GameMap map;
      late Memory testMemory;
      late MapObject testnpc;
      late MapObject scriptableNpc;

      setUp(() {
        map = GameMap(MapId.Test);
        testMemory = Memory()..currentMap = map;
        map.addObject(testnpc = MapObject(
            id: 'testnpc',
            startPosition: Position(0x200, 0x100),
            spec: Npc(Sprite.PalmanMan1, WanderAround(down))));
        map.addObject(scriptableNpc = MapObject(
            id: 'scriptableNpc',
            startPosition: Position(0x100, 0x200),
            spec: AsmSpec(
                routine: scriptableObjectRoutine.index, startFacing: down)));
      });

      test('one scriptable object position and facing', () {
        var moves = InstantMoves()
          ..move(MapObjectById(scriptableNpc.id),
              to: Position(0x100, 0x50), face: down);
        var asm = generate([moves], inMap: map);
        expect(
            asm,
            Asm([
              scriptableNpc.toA4(testMemory),
              move.w(0x100.toWord.i, curr_x_pos(a4)),
              move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
              move.w(0x50.toWord.i, curr_y_pos(a4)),
              move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
              move.w(0x100.toWord.i, dest_x_pos(a4)),
              move.w(0x50.toWord.i, dest_y_pos(a4)),
              move.w(FacingDir_Down.i, facing_dir(a4)),
              move.l(a4, -sp),
              jsr(Label('Field_UpdateObjects').l),
              jsr(Label('UpdateCameraXPosFG').l),
              jsr(Label('UpdateCameraYPosFG').l),
              jsr(Label('UpdateCameraXPosBG').l),
              jsr(Label('UpdateCameraYPosBG').l),
              move.l(sp.postIncrement(), a4),
            ]));
      }, skip: 'not optimized yet; will redundantly load script routine');

      test('one unscriptable object position and facing', () {
        var moves = InstantMoves()
          ..move(MapObjectById(testnpc.id),
              to: Position(0x100, 0x50), face: down);
        var asm = generate([moves], inMap: map);
        expect(
            asm,
            Asm([
              testnpc.toA4(testMemory),
              move.w(0x8194.toWord.i, a4.indirect),
              move.l(0.i, x_step_constant(a4)),
              move.l(0.i, y_step_constant(a4)),
              move.w(0.i, x_step_duration(a4)),
              move.w(0.i, y_step_duration(a4)),
              move.w(0x100.toWord.i, curr_x_pos(a4)),
              move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
              move.w(0x50.toWord.i, curr_y_pos(a4)),
              move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
              move.w(0x100.toWord.i, dest_x_pos(a4)),
              move.w(0x50.toWord.i, dest_y_pos(a4)),
              move.w(FacingDir_Down.i, facing_dir(a4)),
              move.l(a4, -sp),
              jsr(Label('Field_UpdateObjects').l),
              jsr(Label('UpdateCameraXPosFG').l),
              jsr(Label('UpdateCameraYPosFG').l),
              jsr(Label('UpdateCameraXPosBG').l),
              jsr(Label('UpdateCameraYPosBG').l),
              move.l(sp.postIncrement(), a4),
            ]));
      });
    });

    test('multiple object positions', () {
      var moves = InstantMoves()
        ..move(alys, to: Position(0x100, 0x50))
        ..move(shay, to: Position(0x200, 0x80));

      var asm = generate([moves]);

      expect(
          asm,
          Asm([
            alys.toA4(Memory()),
            move.w(0x100.toWord.i, curr_x_pos(a4)),
            move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
            move.w(0x50.toWord.i, curr_y_pos(a4)),
            move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
            move.w(0x100.toWord.i, dest_x_pos(a4)),
            move.w(0x50.toWord.i, dest_y_pos(a4)),
            shay.toA4(Memory()),
            move.w(0x200.toWord.i, curr_x_pos(a4)),
            move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
            move.w(0x80.toWord.i, curr_y_pos(a4)),
            move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
            move.w(0x200.toWord.i, dest_x_pos(a4)),
            move.w(0x80.toWord.i, dest_y_pos(a4)),
            move.l(a4, -sp),
            jsr(Label('Field_UpdateObjects').l),
            jsr(Label('UpdateCameraXPosFG').l),
            jsr(Label('UpdateCameraYPosFG').l),
            jsr(Label('UpdateCameraXPosBG').l),
            jsr(Label('UpdateCameraYPosBG').l),
            move.l(sp.postIncrement(), a4),
          ]));
    });

    test('multiple object positions and facing', () {
      var moves = InstantMoves()
        ..move(alys, to: Position(0x100, 0x50), face: down)
        ..move(shay, to: Position(0x200, 0x80), face: up);

      var asm = generate([moves]);

      expect(
          asm,
          Asm([
            alys.toA4(Memory()),
            move.w(0x100.toWord.i, curr_x_pos(a4)),
            move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
            move.w(0x50.toWord.i, curr_y_pos(a4)),
            move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
            move.w(0x100.toWord.i, dest_x_pos(a4)),
            move.w(0x50.toWord.i, dest_y_pos(a4)),
            move.w(FacingDir_Down.i, facing_dir(a4)),
            shay.toA4(Memory()),
            move.w(0x200.toWord.i, curr_x_pos(a4)),
            move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
            move.w(0x80.toWord.i, curr_y_pos(a4)),
            move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
            move.w(0x200.toWord.i, dest_x_pos(a4)),
            move.w(0x80.toWord.i, dest_y_pos(a4)),
            move.w(FacingDir_Up.i, facing_dir(a4)),
            move.l(a4, -sp),
            jsr(Label('Field_UpdateObjects').l),
            jsr(Label('UpdateCameraXPosFG').l),
            jsr(Label('UpdateCameraYPosFG').l),
            jsr(Label('UpdateCameraXPosBG').l),
            jsr(Label('UpdateCameraYPosBG').l),
            move.l(sp.postIncrement(), a4),
          ]));
    });

    test('mix of positions and facing', () {
      var moves = InstantMoves()
        ..move(alys, to: Position(0x100, 0x50))
        ..move(shay, face: up)
        ..move(hahn, to: Position(0x200, 0x80), face: down);

      var asm = generate([moves]);

      expect(
          asm,
          Asm([
            alys.toA4(Memory()),
            move.w(0x100.toWord.i, curr_x_pos(a4)),
            move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
            move.w(0x50.toWord.i, curr_y_pos(a4)),
            move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
            move.w(0x100.toWord.i, dest_x_pos(a4)),
            move.w(0x50.toWord.i, dest_y_pos(a4)),
            shay.toA4(Memory()),
            move.w(FacingDir_Up.i, facing_dir(a4)),
            hahn.toA4(Memory()),
            move.w(0x200.toWord.i, curr_x_pos(a4)),
            move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
            move.w(0x80.toWord.i, curr_y_pos(a4)),
            move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
            move.w(0x200.toWord.i, dest_x_pos(a4)),
            move.w(0x80.toWord.i, dest_y_pos(a4)),
            move.w(FacingDir_Down.i, facing_dir(a4)),
            move.l(a4, -sp),
            jsr(Label('Field_UpdateObjects').l),
            jsr(Label('UpdateCameraXPosFG').l),
            jsr(Label('UpdateCameraYPosFG').l),
            jsr(Label('UpdateCameraXPosBG').l),
            jsr(Label('UpdateCameraYPosBG').l),
            move.l(sp.postIncrement(), a4),
          ]));
    });

    group('using expressions', () {
      test('multiple object positions and facing', () {
        var moves = InstantMoves()
          ..move(alys, to: PositionOfObject(shay), face: down)
          ..move(shay, to: Position(0x100, 0x50), face: shay.towards(alys));

        var asm = generate([moves]);
        var testState = Memory();

        print(asm);

        expect(
            asm,
            Asm([
              shay.toA3(testState),
              alys.toA4(testState),
              move.w(curr_x_pos(a3), curr_x_pos(a4)),
              move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a4)),
              move.w(curr_y_pos(a3), curr_y_pos(a4)),
              move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a4)),
              move.w(curr_x_pos(a3), dest_x_pos(a4)),
              move.w(curr_y_pos(a3), dest_y_pos(a4)),
              move.w(FacingDir_Down.i, facing_dir(a4)),
              move.w(0x100.toWord.i, curr_x_pos(a3)),
              move.w(0.toWord.i, (curr_x_pos + 2.toValue)(a3)),
              move.w(0x50.toWord.i, curr_y_pos(a3)),
              move.w(0.toWord.i, (curr_y_pos + 2.toValue)(a3)),
              move.w(0x100.toWord.i, dest_x_pos(a3)),
              move.w(0x50.toWord.i, dest_y_pos(a3)),
              move.w(curr_x_pos(a4), d2),
              subi.w(0x100.toWord.i, d2),
              move.w(curr_y_pos(a4), d3),
              subi.w(0x50.toWord.i, d3),
              move.w(d2, d4),
              bpl.s(Label(r'.positive_dx_1_Shay')),
              neg.w(d4),
              label(Label(r'.positive_dx_1_Shay')),
              move.w(d3, d5),
              bpl.s(Label(r'.positive_dy_1_Shay')),
              neg.w(d5),
              label(Label(r'.positive_dy_1_Shay')),
              cmp.w(d4, d5),
              bgt.s(Label(r'.checky_1_Shay')),
              tst.w(d2),
              bpl.s(Label(r'.right_1_Shay')),
              move.w(FacingDir_Left.i, d0),
              bra.s(Label(r'.keep_1_Shay')),
              label(Label(r'.right_1_Shay')),
              move.w(FacingDir_Right.i, d0),
              bra.s(Label(r'.keep_1_Shay')),
              label(Label(r'.checky_1_Shay')),
              tst.w(d3),
              bpl.s(Label(r'.down_1_Shay')),
              move.w(FacingDir_Up.i, d0),
              bra.s(Label(r'.keep_1_Shay')),
              label(Label(r'.down_1_Shay')),
              move.w(FacingDir_Down.i, d0),
              label(Label(r'.keep_1_Shay')),
              move.w(d0, facing_dir(a3)),
              move.l(a4, -sp),
              jsr(Label('Field_UpdateObjects').l),
              jsr(Label('UpdateCameraXPosFG').l),
              jsr(Label('UpdateCameraYPosFG').l),
              jsr(Label('UpdateCameraXPosBG').l),
              jsr(Label('UpdateCameraYPosBG').l),
              move.l(sp.postIncrement(), a4),
            ]));
      });
    });
  });
}
