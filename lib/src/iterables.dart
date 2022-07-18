extension ReduceOrEmpty<T> on Iterable<T> {
  T reduceOr(T Function(T, T) combine, {required T ifEmpty}) {
    if (isEmpty) return ifEmpty;
    return reduce(combine);
  }
}
