import 'package:charcode/ascii.dart';

import 'asm.dart';

class _ControlCodes {
  static final portrait = Data.fromByteHex('F4');
  static final newLine = Data.fromByteHex('FC');
  static final cursor = Data.fromByteHex('FD');
  static final endDialog = Data.fromByteHex('FF');
}

// TODO: transforms needs to happen in another layer
// because they go from utf8 to ascii
final _transforms = {
  '‘': '[',
  '’': "'",
  '–': '=',
  '—': '=',
  '…': '...',
};

Asm dialog(Data portrait, Data dialog) {
  dialog = dialog.trim(asciiSpace);

  var asm = Asm.empty();
  var lineStart = 0;
  var breakPoint = 0;
  // var quotes = _Quotes(); TODO: need to swap utf8 at another layer again
  //  I think ... goes with transforms.

  asm.add(dc.b(_ControlCodes.portrait));
  asm.add(dc.b(portrait));

  void append(Data line) {
    var lineOffset = (asm.length - 2) % 4;
    if (lineOffset == 1) {
      asm.add(dc.b(_ControlCodes.newLine));
    } else if (lineOffset == 3) {
      asm.add(dc.b(_ControlCodes.cursor));
    }
    asm.add(dc.b(line));
  }

  for (var i = 0; i < dialog.length; i++) {
    var c = dialog[i];

    if (_isBreakable(c, dialog, i)) {
      breakPoint = i;
    }

    if (i - lineStart == 32) {
      append(dialog.sublist(lineStart, breakPoint));

      // Determine new line start (skip whitespace)
      var skip = dialog.sublist(breakPoint).indexWhere((b) => b != $space);
      // If -1, then means empty or all space;
      lineStart = skip == -1 ? i : breakPoint + skip;
      if (lineStart > i) i = lineStart;
    }
  }

  var remaining = dialog.sublist(lineStart);
  if (remaining.isNotEmpty) {
    append(remaining);
  }

  asm.add(dc.b(_ControlCodes.cursor));

  return asm;
}

bool _isBreakable(int char, Data dialog, int index) {
  if (index == 0) return false;

  if (char == $space) {
    return true;
  }

  for (var canBreakAfter in _canBreakAfterButNotOn) {
    if (char != canBreakAfter && dialog[index - 1] == canBreakAfter) {
      return true;
    }
  }

  return false;
}

class _Quotes {
  var _current = $less_than;
  var _next = $greater_than;

  int next() {
    var q = _current;
    _current = _next;
    _next = q;
    return q;
  }
}

const _canBreakAfterButNotOn = [$dash, $dot];
