import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/check.dart';

import '../asm/dialog.dart';
import '../asm/text.dart';
import '../model/text.dart';
import '../src/iterables.dart';
import 'dialog.dart';
import 'event.dart';
import 'generator.dart';
import 'labels.dart';

const _planeABuffer = 0xffff8000;
const _perLine = 0x180;
const _perLineOffset = 0x80; // _perLine ~/ 3
const _perCharacter = 0x2;
const _perPaletteLine = 0x2000;
const _maxPosition =
    _planeABuffer + _perLineOffset * 27; // last you can fit is * 26

SceneAsm displayTextToAsm(DisplayText display, DialogTree dialogTree,
    {Labeller? labeller}) {
  var newDialogs = <DialogAsm>[];
  // todo: handle hitting max trees!
  var currentDialogId = dialogTree.nextDialogId!;
  var eventAsm = EventAsm.empty();
  var eventRoutines = EventAsm.empty();
  labeller ??= Labeller();

  var column = display.column;

  // first associate all the asm with each Text, regardless of text group
  // TODO: position at start of line
  // TODO: use position as offset within plane A buffer instead of absolute RAM addr
  var textAsmRefs = _generateDialogs(currentDialogId, display, newDialogs);
  newDialogs.forEach(dialogTree.add);

  // todo: should probably merge the vram stuff into cursor? cursor has to
  //   remember related information anyway
  var planeA = Plane();
  var vramTileRanges = _VramTileRanges();
  var eventCursor = _ColumnEventCursor(column, labeller);

  while (!eventCursor.isDone) {
    for (var group in eventCursor.finishedGroups) {
      if (group.loadedBlock != null) {
        _clearBlock(group, vramTileRanges, eventAsm, textAsmRefs, planeA);
      }
    }

    var currentGroups = eventCursor.unfinishedGroups;

    // setup text or fade routines if necessary
    var lastVint = -1;
    for (var i = 0; i < currentGroups.length; i++) {
      var group = currentGroups[i];

      if (!group.generatedEvent) {
        group.generatedEvent = true;
        // todo: often due to symmetry desired in design, these fade routines
        //   end up being the same, creating a lot of redundant code.
        //   especially if we parameterize the palette address
        var eventRoutine = group.eventRoutine();
        if (eventRoutine != null) {
          eventRoutines.add(eventRoutine);
          eventRoutines.addNewline();
        }
      }

      if (!group.hidden) {
        if (!group.isCurrentBlockLoaded) {
          if (group.isPreviousBlockLoaded) {
            _clearBlock(group, vramTileRanges, eventAsm, textAsmRefs, planeA);
          }

          group.loadedBlock = group.block;

          lastVint = _loadTextBlock(
                  textAsmRefs, vramTileRanges, group, eventAsm, planeA) ??
              lastVint;
        }
      } else if (group.loadedBlock != null) {
        _clearBlock(group, vramTileRanges, eventAsm, textAsmRefs, planeA);
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

      // We are limited to only two groups event routines simultaneously
      // currently. Due to only wanting to use two palette lines?
      var routine1 = currentGroups[0].fadeRoutineLbl;
      var routine2 =
          currentGroups.length > 1 ? currentGroups[1].fadeRoutineLbl : null;
      eventAsm.add(Asm([
        if (frames < 128)
          moveq(frames.toByte.i, d0)
        else
          move.l(frames.toLongword.i, d0),
        setLabel(loopRoutine.name),
        // TODO: could write a macro that determines whether to use bsr or jsr
        if (routine1 != null) bsr(routine1),
        if (routine2 != null) bsr(routine2),
        vIntPrepare(),
        dbf(d0, loopRoutine)
      ]));

      eventAsm.addNewline();

      eventCursor.advanceToNextEvent();
    }
  }

  var done = labeller.withContext('done').nextLocal();
  // todo: would be nice to use bra i guess? but we don't know how much fade
  //   routine ASM we have.
  eventAsm.add(bra(done));
  eventAsm.addNewline();

  eventAsm.add(eventRoutines);
  eventAsm.add(setLabel(done.name));
  return SceneAsm(event: eventAsm);
}

void _clearBlock(_GroupCursor group, _VramTileRanges vramTileRanges,
    EventAsm eventAsm, Map<Text, List<TextAsmRef>> textAsmRefs, Plane planeA) {
  var loaded = group.loadedBlock;
  if (loaded != null) {
    group.loadedBlock = null;

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

int? _loadTextBlock(
    Map<Text, List<TextAsmRef>> textAsmRefs,
    _VramTileRanges vramTileRanges,
    _GroupCursor group,
    EventAsm eventAsm,
    Plane planeA) {
  TextBlock block = group.block!;
  int? lastVint;

  // todo: assumes previous set faded out
  if (group.previousBlock?.black != block.black) {
    var palette = Palette_Table_Buffer + (0x5e + 0x20 * group.index).toByte;
    var setBlack = block.black == Word(0)
        ? clr.w(palette.w)
        : move.w(block.black.i, palette.w);
    eventAsm.add(setBlack);
    eventAsm.addNewline();
  }

  for (var j = 0; j < block.texts.length; j++) {
    var text = block.texts[j];

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
      var tileMapping = Word(
          _perPaletteLine * (group.index + 2) + _perCharacter * tile + 0x200);

      // each block takes about 0x22 bytes
      eventAsm.add(getDialogueByID(asmRef.dialogId));
      eventAsm.add(runText2(asmRef.position.l, tileMapping.i));
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
  var layout = _ColumnLayout();
  var quotes = Quotes();

  for (var text in column.texts) {
    var ascii = text.spans
        .map((s) => s.toAscii(quotes))
        .reduceOr((s1, s2) => s1 + s2, ifEmpty: Bytes.empty());
    var lines = dialogLines(ascii,
        startingColumn: layout.col, dialogIdOffset: currentDialogId);

    var startLineNumber = layout.line;

    for (var outputLine
        in lines.groupListsBy((l) => l.outputLineNumber).entries) {
      layout.line = startLineNumber + outputLine.key;
      var lines = outputLine.value;

      if (column.hAlign != HorizontalAlignment.left) {
        var length = lines
            .map((l) => l.length)
            .reduceOr((l1, l2) => l1 + l2, ifEmpty: 0);
        if (column.hAlign == HorizontalAlignment.center) {
          var leftOffset = (column.width - length) ~/ 2;
          layout.advanceCharactersWithinLine(leftOffset);
        } else {
          var leftOffset = column.width - length;
          layout.advanceCharactersWithinLine(leftOffset);
        }
      }

      for (var line in lines) {
        layout.place(line, text);
        currentDialogId = (line.dialogId + 1.toByte) as Byte;
        newDialogs.add(DialogAsm([line.asm]));
      }
    }

    if (text.lineBreak) {
      layout.advanceLine();
    }
  }

  var alignedLineOffset = display.lineOffset;
  if (column.vAlign != VerticalAlignment.top) {
    var totalLines = layout.line + (layout.col == 0 ? 0 : 1);
    var maxOffsets = (_maxPosition -
            (_planeABuffer + display.lineOffset * _perLineOffset)) ~/
        _perLineOffset;
    var heightInOffsets = totalLines * (_perLine ~/ _perLineOffset);
    if (column.vAlign == VerticalAlignment.center) {
      alignedLineOffset += (maxOffsets - heightInOffsets) ~/ 2;
    } else {
      alignedLineOffset += maxOffsets - heightInOffsets;
    }
  }

  for (var placement in layout.placements) {
    var position = Longword(_planeABuffer +
        alignedLineOffset * _perLineOffset +
        placement.line * _perLine +
        placement.col * _perCharacter);

    var text = placement.text;
    var asm = placement.asm;

    if (position >= _maxPosition.toValue) {
      throw ArgumentError('text extends past bottom of screen. text="$text"');
    }

    textAsmRefs.putIfAbsent(text, () => []).add(TextAsmRef(
        dialogId: asm.dialogId, length: asm.length, position: position));
  }

  return textAsmRefs;
}

class _GroupCursor {
  final int index;
  final TextGroup group;
  final Labeller labeller;

  Duration lastEventTime = Duration.zero;
  int _blockIndex = 0;
  int _eventIndex = 0;

  TextBlock? previousBlock;
  TextBlock? block;
  PaletteEvent? _event;
  PaletteEvent? get event => _event;
  Duration? timeLeftInEvent;

  TextBlock? loadedBlock;
  bool get isPreviousBlockLoaded =>
      previousBlock != null && loadedBlock == previousBlock;
  bool get isCurrentBlockLoaded => loadedBlock == block;
  bool generatedEvent = false;
  final Set<int> _loadedTiles = {};
  Set<int> get loadedTiles => Set.unmodifiable(_loadedTiles);

  bool hidden = true;

  _GroupCursor(this.index, this.group, Labeller labeller)
      : labeller = labeller.withContext('group$index') {
    block = group.blocks.firstOrNull;
    _setEvent(block?.paletteEvents.firstOrNull, Duration.zero);
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
    generatedEvent = false;
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

  Label? get fadeRoutineLbl {
    switch (_event?.state) {
      case null || FadeState.wait:
        return null;
      default:
        return labeller
            .withContext('block$_blockIndex')
            .withContext('event$_eventIndex')
            .nextLocal();
    }
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

    var events = block!.paletteEvents;
    if (_eventIndex >= events.length) {
      _blockIndex++;
      var blocks = group.blocks;
      if (_blockIndex >= blocks.length) {
        previousBlock = block;
        block = null;
        _setEvent(null, time);
        return false;
      }
      previousBlock = block;
      block = blocks[_blockIndex];
      events = block!.paletteEvents;
      _eventIndex = 0;
    }

    _setEvent(events[_eventIndex], time);

    return true;
  }

  Asm? eventRoutine() {
    // check there is an event and a block
    checkState(index <= 1,
        message: 'text must not have more that 2 text groups');
    checkState(block != null, message: 'block must not be null');
    checkState(event != null, message: 'event must not be null');

    var lbl = fadeRoutineLbl;

    // No fade routine for this event
    if (lbl == null) return null;

    return event!.fadeRoutine(lbl: lbl, groupIndex: index, block: block!);
  }
}

class _ColumnEventCursor {
  final TextColumn column;
  final Labeller _labeller;

  var _time = Duration.zero;
  final _groupCursors = <int, _GroupCursor>{};

  _ColumnEventCursor(this.column, this._labeller) {
    var groups = column.groups;
    for (int i = 0; i < groups.length; i++) {
      var group = groups[i];
      _groupCursors[i] = _GroupCursor(i, group, _labeller);
    }
  }

  _GroupCursor get shortest => unfinishedGroups
      .sorted((a, b) => a.timeLeftInEvent!.compareTo(b.timeLeftInEvent!))
      .first;

  Duration? get timeUntilNextEvent => shortest.timeLeftInEvent;

  Label get currentLoopRoutine =>
      // 'loop_${column.hashCode}_t${_time.inMilliseconds}'.toLabel;
      _labeller
          .withContext('fadeloop')
          .withContext('t${_time.inMilliseconds}')
          .nextLocal();

  bool advanceToNextEvent() {
    _time += timeUntilNextEvent!;

    for (var c in _groupCursors.values) {
      c.advanceTo(_time);
    }

    return !isDone;
  }

  bool get isDone =>
      finishedGroups.where((g) => g.loadedBlock == null).length ==
      groups.length;

  Iterable<_GroupCursor> get groups => _groupCursors.values;

  List<_GroupCursor> get finishedGroups =>
      groups.where((group) => group.event == null).toList(growable: false);

  List<_GroupCursor> get unfinishedGroups =>
      groups.where((group) => group.event != null).toList(growable: false);
}

extension _PaletteEventAsm on PaletteEvent {
  Asm? fadeRoutine(
      {required Label lbl, required int groupIndex, required TextBlock block}) {
    checkArgument(groupIndex <= 1,
        message: 'text must not have more that 2 text groups');

    // todo: fade routines with the same parameters produce the same code
    //   we should reuse them.
    // we can even do this across text events if we push this into global
    // context.

    var paletteOffset = 0x5e + 0x20 * groupIndex;

    // if there are 8 color values that we fade through
    // e.g. if 16 frame duration
    // we want to spend 2 frames at each color value

    // todo: values must be perfectly divisible by 0x222
    var white = block.white;
    var black = block.black;
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

    var returnLbl = lbl.withSuffix('_ret');

    // takes about 0x1e bytes
    return Asm([
      setLabel(lbl.name),
      stepTest,
      bne.s(returnLbl),
      // todo: do we have to load this every loop?
      lea((Palette_Table_Buffer + paletteOffset.toByte).w, a0),
      move.w(a0.indirect, d1),
      if (state == FadeState.fadeIn)
        Asm([
          addi.w(0x222.toWord.i, d1),
          if (white == Word(0xEEE)) ...[
            btst(0xC.i, d1),
            bne.s(returnLbl)
          ] else ...[
            cmpi.w((white).i, d1),
            // if d1 > white, don't add to
            bpl.s(returnLbl)
          ],
        ])
      else
        Asm([
          // if we want a non-zero lower bound, can use
          // e.g. cmpi.w(0x666.toWord.i, d1),
          if (black == Word(0)) tst.w(d1) else cmpi.w(black.i, d1),
          beq.s(returnLbl),
          subi.w(0x222.toWord.i, d1)
        ]),
      move.w(d1, a0.indirect),
      setLabel(returnLbl.name),
      rts,
    ]);
  }
}

class _ColumnLayout {
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

  final _placements = <_Placement>[];
  List<_Placement> get placements => _placements;

  void place(LineAsm asm, Text text) {
    _placements.add(_Placement(line: line, col: col, text: text, asm: asm));
    advanceCharactersWithinLine(asm.length);
  }
}

class _Placement {
  final int line;
  final int col;
  final Text text;
  final LineAsm asm;

  _Placement(
      {required this.line,
      required this.col,
      required this.text,
      required this.asm});
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
    var cell = text.position.value - _planeABuffer;

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
