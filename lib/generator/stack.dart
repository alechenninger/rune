import '../asm/asm.dart';

sealed class PushToStack {
  factory PushToStack.none() => const NoneToPush();
  factory PushToStack.one(Address push, Size size, {Address? popToAddress}) =>
      PushOneToStack(push, size, popToAddress: popToAddress);

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

  const PushToStack();

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
  Asm wrap(Asm inner) => inner;

  @override
  PushManyToStack? mergeMany(PushManyToStack other) {
    return other;
  }

  @override
  PushManyToStack? mergeOne(PushOneToStack other) {
    return switch (other.push) {
      DirectRegister r => PushManyToStack(RegisterList.of([r]), other.size),
      _ => null,
    };
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
    if (size != other.size) return null;
    switch (other.push) {
      case DirectRegister r:
        return PushManyToStack(RegisterList.of([...registers, r]), other.size);
      default:
        return null;
    }
  }
}

class PushOneToStack extends PushToStack {
  final Address push;
  final Address popToAddress;
  final Size size;

  const PushOneToStack(this.push, this.size, {Address? popToAddress})
      : popToAddress = popToAddress ?? push;

  /// Merges two [PushOneToStack] instances into a [PushManyToStack]
  /// if they are of the same size. Otherwise, returns `null`.
  @override
  PushManyToStack? mergeOne(PushOneToStack other) {
    if (size != other.size) return null;
    switch ((push, other.push)) {
      case (DirectRegister a, DirectRegister b):
        return PushManyToStack(RegisterList.of([a, b]), size);
      default:
        return null;
    }
  }

  /// Merges this [PushOneToStack] with [other] [PushManyToStack].
  @override
  PushManyToStack? mergeMany(PushManyToStack other) {
    if (size != other.size) return null;
    switch ((push, other.registers)) {
      case (DirectRegister a, RegisterList b):
        return PushManyToStack(RegisterList.of([a, ...b]), size);
      default:
        return null;
    }
  }

  @override
  PopFromStack pop() {
    return PopOneFromStack(popToAddress, size);
  }

  @override
  Asm asm() => switch (size) {
        Size.b => move.b(push, -(sp)),
        Size.w => move.w(push, -(sp)),
        Size.l => move.l(push, -(sp)),
      };
}

class PopOneFromStack extends PopFromStack {
  final Address destination;
  final Size size;

  PopOneFromStack(this.destination, this.size);

  @override
  Asm asm() => switch (size) {
        Size.b => move.b(sp.postIncrement(), destination),
        Size.w => move.w(sp.postIncrement(), destination),
        Size.l => move.l(sp.postIncrement(), destination),
      };
}

class PopManyFromStack extends PopFromStack {
  final RegisterList registers;
  final Size size;

  PopManyFromStack(this.registers, this.size);

  @override
  Asm asm() => switch (size) {
        Size.b => throw 'nope',
        Size.w => movem.w(sp.postIncrement(), registers),
        Size.l => movem.l(sp.postIncrement(), registers),
      };
}
