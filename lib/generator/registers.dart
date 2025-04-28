import 'package:rune/asm/asm.dart';
import 'package:rune/generator/stack.dart';

/// Tracks free registers for the use of a single computation involving many
/// registers.
class Registers {
  final _kept = <PushOneToStack>[];

  Registers();

  Registers branch() {
    return Registers().._kept.addAll(_kept);
  }

  Asm keep(RegisterListOrRegister registers, Size size,
      {required Asm Function() around}) {
    switch (registers) {
      case RegisterList l when l.isEmpty:
        return around();
      case DirectRegister one:
        _kept.insert(0, PushOneToStack(one, size));
        var asm = around();
        release(one);
        return asm;
      case RegisterList list:
        for (var r in list) {
          _kept.insert(0, PushOneToStack(r, size));
        }
        var asm = around();
        release(list);
        return asm;
    }
  }

  void release(RegisterListOrRegister registers) {
    var toRelease = Set.of(switch (registers) {
      RegisterList many => many,
      DirectRegister register => [register]
    });

    for (var i = 0; i < _kept.length; i++) {
      var kept = _kept[i];
      if (toRelease.remove(kept.push)) {
        _kept.removeAt(i);
      }
    }
  }

  PushToStack _keep(DirectRegister r) {
    for (var kept in _kept) {
      if (kept.push == r) {
        return kept;
      }
    }
    return NoneToPush();
  }

  /// Wraps [inner] while maintaining register state via the stack
  /// for any [registers] which have been previously kept via [keep].
  Asm maintain(RegisterListOrRegister registers, Asm asm) {
    // TODO: merge multiple pushes IF
    // - register list offered here
    // - multiple of those registers are kept
    // - all kept registers are of the same size

    // If any of these registers are kept,
    // wrap `asm` with push/pop.
    switch (registers) {
      case DirectRegister r:
        return _keep(r).wrap(asm);
      case RegisterList many:
        // TODO: could do merge logic here as optimization
        for (var r in many) {
          asm = _keep(r).wrap(asm);
        }
        return asm;
    }
  }
}
