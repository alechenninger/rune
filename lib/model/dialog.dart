import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:rune/generator/generator.dart';

import 'model.dart';

class Dialog extends Event {
  Speaker speaker;
  Portrait get portrait => speaker.portrait;
  bool hidePanelsOnClose = false;
  final List<DialogSpan> _spans = [];
  List<DialogSpan> get spans => UnmodifiableListView(_spans);

  factory Dialog.parse(String markup, {Speaker? speaker}) {
    return Dialog(spans: DialogSpan.parse(markup), speaker: speaker);
  }

  Dialog({Speaker? speaker, List<DialogSpan> spans = const []})
      : speaker = speaker ?? const UnnamedSpeaker() {
    var lastSpanSkipped = false;

    for (var i = 0; i < spans.length; i++) {
      var span = spans[i];
      if (_spans.where((s) => s.hasText).isEmpty) {
        span = span.trimLeft();
      }

      if (i == spans.length - 1) {
        span = span.trimRight();
      }

      if (span.text.isEmpty) {
        // empty span is merged or just skipped unless contains events
        if (span.events.isEmpty) {
          lastSpanSkipped = true;
          continue;
        } else if (_spans.isNotEmpty) {
          // merge with previous
          var previous = _spans.last;
          var events = switch ([...previous.events, ...span.events]) {
            [Pause p1, Pause p2, ...(var rest)] => [
                Pause(p1.duration + p2.duration, duringDialog: true),
                ...rest
              ],
            var events => events
          };
          _spans.last = DialogSpan.fromSpan(previous.span, events: events);
          lastSpanSkipped = true;
          continue;
        }

        // fall through (keep)
      }

      lastSpanSkipped = false;
      _spans.add(span);
    }

    if (lastSpanSkipped) {
      // Remove other trailing empty spans that were kept assuming more
      // spans would come after
      for (var i = _spans.length - 1; i >= 0; i--) {
        var span = _spans[i].trimRight();
        if (span.text.isEmpty && span.events.isEmpty) {
          _spans.removeAt(i);
        } else {
          _spans[i] = span;
          break;
        }
      }
    }

    if (_spans.isEmpty) {
      // todo: consider relaxing this rule to allow reusing dialog to
      //   simply control potraits
      throw ArgumentError.value(spans.toString(), 'spans',
          'must contain at least one span with text');
    }
  }

  @override
  String toString() {
    return 'Dialog{'
        'speaker: $speaker, '
        'hidePanelsOnClose: $hidePanelsOnClose, '
        'spans: $_spans'
        '}';
  }

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.dialogToAsm(this);
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.dialog(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dialog &&
          runtimeType == other.runtimeType &&
          speaker == other.speaker &&
          hidePanelsOnClose == other.hidePanelsOnClose &&
          const ListEquality().equals(_spans, other._spans);

  @override
  int get hashCode => speaker.hashCode ^ const ListEquality().hash(_spans);
}

class DialogSpan {
  final Span span;

  /// Duration to pause for after the [span].
  @Deprecated('Use events instead')
  final Duration pause;

  /// Panel to be displayed after the [span].
  ///
  /// Comes after [pause] if pause is also set.
  @Deprecated('Use events instead')
  final Panel? panel;

  /// Events to run after the [span].
  ///
  /// Includes [pause] and [panel] if either are set,
  /// which will always be first (in that order).
  final List<RunnableInDialog> events;

  bool get hasText => span.text.isNotEmpty;
  String get text => span.text;
  bool get italic => span.italic;

  DialogSpan(String text,
      {bool italic = false,
      @Deprecated('Use events instead') Duration pause = Duration.zero,
      @Deprecated('Use events instead') Panel? panel,
      Iterable<RunnableInDialog> events = const []})
      : this.fromSpan(Span(text, italic: italic),
            pause: pause, panel: panel, events: events);

  DialogSpan.italic(String text) : this(text, italic: true);

