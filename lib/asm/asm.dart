import 'data.dart';

export 'data.dart';

/// Data constant
const Dc dc = Dc();
const Move move = Move();

// It looks like this should be limited to 32 bytes per line
class Dc {
  const Dc();

  Asm b(Bytes d) => Asm.fromLine('	dc.b	$d');
  Asm w(Words d) => Asm.fromLine('	dc.w	$d');
  Asm l(Longwords d) => Asm.fromLine('	dc.l	$d');
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
