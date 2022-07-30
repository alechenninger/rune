import 'dart:math';

import 'package:collection/collection.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/text.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/scene.dart';
import 'package:rune/model/text.dart';
import 'package:rune/src/iterables.dart';

import '../asm/asm.dart';
import 'dialog.dart';

const _topLeft = 0xffff8000;
const _perLine = 0x180;
const _perLineOffset = 0x80; // _perLine ~/ 3
const _perCharacter = 0x2;
const _perPaletteLine = 0x2000;
const _maxPosition = _topLeft + _perLineOffset * 27; // last you can fit is * 26

SceneAsm displayText(DisplayText display, AsmContext ctx,
    {DialogTree? dialogTree}) {
  var tree = dialogTree ?? DialogTree();
  return _displayText(display, tree, ctx);
}

SceneAsm _displayText(
    DisplayText display, DialogTree dialogTree, AsmContext ctx) {
  // todo: otherwise we assume in dialog loop, in which case we would do similar
  // to scene asm and fork into event mode... however if we're in dialog loop,
  // different asm generator should be called? (e.g. scene)
  if (!ctx.inEvent) {
    throw StateError(
        'asm must be generating event to generate display text asm');
  }

  var newDialogs = <DialogAsm>[];
  // todo: handle hitting max trees!
  var currentDialogId = dialogTree.nextDialogId!,
      dialogIdOffset = currentDialogId;
  var eventAsm = EventAsm.empty();
  var fadeRoutines = EventAsm.empty();

  var column = display.column;

  // first associate all the asm with each Text, regardless of text group
  var textAsmRefs = _generateDialogs(currentDialogId, display, newDialogs);

  // todo: should probably merge the vram stuff into cursor? cursor has to
  //   remember related information anyway
  var planeA = Plane();
  var vramTileRanges = _VramTileRanges();
  var eventCursor = _ColumnEventIterator(column);

  while (!eventCursor.isDone) {
    for (var group in eventCursor.finishedGroups) {
      if (group.loadedSet != null) {
        _clearSet(group, vramTileRanges, eventAsm, textAsmRefs, planeA);
      }
    }

    var currentGroups = eventCursor.currentGroups;

    // setup text or fade routines if necessary
    var lastVint = -1;
    for (var i = 0; i < currentGroups.length; i++) {
      var group = currentGroups[i];

      if (!group.loadedEvent) {
        group.loadedEvent = true;
        var fadeRoutine =
            group.event!.fadeRoutine(groupIndex: group.index, set: group.set!);
        if (fadeRoutine != null) {
          fadeRoutines.add(fadeRoutine);
          fadeRoutines.addNewline();
        }
      }

      if (!group.hidden) {
        if (!group.isCurrentSetLoaded) {
          if (group.isPreviousSetLoaded) {
            _clearSet(group, vramTileRanges, eventAsm, textAsmRefs, planeA);
          }

          group.loadedSet = group.set;

          lastVint = _loadSetText(
                  textAsmRefs, vramTileRanges, group, eventAsm, planeA) ??
              lastVint;
        }
      } else if (group.loadedSet != null) {
        _clearSet(group, vramTileRanges, eventAsm, textAsmRefs, planeA);
      }
    }

    if (planeA.isBufferDirty) {
      if (lastVint > -1) {
        eventAsm.replace(lastVint, planeA.queueDmaUpdate(vIntPrepare: true));
      } else {
        eventAsm.add(planeA.queueDmaUpdate());
        eventAsm.addNewline();
      }
    }

    if (currentGroups.isNotEmpty) {
      // now loop until next event
      // add 1 just in case there is some vint timing issue
      // sometimes certain configurations don't make it to the next key frame
      // in the animation for some reason.
      var frames = eventCursor.timeUntilNextEvent!.toFrames() + 1;
      var loopRoutine = eventCursor.currentLoopRoutine;

      var routine1 = currentGroups[0].event?.fadeRoutineLbl;
      var routine2 = currentGroups.length > 1
          ? currentGroups[1].event?.fadeRoutineLbl
          : null;
      eventAsm.add(Asm([
        if (frames < 128)
          moveq(frames.toByte.i, d0)
        else
          move.l(frames.toLongword.i, d0),
        setLabel(loopRoutine.name),
        // can potentially use bsr
        if (routine1 != null) bsr.w(routine1),
        if (routine2 != null) bsr.w(routine2),
        vIntPrepare(),
        dbf(d0, loopRoutine)
      ]));

      eventAsm.addNewline();

      eventCursor.advanceToNextEvent();
    }
  }

  var done = 'done_${display.hashCode}';
  // todo: would be nice to use bra i guess? but we don't know how much fade
  //   routine ASM we have.
  eventAsm.add(bra.w(done.toLabel));
  eventAsm.addNewline();

  eventAsm.add(fadeRoutines);
  eventAsm.add(setLabel(done));

  return SceneAsm(
      event: eventAsm, dialogIdOffset: dialogIdOffset, dialog: newDialogs);
}

