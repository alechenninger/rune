import 'package:charcode/ascii.dart';

import 'asm.dart';

class _ControlCodes {
  static final portrait = Bytes.hex('F4');
  static final newLine = Bytes.hex('FC');
  static final cursor = Bytes.hex('FD');
  static final endDialog = Bytes.hex('FF');
  static final event = Bytes.hex('F7'); // same as FE
}

Asm eventBreak() {
  return dc.b(_ControlCodes.event);
}

Asm endDialog() {
  return dc.b(_ControlCodes.endDialog);
}

Asm cursor() {
  return dc.b(_ControlCodes.cursor);
}

Asm dialog(Bytes portrait, Bytes dialog) {
  dialog = dialog.trim($space);

  var asm = Asm.empty();
  var lineStart = 0;
  var breakPoint = 0;

  asm.add(dc.b(_ControlCodes.portrait));
  asm.add(dc.b(portrait));

  void append(Bytes line) {
    var lineOffset = (asm.length - 2) % 4;
    if (lineOffset == 1) {
      asm.add(dc.b(_ControlCodes.newLine));
    } else if (lineOffset == 3) {
      asm.add(dc.b(_ControlCodes.cursor));
    }
    asm.add(dc.b(line));
  }

  for (var i = 0; i < dialog.length; i++) {
    var char = dialog[i];

    if (_isBreakable(char.value, dialog, i)) {
      breakPoint = i;
    }

    if (i - lineStart == 32) {
      append(dialog.sublist(lineStart, breakPoint));

      // Determine new line start (skip whitespace)
      var skip =
          dialog.sublist(breakPoint).indexWhere((b) => b.value != $space);
      // If -1, then means empty or all space;
      lineStart = skip == -1 ? i : breakPoint + skip;
      if (lineStart > i) i = lineStart;
    }
  }

  var remaining = dialog.sublist(lineStart);
  if (remaining.isNotEmpty) {
    append(remaining);
  }

  return asm;
}

bool _isBreakable(int char, Bytes dialog, int index) {
  if (index == 0) return false;

  if (char == $space) {
    return true;
  }

  for (var canBreakAfter in _canBreakAfterButNotOn) {
    if (char != canBreakAfter && dialog[index - 1].value == canBreakAfter) {
      return true;
    }
  }

  return false;
}

const _canBreakAfterButNotOn = [$dash, $dot];
