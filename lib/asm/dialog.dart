import 'dart:math';

import 'package:charcode/ascii.dart';

import 'asm.dart';

final class ControlCodes {
  static const action = Byte.constant(0xf2);
  static final keepNpcFacingDirection = Bytes.list(const [0xF3]);
  static final portrait = Bytes.list(const [0xF4]);
  static final yesNo = Bytes.list(const [0xF5]);
  static final event = Bytes.list(const [0xF6]);
  static final eventBreak = Bytes.list(const [0xF7]); // same as FE
  static final keepDialog = Bytes.list(const [0xF8]);
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

Asm keepDialog() {
  return dc.b(ControlCodes.keepDialog);
}

Asm eventBreak({bool keepDialog = false}) {
  return keepDialog
      ? Asm([dc.b(ControlCodes.keepDialog), dc.b(ControlCodes.eventBreak)])
      : dc.b(ControlCodes.eventBreak);
}

Asm terminateDialog({bool keepDialog = false}) {
  return keepDialog
      ? Asm([dc.b(ControlCodes.keepDialog), dc.b(ControlCodes.terminate)])
      : dc.b(ControlCodes.terminate);
}

Asm interrupt() {
  return dc.b(ControlCodes.interrupt);
}

Asm delay(Byte frames) {
  return dc.b([...ControlCodes.delay, frames]);
}

Asm runEvent(Word index) {
  return Asm([
    dc.b(ControlCodes.event),
    dc.w([index])
  ]);
}

Asm portrait(Byte portrait) {
  return dc.b([...ControlCodes.portrait, portrait]);
}

Asm extendableEventCheck(KnownConstantValue flag, Byte dialogOffset) {
  if (flag.value > Byte.max) {
    return Asm([
      dc.b(ControlCodes.extendedEventCheck),
      dc.w([flag.constant]),
      dc.b([dialogOffset])
    ]);
  } else {
    return eventCheck(flag.constant, dialogOffset);
  }
}

Asm eventCheck(Expression flag, Byte dialogOffset) {
  return Asm([
    dc.b(ControlCodes.eventCheck),
    dc.b([flag, dialogOffset])
  ]);
}

Asm panel(Word panelIndex) {
  return Asm([
    dc.b([ControlCodes.action, Byte.zero]),
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
          asm: Asm([dc.b(split), dc.b(ControlCodes.terminate)])));
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

class CodePoints extends Iterable<List<Asm>?> {
  final List<List<Asm>?> _codePoints;

  CodePoints() : _codePoints = [];
  CodePoints.from(List<List<Asm>?> codePoints) : _codePoints = codePoints;
  const CodePoints.none() : _codePoints = const [];

  @override
  int get length => _codePoints.length;

  List<Asm>? operator [](int index) {
    return _codePoints[index];
  }

  CodePoints sublist(int start, [int? end]) {
    return CodePoints.from(_codePoints.sublist(start, end));
  }

  /// Add an element to the list at [index], growing the [length] of the
  /// `CodePoints` if necessary.
  ///
  /// Initializes an empty list if there is no element at [index].
  void add(int index, Asm codePoint) {
    if (_codePoints.length <= index) {
      _codePoints.length = index + 1;
    }

    if (_codePoints[index] case var list?) {
      list.add(codePoint);
    } else {
      _codePoints[index] = [codePoint];
    }
  }

  @override
  Iterator<List<Asm>?> get iterator => _codePoints.iterator;
}

Asm dialog(Bytes dialog, {CodePoints codePoints = const CodePoints.none()}) {
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
      asm.add(dc.b(ControlCodes.newLine));
    } else if (lineOffset == 0 && dialogLines > 0) {
      asm.add(dc.b(ControlCodes.interrupt));
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
          codes.forEach(asm.add);
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
      codes.forEach(asm.add);
    }
  }

  return asm;
}

bool _isBreakable(int char, Bytes dialog, int index) {
  if (index == 0) return false;

  if (char == $space) {
    return true;
  }

  bool? breakable;

  for (var afterButNotOn in _canBreakAfterButNotOn) {
    if (char == afterButNotOn) return false;
    if (dialog[index - 1].value == afterButNotOn) {
      breakable ??= true;
    }
  }

  return breakable ?? false;
}

const _canBreakAfterButNotOn = [$dash, $dot, $greaterThan];
