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

SceneAsm dislayText(DisplayText display, AsmContext ctx,
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
  var textAsmRefs = generateDialogs(currentDialogId, display, newDialogs);

  var vramTileRanges = _VramTileRanges();
  var eventCursor = _ColumnEventIterator(column);

  while (!eventCursor.isDone) {
    // only 2 simultaneous are supported for now
    // to do more would have to figure out how to use more palette cells for
    // text

    var currentGroups = eventCursor.currentGroups;

    // setup text or fade routines if necessary
    for (var i = 0; i < currentGroups.length; i++) {
      var group = currentGroups[i];
      var event = group.event!;
      var groupIndex = group.index;

      if (!group.loadedEvent) {
        group.loadedEvent = true;
        var fadeRoutine = event.fadeRoutine(groupIndex: groupIndex);
        if (fadeRoutine != null) {
          fadeRoutines.add(fadeRoutine);
          fadeRoutines.addNewline();
        }
      }

      if (!group.loadedSet) {
        group.loadedSet = true;

        for (var tile in group.loadedTiles) {
          vramTileRanges.releaseRange(startingAt: tile, forGroup: groupIndex);
          group.unloadTile(tile);
        }

        var set = group.set!;
        for (var j = 0; j < set.texts.length; j++) {
          var text = set.texts[j];

          var asmRefs = textAsmRefs[text];
          if (asmRefs == null) {
            throw StateError(
                'no asm refs for text: text=$text, asmRefs=$textAsmRefs');
          }
          // each text has position
          for (var asmRef in asmRefs) {
            var tile = vramTileRanges.tileForRange(
                length: asmRef.length, forGroup: groupIndex);
            group.loadedTile(tile);

            // todo: parameterize palette row offset?
            var tileNumber = Word(_perPaletteLine * (groupIndex + 2) +
                _perCharacter * tile +
                0x200);

            // each dialog has a length and id
            eventAsm.add(getDialogueByID(asmRef.dialogId));
            eventAsm.add(runText2(asmRef.position.l, tileNumber.i));
            if (i + 1 == currentGroups.length && j + 1 == set.texts.length) {
              eventAsm.add(dmaPlaneAVInt());
            } else {
              eventAsm.add(vIntPrepare());
            }
            eventAsm.addNewline();
          }
        }
      }
    }

    // now loop until next event
    var frames = eventCursor.timeUntilNextEvent!.toFrames();
    var loopRoutine = eventCursor.currentLoopRoutine;

    var routine1 = currentGroups[0].event?.fadeRoutineLbl;
    var routine2 = currentGroups.length > 1
        ? currentGroups[1].event?.fadeRoutineLbl
        : null;
    eventAsm.add(Asm([
      moveq(frames.toByte.i, d0),
      setLabel(loopRoutine.name),
      // can potentially use bsr
      if (routine1 != null) jsr(routine1.l),
      if (routine2 != null) jsr(routine2.l),
      vIntPrepare(),
      dbf(d0, loopRoutine)
    ]));

    eventAsm.addNewline();

    eventCursor.advanceToNextEvent();
  }

  var done = 'done_${display.hashCode}';
  // todo: would be nice to use bra i guess? but we don't know how much fade
  //   routine ASM we have.
  eventAsm.add(jmp(done.toLabel.l));
  eventAsm.addNewline();

  eventAsm.add(fadeRoutines);
  eventAsm.add(setLabel(done));

  return SceneAsm(
      event: eventAsm, dialogIdOffset: dialogIdOffset, dialog: newDialogs);
}

