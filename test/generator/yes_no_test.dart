import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

main() {
  late GameMap map;
  late GameMap map2;
  late MapObject mapObject;
  late Program program;

  var testSceneId = SceneId('test_scene');

  setUp(() {
    map = GameMap(MapId.Test);
    map2 = GameMap(MapId.Test_Part2);

    mapObject = MapObject(
        startPosition: Position(0x100, 0x100),
        spec: Npc(Sprite.Motavian1, FaceDown()));

    map.addObject(mapObject);

    program = Program();
  });

  group('yes no choice generates', () {
    setUp(() {
      mapObject.onInteract = Scene([
        InteractionObject.facePlayer(),
        YesOrNoChoice(
          ifYes: [Dialog.parse('Great!')],
          ifNo: [Dialog.parse('Too bad.')],
        )
      ]);
    });

    test('ctrl code for choice and no branch in same dialog and yes in next',
        () {
      program.addMap(map);

      var dialogTree = program.dialogTrees.forMap(map.id);

      expect(dialogTree, hasLength(2));
      expect(
          dialogTree[0],
          DialogAsm([
            dc.b([Byte(0xf5)]),
            dc.b([Byte(0x1), Byte(0)]),
            dc.b(Bytes.ascii('Too bad.')),
            dc.b([Byte(0xff)]),
          ]));
    });

    test('no event asm', () {
      var asm = program.addMap(map);
      expect(asm.events, isEmpty);
    });

    test('no branch dialog in next', () {
      // todo: can we come up with more complex scenarios?
      // e.g. event flag checks + choices
      program.addMap(map);

      var dialogTree = program.dialogTrees.forMap(map.id);

      expect(dialogTree, hasLength(2));
      expect(
          dialogTree[1],
          DialogAsm([
            dc.b(Bytes.ascii('Great!')),
            dc.b([Byte(0xff)]),
          ]));
    });

    group('when following dialog', () {
      setUp(() {
        mapObject.onInteract = Scene([
          InteractionObject.facePlayer(),
          Dialog.parse('Are you great?'),
          YesOrNoChoice(
            ifYes: [Dialog.parse('Great!')],
            ifNo: [Dialog.parse('Too bad.')],
          )
        ]);
      });

      test('does not generate interrupt before choice', () {
        // This time, start the scene with dialog,
        // then add the choice.
        // When presenting the choice, we should not have
        // an interrupt control code.

        program.addMap(map);

        var dialogTree = program.dialogTrees.forMap(map.id);

        // Expect the dialog followed by the choice
        expect(
            dialogTree[0],
            DialogAsm([
              dc.b(Bytes.ascii('Are you great?')),
              dc.b([Byte(0xf5)]),
              dc.b([Byte(0x1), Byte(0)]),
              dc.b(Bytes.ascii('Too bad.')),
              dc.b([Byte(0xff)]),
            ]));
      });

      test('does not generate interrupt before yes branch', () {
        program.addMap(map);

        var dialogTree = program.dialogTrees.forMap(map.id);

        // In the yes branch, just expect the yes branch dialog
        // as before
        expect(dialogTree, hasLength(2));
        expect(
            dialogTree[1],
            DialogAsm([
              dc.b(Bytes.ascii('Great!')),
              dc.b([Byte(0xff)]),
            ]));
      });
    });
  });
}
