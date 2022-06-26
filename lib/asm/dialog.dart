import 'dart:math';

import 'package:charcode/ascii.dart';
import 'package:collection/collection.dart';
import 'package:rune/generator/map.dart';

import 'asm.dart';

class _ControlCodes {
  static final action = Bytes.hex('F2');
  static final keepNpcFacingDirection = Bytes.hex('F3'); // ?
  static final portrait = Bytes.hex('F4');
  static final yesNo = Bytes.hex('F5');
  static final event = Bytes.hex('F6');
  static final eventBreak = Bytes.hex('F7'); // same as FE
  /*
TextCtrlCode_Delay:
	moveq	#0, d7
	move.b	(a0)+, d7
	subq.b	#1, d7
loc_6A39E:
	jsr	(DMAPlane_A_VInt).l
	dbf	d7, loc_6A39E
	bra.w	RunText_CharacterLoop
   */
  static final delay = Bytes.hex('F9');
  static final eventCheck = Bytes.hex('FA');
  static final newLine = Bytes.hex('FC');
  static final interrupt = Bytes.hex('FD');
  static final terminate = Bytes.hex('FF');
}

Asm eventBreak() {
  return dc.b(_ControlCodes.eventBreak);
}

Asm terminateDialog() {
  return dc.b(_ControlCodes.terminate);
}

Asm interrupt() {
  return dc.b(_ControlCodes.interrupt);
}

Asm delay(Byte frames) {
  return dc.b([..._ControlCodes.delay, frames]);
}

Asm runEvent(Word index) {
  return Asm([
    dc.b(_ControlCodes.event),
    dc.w([index])
  ]);
}

Asm portrait(Byte portrait) {
  return dc.b([..._ControlCodes.portrait, portrait]);
}

Asm dialog(Bytes dialog, [List<Byte?> pausePoints = const []]) {
  if (pausePoints.isNotEmpty) {
    var maxPausePoint = pausePoints.length - 1;
    if (maxPausePoint > dialog.length) {
      throw ArgumentError.value(maxPausePoint, 'pausePoints',
          'all pause points must be >= 0 and <= dialog.length');
    }
  }

  var asm = Asm.empty();
  var dialogLines = 0;
  var lineStart = 0;
  var breakPoint = 0;

  void append(int start, [int? end]) {
    var line = dialog.sublist(start, end);
    if (line.isEmpty) return;

    // 2 lines per window.
    var lineOffset = (dialogLines) % 2;
    if (lineOffset == 1) {
      asm.add(dc.b(_ControlCodes.newLine));
    } else if (lineOffset == 0 && dialogLines > 0) {
      asm.add(dc.b(_ControlCodes.interrupt));
    }

    // split line bytes up where there are pauses
    var lastPauseChar = 0;
    if (start < pausePoints.length) {
      var pausesInLine = pausePoints.sublist(
          start, min(line.length + start, pausePoints.length));
      for (var i = 0; i < pausesInLine.length; i++) {
        var pause = pausesInLine[i];
        if (pause != null) {
          var charOfPause = i;
          var beforePause = line.sublist(lastPauseChar, charOfPause);
          if (beforePause.isNotEmpty) {
            asm.add(dc.b(beforePause));
          }
          asm.add(delay(pause));
          lastPauseChar = charOfPause;
        }
      }
    }

    var afterPause = line.sublist(lastPauseChar);
    if (afterPause.isNotEmpty) {
      asm.add(dc.b(afterPause));
    }

    dialogLines++;
  }

  for (var i = 0; i < dialog.length; i++) {
    var char = dialog[i];

    if (_isBreakable(char.value, dialog, i)) {
      breakPoint = i;
    }

    if (i - lineStart == 32) {
      append(lineStart, breakPoint);

      // Determine new line start (skip whitespace)
      var skip =
          dialog.sublist(breakPoint).indexWhere((b) => b.value != $space);
      // If -1, then means empty or all space;
      lineStart = skip == -1 ? i : breakPoint + skip;
      if (lineStart > i) i = lineStart;
    }
  }

  append(lineStart);

  if (pausePoints.length > dialog.length) {
    var frames = pausePoints[dialog.length];
    if (frames != null) {
      asm.add(delay(frames));
    }
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