void _clearSet(_GroupCursor group, _VramTileRanges vramTileRanges,
    EventAsm eventAsm, Map<Text, List<TextAsmRef>> textAsmRefs, Plane planeA) {
  var loaded = group.loadedSet;
  if (loaded != null) {
    group.loadedSet = null;

    for (var tile in group.loadedTiles) {
      vramTileRanges.releaseRange(startingAt: tile, forGroup: group.index);
      group.unloadTile(tile);
    }

    eventAsm.add(comment('clear previous text in plane A buffer'));

    for (var text in loaded.texts) {
      for (var asmRef in textAsmRefs[text]!) {
        eventAsm.add(planeA.clear(asmRef));
      }
    }

    eventAsm.addNewline();
  }
}

int? _loadSetText(
    Map<Text, List<TextAsmRef>> textAsmRefs,
    _VramTileRanges vramTileRanges,
    _GroupCursor group,
    EventAsm eventAsm,
    Plane planeA) {
  TextGroupSet set = group.set!;
  int? lastVint;

  // todo: assumes previous set faded out
  if (group.previousSet?.black != set.black) {
    var palette = Palette_Table_Buffer + (0x5e + 0x20 * group.index).toByte;
    var setBlack = set.black == Word(0)
        ? clr.w(palette.w)
        : move.w(set.black.i, palette.w);
    eventAsm.add(setBlack);
    eventAsm.addNewline();
  }

  for (var j = 0; j < set.texts.length; j++) {
    var text = set.texts[j];

    var asmRefs = textAsmRefs[text];
    if (asmRefs == null) {
      throw StateError(
          'no asm refs for text: text=$text, asmRefs=$textAsmRefs');
    }

    for (var asmRef in asmRefs) {
      var tile = vramTileRanges.tileForRange(
          length: asmRef.length, forGroup: group.index);
      group.loadedTile(tile);

      planeA.write(asmRef);

      // todo: parameterize palette row offset?
      var tileNumber = Word(
          _perPaletteLine * (group.index + 2) + _perCharacter * tile + 0x200);

      // each block takes about 0x22 bytes
      eventAsm.add(getDialogueByID(asmRef.dialogId));
      eventAsm.add(runText2(asmRef.position.l, tileNumber.i));
      lastVint = eventAsm.add(vIntPrepare());
      eventAsm.addNewline();
    }
  }

  return lastVint;
}