  DialogSpan.fromSpan(this.span,
      {this.pause = Duration.zero,
      this.panel,
      Iterable<RunnableInDialog> events = const []})
      : events = List.unmodifiable([
          if (pause != Duration.zero) Pause(pause, duringDialog: true),
          if (panel != null) ShowPanel(panel, showDialogBox: true),
          ...events
        ]) {
    // Ensure events are all compatible with dialog
    for (var event in events) {
      if (!event.canRunInDialog()) {
        throw ArgumentError.value(
            event, 'events', 'event cannot run in dialog');
      }
    }
  }

  DialogSpan trimLeft() => DialogSpan.fromSpan(span.trimLeft(), events: events);
  DialogSpan trimRight() =>
      DialogSpan.fromSpan(span.trimRight(), events: events);

  // TODO: markup parsing belongs in parse layer
  static List<DialogSpan> parse(String markup,
      {List<RunnableInDialog> events = const []}) {
    return Span.parse(markup)
        .map((e) => DialogSpan.fromSpan(e, events: events))
        .toList();
  }

  @override
  String toString() {
    return 'DialogSpan{'
        'text: $text, '
        'italic: $italic, '
        'events: $events'
        '}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DialogSpan &&
          runtimeType == other.runtimeType &&
          span == other.span &&
          const ListEquality().equals(events, other.events);

  @override
  int get hashCode => span.hashCode ^ const ListEquality().hash(events);
}

class Span {
  final String text;
  final bool italic;

  // TODO: process / validate text
  // e.g. newlines don't really make sense (yet?).
  Span(this.text, {this.italic = false});

  Span.italic(String text) : this(text, italic: true);

  Span trimLeft() => Span(text.trimLeft(), italic: italic);
  Span trimRight() => Span(text.trimRight(), italic: italic);

  // TODO: markup parsing belongs in parse layer
  static List<Span> parse(String markup) {
    var spans = <Span>[];
    var italic = false;
    var text = StringBuffer();

    for (var c in markup.characters) {
      // Note, no escape sequence support, but at the moment not needed because
      // _ not otherwise a supported character in dialog.
      if (c == '_') {
        if (text.isNotEmpty) {
          spans.add(Span(text.toString(), italic: italic));
          text.clear();
        }
        italic = !italic;
        continue;
      }

      text.write(c);
    }

    if (text.isNotEmpty) {
      spans.add(Span(text.toString(), italic: italic));
    }

    return spans;
  }

