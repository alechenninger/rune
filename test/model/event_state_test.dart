import 'package:rune/model/model.dart';
import 'package:rune/generator/memory.dart';
import 'package:test/test.dart';

void main() {
  test('setting character position also sets slot if known', () {
    var state = EventState();
    state.slots[2] = rune;
    state.positions[rune] = Position(0x10, 0x20);
    expect(state.positions[BySlot(2)], Position(0x10, 0x20));
  });

  for (var factory in <String, EventState Function()>{
    'EventState': EventState.new,
    'Memory': Memory.new,
  }.entries) {
    group('${factory.key} initial interaction facing', () {
      test('is unknown outside interaction entry', () {
        expect(factory.value().playerFacesInteractionObject, isFalse);
      });

      final mutations = <String, void Function(EventState)>{
        'known position': (s) => s.positions[shay] = Position(0x10, 0x20),
        'unknown position': (s) => s.positions[shay] = null,
        'all positions': (s) => s.positions.clear(),
        'known facing': (s) => s.setFacing(shay, Direction.up),
        'unknown facing': (s) => s.clearFacing(shay),
        'new character facing': (s) =>
            s.addCharacter(shay, facing: Direction.up),
        'movement start': (s) => s.startMovement(shay),
        'movement completion': (s) => s.finishMovement(shay),
      };
      for (final mutation in mutations.entries) {
        test('${mutation.key} invalidates initial facing', () {
          final state = factory.value()
            ..setFacing(
                BySlot.one, BySlot.one.towards(const InteractionObject()));
          mutation.value(state);
          expect(state.playerFacesInteractionObject, isFalse);
        });
      }

      test('branching copies the fact without invalidating the parent', () {
        final state = factory.value()
          ..positions[shay] = Position(0x10, 0x20)
          ..setFacing(
              BySlot.one, BySlot.one.towards(const InteractionObject()));
        final branch = state.branch();
        expect(branch.playerFacesInteractionObject, isTrue);
        branch.positions[shay] = null;
        expect(branch.playerFacesInteractionObject, isFalse);
        expect(state.playerFacesInteractionObject, isTrue);
        expect(state.positions[shay], Position(0x10, 0x20));
      });

      test('recording routine knowledge preserves initial facing', () {
        final state = factory.value()
          ..setFacing(
              BySlot.one, BySlot.one.towards(const InteractionObject()));
        state.setRoutine(shay, scriptableObjectRoutine);
        expect(state.playerFacesInteractionObject, isTrue);
        state.setRoutine(shay, null);
        expect(state.playerFacesInteractionObject, isTrue);
      });

      test('resetting routine knowledge preserves positions and facing', () {
        final npc = MapObject(
            id: 'npc', startPosition: Position(0, 0), spec: AlysWaiting());
        final state = factory.value()
          ..currentMap = (GameMap(MapId.Test)..addObject(npc))
          ..setSlot(1, alys)
          ..positions[alys] = Position(0x10, 0x20)
          ..positions[npc] = Position(0x30, 0x40)
          ..setFacing(BySlot.one, BySlot.one.towards(const InteractionObject()))
          ..setFacing(npc, Direction.left)
          ..setRoutine(alys, scriptableObjectRoutine)
          ..setRoutine(npc, scriptableObjectRoutine);

        state.resetRoutines();

        expect(state.getRoutine(alys), isNull);
        expect(state.getRoutine(npc), isNull);
        expect(state.positions[alys], Position(0x10, 0x20));
        expect(state.positions[npc], Position(0x30, 0x40));
        expect(state.playerFacesInteractionObject, isTrue);
        expect(state.getFacing(npc), Direction.left);
      });
    });

    group('${factory.key} slot ownership', () {
      final mutations =
          <String, ({void Function(Slots) change, Character? firstSlot})>{
        'assignment': (change: (slots) => slots[1] = rune, firstSlot: rune),
        'party order': (
          change: (slots) => slots.setPartyOrder([rune, shay]),
          firstSlot: rune,
        ),
        'party restoration': (
          change: (slots) => slots.restorePreviousParty(),
          firstSlot: rune,
        ),
        'unknown order': (
          change: (slots) => slots.unknownPartyOrder(),
          firstSlot: null,
        ),
      };

      for (final mutation in mutations.entries) {
        test('${mutation.key} affects only its owning state', () {
          final state = factory.value();
          state.slots.setPartyOrder([rune, shay]);
          state.slots.setPartyOrder([alys, shay],
              saveCurrent: true, maintainOrder: true);
          final position = Position(0x10, 0x20);
          final direction = BySlot.one.towards(BySlot.two);
          state.positions[BySlot.one] = position;
          state.setFacing(BySlot.one, direction);

          final branch = state.branch();
          expect(branch.slots[1], alys);
          expect(branch.slots.partyOrderMaintained, isTrue);
          expect(branch.positions[BySlot.one], position);
          expect(branch.getFacing(BySlot.one), direction);
          mutation.value.change(branch.slots);

          expect(branch.slots[1], mutation.value.firstSlot);
          expect(branch.positions[BySlot.one], isNull);
          expect(branch.getFacing(alys), isNull);
          expect(state.slots[1], alys);
          expect(state.slots.partyOrderMaintained, isTrue);
          expect(state.positions[BySlot.one], position);
          expect(state.getFacing(BySlot.one), direction);
        });
      }
    });

    group('${factory.key} pending movements', () {
      test(
          'interaction updates clear poses and dependencies without completing',
          () {
        final position = Position(0x10, 0x20);
        final state = factory.value()
          ..setSlot(2, shay)
          ..startMovement(BySlot.two)
          ..positions[shay] = position
          ..setFacing(shay, left)
          ..setRoutine(shay, scriptableObjectRoutine)
          ..setFacing(alys, alys.towards(BySlot.two))
          ..setFacing(rika, alys.facing())
          ..positions[rune] = position
          ..setFacing(rune, up);

        state.clearPendingMovementState();

        expect(state.positions[shay], isNull);
        expect(state.positions[BySlot.two], isNull);
        expect(state.getFacing(shay), isNull);
        expect(state.getFacing(alys), isNull);
        expect(state.getFacing(rika), isNull);
        expect(state.getRoutine(shay), scriptableObjectRoutine);
        expect(state.pendingMovements, {shay});
        expect(state.positions[rune], position);
        expect(state.getFacing(rune), up);
      });

      test('resolves character/slot aliases, starting with slot', () {
        var state = factory.value()..setSlot(2, rune);
        state.startMovement(BySlot.two);
        expect(state.hasPendingMovement(rune), isTrue);
        state.startMovement(rune);
        expect(state.pendingMovements, {rune});
        state.finishMovement(rune);
        expect(state.hasPendingMovement(BySlot.two), isFalse);
        expect(state.pendingMovements, isEmpty);
      });

      test('resolves character/slot aliases, starting with character', () {
        var state = factory.value()..setSlot(2, rune);
        state.startMovement(rune);
        expect(state.hasPendingMovement(BySlot.two), isTrue);
        state.startMovement(BySlot.two);
        expect(state.pendingMovements, {rune});
        state.finishMovement(BySlot.two);
        expect(state.hasPendingMovement(rune), isFalse);
        expect(state.pendingMovements, isEmpty);
      });

      test('resolves map object IDs for add, query, and removal', () {
        var object = MapObject(
            id: 'npc', startPosition: Position(0, 0), spec: AlysWaiting());
        var map = GameMap(MapId.Test)..addObject(object);
        var state = factory.value()..currentMap = map;
        var reference = MapObjectById.of('npc');
        for (var pair in [(reference, object), (object, reference)]) {
          state.startMovement(pair.$1);
          expect(state.hasPendingMovement(pair.$2), isTrue);
          state.startMovement(pair.$2);
          expect(state.pendingMovements, {object});
          state.finishMovement(pair.$2);
          expect(state.pendingMovements, isEmpty);
        }
      });

      test('branch copies pending objects independently', () {
        var state = factory.value()..startMovement(rune);
        var branch = state.branch()
          ..finishMovement(rune)
          ..startMovement(shay);
        expect(state.pendingMovements, {rune});
        expect(branch.pendingMovements, {shay});
        expect(() => state.pendingMovements.clear(), throwsUnsupportedError);
      });
    });
  }

  group('possible state changes', () {
    final mutations =
        <String, ({void Function(Memory) change, Position? position})>{
      'position': (change: (s) => s.positions[shay] = null, position: null),
      'facing': (
        change: (s) => s.setFacing(shay, Direction.up),
        position: Position(0x10, 0x20),
      ),
      'position clear': (change: (s) => s.positions.clear(), position: null),
      'movement completion': (
        change: (s) => s.finishMovement(shay),
        position: null,
      ),
    };
    for (final mutation in mutations.entries) {
      test('${mutation.key} invalidates initial facing when replayed', () {
        final state = Memory()
          ..positions[shay] = Position(0x10, 0x20)
          ..setFacing(
              BySlot.one, BySlot.one.towards(const InteractionObject()));
        final branch = state.branch();
        mutation.value.change(branch);
        for (final change in branch.changes) {
          change.mayApply(state);
        }
        expect(state.playerFacesInteractionObject, isFalse);
        expect(state.positions[shay], mutation.value.position);
      });
    }
  });
}