Map<Text, List<TextAsmRef>> _generateDialogs(
    Byte currentDialogId, DisplayText display, List<DialogAsm> newDialogs) {
  var column = display.column;
  var textAsmRefs = <Text, List<TextAsmRef>>{};
  var cursor = _Cursor();
  var quotes = Quotes();

  for (var text in column.texts) {
    var ascii = text.spans
        .map((s) => s.toAscii(quotes))
        .reduceOr((s1, s2) => s1 + s2, ifEmpty: Bytes.empty());
    var lines = dialogLines(ascii,
        startingColumn: cursor.col, dialogIdOffset: currentDialogId);
    var startLineNumber = cursor.line;

    for (var outputLine
        in lines.groupListsBy((l) => l.outputLineNumber).entries) {
      cursor.line = startLineNumber + outputLine.key;
      var lines = outputLine.value;

      if (column.hAlign != HorizontalAlignment.left) {
        var length = lines
            .map((l) => l.length)
            .reduceOr((l1, l2) => l1 + l2, ifEmpty: 0);
        if (column.hAlign == HorizontalAlignment.center) {
          var leftOffset = (column.width - length) ~/ 2;
          cursor.advanceCharactersWithinLine(leftOffset);
        } else {
          var leftOffset = column.width - length;
          cursor.advanceCharactersWithinLine(leftOffset);
        }
      }

      for (var line in lines) {
        var position = Longword(_topLeft +
            display.lineOffset * _perLineOffset +
            cursor.line * _perLine +
            cursor.col * _perCharacter);

        if (position >= _maxPosition.toValue) {
          throw ArgumentError(
              'text extends past bottom of screen. text="$text"');
        }

        textAsmRefs.putIfAbsent(text, () => []).add(TextAsmRef(
            dialogId: line.dialogId, length: line.length, position: position));

        cursor.advanceCharactersWithinLine(line.length);
        currentDialogId = (line.dialogId + 1.toByte) as Byte;

        newDialogs.add(DialogAsm([line.asm]));
      }
    }

    if (text.lineBreak) {
      cursor.advanceLine();
    }
  }

  return textAsmRefs;
}

class _GroupCursor {
  final int index;
  final TextGroup group;

  Duration lastEventTime = Duration.zero;
  int _setIndex = 0;
  int _eventIndex = 0;

  TextGroupSet? previousSet;
  TextGroupSet? set;
  PaletteEvent? _event;
  PaletteEvent? get event => _event;
  Duration? timeLeftInEvent;

  TextGroupSet? loadedSet;
  bool get isPreviousSetLoaded =>
      previousSet != null && loadedSet == previousSet;
  bool get isCurrentSetLoaded => loadedSet == set;
  bool loadedEvent = false;
  final Set<int> _loadedTiles = {};
  Set<int> get loadedTiles => Set.unmodifiable(_loadedTiles);

  bool hidden = true;

  _GroupCursor(this.index, this.group) {
    set = group.sets.firstOrNull;
    _setEvent(set?.paletteEvents.firstOrNull, Duration.zero);
    timeLeftInEvent = event?.duration;
  }

  void _setEvent(PaletteEvent? event, Duration at) {
    if (event?.state == FadeState.fadeIn) {
      hidden = false;
    }
    if (event?.state == FadeState.wait && _event?.state == FadeState.fadeOut) {
      hidden = true;
    }
    _event = event;
    loadedEvent = false;
    if (event != null) {
      lastEventTime = at;
      timeLeftInEvent = event.duration;
    }
  }

  void loadedTile(int tile) {
    _loadedTiles.add(tile);
  }

  void unloadTile(int tile) {
    _loadedTiles.remove(tile);
  }

  /// returns true if there is still a current event
  bool advanceTo(Duration time) {
    if (event == null) return false;
    var nextEventThreshold = event!.duration + lastEventTime;
    if (nextEventThreshold > time) {
      timeLeftInEvent = nextEventThreshold - time;
      return true;
    }

    if (time > nextEventThreshold) {
      throw ArgumentError('time advanced past next event; timing will be off');
    }

    _eventIndex++;

    var events = set!.paletteEvents;
    if (_eventIndex >= events.length) {
      _setIndex++;
      var sets = group.sets;
      if (_setIndex >= sets.length) {
        previousSet = set;
        set = null;
        _setEvent(null, time);
        return false;
      }
      previousSet = set;
      set = sets[_setIndex];
      events = set!.paletteEvents;
      _eventIndex = 0;
    }

    _setEvent(events[_eventIndex], time);

    return true;
  }
}

class _ColumnEventIterator {
  final TextColumn column;

  var _time = Duration.zero;
  final _groupCursors = <int, _GroupCursor>{};

  _ColumnEventIterator(this.column) {
    var groups = column.groups;
    for (int i = 0; i < groups.length; i++) {
      var group = groups[i];
      _groupCursors[i] = _GroupCursor(i, group);
    }
  }

