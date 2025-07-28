import '../asm/asm.dart';
import '../asm/events.dart';
import '../model/model.dart';
import 'memory.dart';
import 'movement.dart';

class BranchLabels extends Iterable<(ComparisonBranch, Label?)> {
  final String _prefix;
  final Map<Comparison, (ComparisonBranch, Label)> _labels = {};
  final Comparison? emptyBranch;
  late final ComparisonBranch fallThrough;
  final Label _continueLbl;
  bool _continued = false;

  BranchLabels(this._prefix, IfValue ifValue)
      : emptyBranch = ifValue.emptyBranch,
        _continueLbl = Label('${_prefix}continue') {
    var branches = ifValue.branches;

    // Should fall through on an equals branch if not a unary expression,
    // because equals requires comparison of all values
    // (cannot short-circuit).
    fallThrough = (ifValue.operand1 is! UnaryExpression && branches.length <= 2)
        ? branches.lastWhere((b) => b.comparison.isEqual,
            orElse: () => branches.last)
        : branches.last;

    if (emptyBranch case var b?) {
      _labels[b] = (ComparisonBranch.empty(b), _continueLbl);
      _continued = true;
    }

    for (var branch in branches) {
      // Fall through branch is not labeled unless necessary
      if (branch.comparison == fallThrough.comparison) continue;
      _label(branch);
    }
  }

  Label _label(ComparisonBranch branch) {
    var label = labelFor(branch.comparison);
    _labels[branch.comparison] = (branch, label);
    return label;
  }

  @override
  Iterator<(ComparisonBranch, Label?)> get iterator =>
      fallThroughFirst.iterator;

  Iterable<(ComparisonBranch, Label?)> get fallThroughFirst sync* {
    if (!_labels.containsKey(fallThrough.comparison)) {
      yield (fallThrough, null);
    }

    for (var (branch, label) in _labels.values) {
      yield (branch, label);
    }
  }

  bool containsBranch(Comparison b) => _labels.containsKey(b);

  Label? get labeledFallThrough => _labels[fallThrough.comparison]?.$2;
  Label? get continued => _continued ? _continueLbl : null;
  Label labelContinue() {
    _continued = true;
    return _continueLbl;
  }

  Label labelFor(Comparison c) {
    return Label('$_prefix${c.name}');
  }

  operator [](Comparison condition) => _labels[condition];

  Iterable<(ComparisonBranch, Label)> get excludingFallThrough =>
      _labels.entries
          .where((e) => e.key != fallThrough.comparison)
          .map((e) => e.value);

  Asm branchIfNotEqual() {
    var asm = Asm.empty();
    for (var (branch, label) in notEqualBranches()) {
      asm.add(branch.comparison.mnemonicUnsigned(label));
    }
    if (asm.isEmpty) {
      throw StateError('no branches to jump to');
    }
    return asm;
  }

  /// May label fall through if it is a not-equal branch.
  Iterable<(ComparisonBranch, Label)> notEqualBranches() sync* {
    if (fallThrough.comparison.isNotEqual &&
        !containsBranch(fallThrough.comparison)) {
      _label(fallThrough);
    }
    for (var (branch, label) in _labels.values) {
      if (branch.comparison.isNotEqual) {
        yield (branch, label);
      }
    }
  }
}

extension IfValueAsm on IfValue {
  /// Set CCR based on subtracing comparing [operand1] with [operand2].
  ///
  /// Note that in this case, [operand1] is the destination operand,
  /// and [operand2] is the source operand.
  /// I.e. if we're checking if an x position is > some constant,
  /// the constant will be the source operand,
  /// and x position will be the the destination,
  /// as in `cmpi.w #constant, curr_x_pos(a4)`
  Asm compare({required Memory memory, required BranchLabels branches}) {
    // TODO: to support "and"s we would need an alternative IfValue
    //  with multiple condition comparisons.
    //  Then, push each comparison's CCR vale onto the stack,
    //  and compare them in a series of branches.
    //  e.g.   ; compare left operand and save ccr to stack
    //         move.w sr, d0
    //         move.b d0, -(sp)
    //         ; compare right operand
    //         bne.s right_neq
    //         ; ...
    //      right_neq:
    //         ; restore CCR for left operand
    //         move.w sr, d0
    //         move.b (sp)+, d0
    //         move.w d0, sr
    //         bne.s right_neq

    var compareTo = _compare(operand1, memory, branches);

    // Compare operand2 to operand1
    switch (operand2) {
      case PositionComponentExpression c:
        return c.withValue(memory: memory, load: a4, asm: compareTo);
      case NullSlot():
        return compareTo(0xFF.i);
      case RoutineIdOfSlot r:
        return r.withValue(memory: memory, load: d2, asm: compareTo);
      case NullObjectRoutineId():
        return compareTo(Word(0).i);
      case Slot s:
        return compareTo(s.offset.i);
      case SlotOfCharacter s:
        return s.withValue(memory: memory, asm: compareTo);
      case IsOffScreen o:
        return o.withValue(memory: memory, asm: compareTo);
      case BooleanConstant b:
        return b.withValue(memory: memory, asm: compareTo);
      // PositionEquals p => p.withValue(memory: memory, asm: compareTo),
      case PositionExpression p:
        return p.withPosition(
            memory: memory,
            load: a5,
            load2: a6,
            loadX: d2,
            loadY: d3,
            asm: compareTo);
      case DirectionExpression():
      case DoubleExpression():
      case Vector2dExpression():
        throw 'todo: compare($operand2)';
    }
  }
}

