import 'package:collection/collection.dart';

import 'asm.dart';

abstract class JumpTable<S extends SizedValue> {
  factory JumpTable(
          {required Jump<Label> jump,
          required S Function(int index) newIndex,
          List<Label> labels = const []}) =>
      _JumpTable<S>(jump: jump, newIndex: newIndex, labels: labels);

  factory JumpTable.sparse(
          {required Jump<Label?> jump,
          required S Function(int index) newIndex,
          List<Label?> labels = const []}) =>
      _SparseJumpTable<S>(jump: jump, newIndex: newIndex, labels: labels);

  Label? labelAtIndex(int index);
  Label? labelAt(S index);
  S? operator [](Label name);
  S add(Label name);
  Asm toAsm({bool comment = true});
}

abstract class _AbstractJumpTable<T extends Label?, S extends SizedValue>
    implements JumpTable<S> {
  final Jump<T> _jump;
  final S Function(int) _newIndex;
  final _labels = <T>[];

  _AbstractJumpTable(
      {required Jump<T> jump,
      required S Function(int index) newIndex,
      List<T> labels = const []})
      : _jump = jump,
        _newIndex = newIndex {
    _labels.addAll(labels);
  }

  @override
  T labelAtIndex(int index) => _labels[index];

  @override
  T labelAt(S index) => labelAtIndex(index.value);

  @override
  S? operator [](Label name) {
    return switch (_labels.indexWhere((l) => l == name)) {
      var i when i != -1 => _newIndex(i),
      _ => null
    };
  }

  @override
  Asm toAsm({bool comment = true}) => _labels
      .mapIndexed(
          (i, e) => _jump(e, comment: comment ? _newIndex(i).toString() : null))
      .reduce((asm, r) => asm..add(r));
}

class _SparseJumpTable<S extends SizedValue>
    extends _AbstractJumpTable<Label?, S> {
  _SparseJumpTable(
      {required super.jump, required super.newIndex, super.labels = const []});

  @override
  S? operator [](Label? name) {
    return switch (_labels.indexOf(name)) {
      var i when i != -1 => _newIndex(i),
      _ => null
    };
  }

  @override
  S add(Label name) {
    var i = this[name];
    if (i != null) return i;

    switch (this[null]) {
      case S s:
        _labels[s.value] = name;
        return s;
      default:
        _labels.add(name);
        return _newIndex(_labels.length - 1);
    }
  }
}

class _JumpTable<S extends SizedValue> extends _AbstractJumpTable<Label, S> {
  _JumpTable(
      {required super.jump, required super.newIndex, super.labels = const []});

  @override
  S add(Label name) {
    _labels.add(name);
    return _newIndex(_labels.length - 1);
  }
}

typedef Jump<T extends Label?> = Asm Function(T, {String? comment});

Jump<Label?> withNoop(Label noop, Jump<Label> jump) =>
    (Label? label, {String? comment}) => jump(label ?? noop, comment: comment);
