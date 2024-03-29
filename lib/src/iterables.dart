extension OnIterable<T> on Iterable<T> {
  T reduceOr(T Function(T, T) combine, {required T ifEmpty}) {
    if (isEmpty) return ifEmpty;
    return reduce(combine);
  }

  T? reduceOrNull(T Function(T, T) combine) {
    if (isEmpty) return null;
    return reduce(combine);
  }
}

extension OnIterableOfComparable<E extends Comparable> on Iterable<E> {
  E max({E? ifEmpty}) {
    if (ifEmpty != null) {
      return reduceOr(greater, ifEmpty: ifEmpty);
    }
    return reduce(greater);
  }
}

T greater<T extends Comparable>(T value, T element) {
  return value.compareTo(element) > 0 ? value : element;
}

T sum<T extends num>(T a, T b) => a + b as T;

String toIndentedString(Iterable<Object> o, String indent) => o
    .map((e) => '$e'.split('\n').map((l) => '$indent$l').join('\n'))
    .join('\n');
