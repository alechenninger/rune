import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

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
        id: 'Npc',
        startPosition: Position(0x100, 0x100),
        spec: Npc(Sprite.Motavian1, FaceDown()));

    map.addObject(mapObject);

    program = Program(eventPointers: EventPointers.empty());
  });

  group('yes no choice in interaction', () {
    group('with dialog then event in branches', () {
      // This time use a scene that ends in an event
      setUp(() {
        mapObject.onInteract = Scene([
          Dialog.parse('Are you great?'),
          YesOrNoChoice(
            ifYes: [Dialog.parse('Great!'), Pause(1.second)],
            ifNo: [Dialog.parse('Too bad.'), Pause(2.seconds)],
          )
        ]);
      });

      test('requires event at start of interaction', () {
        var asm = program.addMap(map);
        var dialogTree = program.dialogTrees.forMap(map.id);
        expect(dialogTree, hasLength(3));
        expect(
            dialogTree[0],
            DialogAsm([
              runEvent(0.toWord),
              dc.b([Byte(0xff)])
            ]));

        expect(
            program.additionalEventPointers.withoutComments(),
            Asm([
              dc.l([Label('Event_GrandCross_Test_Npc')])
            ]));

        expect(
            asm.events.withoutComments().head(1),
            Asm([
              setLabel('Event_GrandCross_Test_Npc'),
            ]));
      });

      test('event asm just runs event', () {
        var asm = program.addMap(map);

        expect(
            asm.events.withoutComments().trim().skip(1),
            Asm([
              getAndRunDialog3LowDialogId(Byte(1).i),
              tst.b(Constant('Yes_No_Option').w),
              beq.w(Label('.2_yes_choice')),
              generateEventAsm([Pause(2.seconds)]),
              bra.w(Label('.2_choice_continue')),
              setLabel('.2_yes_choice'),
              generateEventAsm([Pause(1.seconds)]),
              setLabel('.2_choice_continue'),
              returnFromInteractionEvent(),
            ]));
      });

      test('dialog terminates to run events', () {
        program.addMap(map);
        var dialogTree = program.dialogTrees.forMap(map.id);

        expect(dialogTree, hasLength(3));
        expect(
            dialogTree[1].withoutComments(),
            DialogAsm([
              dc.b(Bytes.ascii("Are you great?")),
              dc.b([Byte(0xf5)]),
              dc.b([Byte(0x1), Byte(0)]),
              dc.b(Bytes.ascii('Too bad.')),
              dc.b([Byte(0xff)])
            ]));

        expect(
            dialogTree[2].withoutComments(),
            DialogAsm([
              dc.b(Bytes.ascii('Great!')),
              dc.b([Byte(0xff)])
            ]));
      });
    });

    group('with event then dialog in branches generates', () {
      setUp(() {
        mapObject.onInteract = Scene([
          YesOrNoChoice(
            ifYes: [Pause(1.second), Dialog.parse('Great!')],
            ifNo: [Pause(2.seconds), Dialog.parse('Too bad.')],
          )
        ]);
      });

      test('requires event at start of interaction', () {
        var asm = program.addMap(map);
        var dialogTree = program.dialogTrees.forMap(map.id);
        expect(dialogTree, hasLength(3));
        expect(
            dialogTree[0],
            DialogAsm([
              runEvent(0.toWord),
              dc.b([Byte(0xff)])
            ]));

        expect(
            program.additionalEventPointers.withoutComments(),
            Asm([
              dc.l([Label('Event_GrandCross_Test_Npc')])
            ]));

        expect(
            asm.events.withoutComments().head(1),
            Asm([
              setLabel('Event_GrandCross_Test_Npc'),
            ]));
      });

      test('event runs dialog and branches', () {
        var asm = program.addMap(map);

        expect(
            asm.events.withoutComments().trim().skip(1),
            Asm([
              getAndRunDialog3LowDialogId(Byte(1).i),
              tst.b(Constant('Yes_No_Option').w),
              beq.w(Label('.2_yes_choice')),
              generateEventAsm([Pause(2.seconds)]),
              popAndRunDialog3,
              bra.w(Label('.2_choice_continue')),
              setLabel('.2_yes_choice'),
              generateEventAsm([Pause(1.seconds)]),
              popAndRunDialog3,
              setLabel('.2_choice_continue'),
              returnFromInteractionEvent(),
            ]));
      });

      test('dialog jumps to event', () {
        program.addMap(map);
        var dialogTree = program.dialogTrees.forMap(map.id);

        expect(dialogTree, hasLength(3));
        expect(
            dialogTree[1].withoutComments(),
            DialogAsm([
              dc.b([Byte(0xf5)]),
              dc.b([Byte(0x1), Byte(0)]),
              dc.b([Byte(0xf7)]),
              dc.b(Bytes.ascii('Too bad.')),
              dc.b([Byte(0xff)])
            ]));

        expect(
            dialogTree[2].withoutComments(),
            DialogAsm([
              dc.b([Byte(0xf7)]),
              dc.b(Bytes.ascii('Great!')),
              dc.b([Byte(0xff)])
            ]));
      });
    });

    group('with just dialog in branches generates', () {
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
            dialogTree[0].withoutComments(),
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
  });
}