  _GroupCursor get shortest => currentGroups
      .sorted((a, b) => a.timeLeftInEvent!.compareTo(b.timeLeftInEvent!))
      .first;

  Duration? get timeUntilNextEvent => shortest.timeLeftInEvent;

  Label get currentLoopRoutine =>
      'loop_${column.hashCode}_t${_time.inMilliseconds}'.toLabel;

  bool advanceToNextEvent() {
    _time += timeUntilNextEvent!;

    for (var c in _groupCursors.values) {
      c.advanceTo(_time);
    }

    return !isDone;
  }

  bool get isDone =>
      finishedGroups.where((g) => g.loadedSet == null).length == groups.length;

  Iterable<_GroupCursor> get groups => _groupCursors.values;

  List<_GroupCursor> get finishedGroups =>
      groups.where((group) => group.event == null).toList(growable: false);

  List<_GroupCursor> get currentGroups =>
      groups.where((group) => group.event != null).toList(growable: false);
}

extension _PaletteEventAsm on PaletteEvent {
  Label? get fadeRoutineLbl {
    if (state == FadeState.wait) return null;
    return '${state.name}_$hashCode'.toLabel;
  }

  Asm? fadeRoutine({required int groupIndex, required TextGroupSet set}) {
    if (groupIndex > 1) {
      throw ArgumentError('text must not have more that 2 text groups');
    }

    var lbl = fadeRoutineLbl;
    if (lbl == null) return null;

    var paletteOffset = 0x5e + 0x20 * groupIndex;

    // if there are 8 color values that we fade through
    // e.g. if 16 frame duration
    // we want to spend 2 frames at each color value

    // todo: values must be perfectly divisible by 0x222
    var white = set.white;
    var black = set.black;
    var steps = (white.value - black.value) ~/ 0x222;

    Asm stepTest;
    var framesPerStep = (duration ~/ steps).toFrames();
    var power = log(framesPerStep) / log(2);
    var andBits = (1 << power.round()) - 1;
    if ((framesPerStep / (andBits + 1) - 1).abs() < .2) {
      // close enough to and..?
      stepTest = Asm([
        move.b((Main_Frame_Count + 1.toValue).w, d1),
        andi.w(andBits.toWord.i, d1)
      ]);
    } else {
      stepTest = Asm([
        moveq(0.i, d1),
        move.w((Main_Frame_Count /* + 1.toValue*/).w, d1),
        divu.w(framesPerStep.toWord.i, d1),
        swap(d1),
        tst.w(d1),
      ]);
    }

    // takes about 0x1e bytes
    return Asm([
      setLabel(lbl.name),
      stepTest,
      bne.s('.ret'.toLabel),
      // todo: do we have to load this every loop?
      lea((Palette_Table_Buffer + paletteOffset.toByte).w, a0),
      move.w(a0.indirect, d1),
      if (state == FadeState.fadeIn)
        Asm([
          addi.w(0x222.toWord.i, d1),
          if (white == Word(0xEEE)) ...[
            btst(0xC.i, d1),
            bne.s('.ret'.toLabel)
          ] else ...[
            cmpi.w((white).i, d1),
            // if d1 > white, don't add to
            bpl.s('.ret'.toLabel)
          ],
        ])
      else
        Asm([
          // if we want a non-zero lower bound, can use
          // e.g. cmpi.w(0x666.toWord.i, d1),
          if (black == Word(0)) tst.w(d1) else cmpi.w(black.i, d1),
          beq.s('.ret'.toLabel),
          subi.w(0x222.toWord.i, d1)
        ]),
      move.w(d1, a0.indirect),
      setLabel('.ret'),
      rts,
    ]);
  }
}

class _Cursor {
  var _position = [0, 0];
  var _advanced = 0;
  int get line => _position[0];
  int get col => _position[1];
  int get advanced => _advanced;
  void advanceCharactersWithinLine(int length) {
    _position[1] = _position[1] + length;
    _advanced += length;
  }

  set line(int line) {
    if (line == this.line) return;
    if (line < this.line) {
      throw ArgumentError('line must be >= current line. '
          'line=$line this.line=${this.line}');
    }
    _position = [line, 0];
  }