Map<Text, List<TextAsmRef>> generateDialogs(
    Byte currentDialogId, DisplayText display, List<DialogAsm> newDialogs) {
  var column = display.column;
  var textAsmRefs = <Text, List<TextAsmRef>>{};
  var cursor = _Cursor();
  var quotes = Quotes();

  for (var text in column.texts) {
    var ascii = text.spans
        .map((s) => s.toAscii(quotes))
        .reduceOr((s1, s2) => s1 + s2, ifEmpty: Bytes.empty());
    var lines = dialogLines(ascii, dialogIdOffset: currentDialogId);
    int? lastLine;

    for (var line in lines) {
      var position = Longword(_topLeft +
          display.lineOffset * _perLineOffset +
          cursor.line * _perLine +
          cursor.col * _perCharacter);

      if (position >= _maxPosition.toValue) {
        throw ArgumentError('text extends past bottom of screen. text="$text"');
      }

      textAsmRefs.putIfAbsent(text, () => []).add(TextAsmRef(
          dialogId: line.dialogId, length: line.length, position: position));

      cursor.advanceCharactersWithinLine(line.length);
      currentDialogId = (line.dialogId + 1.toByte) as Byte;
      // assumes lines only ever advance by 1...
      if (lastLine != null && line.outputLineNumber > lastLine) {
        cursor.advanceLine();
      }
      lastLine = line.outputLineNumber;

      newDialogs.add(DialogAsm([line.asm]));
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

  TextGroupSet? set;
  PaletteEvent? event;
  Duration? timeLeftInEvent;

  bool loadedSet = false;
  bool loadedEvent = false;
  Set<int> loadedTiles = {};

  _GroupCursor(this.index, this.group) {
    set = group.sets.firstOrNull;
    event = set?.paletteEvents.firstOrNull;
    timeLeftInEvent = event?.duration;
  }

  void loadedTile(int tile) {
    loadedTiles.add(tile);
  }

  void unloadTile(int tile) {
    loadedTiles.remove(tile);
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
        set = null;
        loadedSet = false;
        loadedEvent = false;
        event = null;
        return false;
      }
      set = sets[_setIndex];
      loadedSet = false;
      events = set!.paletteEvents;
      _eventIndex = 0;
    }

    event = events[_eventIndex];
    loadedEvent = false;
    lastEventTime = time;
    timeLeftInEvent = event!.duration;

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
      .sorted((a, b) => a.event!.duration.compareTo(b.event!.duration))
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

  bool get isDone => currentGroups.isEmpty;

  List<_GroupCursor> get currentGroups => _groupCursors.values
      .where((group) => group.event != null)
      .toList(growable: false);
}

extension _PaletteEventAsm on PaletteEvent {
  Label? get fadeRoutineLbl {
    if (state == FadeState.wait) return null;
    return 'fade_$hashCode'.toLabel;
  }

  Asm? fadeRoutine({required int groupIndex}) {
    if (groupIndex > 1) {
      throw ArgumentError('text must not have more that 2 text groups');
    }

    var lbl = fadeRoutineLbl;
    if (lbl == null) return null;

    var paletteOffset = 0x5e + 0x20 * groupIndex;

    return Asm([
      setLabel(lbl.name),
      move.b((Main_Frame_Count + 1.toValue).w, d1),
      // TODO: figure out value for this
      andi.w(3.i, d1),
      bne.s('.ret'.toLabel),
      // todo: do we have to load this every loop?
      lea((Palette_Table_Buffer + paletteOffset.toByte).w, a0),
      move.w(a0.indirect, d1),
      if (state == FadeState.fadeIn)
        Asm([
          addi.w(0x222.toWord.i, d1),
          btst(0xC.i, d1),
          bne.s('.ret'.toLabel)
        ])
      else
        Asm([
          cmpi.w(0x666.toWord.i, d1),
          beq.s('.clear'.toLabel),
          subi.w(0x222.toWord.i, d1)
        ]),
      move.w(d1, a0.indirect),
      setLabel('.ret'),
      rts,
      if (state == FadeState.fadeOut)
        Asm([
          setLabel('.clear'),
          jsr('ClearPlaneABuf'.toLabel.l),
          jmp(DMAPlane_A_VInt.l)
        ])
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
  // todo: not sure if we relaly need to track group here
  final _rangesByGroup = <int, List<List<int>>>{};

  static final _maxTiles = 0x800;

  int tileForRange({required int length, required int forGroup}) {
    var start = 0;
    var allRanges = _rangesByGroup.values
        .expand((groupRanges) => groupRanges)
        .sorted((a, b) => a.first.compareTo(b.first));
    for (int i = 0; i < allRanges.length; i++) {
      var range = allRanges[i];

      var gap = range[0] - start;
      if (length <= gap) {
        break;
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
