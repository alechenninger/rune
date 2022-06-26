import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:rune/generator/generator.dart';

import 'model.dart';

class Dialog extends Event {
  Speaker? speaker;
  final List<Span> _spans = [];
  List<Span> get spans => UnmodifiableListView(_spans);

  Dialog({this.speaker, List<Span> spans = const []}) {
    if (spans.isEmpty) {
      throw ArgumentError.value(
          spans, 'spans', 'must contain at least one span');
    }

    for (var i = 0; i < spans.length; i++) {
      var span = spans[i];
      if (i == 0) {
        span = span.trimLeft();
      } else if (span.text.isEmpty) {
        // empty span is merged or just skipped
        if (span.pause > Duration.zero) {
          var previous = _spans[i - 1];
          _spans[i - 1] = previous.withPause(previous.pause + span.pause);
        }
        continue;
      }

      if (i == spans.length - 1) {
        span = span.trimRight();
      }

      _spans.add(span);
    }
  }

  @override
  String toString() {
    return 'Dialog{speaker: $speaker, _spans: $_spans}';
  }

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.dialogToAsm(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dialog &&
          runtimeType == other.runtimeType &&
          speaker == other.speaker &&
          const ListEquality().equals(_spans, other._spans);

  @override
  int get hashCode => speaker.hashCode ^ const ListEquality().hash(_spans);
}

class Span {
  final String text;
  final bool italic;
  final Duration pause;

  Span(this.text, {this.italic = false, this.pause = Duration.zero});

  Span.italic(String text) : this(text, italic: true);

  Span trimLeft() => Span(text.trimLeft(), italic: italic, pause: pause);
  Span trimRight() => Span(text.trimRight(), italic: italic, pause: pause);
  Span withPause(Duration pause) => Span(text, italic: italic, pause: pause);

  // TODO: markup parsing belongs in parse layer
  static List<Span> parse(String markup) {
    var _spans = <Span>[];
    var italic = false;
    var text = StringBuffer();

    for (var c in markup.characters) {
      // Note, no escape sequence support, but at the moment not needed because
      // _ not otherwise a supported character in dialog.
      if (c == '_') {
        if (text.isNotEmpty) {
          _spans.add(Span(text.toString(), italic: italic));
          text.clear();
        }
        italic = !italic;
        continue;
      }

      text.write(c);
    }

    if (text.isNotEmpty) {
      _spans.add(Span(text.toString(), italic: italic));
    }

    return _spans;
  }

  @override
  String toString() {
    return 'Span{text: $text, italic: $italic, pause: $pause}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Span &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          italic == other.italic &&
          pause == other.pause;

  @override
  int get hashCode => text.hashCode ^ italic.hashCode ^ pause.hashCode;
}

abstract class Speaker {
  static Speaker? byName(String name) {
    switch (name.toLowerCase()) {
      case 'alys':
        return alys;
      case 'shay':
        return shay;
      case 'principal':
        return const Principal();
    }
    return null;
  }
}

class Principal implements Speaker {
  const Principal();
}
