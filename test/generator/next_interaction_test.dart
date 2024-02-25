import 'package:collection/collection.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  late Program program;
  late GameMap map;
  late MapObject object;

  setUp(() {
    program = Program(eventIndexOffset: 0.toWord);
    map = GameMap(MapId.Test);
    object = MapObject(
        id: 'test_0',
        startPosition: Position(0x100, 0x100),
        spec: Npc(
            Sprite.PalmanWoman1,
            WanderAround(Direction.down,
                onInteract: Scene([Dialog.parse('Hello')]))));
    map.addObject(object);
  });

  group('next interaction', () {
    group('in interaction is just dialog', () {
      setUp(() {
        object.onInteract = Scene([
          Dialog.parse('Hello'),
          OnNextInteraction(
              withObjects: [object.id],
              onInteract: Scene([
                InteractionObject.facePlayer(),
                Dialog.parse('Hi again!'),
              ]))
        ]);
      });

      test('updates dialog ids for objects', () {
        var asm = program.addMap(map);

        expect(
            asm.events.withoutComments().withoutEmptyLines().skip(1),
            Asm([
              getAndRunDialog3LowDialogId(1.toByte.i),
              lea(0xFFFFC300.w, a4),
              move.b(0x2.toByte.i, dialogue_id(a4)),
              returnFromInteractionEvent(),
            ]));
      });

      test('generates new dialog', () {
        program.addMap(map);

        expect(
            program.dialogTrees.forMap(map.id).withoutComments(),
            DialogTree()
              // First one runs event
              ..add(DialogAsm([
                dc.b(ControlCodes.event),
                dc.w([0x0.toWord]),
                dc.b(ControlCodes.terminate)
              ]))
              // Next one is the first interaction
              ..add(DialogAsm([
                dc.b(Bytes.ascii('Hello')),
                dc.b(ControlCodes.terminate),
              ]))
              // Next is the subsequent interaction
              ..add(DialogAsm([
                dc.b(Bytes.ascii('Hi again!')),
                dc.b(ControlCodes.terminate),
              ])));
      });
    });

    test('generates new event routine if needed', () {
      object.onInteract = Scene([
        Dialog.parse('Hello'),
        OnNextInteraction(
            withObjects: [object.id],
            onInteract: Scene([
              InteractionObject.facePlayer(),
              Pause(1.second),
              Dialog.parse('Hi again!'),
            ]))
      ]);

      var asm = program.addMap(map);

      // First split the event ASM into both routines
      var routines = asm.events
          .splitBeforeIndexed((i, line) =>
              i != 0 && (line.label?.startsWith('Event_') ?? false))
          .toList();

      expect(routines.length, 2);
      expect(routines[0][0], isNot(routines[1][0]));
    });

    test('works from scene', () {},
        skip: "this won't work currently "
            "due to missing depencies for generation");
  });
}