Asm Function(Address src, [Address? src2]) _compare(
    ModelExpression operand1, Memory memory, BranchLabels branches) {
  // Compares [src] with [operand1] and sets the CCR.
  // Called below.
  return (Address src, [Address? src2]) {
    var asm = Asm.empty();

    switch (operand1) {
      case PositionComponent c:
        asm.add(
            c.withValue(memory: memory, asm: (dst) => _cmp(src, dst, Size.w)));
        break;
      case PositionComponentOfObject c:
        if (src is OfAddressRegister) {
          asm.add(lea(Address.a(src.register).indirect, a3));
          src = src.withRegister(3);
        }

        asm.add(c.withValue(
            memory: memory, load: a4, asm: (dst) => _cmp(src, dst, Size.w)));

        break;
      case NullSlot():
        asm.add(_cmp(src, 0xFF.i, Size.b));
      case Slot s:
        asm.add(_cmp(src, s.offset.i, Size.b));
        break;
      case SlotOfCharacter s:
        asm.add(s.withValue(
            memory: memory, asm: (slot) => _cmp(src, slot, Size.b)));
        break;
      case RoutineIdOfSlot r:
        asm.add(r.withValue(
            memory: memory, load: d2, asm: (slot) => _cmp(src, slot, Size.w)));
        break;
      case NullObjectRoutineId():
        asm.add(_cmp(src, Word(0).i, Size.w));
        break;
      case IsOffScreen o:
        asm.add(o.withValue(
            memory: memory, asm: (value) => _cmp(src, value, Size.b)));
        break;
      case BooleanConstant b:
        asm.add(b.withValue(
            memory: memory, asm: (value) => _cmp(src, value, Size.b)));
        break;
      case PositionExpression p:
        var x1 = src;
        var y1 = src2;
        if (y1 == null) {
          throw ArgumentError('missing y coordinate to compare to, '
              'x1=$x1 operand1=$operand1');
        }
        asm.add(p.withPosition(
            memory: memory,
            asm: (x2, y2) => Asm([
                  _cmp(x1, x2, Size.w),
                  branches.branchIfNotEqual(),
                  _cmp(y1, y2, Size.w),
                ])));
      case DirectionExpression():
      case OffsetPositionComponent():
      case DoubleExpression():
      case Vector2dExpression():
        throw 'todo: _compare($operand1)';
    }

    return asm;
  };
}

Asm _cmp(Address src, Address dst, Size size, {DirectDataRegister dR = d0}) {
  var width = switch (size) {
    byte => (c) => c.b,
    word => (c) => c.w,
    long => (c) => c.l
  };

  if (src is Immediate) {
    return width(cmpi)(src, dst);
  }

  if (dst is DirectDataRegister) {
    return width(cmp)(src, dst);
  }

  return Asm([
    width(move)(dst, dR),
    width(cmp)(src, dR),
  ]);
}

extension BranchConditionAsm on Comparison {
  BranchMnemonic get mnemonicUnsigned => switch (this) {
        eq => beq,
        gt => bhi,
        lt => bcs,
        neq => bne,
        gte => bcc,
        lte => bls
      };
}

extension SlotOfCharacterExpressionAsm on SlotOfCharacter {
  Asm withValue(
      {required Memory memory, required Asm Function(Address slot) asm}) {
    return Asm([
      moveq(character.charIdAddress, d0),
      jsr(FindCharacterSlot.l),
      asm(d1)
    ]);
  }
}

extension OffScreenExpressionAsm on IsOffScreen {
  Asm withValue(
      {required Memory memory,
      required Asm Function(Address value) asm,
      DirectAddressRegister load = a4}) {
    return Asm([
      object.toA(load, memory),
      asm(offscreen_flag(load)),
    ]);
  }
}

extension BooleanConstantAsm on BooleanConstant {
  Asm withValue(
      {required Memory memory, required Asm Function(Address value) asm}) {
    return asm(value ? 1.i : 0.i);
  }
}

extension RoutineOfSlotAsm on RoutineIdOfSlot {
  Asm withValue(
      {required Memory memory,
      DirectDataRegister load = d2,
      required Asm Function(Address slot) asm}) {
    if (known(memory) case Character c) {
      asm((c.charIdValue.value + 1 * 4).toWord.i);
    }

    return Asm([
      move.w('Character_$slot'.w, load),
      andi.w(0x7fff.i, load),
      asm(load),
    ]);
  }
}

// extension PositionEqualsAsm on PositionEquals {
//   Asm withValue(
//       {required Memory memory, required Asm Function(Address value) asm}) {
//     if (known(memory) case var v?) {
//       return BooleanConstant(v).withValue(memory: memory, asm: asm);
//     }

//     return Asm([
//       this.left.withX(
//           memory: memory,
//           asm: (x1) {
//             return this.right.withX(
//                 memory: memory,
//                 asm: (x2) {
//                   return Asm([_cmp(x1, x2, Size.w), bne.s(neq)]);
//                 });
//           })
//     ]);
//   }
// }
