import 'data.dart';

export 'data.dart';

/// Data constant
const Dc dc = Dc();
const Move move = Move();

class Dc {
  const Dc();

  /// Byte width (dc.b)
  Asm b(Bytes d) => Asm.fromLine('	dc.b	$d');
}

class Move {
  const Move();
}

class AsmError extends ArgumentError {
  AsmError(dynamic value, String message) : super.value(value, message);
}

class Asm {
  final List<String> lines = [];

  Asm.empty();

  Asm.fromLine(String line) {
    addLine(line);
  }

  void add(Asm asm) {
    lines.addAll(asm.lines);
  }

  void addLine(String line) {
    // TODO: max length
    lines.add(line);
  }

  int get length => lines.length;

  @override
  String toString() {
    return lines.join('\n');
  }
}
