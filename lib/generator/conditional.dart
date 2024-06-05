import '../asm/asm.dart';
import '../asm/events.dart';
import '../model/model.dart';
import 'memory.dart';
import 'movement.dart';

class BranchLabels extends Iterable<(Branch, Label?)> {
  final String _prefix;
  final Map<BranchCondition, (Branch, Label)> _labels = {};
  final BranchCondition? emptyBranch;
  late final Branch fallThrough;
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
        ? branches.lastWhere((b) => b.condition.isEqual,
            orElse: () => branches.last)
        : branches.last;

    if (emptyBranch case var b?) {
      _labels[b] = (Branch.empty(b), _continueLbl);
      _continued = true;
    }

    for (var branch in branches) {
      // Fall through branch is not labeled unless necessary
      if (branch.condition == fallThrough.condition) continue;
      _label(branch);
    }
  }

  Label _label(Branch branch) {
    var label = labelFor(branch.condition);
    _labels[branch.condition] = (branch, label);
    return label;
  }

  @override
  Iterator<(Branch, Label?)> get iterator => fallThroughFirst.iterator;

  Iterable<(Branch, Label?)> get fallThroughFirst sync* {
    if (!_labels.containsKey(fallThrough.condition)) {
      yield (fallThrough, null);
    }

    for (var (branch, label) in _labels.values) {
      yield (branch, label);
    }
  }

  bool containsBranch(BranchCondition b) => _labels.containsKey(b);

  Label? get labeledFallThrough => _labels[fallThrough.condition]?.$2;
  Label? get continued => _continued ? _continueLbl : null;
  Label labelContinue() {
    _continued = true;
    return _continueLbl;
  }

  Label labelFor(BranchCondition c) {
    return Label('$_prefix${c.name}');
  }

  operator [](BranchCondition condition) => _labels[condition];

  Iterable<(Branch, Label)> get excludingFallThrough => _labels.entries
      .where((e) => e.key != fallThrough.condition)
      .map((e) => e.value);

  Asm branchIfNotEqual() {
    var asm = Asm.empty();
    for (var (branch, label) in notEqualBranches()) {
      asm.add(branch.condition.mnemonicUnsigned(label));
    }
    if (asm.isEmpty) {
      throw StateError('no branches to jump to');
    }
    return asm;
  }

  /// May label fall through if it is a not-equal branch.
  Iterable<(Branch, Label)> notEqualBranches() sync* {
    if (fallThrough.condition.isNotEqual &&
        !containsBranch(fallThrough.condition)) {
      _label(fallThrough);
    }
    for (var (branch, label) in _labels.values) {
      if (branch.condition.isNotEqual) {
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
      case NotInParty():
        return compareTo(0xFF.i);
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
        return p.withPosition(memory: memory, asm: compareTo);
      case DirectionExpression d:
        throw 'todo';
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
      case NotInParty():
        asm.add(_cmp(src, 0xFF.i, Size.b));
      case Slot s:
        asm.add(_cmp(src, s.offset.i, Size.b));
        break;
      case SlotOfCharacter s:
        asm.add(s.withValue(
            memory: memory, asm: (slot) => _cmp(src, slot, Size.b)));
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
      case DirectionExpression d:
        throw 'todo';
      case OffsetPositionComponent():
        throw 'todo';
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

extension BranchConditionAsm on BranchCondition {
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
