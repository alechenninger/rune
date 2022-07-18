import 'dart:ffi';

import 'package:collection/collection.dart';
import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/asm/text.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
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
  var currentDialog = DialogAsm.empty();
  var eventAsm = EventAsm.empty();
  var fadeRoutines = EventAsm.empty();

  var column = display.column;

  // first associate all the asm with each Text, regardless of text group
  var cursor = _Cursor();
  var textAsmRefs = <Text, List<TextAsmRef>>{};
  var palettes = <TextGroup, int>{};
  var quotes = Quotes();

  for (var text in column.texts) {
    var palette = palettes.putIfAbsent(
        text.groupSet.group, () => 1 + (palettes.values.firstOrNull ?? 0));
    if (palettes.length > 2) {
      throw ArgumentError('text must not have more that 2 text groups');
    }

    var ascii = text.spans
        .map((s) => s.toAscii(quotes))
        .reduceOr((s1, s2) => s1 + s2, ifEmpty: Bytes.empty());
    var lines = dialogLines(ascii, dialogIdOffset: dialogIdOffset);
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
      // assumes lines only ever advance by 1...
      if (lastLine != null && line.outputLineNumber > lastLine) {
        cursor.advanceLine();
      }
      lastLine = line.outputLineNumber;

      newDialogs.add(DialogAsm([line.asm]));
    }
  }

  // cant just go group by group, need to figure out what to do in parallel.
  // so we do rounds
  /*
  look at each sequence
  each duration represents a breakpoint
  ...iii...oooiii...oo
  iiiii...oo...ii...oo
  ^  ^ ^^ ^^^ ^^ ^  ^
   */
  // todo: consolidate all of these "by group" map values into a class with each
  // GroupCursor with time, set index, pal event index, etc.
  var time = Duration.zero;
  var eventTimeByGroup = <int, Duration>{};
  var setIndexByGroup = <int, int>{};
  var paletteEventIndexByGroup = <int, int>{};
  var vramTileRanges = _VramTileRanges();

  /// Next event in [forGroup] group after [time].
  PaletteEvent? nextEvent({required int forGroup}) {
    var group = column.group(forGroup);
    if (group == null) return null;

    var setIndex = setIndexByGroup.putIfAbsent(forGroup, () => 0);
    if (setIndex >= group.sets.length) return null;

    var set = group.sets[setIndex];

    var paletteEventIndex =
        paletteEventIndexByGroup.putIfAbsent(forGroup, () => 0);
    if (paletteEventIndex >= set.paletteEvents.length) {
      setIndexByGroup[forGroup] = setIndex + 1;
      paletteEventIndexByGroup[forGroup] = 0;
      return nextEvent(forGroup: forGroup);
    }

    var paletteEvent = set.paletteEvents[paletteEventIndex];

    if (time >=
        paletteEvent.duration +
            eventTimeByGroup.putIfAbsent(forGroup, () => Duration.zero)) {
      paletteEventIndexByGroup[forGroup] = paletteEventIndex + 1;
      return nextEvent(forGroup: forGroup);
    }

    return paletteEvent;
  }

  var loadedEvents = <PaletteEvent>{};
  var loadedSetByGroup = <int, int>{};
  var loadedTilesByGroup = <int, List<int>>{};
  PaletteEvent? event0;
  PaletteEvent? event1;
  while (
      // only 2 simultaneous are supported for now
      (event0 = nextEvent(forGroup: 0)) != null ||
          (event1 = nextEvent(forGroup: 1)) != null) {
    // first see if we need to load new text
    for (var groupI = 0; groupI < 2; groupI++) {
      var setIndex = setIndexByGroup[groupI];
      if (setIndex == null) continue;

      var loadedSetIndex = loadedSetByGroup[groupI];
      if (setIndex != loadedSetIndex) {
        for (var tile in loadedTilesByGroup.putIfAbsent(groupI, () => [])) {
          vramTileRanges.releaseRange(startingAt: tile, forGroup: groupI);
        }

        loadedSetIndex = setIndex;
        var set = column.groups[groupI].sets[setIndex];
        for (var text in set.texts) {
          var asmRefs = textAsmRefs[text];
          if (asmRefs == null) {
            throw StateError(
                'no asm refs for text: text=$text, asmRefs=$textAsmRefs');
          }
          // each text has position
          for (var asmRef in asmRefs) {
            var tile = vramTileRanges.tileForRange(
                length: asmRef.length, forGroup: groupI);
            var tileNumber = Word(
                _perPaletteLine * (groupI + 1) + _perCharacter * tile + 0x100);

            // each dialog has a length and id
            eventAsm.add(getDialogueByID(asmRef.dialogId));
            eventAsm.add(runText2(asmRef.position.i, tileNumber.i));
            eventAsm.add(vIntPrepare());
            eventAsm.addNewline();
          }
        }
      }
    }

    eventAsm.replace(eventAsm.length - 2, dmaPlaneAVInt());

    var shortestFirst = {0: event0, 1: event1}
        .entries
        .where((entry) => entry.value != null)
        .sorted((a, b) => a.value!.duration.compareTo(b.value!.duration));

    var first = shortestFirst.first.value!;
    if (first.state == FadeState.fadeIn) {
      if (!loadedEvents.contains(first)) {
        var paletteOffset = 0x5e + 0x20 * shortestFirst.first.key;
        fadeRoutines.add(Asm([
          setLabel('${first.hashCode}_fade'),
          move.b((Main_Frame_Count + 1.toValue).w, d1),
          // TODO: figure out value for this
          andi.w(3.toValue.i, d1),
          bne.s('.ret'.toLabel.l),
          // todo: do we have to load this every loop?
          lea((Palette_Table_Buffer + paletteOffset.toByte).w, a0),
          move.w(a0.indirect, d1),
          addi.w(0x222.toWord.i, d1),
          btst(0xC.toValue.i, d1),
          bne.s('.ret'.toLabel.l),
          move.w(d1, a0.indirect),
          setLabel('.ret'),
          rts
        ]));
      }

      var loop = '${first.hashCode}_in';
      var frames = first.duration.toFrames();
      eventAsm.add(Asm([
        moveq(frames.toByte.i, d0),
        setLabel(loop),
        // can potentially use bsr
        jsr('${first.hashCode}_fade'.toLabel.l),
        vIntPrepare(),
        dbf(d0, loop.toLabel.l)
      ]));
    }

    time += first.duration;
  }

  // for (var group in column.groups) {
  //   // figure out what text to run and where somehow
  //   // cursor stuff actually a bit harder
  //   // have to run through and collect spans in two dimensions
  //   // cursor (where they should render) and fade group (the states of the
  //   // palettes)
  //
  //   // this should be out of the loop, just for first element i think?
  //   // eventAsm.add(setPaletteColor(fadeGroup.paletteRow, fadeGroup.paletteCol, fadeGroup.startColor));
  //
  //   // replace last with dmaplaneint if this should be displayed?
  //
  //   if (fadeGroup.fadeInFrames > 0.toByte) {
  //     var loop = '${fadeGroup.id}_in';
  //     eventAsm.add(Asm([
  //       moveq(fadeGroup.fadeInFrames.i, d0),
  //       setLabel(loop),
  //       // can potentially use bsr
  //       jsr(fadeGroup.fadeInRoutine.l),
  //       vIntPrepare(),
  //       dbf(d0, loop.toLabel.l)
  //     ]));
  //   }
  //
  //   if (fadeGroup.maintainFrames > 0.toWord) {
  //     eventAsm.add(vIntPrepareLoop(fadeGroup.maintainFrames));
  //   }
  //
  //   if (fadeGroup.fadeOutFrames > 0.toByte) {
  //     var loop = '${fadeGroup.id}_out';
  //     eventAsm.add(Asm([
  //       moveq(fadeGroup.fadeOutFrames.i, d0),
  //       setLabel(loop),
  //       // can potentially use bsr
  //       jsr(fadeGroup.fadeOutRoutine.l),
  //       vIntPrepare(),
  //       dbf(d0, loop.toLabel.l)
  //     ]));
  //   }
  // }
  // TODO: need to skip these routines so they only get run during fades
  eventAsm.addNewline();
  eventAsm.add(fadeRoutines);

  return SceneAsm(
      event: eventAsm, dialogIdOffset: dialogIdOffset, dialog: newDialogs);
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
