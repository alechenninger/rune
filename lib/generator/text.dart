import 'dart:ffi';

import 'package:collection/collection.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/asm/text.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/map.dart';
import 'package:rune/generator/scene.dart';
import 'package:rune/model/text.dart';
import 'package:rune/src/iterables.dart';

import 'dialog.dart';

import '../asm/asm.dart';
import '../model/dialog.dart';

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

    var groups = eventCursor.groups;

    for (var i = 0; i < groups.length; i++) {
      var group = groups[i];
      var event = group.event!;
      var groupI = group.index;

      if (event.state != FadeState.wait && !group.loadedEvent) {
        group.loadedEvent = true;
        fadeRoutines.add(event.fadeRoutine(groupIndex: groupI));
        fadeRoutines.addNewline();
      }

      if (!group.loadedSet) {
        group.loadedSet = true;

        for (var tile in group.loadedTiles) {
          vramTileRanges.releaseRange(startingAt: tile, forGroup: groupI);
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
                length: asmRef.length, forGroup: groupI);
            group.loadedTile(tile);

            var tileNumber = Word(
                _perPaletteLine * (groupI + 1) + _perCharacter * tile + 0x100);

            // each dialog has a length and id
            eventAsm.add(getDialogueByID(asmRef.dialogId));
            eventAsm.add(runText2(asmRef.position.i, tileNumber.i));
            if (i + 1 == groups.length && j + 1 == set.texts.length) {
              eventAsm.add(dmaPlaneAVInt());
            } else {
              eventAsm.add(vIntPrepare());
            }
            eventAsm.addNewline();
          }
        }
      }
    }

    var shortest = eventCursor.shortest;
    var remainingDuration = shortest.timeLeftInEvent!;
    var frames = remainingDuration.toFrames();
    var loopRoutine = eventCursor.loopRoutine;

    eventAsm.add(Asm([
      moveq(frames.toByte.i, d0),
      setLabel(loopRoutine.name),
      // can potentially use bsr
      jsr(groups[0].event!.fadeRoutineLbl.l),
      if (groups.length > 1) jsr(groups[1].event!.fadeRoutineLbl.l),
      vIntPrepare(),
      dbf(d0, loopRoutine.l)
    ]));

    eventAsm.addNewline();

    eventCursor.advanceToNextEvent();
  }

  var done = '${display.hashCode}_done';
  // todo: would be nice to use bsr i guess? but we don't know how much fade
  //   routine ASM we have.
  eventAsm.add(jsr(done.toLabel.l));
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

  _GroupCursor get shortest => groups
      .sorted((a, b) => a.event!.duration.compareTo(b.event!.duration))
      .first;

  Label get loopRoutine =>
      '${column.hashCode}_t${_time.inMilliseconds}_loop'.toLabel;

  bool advanceToNextEvent() {
    _time += shortest.timeLeftInEvent!;

    for (var c in _groupCursors.values) {
      c.advanceTo(_time);
    }

    return !isDone;
  }

  bool get isDone => groups.isEmpty;

  List<_GroupCursor> get groups => _groupCursors.values
      .where((group) => group.event != null)
      .toList(growable: false);
}

class _GroupEvent {
  final int group;
  final PaletteEvent event;

  _GroupEvent(this.group, this.event);

  @override
  String toString() {
    return '_GroupEvent{group: $group, event: $event}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GroupEvent &&
          runtimeType == other.runtimeType &&
          group == other.group &&
          event == other.event;

  @override
  int get hashCode => group.hashCode ^ event.hashCode;
}

extension _PaletteEventAsm on PaletteEvent {
  Label get fadeRoutineLbl => '${hashCode}_fade'.toLabel;

  Asm fadeRoutine({required int groupIndex}) {
    if (groupIndex > 1) {
      throw ArgumentError('text must not have more that 2 text groups');
    }

    var paletteOffset = 0x5e + 0x20 * groupIndex;

    return Asm([
      setLabel(fadeRoutineLbl.name),
      move.b((Main_Frame_Count + 1.toValue).w, d1),
      // TODO: figure out value for this
      andi.w(3.i, d1),
      bne.s('.ret'.toLabel),
      // todo: do we have to load this every loop?
      lea((Palette_Table_Buffer + paletteOffset.toByte).w, a0),
      move.w(a0.indirect, d1),
      addi.w(0x222.i, d1),
      btst(0xC.i, d1),
      bne.s('.ret'.toLabel),
      move.w(d1, a0.indirect),
      setLabel('.ret'),
      rts
    ]);
  }
}

class _TextEvent {
  final int groupIndex;
  final int setIndex;
  final int eventIndex;
  final PaletteEvent paletteEvent;

  _TextEvent(
      this.groupIndex, this.setIndex, this.eventIndex, this.paletteEvent);

  Duration get duration => paletteEvent.duration;
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

class FadeGroup {
  String id;
  List<FadeText> texts;
  Byte fadeInFrames;
  Label fadeInRoutine;
  Word maintainFrames;
  Byte fadeOutFrames;
  Label fadeOutRoutine;

  FadeGroup(
      {required this.id,
      required this.texts,
      required this.fadeInFrames,
      required this.fadeInRoutine,
      required this.maintainFrames,
      required this.fadeOutFrames,
      required this.fadeOutRoutine});
}

class FadeText {
  List<TextAsmRef> dialogs;

  FadeText({required this.dialogs});
}

class TextAsmRef {
  final Byte dialogId;
  final Longword position;
  final int length;

  TextAsmRef(
      {required this.dialogId, required this.position, required this.length});
}

class AsmText {}
