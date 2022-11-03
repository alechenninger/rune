/// Utilities for dealing with null
extension MapT<T> on T {
  U map<U>(U Function(T e) mapper) => mapper(this);
}
