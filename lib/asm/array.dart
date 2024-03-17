import 'package:collection/collection.dart';

import 'asm.dart';

class Array<T extends Expression> extends Iterable<T> {
  final List<T> _data;
  final Size elementSize;

  Array.empty(this.elementSize) : _data = [];

  Array.from(Array<T> other)
      : _data = List.of(other._data),
        elementSize = other.elementSize;

  Array.fromIterable(this.elementSize, Iterable<T> data)
      : _data = data.toList();

  const Array.of(this.elementSize, this._data);

  Asm toAsm({bool comment = true}) => _data
      .mapIndexed(
          (i, e) => dc.size(elementSize, [e], comment: Word(i).toString()))
      .reduce((a, b) => a..add(b));

  T operator [](int index) {
    return _data[index];
  }

  void operator []=(int index, T value) {
    _data[index] = value;
  }

  @override
  int get length => _data.length;

  void add(T value) {
    _data.add(value);
  }

  void addAll(Iterable<T> routines) {
    _data.addAll(routines);
  }

  int indexOf(T element) {
    return _data.indexOf(element);
  }

  @override
  Iterator<T> get iterator => _data.iterator;

  @override
  String toString() {
    return 'Array{elementSize: $elementSize, data: $_data}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Array &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(_data, other._data) &&
          elementSize == other.elementSize;

  @override
  int get hashCode => const ListEquality().hash(_data) ^ elementSize.hashCode;
}

class EventPointers {
  final Word _offset;
  final Array<Label> _routines;

  EventPointers(Iterable<Label> routines,
      {Word offset = const Word.constant(0)})
      : _routines = Array.empty(Size.l),
        _offset = offset {
    _routines.addAll(routines);
  }

  EventPointers.empty({Word offset = const Word.constant(0)})
      : _routines = Array.empty(Size.l),
        _offset = offset;

  Word? offsetFor(Label routine) {
    var index = _routines.indexOf(routine);
    if (index == -1) return null;
    return (index + _offset.value).toWord;
  }

  Word add(Label routine) {
    if (offsetFor(routine) case var index?) return index;
    _routines.add(routine);
    return (_routines.length - 1 + _offset.value).toWord;
  }

  Asm toAsm() => _routines.toAsm();

  Word get nextIndex => Word(_routines.length + 1);
}
