import 'package:collection/collection.dart';
import 'package:quiver/check.dart';

import '../generator/generator.dart';
import "../src/iterables.dart";
import 'model.dart';

class DisplayText extends Event {
  /// Columns by starting line offset. Note that lines of text take up 3 offsets
  /// so consecutive columns should be spaced 3 apart. That said, the simpler
  /// way to do this is to just use a single column with new lines.
  ///
  /// See [Text.lineBreak].
  // todo: for now we are assuming just one column at a time
  // multiple is possible but they still have to share the same 2 text groups
  // final Map<int, List<TextColumn>> columns;
  final int lineOffset;
  final TextColumn column;

  DisplayText({this.lineOffset = 0, required this.column});

  @override
  String toString() {
    return 'TextDisplay{lineOffset: $lineOffset, column: $column}';
  }

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    throw 'unsupported';
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.displayText(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayText &&
          runtimeType == other.runtimeType &&
          lineOffset == other.lineOffset &&
          column == other.column;

  @override
  int get hashCode => lineOffset.hashCode ^ column.hashCode;
}

/// A continuously (left-to-right) laid out series of [Text]s which may display
/// at different times but share the same boundaries and alignment.
class TextColumn {
  // todo: unimplemented
  final int left;
  final int width;
  final VerticalAlignment vAlign;
  final HorizontalAlignment hAlign;
  final List<Text> texts;
  final List<TextGroup> groups;
  TextGroup get firstGroup => groups.first;
  TextGroup? group(int index) => groups.length > index ? groups[index] : null;

  TextColumn(
      {this.left = 0,
      this.width = 40,
      this.vAlign = VerticalAlignment.top,
      this.hAlign = HorizontalAlignment.left,
      required List<Text> texts})
      : texts = List.unmodifiable(texts),
        groups = List.unmodifiable(
            texts.map((e) => e.block.group).toSet().toList(growable: false)) {
    checkArgument(left + width <= 40,
        message:
            'left + width must be <= 40 but $left + $width = ${left + width}');
    checkArgument(texts.isNotEmpty, message: 'texts must not be empty');
    // TODO: if we support multiple columns at once this check would move up
    //   to that higher level
    checkArgument(groups.isNotEmpty && groups.length <= 2,
        message: 'cannot display more than 2 text groups '
            '(and must have at least one)');
  }

  @override
  String toString() {
    return 'TextColumn{left: $left, width: $width, alignment: $hAlign, '
        'texts: $texts}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextColumn &&
          runtimeType == other.runtimeType &&
          left == other.left &&
          width == other.width &&
          hAlign == other.hAlign &&
          vAlign == other.vAlign &&
          const ListEquality<Text>().equals(texts, other.texts);

  @override
  int get hashCode =>
      left.hashCode ^
      width.hashCode ^
      hAlign.hashCode ^
      vAlign.hashCode ^
      const ListEquality<Text>().hash(texts);
}

/// Group of spans which are displayed together.
///
/// Spans appear as a continuous block of text which display in unison as one
/// clearly readable unit, bound by the containing [TextColumn].
class Text {
  final TextBlock block;
  final List<Span> spans;

  /// If a line break should occur after these spans.
  final bool lineBreak;

  @Deprecated('use TextBlock#addText instead')
  Text({required this.spans, required this.block, this.lineBreak = false}) {
    block._addToSet(this);
  }

  int get length => spans
      .map((span) => span.text.length)
      .reduceOr((l1, l2) => l1 + l2, ifEmpty: 0);

  @override
  String toString() {
    return 'Text{spans: $spans, lineBreak: $lineBreak}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Text &&
          runtimeType == other.runtimeType &&
          block == other.block &&
          const ListEquality<Span>().equals(spans, other.spans) &&
          lineBreak == other.lineBreak;

  @override
  int get hashCode =>
      block.hashCode ^
      const ListEquality<Span>().hash(spans) ^
      lineBreak.hashCode;
}

enum HorizontalAlignment { left, center, right }

enum VerticalAlignment { top, center, bottom }

enum FadeState {
  fadeIn,
  wait,
  fadeOut;

  PaletteEvent lasting(Duration d) => PaletteEvent(this, d);
}

class PaletteEvent {
  final Duration duration;
  final FadeState state;

  PaletteEvent(this.state, this.duration);
}

PaletteEvent fadeIn(Duration d) => PaletteEvent(FadeState.fadeIn, d);
PaletteEvent wait(Duration d) => PaletteEvent(FadeState.wait, d);
PaletteEvent fadeOut(Duration d) => PaletteEvent(FadeState.fadeOut, d);

/// A sequence of [TextBlock]s.
///
/// Each `TextBlock` is a set of text which is displayed together,
/// with shared [PaletteEvent]s.
class TextGroup {
  final _blocks = <TextBlock>[];
  List<TextBlock> get blocks => List.unmodifiable(_blocks);
  // todo: decouple model from asm
  final Word defaultBlack;
  final Word defaultWhite;

  TextGroup({Word? defaultBlack, Word? defaultWhite})
      : defaultWhite = defaultWhite ?? Word(0xEEE),
        defaultBlack = defaultBlack ?? Word(0);

  TextBlock addBlock({Word? white, Word? black}) {
    var set = TextBlock(
        group: this,
        white: white ?? defaultWhite,
        black: black ?? defaultBlack);
    _blocks.add(set);
    return set;
  }

  TextBlock setBlockAt(int index, {Word? white, Word? black}) {
    if (index >= _blocks.length) {
      if (index != _blocks.length) {
        throw ArgumentError(
            'must be existing or next set but was $index', 'index');
      }
      return addBlock(white: white, black: black);
    }
    return _blocks[index];
  }

  @override
  String toString() {
    return 'TextGroup{$hashCode, blocks: $_blocks}';
  }
}

class TextBlock {
  final _paletteEvents = <PaletteEvent>[];
  List<PaletteEvent> get paletteEvents => UnmodifiableListView(_paletteEvents);

  final TextGroup group;
  final _texts = <Text>[];
  List<Text> get texts => List.unmodifiable(_texts);
  final Word black;
  final Word white;

  TextBlock({required this.group, Word? black, Word? white})
      : black = black ?? Word(0),
        white = white ?? Word(0xeee);
  TextBlock.withDefaultFades(
      {required this.group,
      required Duration showFor,
      Word? black,
      Word? white})
      : black = black ?? Word(0),
        white = white ?? Word(0xeee) {
    addDefaultEvents(showFor: showFor);
  }

  void _addToSet(Text text) {
    _texts.add(text);
  }

  Text addText(List<Span> spans, {bool lineBreak = false}) {
    // ignore: deprecated_member_use_from_same_package
    return Text(spans: spans, block: this, lineBreak: lineBreak);
  }

  void addEvent(PaletteEvent f) => _paletteEvents.add(f);
  void addDefaultEvents({required Duration showFor}) {
    addEvent(fadeIn(Duration(milliseconds: 500)));
    addEvent(wait(showFor));
    addEvent(fadeOut(Duration(milliseconds: 500)));
  }

  @override
  String toString() {
    return 'TextBlock{$hashCode, paletteEvents: $_paletteEvents}';
  }

  @override
  bool operator ==(Object other) {
    // TODO: implement ==
    return super == other;
  }
}