  void advanceLine() {
    _position = [_position[0] + 1, 0];
  }

  void reset() {
    _position = [0, 0];
    _advanced = 0;
  }
}

class _VramTileRanges {
  /// group, [[0,1],[1,2]]
  // todo: not sure if we really need to track group here
  final _rangesByGroup = <int, List<List<int>>>{};

  // this is about 32 lines i think so plenty?
  static final _maxTiles = 0x800;

  int tileForRange({required int length, required int forGroup}) {
    // todo: if we really just want an entire line each time, this logic
    //   can be greatly simplified i think
    length = 32;

    var start = 0;
    var allRanges = _rangesByGroup.values
        .expand((groupRanges) => groupRanges)
        .sorted((a, b) => a.first.compareTo(b.first));
    for (int i = 0; i < allRanges.length; i++) {
      var range = allRanges[i];

      var nextStart = range[0];
      var gap = nextStart - start;
      if (length <= gap) {
        // make sure there range does not start later on same line
        var line = start ~/ 0x20;
        var nextLine = nextStart ~/ 20;
        if (line != nextLine) {
          break;
        }
      }

      start = range[1];
    }

    if (start + length >= _maxTiles) {
      throw ArgumentError('too many tiles needed');
    }

    var groupRanges = _rangesByGroup.putIfAbsent(forGroup, () => []);
    groupRanges.add([start, start + length]);
    return start;
  }

  void releaseRange({required int startingAt, required int forGroup}) {
    _rangesByGroup[forGroup]!.removeWhere((range) => range.first == startingAt);
  }
}

class TextAsmRef {
  final Byte dialogId;
  final Longword position;
  final int length;

  TextAsmRef(
      {required this.dialogId, required this.position, required this.length});
}

class Plane {
  final _cells = List<TextAsmRef?>.filled(0x1000, null);
  final _texts = <TextAsmRef, int>{};

  var _bufferDirty = false;
  bool get isBufferDirty => _bufferDirty;

  Asm queueDmaUpdate({bool vIntPrepare = false}) {
    _bufferDirty = false;
    if (vIntPrepare) {
      return dmaPlaneAVInt();
    }
    return jsr('DMA_PlaneA'.toLabel.l);
  }

  void write(TextAsmRef text) {
    // we know what text we actually care about
    // vs extra that is mapped
    var cell = text.position.value - _topLeft;

    for (var i = 0; i < 32 * _perCharacter; i++) {
      _cells[cell + i] = text;
    }

    _texts[text] = cell;
    _bufferDirty = true;
  }

  Asm clear(TextAsmRef text) {
    // so when we free some text, we actually want to free whatever that text
    // is mapped to
    // if something else overwrote part of the mapping, it won't get freed
    var asm = Asm.empty();

    var start = _texts.remove(text);
    if (start == null) throw 'text not present';
    int end = start;

    // do 32 characters unless there is vram mapping to other text which
    // overwrote the buffer there
    for (; end < start + 32 * _perCharacter; end++) {
      if (_cells[end] != text) break;
      _cells[end] = null;
    }

    var words = end - start;
    var longwords = words ~/ 2;
    var remainingWords = words % 2;

    for (var lineOffset = 0;
        // not sure why but only 2 lines works and 3 clears too much
        lineOffset < _perLine - _perLineOffset;
        lineOffset += _perLineOffset) {
      if (longwords > 0) {
        asm.add(Asm([
          // why w?
          lea((text.position + lineOffset.toValue).w, a0),
          // trap 0 deletes 1 + argument, but we have the number of
          // longs to delete total, so subtract one.
          move.w((longwords - 1).toWord.i, d7),
          trap(0.i)
        ]));
      }

      if (remainingWords > 0) {
        // only ever 1
        asm.add(Asm([
          // if we deleted any longwords, d0 will already be 0
          if (longwords == 0) moveq(0.i, d0),
          // trap 0 already increments a0 to the next address
          // now we just clear the lower word
          move.w(d0, a0.indirect)
        ]));
      }
    }

    _bufferDirty = true;

    return asm;
  }
}