  @override
  String toString() {
    return 'Span{text: $text, italic: $italic}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Span &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          italic == other.italic;

  @override
  int get hashCode => text.hashCode ^ italic.hashCode;
}

abstract mixin class Speaker {
  String get name;
  Portrait get portrait;

  /// Returns the [Speaker] if they have a well known [name].
  ///
  /// Case insensitive.
  // todo: could use allSpeakers to build this index instead now?
  static Speaker? byName(String name) {
    if (name.toLowerCase() == 'unnamed speaker') {
      return const UnnamedSpeaker();
    }
    return _byName[name.toLowerCase()];
  }

  static Speaker? byPortrait(Portrait portrait) {
    return allSpeakers.where((s) => s.portrait == portrait).firstOrNull;
  }

  static final Iterable<Speaker> allSpeakers = [
    ...Character.allCharacters,
    PrincipalKroft,
    Saya,
    Holt,
    Zio,
    HuntersGuildClerk,
    Baker,
    Pana,
    Dorin,
    Seed,
    Mito,
    Juza,
    Shopkeeper1,
    Shopkeeper2,
    Shopkeeper3,
    Shopkeeper4,
    Shopkeeper5,
    Shopkeeper6,
    Shopkeeper7,
    HuntersGuildBartender,
    MissingStudent,
    AlysWounded,
    Gyuna,
  ];

  static final Map<String, Speaker> _byName = allSpeakers.groupFoldBy(
      (element) => element.name.toLowerCase(), (previous, element) => element);

  // Known NPCs...

  static final PrincipalKroft =
      NpcSpeaker(Portrait.PrincipalKroft, 'Principal Kroft');
  static final Saya = NpcSpeaker(Portrait.Saya, 'Saya');
  static final Holt = NpcSpeaker(Portrait.Holt, 'Holt');
  static final Zio = NpcSpeaker(Portrait.Zio, 'Zio');
  static final HuntersGuildClerk =
      NpcSpeaker(Portrait.HuntersGuildClerk, "Hunter's Guild Clerk");
  static final Baker = NpcSpeaker(Portrait.Baker, "Baker");
  static final Pana = NpcSpeaker(Portrait.Pana, "Pana");
  static final Dorin = NpcSpeaker(Portrait.Dorin, "Dorin");
  static final Seed = NoPortraitSpeaker('Seed');
  static final Mito = NpcSpeaker(Portrait.FortuneTeller, 'Mito');
  static final Juza = NpcSpeaker(Portrait.Juza, 'Juza');
  static final SandwormRancher =
      NpcSpeaker(Portrait.Shopkeeper1, 'Sandworm Rancher');
  static final Shopkeeper1 = NpcSpeaker(Portrait.Shopkeeper1, 'Shopkeeper1');
  static final Shopkeeper2 = NpcSpeaker(Portrait.Shopkeeper2, 'Shopkeeper2');
  static final Shopkeeper3 = NpcSpeaker(Portrait.Shopkeeper3, 'Shopkeeper3');
  static final Shopkeeper4 = NpcSpeaker(Portrait.Shopkeeper4, 'Shopkeeper4');
  static final Shopkeeper5 = NpcSpeaker(Portrait.Shopkeeper5, 'Shopkeeper5');
  static final Shopkeeper6 = NpcSpeaker(Portrait.Shopkeeper6, 'Shopkeeper6');
  static final Shopkeeper7 = NpcSpeaker(Portrait.Shopkeeper7, 'Shopkeeper7');
  static final HuntersGuildBartender =
      NpcSpeaker(Portrait.Shopkeeper6, "Hunter's Guild bartender");
  static final MissingStudent =
      NpcSpeaker(Portrait.MissingStudent, 'Missing Student');
  static final AlysWounded = NpcSpeaker(Portrait.AlysWounded, 'Alys (sick)');
  static final Gyuna = NpcSpeaker(Portrait.Gyuna, 'Gyuna');

  @override
  String toString() => name;
}

// todo: this is really more like "unseen" speaker
class UnnamedSpeaker with Speaker {
  const UnnamedSpeaker();

  @override
  final name = 'Unnamed Speaker';

  @override
  final portrait = Portrait.none;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnnamedSpeaker && runtimeType == other.runtimeType;

  @override
  int get hashCode => name.hashCode;
}

class NoPortraitSpeaker with Speaker {
  @override
  final portrait = Portrait.none;
  @override
  final String name;

  NoPortraitSpeaker(this.name);
}

class NpcSpeaker with Speaker {
  @override
  final Portrait portrait;
  @override
  final String name;

  NpcSpeaker(this.portrait, this.name);
}

enum Portrait {
  none,
  Shay,
  Alys,
  Hahn,
  Rune,
  Gryz,
  Rika,
  Demi,
  Wren,
  Raja,
  Kyra,
  Seth,
  Saya,
  Holt,
  PrincipalKroft,
  Dorin,
  Pana,
  HuntersGuildClerk,
  Baker,
  Zio,
  Juza,
  Gyuna,
  Esper,
  EsperChief,
  GumbiousPriest,
  GumbiousBishop,
  Lashiec,
  XeAThoul,
  XeAThoul2,
  FortuneTeller,
  DElmLars,
  AlysWounded,
  ReFaze,
  MissingStudent,
  Tallas,
  DyingBoy,
  Sekreas,

  /// Mustache guy brown and white clothes, green background
  Shopkeeper1,

  /// Woman
  Shopkeeper2,

  /// Younger woman
  Shopkeeper3,

  /// Dezolian
  Shopkeeper4,

  /// Dezolian
  Shopkeeper5,

  // Tough looking guy
  Shopkeeper6,

  /// Blue motavian, brown hood, green background
  Shopkeeper7;

  /// Returns the portrait for the given [name].
  static Portrait? byName(String name) {
    return Portrait.values
        .firstWhereOrNull((e) => e.name.toLowerCase() == name.toLowerCase());
  }
}
