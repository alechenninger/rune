import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:rune/generator/generator.dart';

import 'model.dart';

class Dialog extends Event {
  Character? speaker;
  final List<Span> _spans;
  List<Span> get spans => UnmodifiableListView(_spans);

  Dialog({this.speaker, List<Span> spans = const []}) : _spans = spans {
    if (_spans.isEmpty) {
      throw ArgumentError.value(
          spans, 'spans', 'must contain at least one span');
    }
  }

  @override
  String toString() {
    return 'Dialog{speaker: $speaker, _spans: $_spans}';
  }

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    return generator.dialogToAsm(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dialog &&
          runtimeType == other.runtimeType &&
          speaker == other.speaker &&
          ListEquality().equals(_spans, other._spans);

  @override
  int get hashCode => speaker.hashCode ^ ListEquality().hash(_spans);
}

class Span {
  final String text;
  final bool italic;

  Span(this.text, this.italic);

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
          _spans.add(Span(text.toString(), italic));
          text.clear();
        }
        italic = !italic;
        continue;
      }

      text.write(c);
    }

    if (text.isNotEmpty) {
      _spans.add(Span(text.toString(), italic));
    }

    return _spans;
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
