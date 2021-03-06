import 'dart:collection';

import 'address.dart';
import 'data.dart';

export 'address.dart';
export 'data.dart';

/// Data constant
const Dc dc = Dc();
const Move move = Move();

Asm lea(Address src, Address dst) => cmd('lea', [src, dst]);
Asm moveq(Address src, Address dst) => cmd('moveq', [src, dst]);
Asm jsr(Address to) => cmd('jsr', [to]);

// It looks like this should be limited to 32 bytes per line
class Dc {
  const Dc();

  Asm b(Bytes d) => cmd('dc.b', [d]);
  Asm w(Words d) => cmd('dc.w', [d]);
  Asm l(Longwords d) => cmd('dc.l', [d]);
}

class Move {
  const Move();

  Asm b(Address from, Address to) => cmd('move.b', [from, to]);
  Asm w(Address from, Address to) => cmd('move.w', [from, to]);
  Asm l(Address from, Address to) => cmd('move.l', [from, to]);
}

class AsmError extends ArgumentError {
  AsmError(dynamic value, String message) : super.value(value, message);
}

class Asm extends IterableBase<Asm> {
  final List<String> lines = [];

  Asm.empty();

  Asm(List<Asm> asm) {
    asm.forEach((a) => add(a));
  }

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

  @override
  int get length => lines.length;

  @override
  String toString() {
    return lines.join('\n');
  }

  @override
  Iterator<Asm> get iterator => lines.map((e) => Asm.fromLine(e)).iterator;
}

Asm setLabel(String label) {
  return Asm.fromLine('$label:');
}

Asm cmd(String cmd, List operands, {String? label}) {
  return Asm.fromLine([
    if (label == null) '' else '$label:',
    cmd,
    operands.join(', ')
  ].join('	'));
}
