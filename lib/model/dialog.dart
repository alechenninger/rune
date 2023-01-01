import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:rune/generator/generator.dart';

import 'model.dart';

class Dialog extends Event {
  Speaker speaker;
  // fixme: toString/==/etc
  bool hidePanelsOnClose = false;
  final List<DialogSpan> _spans = [];
  List<DialogSpan> get spans => UnmodifiableListView(_spans);

  factory Dialog.parse(String markup) {
    return Dialog(spans: DialogSpan.parse(markup));
  }

  Dialog({Speaker? speaker, List<DialogSpan> spans = const []})
      : speaker = speaker ?? const UnnamedSpeaker() {
    var lastSpanSkipped = false;

    for (var i = 0; i < spans.length; i++) {
      var span = spans[i];
      if (_spans.isEmpty) {
        span = span.trimLeft();
      }

      if (i == spans.length - 1) {
        span = span.trimRight();
      }

      if (span.text.isEmpty) {
        // empty span is merged or just skipped unless contains pause or panel
        if (span.pause == Duration.zero && span.panel == null) {
          lastSpanSkipped = true;
          continue;
        } else if (_spans.isNotEmpty) {
          // merge if previous has no panel
          var previous = _spans.last;
          if (previous.panel == null) {
            _spans.last = DialogSpan.fromSpan(previous.span,
                panel: span.panel, pause: span.pause + previous.pause);
            lastSpanSkipped = true;
            continue;
          }

          // fall through (keep)
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
        if (span.text.isEmpty && span.pause == Duration.zero) {
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
      throw ArgumentError.value(
          spans, 'spans', 'must contain at least one span with text');
    }
  }

  @override
  String toString() {
    return 'Dialog{'
        'speaker: $speaker, '
        'hidePanelsOnClose: $hidePanelsOnClose, '
        '_spans: $_spans'
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
  final Duration pause;

  /// Panel to be displayed after the [span].
  final Panel? panel;

  String get text => span.text;
  bool get italic => span.italic;

  DialogSpan(String text,
      {bool italic = false, this.pause = Duration.zero, this.panel})
      : span = Span(text, italic: italic);

  DialogSpan.italic(String text) : this(text, italic: true);

  DialogSpan.fromSpan(this.span, {this.pause = Duration.zero, this.panel});

  DialogSpan trimLeft() =>
      DialogSpan.fromSpan(span.trimLeft(), pause: pause, panel: panel);
  DialogSpan trimRight() =>
      DialogSpan.fromSpan(span.trimRight(), pause: pause, panel: panel);

  // TODO: markup parsing belongs in parse layer
  static List<DialogSpan> parse(String markup) {
    return Span.parse(markup).map((e) => DialogSpan.fromSpan(e)).toList();
  }

  @override
  String toString() {
    return 'DialogSpan{'
        'text: $text, '
        'italic: $italic, '
        'pause: $pause, '
        'panel: $panel}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DialogSpan &&
          runtimeType == other.runtimeType &&
          span == other.span &&
          pause == other.pause &&
          panel == other.panel;

  @override
  int get hashCode => span.hashCode ^ pause.hashCode ^ panel.hashCode;
}

class Span {
  final String text;
  final bool italic;

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

abstract class Speaker {
  /// Returns the [Speaker] if they have a well known [name].
  ///
  /// Case insensitive.
  static Speaker? byName(String name) {
    switch (name.toLowerCase()) {
      case 'alys':
        return alys;
      case 'shay':
        return shay;
      case 'kroft':
      case 'principal kroft':
        return const PrincipalKroft();
    }
    return null;
  }
}

// todo: this is really more like "unseen" speaker
class UnnamedSpeaker implements Speaker {
  const UnnamedSpeaker();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnnamedSpeaker && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override
  String toString() {
    return 'UnnamedSpeaker{}';
  }
}

class PrincipalKroft implements Speaker {
  const PrincipalKroft();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrincipalKroft && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override
  String toString() {
    return 'PrincipalKroft{}';
  }
}
