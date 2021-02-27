extension ParseCodePoint on int {
  String get utf16 => String.fromCharCode(this);
}

extension CodePoint on String {
  int get codePoint {
    if (runes.length > 1) {
      throw StateError('Expected single character but was "$this"');
    }
    return runes.first;
  }
}
