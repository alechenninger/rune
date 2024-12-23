/// Utilities for dealing with null
extension MapT<T> on T {
  U map<U>(U Function(T e) mapper) => mapper(this);
}

T requireNonNull<T>(T? value, [String? name]) {
  if (value == null) {
    throw ArgumentError.notNull(name);
  }
  return value;
}
