import 'package:rune/generator/memory.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  for (final factory in <String, EventState Function()>{
    'EventState': EventState.new,
    'Memory': Memory.new,
  }.entries) {
    group('${factory.key} symbolic facing', () {
      late EventState state;
      late DirectionExpression towardsShay;

      setUp(() {
        state = factory.value();
        towardsShay = alys.towards(shay);
      });

      test('records a relationship without knowing either position', () {
        state.setFacing(alys, towardsShay);
        expect(state.getFacing(alys), towardsShay);
        expect(alys.facing().known(state), isNull);
      });

      test('projects interaction facing from the player facing expression', () {
        state.setFacing(
            BySlot.one, BySlot.one.towards(const InteractionObject()));
        expect(state.playerFacesInteractionObject, isTrue);
        state.setFacing(BySlot.one, Direction.up);
        expect(state.playerFacesInteractionObject, isFalse);
      });

      for (final object in [alys, shay]) {
        test(
            'changing a referenced position invalidates the relationship '
            '($object)', () {
          state.setFacing(alys, towardsShay);
          state.positions[object] = null;
          expect(state.getFacing(alys), isNull);
        });
      }

      test('unrelated position and facing changes preserve the relationship',
          () {
        state.setFacing(alys, towardsShay);
        state.positions[rune] = null;
        state.setFacing(rune, Direction.up);
        expect(state.getFacing(alys), towardsShay);
      });

      test('the target turning does not change the direction toward it', () {
        state.setFacing(alys, towardsShay);
        state.setFacing(shay, Direction.up);
        expect(state.getFacing(alys), towardsShay);
      });

      test('position changes preserve concrete facing', () {
        state.setFacing(alys, Direction.left);
        state.positions[alys] = null;
        expect(state.getFacing(alys), Direction.left);
      });

      test('finds dependencies in offsets and mixed coordinate components', () {
        final expression = DirectionOfVector(
                from: Position(0, 0),
                to: PositionOfXY(
                        OffsetPositionComponent(
                            shay.position().component(Axis.x),
                            offset: 16),
                        rune.position().component(Axis.y))
                    .offset(Position(16, 0)))
            .turn(1);
        state.setFacing(alys, expression);
        state.positions[rika] = null;
        expect(state.getFacing(alys), expression);
        state.positions[rune] = null;
        expect(state.getFacing(alys), isNull);
      });

      test('invalidates dependencies in the zero-vector fallback', () {
        state.setFacing(
            alys,
            DirectionOfVector(
                from: Position(0, 0),
                to: Position(0, 0),
                zeroValue: rune.facing()));
        state.clearFacing(rune);
        expect(state.getFacing(alys), isNull);
      });

      test('invalidates facing dependencies transitively', () {
        state.setFacing(alys, towardsShay);
        state.setFacing(rune, alys.facing().turn(1));
        state.setFacing(rika, rune.facing());
        state.positions[shay] = null;
        expect(state.getFacing(alys), isNull);
        expect(state.getFacing(rune), isNull);
        expect(state.getFacing(rika), isNull);
      });

      for (final turns in [1, 2, 3]) {
        test('does not remember an unknown self-relative turn ($turns)', () {
          state.setFacing(BySlot.one, BySlot.one.facing().turn(turns));

          expect(state.getFacing(BySlot.one), isNull);
        });
      }

      test('evaluates self-relative turns before replacing the old facing', () {
        state.setFacing(BySlot.one, Direction.up);
        state.setFacing(BySlot.one, BySlot.one.facing().opposite);
        expect(state.getFacing(BySlot.one), Direction.down);

        state.setFacing(BySlot.one, BySlot.one.facing().opposite);
        expect(state.getFacing(BySlot.one), Direction.up);
      });

      for (final knownSlot in [false, true]) {
        test('recognizes self-relative turns through aliases ($knownSlot)', () {
          if (knownSlot) state.setSlot(1, alys);
          state.setFacing(alys, BySlot.one.facing().opposite);

          expect(state.getFacing(alys), isNull);
        });
      }

      test('remembers a turn relative to a distinct unknown slot', () {
        final direction = BySlot.one.facing().opposite;
        state.setFacing(BySlot.two, direction);

        expect(state.getFacing(BySlot.two), direction);
      });

      test('discarding a self-relative turn also invalidates its dependents',
          () {
        state.setFacing(rune, alys.facing());
        state.setFacing(alys, alys.facing().opposite);

        expect(state.getFacing(alys), isNull);
        expect(state.getFacing(rune), isNull);
      });

      test('facing changes break indirect cycles before storing a new fact',
          () {
        state.setFacing(alys, shay.facing());
        state.setFacing(shay, alys.facing());
        expect(state.getFacing(alys), isNull);
        expect(state.getFacing(shay), alys.facing());
        expect(alys.facing().known(state), isNull);
        state.clearFacing(shay);
        expect(state.getFacing(alys), isNull);
      });

      test('zero-vector self fallback does not recurse indefinitely', () {
        state.positions[alys] = Position(0, 0);
        state.positions[shay] = Position(0, 0);
        state.setFacing(alys, towardsShay);
        expect(state.getFacing(alys), towardsShay);
        expect(alys.facing().known(state), isNull);
      });

      test('discards a rotating self fallback through a slot alias', () {
        state.setSlot(1, alys);
        state.positions[alys] = Position(0, 0);
        state.positions[shay] = Position(0, 0);
        state.setFacing(
            alys,
            DirectionOfVector(
                from: BySlot.one.position(),
                to: shay.position(),
                zeroValue: BySlot.one.facing().turn(1)));

        expect(state.getFacing(alys), isNull);
        expect(alys.facing().known(state), isNull);
        expect(BySlot.one.facing().known(state), isNull);
      });

      test('does not remember a vector with a rotated keep-facing fallback',
          () {
        state.setFacing(alys, towardsShay.turn(1));

        expect(state.getFacing(alys), isNull);
      });

      test('finds self-relative turns in nested vector fallbacks', () {
        final direction = DirectionOfVector(
            from: Position(0, 0),
            to: Position(0, 0),
            zeroValue: DirectionOfVector(
                from: alys.position(),
                to: shay.position(),
                zeroValue: alys.facing().opposite));
        state.setFacing(alys, direction);

        expect(state.getFacing(alys), isNull);
      });

      test('remembers a vector when fallback turns cancel out', () {
        final direction = DirectionOfVector(
                from: alys.position(),
                to: shay.position(),
                zeroValue: alys.facing().turn(3))
            .turn(1);
        state.setFacing(alys, direction);

        expect(state.getFacing(alys), direction);
      });

      test('can evaluate a vector even when its self fallback is unsafe', () {
        state.positions[alys] = Position(0, 0);
        state.positions[shay] = Position(16, 0);
        state.setFacing(alys, towardsShay.turn(1));

        expect(state.getFacing(alys), Direction.down);
      });

      test('independent queries evaluate nested symbolic facing normally', () {
        state.positions[alys] = Position(0, 0);
        state.positions[shay] = Position(16, 0);
        state.setFacing(alys, towardsShay);
        state.setFacing(rune, alys.facing().turn(1));

        for (var query = 0; query < 2; query++) {
          expect(rune.facing().known(state), Direction.down);
          expect(alys.facing().known(state), Direction.right);
        }
      });

      test('known slot aliases invalidate named position dependencies', () {
        state.setSlot(2, shay);
        state.setFacing(alys, towardsShay);
        state.positions[BySlot.two] = null;
        expect(state.getFacing(alys), isNull);
      });

      test('unknown slot aliases conservatively invalidate named dependencies',
          () {
        state.setFacing(alys, towardsShay);
        state.positions[BySlot.two] = null;
        expect(state.getFacing(alys), isNull);
      });

      test('distinct unknown slots do not alias each other', () {
        state.setFacing(
            BySlot.one, BySlot.one.towards(const InteractionObject()));
        state.positions[BySlot.two] = null;
        state.clearFacing(BySlot.two);
        expect(state.playerFacesInteractionObject, isTrue);
      });

      test('named map objects invalidate the interaction object dependency',
          () {
        final npc = MapObject(
            id: 'npc', startPosition: Position(0, 0), spec: AlysWaiting());
        state.currentMap = GameMap(MapId.Test)..addObject(npc);
        state.setFacing(
            BySlot.one, BySlot.one.towards(const InteractionObject()));
        state.positions[MapObjectById(npc.id)] = null;
        expect(state.playerFacesInteractionObject, isFalse);
      });

      test('slot remapping invalidates expressions containing slot references',
          () {
        state.setSlot(1, alys);
        state.setFacing(alys, BySlot.one.towards(shay));
        state.slots[1] = rune;
        expect(state.getFacing(alys), isNull);
        expect(state.getFacing(BySlot.one), isNull);
      });

      test('slot remapping preserves expressions using only named characters',
          () {
        state.setSlot(1, alys);
        state.setFacing(alys, towardsShay);
        state.slots[1] = rune;
        expect(state.getFacing(alys), towardsShay);
      });

      test(
          'bulk position clearing invalidates symbolic but not concrete facing',
          () {
        state.setFacing(alys, towardsShay);
        state.setFacing(rune, Direction.left);
        state.positions.clear();
        expect(state.getFacing(alys), isNull);
        expect(state.getFacing(rune), Direction.left);
      });

      test('branching preserves independent symbolic facts', () {
        state.setSlot(1, alys);
        state.setSlot(2, shay);
        state.positions[alys] = Position(0, 0);
        state.positions[shay] = Position(16, 0);
        state.setFacing(alys, towardsShay);
        final branch = state.branch();

        expect(branch.positions[alys], Position(0, 0));
        expect(branch.positions[BySlot.one], Position(0, 0));
        expect(branch.positions[shay], Position(16, 0));
        expect(branch.positions[BySlot.two], Position(16, 0));
        expect(branch.getFacing(alys), towardsShay);

        branch.positions[shay] = null;
        expect(branch.getFacing(alys), isNull);
        expect(state.positions[shay], Position(16, 0));
        expect(state.getFacing(alys), towardsShay);
      });

      test('slot remapping invalidates transitive facing dependencies', () {
        state.setSlot(1, alys);
        state.setFacing(rune, BySlot.one.facing());
        state.setFacing(rika, rune.facing());
        state.slots.setPartyOrder([shay, alys]);
        expect(state.getFacing(rune), isNull);
        expect(state.getFacing(rika), isNull);
      });

      test('unrelated slots preserve a relationship', () {
        state.setFacing(
            BySlot.one, BySlot.one.towards(const InteractionObject()));
        state.slots[2] = shay;
        expect(state.playerFacesInteractionObject, isTrue);
      });

      test('routine knowledge preserves position and facing facts', () {
        final position = Position(16, 32);
        state.positions[shay] = position;
        state.setFacing(shay, Direction.left);
        state.setFacing(alys, towardsShay);
        state.setRoutine(shay, scriptableObjectRoutine);
        expect(state.getFacing(alys), towardsShay);
        state.setRoutine(shay, null);
        expect(state.getFacing(alys), towardsShay);
        expect(state.positions[shay], position);
        expect(state.getFacing(shay), Direction.left);
      });

      test('field updates forget native poses and preserve stationary scripts',
          () {
        final native = MapObject(
            id: 'native', startPosition: Position(0, 0), spec: AlysWaiting());
        final scripted = MapObject(
            id: 'scripted', startPosition: Position(0, 0), spec: AlysWaiting());
        state.currentMap = GameMap(MapId.Test)
          ..addObject(native)
          ..addObject(scripted);
        state.setRoutine(scripted, scriptableObjectRoutine);
        state.positions[native] = Position(16, 32);
        state.setFacing(native, Direction.up);
        state.positions[scripted] = Position(48, 64);
        state.setFacing(scripted, Direction.left);
        state.positions[alys] = Position(80, 96);
        state.setFacing(alys, alys.towards(native));

        state.clearObjectState(preserveScripted: true);

        expect(state.positions[native], isNull);
        expect(state.getFacing(native), isNull);
        expect(state.positions[scripted], Position(48, 64));
        expect(state.getFacing(scripted), Direction.left);
        expect(state.positions[alys], Position(80, 96));
        expect(state.getFacing(alys), isNull);
      });

      test('field updates preserve a relationship to a stationary scripted NPC',
          () {
        final npc = MapObject(
            id: 'npc', startPosition: Position(0, 0), spec: AlysWaiting());
        state.currentMap = GameMap(MapId.Test)..addObject(npc);
        state.setRoutine(npc, scriptableObjectRoutine);
        state.setFacing(
            BySlot.one, BySlot.one.towards(const InteractionObject()));
        state.clearObjectState(preserveScripted: true);
        expect(state.playerFacesInteractionObject, isTrue);
      });

      test('field updates invalidate a pending scripted movement', () {
        state.positions[shay] = Position(16, 32);
        state.setFacing(shay, Direction.right);
        state.startMovement(shay);
        state.clearObjectState(preserveScripted: true);
        expect(state.positions[shay], isNull);
        expect(state.getFacing(shay), isNull);
        expect(state.hasPendingMovement(shay), isTrue);
      });

      test('unknown object changes clear concrete facts and routine knowledge',
          () {
        state.positions[shay] = Position(16, 32);
        state.setFacing(shay, Direction.right);
        state.setRoutine(shay, scriptableObjectRoutine);
        state.clearObjectState();
        expect(state.positions[shay], isNull);
        expect(state.getFacing(shay), isNull);
        expect(state.getRoutine(shay), isNull);
      });
    });
  }

  test('possible position and slot changes invalidate symbolic dependencies',
      () {
    for (final mutate in <void Function(Memory)>[
      (s) => s.positions[shay] = null,
      (s) => s.slots[1] = rune,
    ]) {
      final state = Memory()..setSlot(1, alys);
      state.setFacing(alys, BySlot.one.towards(shay));
      final branch = state.branch();
      mutate(branch);
      for (final change in branch.changes) {
        change.mayApply(state);
      }
      expect(state.getFacing(alys), isNull);
    }
  });

  test('possible routine changes preserve position and facing facts', () {
    final state = Memory()
      ..positions[shay] = Position(16, 32)
      ..setFacing(alys, alys.towards(shay));
    final branch = state.branch()..setRoutine(shay, scriptableObjectRoutine);
    for (final change in branch.changes) {
      change.mayApply(state);
    }
    expect(state.positions[shay], Position(16, 32));
    expect(state.getFacing(alys), alys.towards(shay));
  });
}
