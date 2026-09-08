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
    group('${factory.key} pending movements', () {
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

  test('Memory records definite and possible movement changes', () {
    var state = Memory()..setSlot(2, rune);
    state.clearChanges();
    state.startMovement(BySlot.two);
    state.finishMovement(rune);
    var [start, finish] = state.changes;
    var target = Memory()..setSlot(2, shay);
    start.mayApply(target);
    expect(target.pendingMovements, {rune});
    finish.mayApply(target);
    expect(target.pendingMovements, {rune});
    finish.apply(target);
    expect(target.pendingMovements, isEmpty);
    start.apply(target);
    expect(target.pendingMovements, {rune});
  });
}
