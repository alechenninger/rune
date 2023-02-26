import 'dart:math';

import 'package:charcode/ascii.dart';
import 'package:collection/collection.dart';
import 'package:rune/generator/map.dart';

import 'asm.dart';

class _ControlCodes {
  static final action = Byte(0xf2);
  static final keepNpcFacingDirection = Bytes.hex('F3');
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
  static final extendedEventCheck = Bytes.hex('FB');
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

Asm extendableEventCheck(KnownConstantValue flag, Byte dialogOffset) {
  if (flag.value > Byte.max) {
    return Asm([
      dc.b(_ControlCodes.extendedEventCheck),
      dc.w([flag.constant]),
      dc.b([dialogOffset])
    ]);
  } else {
    return eventCheck(flag.constant, dialogOffset);
  }
}

Asm eventCheck(Expression flag, Byte dialogOffset) {
  return Asm([
    dc.b(_ControlCodes.eventCheck),
    dc.b([flag, dialogOffset])
  ]);
}

Asm panel(Word panelIndex) {
  return Asm([
    dc.b([_ControlCodes.action, Byte.zero]),
    dc.w([panelIndex]),
  ]);
}

List<LineAsm> dialogLines(Bytes dialog,
    {int outputWidth = 40,
    int startingColumn = 0,
    Byte dialogIdOffset = Byte.zero}) {
  var lines = List<LineAsm>.empty(growable: true);
  var lineNum = 0;
  var lineStart = 0;
  var breakPoint = -1;

  void append(int start, [int? end]) {
    var line = dialog.sublist(start, end);
    if (line.isEmpty) return;

    // can only express 32 characters per data line
    for (var split in line.split(32)) {
      lines.add(LineAsm(
          dialogId: dialogIdOffset,
          length: split.length,
          outputLineNumber: lineNum,
          asm: Asm([dc.b(split), dc.b(_ControlCodes.terminate)])));
      dialogIdOffset = (dialogIdOffset + 1.toByte) as Byte;
    }

    lineNum++;
  }

  for (var i = 0; i < dialog.length; i++) {
    var char = dialog[i];

    if (_isBreakable(char.value, dialog, i)) {
      breakPoint = i;
    }

    var lineOffset = lineNum == 0 ? startingColumn : 0;
    if (i - lineStart + lineOffset == outputWidth) {
      if (breakPoint == -1) {
        // No breakpoint before hitting end of line.
        // Jump to next line and reset
        lineNum++;
        breakPoint = 0;
        continue;
      }

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

  return lines;
}

class LineAsm {
  Byte dialogId;
  int length;
  int outputLineNumber;
  Asm asm;

  LineAsm(
      {required this.dialogId,
      required this.length,
      required this.outputLineNumber,
      required this.asm});
}

abstract class ControlCode {
  Asm toAsm();
}

class PauseCode extends ControlCode {
  final Byte frames;

  PauseCode(this.frames);

  @override
  Asm toAsm() => delay(frames);
}

class PanelCode extends ControlCode {
  final Word panelIndex;

  PanelCode(this.panelIndex);

  @override
  Asm toAsm() => panel(panelIndex);
}

Asm dialog(Bytes dialog, {List<List<ControlCode>?> codePoints = const []}) {
  if (codePoints.isNotEmpty) {
    var maxCodePoint = codePoints.length - 1;
    if (maxCodePoint > dialog.length) {
      throw ArgumentError.value(maxCodePoint, 'codePoints',
          'all code points must be >= 0 and <= dialog.length');
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
    var lastCodeIndex = 0;
    if (start < codePoints.length) {
      var codesInLine = codePoints.sublist(
          start, min(line.length + start, codePoints.length));
      for (var i = 0; i < codesInLine.length; i++) {
        var codes = codesInLine[i];
        if (codes != null) {
          var indexOfCode = i;
          var beforeCode = line.sublist(lastCodeIndex, indexOfCode);
          if (beforeCode.isNotEmpty) {
            asm.add(dc.b(beforeCode));
          }
          codes.map((c) => c.toAsm()).forEach(asm.add);
          lastCodeIndex = indexOfCode;
        }
      }
    }

    var afterCode = line.sublist(lastCodeIndex);
    if (afterCode.isNotEmpty) {
      asm.add(dc.b(afterCode));
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

  if (codePoints.length > dialog.length) {
    var codes = codePoints[dialog.length];
    if (codes != null) {
      codes.map((c) => c.toAsm()).forEach(asm.add);
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
