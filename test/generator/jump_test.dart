import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  Asm generate(List<Event> events) => Program()
      .addScene(SceneId('jump'), Scene(events),
          startingMap: GameMap(MapId.Test))
      .event
      .withoutComments();

  final saveY = move.w(curr_y_pos(a4), dest_y_pos(a4)).single;
  final beginOrder = bset(priority_ground_y_bit.i, priority_flag(a4)).single;
  final endOrder = bclr(priority_ground_y_bit.i, priority_flag(a4)).single;

  test(
      'stationary hop keeps takeoff Y through the apex and releases on landing',
      () {
    final asm = generate([
      JumpObject(BySlot.one,
          duration: const Duration(milliseconds: 150), height: 5),
    ]).toList();
    final call = jsr(Label('Event_StepObjectNoAnimate').l).single;
    final calls = [
      for (var i = 0; i < asm.length; i++)
        if (asm[i] == call) i,
    ];

    expect(calls, hasLength(2));
    expect(asm.where((i) => i == saveY), hasLength(2));
    expect(asm.indexOf(saveY), lessThan(asm.indexOf(beginOrder)));
    expect(asm.indexOf(beginOrder), lessThan(calls.first));
    expect(asm.sublist(calls.first, calls.last), isNot(contains(saveY)));
    expect(asm.indexOf(endOrder), greaterThan(calls.last));
    expect(asm.lastIndexOf(saveY), greaterThan(asm.indexOf(endOrder)));
    expect(asm.where((i) => i.operands.contains(priority_flag(a4))),
        [beginOrder, endOrder]); // Other priority bits are untouched.
  });

  test('group jump holds every destination across both distinct phase loops',
      () {
    final asm = generate([
      JumpObject.all([BySlot.one, BySlot.two],
          duration: const Duration(milliseconds: 150),
          height: 5,
          xMovement: 8,
          animate: true),
    ]).toList();
    final call = jsr(Label('Event_StepObjectNoWait').l).single;
    final firstCall = asm.indexOf(call);
    final lastCall = asm.lastIndexOf(call);

    expect(asm.where((i) => i == call), hasLength(4));
    expect(asm.take(firstCall).where((i) => i == beginOrder), hasLength(2));
    expect(asm.take(firstCall).where((i) => i == saveY), hasLength(2));
    expect(asm.sublist(firstCall, lastCall), isNot(contains(saveY)));
    expect(asm.skip(lastCall).where((i) => i == endOrder), hasLength(2));
    expect(asm.skip(lastCall).where((i) => i == saveY), hasLength(2));
    final labels = asm.map((i) => i.label).whereType<String>().toList();
    expect(labels.toSet().length, labels.length);
  });

  test('ordinary steps after a jump resume updating the movement destination',
      () {
    final asm = generate([
      JumpObject(BySlot.one, duration: const Duration(seconds: 1), height: 5, yMovement: 8),
      StepObject.constantStep(BySlot.one,
          stepPerFrame: const Point(0, 1), frames: 2),
    ]).toList();
    final call = jsr(Label('Event_StepObject').l).single;
    expect(asm.indexOf(endOrder), lessThan(asm.indexOf(call)));
    expect(asm.last, saveY);
    expect(asm.where((i) => i == saveY), hasLength(3));
  });
}
