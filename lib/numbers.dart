extension Hex on String {
  int get hex {
    return int.parse('0x$this');
  }
}
