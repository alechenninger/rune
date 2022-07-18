import 'package:collection/collection.dart';
import 'package:quiver/check.dart';

import '../generator/generator.dart';
import 'model.dart';

class DisplayText extends Event {
  /// Columns by starting line offset. Note that lines of text take up 3 offsets
  /// so consecutive columns should be spaced 3 apart. That said, the simpler
  /// way to do this is to just use a single column with new lines.
  ///
  /// See [Text.lineBreak].
  // final Map<int, List<TextColumn>> columns;
  final int lineOffset;
  final TextColumn column;

  DisplayText({required this.lineOffset, required this.column});

  @override
  String toString() {
    return 'TextDisplay{lineOffset: $lineOffset, column: $column}';
  }

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    // TODO: implement generateAsm
    throw UnimplementedError();
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
      required this.texts})
      : groups =
            texts.map((e) => e.groupSet.group).toSet().toList(growable: false) {
    checkArgument(left + width <= 40,
        message:
            'left + width must be <= 40 but $left + $width = ${left + width}');
    // TODO: if we support multiple columns at once this check would move up
    //   to that higher level
    checkArgument(groups.length <= 2,
        message: 'cannot display more than 2 text groups');
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
          const ListEquality<Text>().equals(texts, other.texts);

  @override
  int get hashCode =>
      left.hashCode ^
      width.hashCode ^
      hAlign.hashCode ^
      const ListEquality<Text>().hash(texts);
}

/// Group of spans which are displayed together.
///
/// Spans appear as a continuous block of text which display in unison as one
/// clearly readable unit, bound by the containing [TextColumn].
class Text {
  final TextGroupSet groupSet;
  final List<Span> spans;

  /// If a line break should occur after these spans.
  final bool lineBreak;

  Text({required this.spans, required this.groupSet, this.lineBreak = false}) {
    groupSet.texts.add(this);
  }

  @override
  String toString() {
    return 'Text{spans: $spans, lineBreak: $lineBreak}';
  }
}

enum HorizontalAlignment { left, center, right }

enum VerticalAlignment { top, center, bottom }

enum FadeState { fadeIn, wait, fadeOut }

class PaletteEvent {
  final Duration duration;
  final FadeState state;

  PaletteEvent(this.state, this.duration);
}

PaletteEvent fadeIn(Duration d) => PaletteEvent(FadeState.fadeIn, d);
PaletteEvent wait(Duration d) => PaletteEvent(FadeState.wait, d);
PaletteEvent fadeOut(Duration d) => PaletteEvent(FadeState.fadeOut, d);

class TextGroup {
  final sets = <TextGroupSet>[];

  TextGroupSet addSet() {
    var set = TextGroupSet(group: this);
    sets.add(set);
    return set;
  }
}

class TextGroupSet {
  final _paletteEvents = <PaletteEvent>[];
  List<PaletteEvent> get paletteEvents => UnmodifiableListView(_paletteEvents);

  final TextGroup group;
  final List<Text> texts = [];

  void add(PaletteEvent f) => _paletteEvents.add(f);
  void addDefaultEvents({required Duration showFor}) {
    add(fadeIn(Duration(milliseconds: 500)));
    add(wait(showFor));
    add(fadeOut(Duration(milliseconds: 500)));
  }

  TextGroupSet({required this.group});
  TextGroupSet.withDefaultFades(
      {required this.group, required Duration showFor}) {
    addDefaultEvents(showFor: showFor);
  }

  /*
  FadeState? fadeAt(Duration time) {
    if (delay > time) return null;
    var doneFadeIn = delay + fadeIn;
    if (doneFadeIn > time) return FadeState.fadeIn;
    var doneMaintain = doneFadeIn + duration;
    if (doneMaintain > time) return FadeState.wait;
    var doneFadeOut = doneMaintain + fadeOut;
    if (doneFadeOut > time) return FadeState.fadeOut;
    return null;
  }
   */
}
