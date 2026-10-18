import 'package:collection/collection.dart';

import 'asm.dart';

abstract class JumpTable<S extends SizedValue> {
  /// [capacity] is the maximum number of slots, including seeded entries.
  factory JumpTable(
          {required Jump<Label> jump,
          required S Function(int index) newIndex,
          required int capacity,
          List<Label> labels = const []}) =>
      _JumpTable<S>(
          jump: jump, newIndex: newIndex, capacity: capacity, labels: labels);

  /// Seeded unused slots count toward [capacity] and remain reusable when full.
  factory JumpTable.sparse(
          {required Jump<Label?> jump,
          required S Function(int index) newIndex,
          required int capacity,
          List<Label?> labels = const []}) =>
      _SparseJumpTable<S>(
          jump: jump, newIndex: newIndex, capacity: capacity, labels: labels);

  /// Returns null for an unused slot or an index beyond the table.
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
  final int _capacity;
  final _labels = <T>[];

  _AbstractJumpTable(
      {required Jump<T> jump,
      required S Function(int index) newIndex,
      required int capacity,
      List<T> labels = const []})
      : _jump = jump,
        _newIndex = newIndex,
        _capacity = RangeError.checkNotNegative(capacity, 'capacity') {
    if (labels.length > _capacity) {
      throw ArgumentError.value(labels.length, 'labels.length',
          'exceeds jump table capacity of $_capacity');
    }
    _labels.addAll(labels);
  }

  S _append(T name) {
    if (_labels.length >= _capacity) {
      throw StateError('jump table capacity of $_capacity exceeded');
    }
    final index = _newIndex(_labels.length);
    _labels.add(name);
    return index;
  }

  @override
  T? labelAtIndex(int index) => _labels.elementAtOrNull(index);

  @override
  T? labelAt(S index) => labelAtIndex(index.value);

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
      {required super.jump,
      required super.newIndex,
      required super.capacity,
      super.labels = const []});

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
        return _append(name);
    }
  }
}

class _JumpTable<S extends SizedValue> extends _AbstractJumpTable<Label, S> {
  _JumpTable(
      {required super.jump,
      required super.newIndex,
      required super.capacity,
      super.labels = const []});

  @override
  S add(Label name) => _append(name);
}

typedef Jump<T extends Label?> = Asm Function(T, {String? comment});

Jump<Label?> withNoop(Label noop, Jump<Label> jump) =>
    (Label? label, {String? comment}) => jump(label ?? noop, comment: comment);
