import '../asm/asm.dart';

sealed class PushToStack {
  factory PushToStack.none() => const NoneToPush();
  factory PushToStack.one(Register register, Size size) =>
      PushOneToStack(register, size);

  /// Cannot push [size] of [Size.b]
  /// (only word and longword) supported.
  factory PushToStack.many(RegisterList registers, Size size) {
    switch (registers.length) {
      case 0:
        return const NoneToPush();
      case 1:
        return PushOneToStack(registers.first, size);
      default:
        return PushManyToStack(registers, size);
    }
  }

  PushToStack();

  PopFromStack pop();
  Asm asm();

  /// Merges two [PushOneToStack] instances into a [PushManyToStack]
  /// if they are of the same size. Otherwise, returns `null`.
  PushToStack? mergeOne(PushOneToStack other);

  /// Merges this [PushOneToStack] with [other] [PushManyToStack].
  PushManyToStack? mergeMany(PushManyToStack other);

  /// Wraps [inner] while maintaining register state via the stack
  /// (pushes before, and pops after `inner` asm).
  Asm wrap(Asm inner) {
    return Asm([
      asm(),
      inner,
      pop().asm(),
    ]);
  }
}

abstract class PopFromStack {
  PushToStack push();
  Asm asm();
}

class NoneToPush implements PushToStack, PopFromStack {
  const NoneToPush();

  @override
  PopFromStack pop() {
    return NoneToPush();
  }

  @override
  Asm asm() => Asm([]);

  @override
  PushToStack push() {
    return NoneToPush();
  }

  @override
  Asm wrap(Asm inner) => inner;

  @override
  PushManyToStack? mergeMany(PushManyToStack other) {
    return other;
  }

  @override
  PushManyToStack? mergeOne(PushOneToStack other) {
    return PushManyToStack(RegisterList.of([other.register]), other.size);
  }
}

class PushManyToStack extends PushToStack {
  final RegisterList registers;
  final Size size;

  PushManyToStack(this.registers, this.size);

  @override
  PopFromStack pop() {
    return PopManyFromStack(registers, size);
  }

  @override
  Asm asm() => switch (size) {
        Size.b => throw 'nope',
        Size.w => movem.w(registers, -(sp)),
        Size.l => movem.l(registers, -(sp)),
      };

  @override
  PushManyToStack? mergeMany(PushManyToStack other) {
    if (size != other.size) return null;
    return PushManyToStack(
        RegisterList.of([...registers, ...other.registers]), size);
  }

  @override
  PushManyToStack? mergeOne(PushOneToStack other) {
    return PushManyToStack(
        RegisterList.of([...registers, other.register]), other.size);
  }
}

class PushOneToStack extends PushToStack {
  final Register register;
  final Size size;

  PushOneToStack(this.register, this.size);

  /// Merges two [PushOneToStack] instances into a [PushManyToStack]
  /// if they are of the same size. Otherwise, returns `null`.
  PushManyToStack? mergeOne(PushOneToStack other) {
    if (size != other.size) return null;
    return PushManyToStack(RegisterList.of([register, other.register]), size);
  }

  /// Merges this [PushOneToStack] with [other] [PushManyToStack].
  PushManyToStack? mergeMany(PushManyToStack other) {
    if (size != other.size) return null;
    return PushManyToStack(
        RegisterList.of([register, ...other.registers]), size);
  }

  @override
  PopFromStack pop() {
    return PopOneFromStack(register, size);
  }

  @override
  Asm asm() => switch (size) {
        Size.b => move.b(register, -(sp)),
        Size.w => move.w(register, -(sp)),
        Size.l => move.l(register, -(sp)),
      };
}

class PopOneFromStack extends PopFromStack {
  final Register register;
  final Size size;

  PopOneFromStack(this.register, this.size);

  @override
  PushToStack push() {
    return PushOneToStack(register, size);
  }

  @override
  Asm asm() => switch (size) {
        Size.b => move.b(sp.postIncrement(), register),
        Size.w => move.w(sp.postIncrement(), register),
        Size.l => move.l(sp.postIncrement(), register),
      };
}

class PopManyFromStack extends PopFromStack {
  final RegisterList registers;
  final Size size;

  PopManyFromStack(this.registers, this.size);

  @override
  PushToStack push() {
    return PushManyToStack(registers, size);
  }

  @override
  Asm asm() => switch (size) {
        Size.b => throw 'nope',
        Size.w => movem.w(sp.postIncrement(), registers),
        Size.l => movem.l(sp.postIncrement(), registers),
      };
}
