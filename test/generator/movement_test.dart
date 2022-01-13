import 'dart:math';

import 'package:rune/generator/movement.dart';
import 'package:rune/model/model.dart';
import 'package:rune/numbers.dart';
import 'package:test/test.dart';

void main() {
  test('generates asm from simple one directional steps', () {
    var ctx = EventContext();
    ctx.slots.insert(0, alys);
    ctx.slots.insert(1, shay);

    ctx.positions[alys] = Point('230'.hex, '250'.hex);
    ctx.positions[shay] = Point('230'.hex, '240'.hex);

    var move = Move();
    move.movements[alys] = StepDirection()
      ..distance = 5
      ..direction = Direction.right;

    var asm = move.toAsm(ctx);

    print(asm);

    expect(asm.toString(), r'''''');
  });

  test('multiple moves same distance', () {
    var ctx = EventContext();
    ctx.slots.insert(0, alys);
    ctx.slots.insert(1, shay);

    ctx.positions[alys] = Point('230'.hex, '250'.hex);
    ctx.positions[shay] = Point('230'.hex, '240'.hex);

    var move = Move();
    move.movements[alys] = StepDirection()
      ..distance = 5
      ..direction = Direction.right;
    move.movements[shay] = StepDirection()
      ..distance = 1
      ..direction = Direction.down;

    var asm = move.toAsm(ctx);

    print(asm);

    expect(asm.toString(), r'''''');
  });

  test('multiple moves different distance', () {
    var ctx = EventContext();
    ctx.slots.insert(0, alys);
    ctx.slots.insert(1, shay);

    ctx.positions[alys] = Point('230'.hex, '240'.hex);
    ctx.positions[shay] = Point('230'.hex, '250'.hex);

    var move = Move();
    move.movements[alys] = StepDirection()
      ..distance = 4
      ..direction = Direction.left;
    move.movements[shay] = StepDirection()
      ..distance = 2
      ..direction = Direction.down;

    var asm = move.toAsm(ctx);

    print(asm);

    expect(asm.toString(), r'''''');
  });

  test('multiple moves with some delayed', () {
    var ctx = EventContext();
    ctx.slots.insert(0, alys);
    ctx.slots.insert(1, shay);

    ctx.positions[alys] = Point('2A0'.hex, '250'.hex);
    ctx.positions[shay] = Point('230'.hex, '1F0'.hex);

    var move = Move();
    move.movements[alys] = StepDirection()
      ..distance = 5
      ..direction = Direction.left;
    move.movements[shay] = StepDirection()
      ..distance = 5
      ..delay = 2
      ..direction = Direction.down;

    var asm = move.toAsm(ctx);

    print(asm);

    expect(asm.toString(), r'''''');
  });
}
