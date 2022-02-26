import 'package:characters/src/extensions.dart';
import 'package:logging/logging.dart';
import 'package:rune/parser/movement.dart';

import '../asm/asm.dart';
import '../gapps/document.dart' hide Logger if (dart.library.io) '../gapps/fake_document.dart';
import '../generator/generator.dart';
import '../generator/scene.dart';
import '../model/model.dart';
import '../src/logging.dart';

class CompiledScene {
  final SceneId id;
  final SceneAsm asm;

  CompiledScene(this.id, this.asm);
}

var log = Logger('parser/gdocs');

// Consider not also doing the generation and just spit out the model instead
/// Parse from the provided [heading] element until the next paragraph heading.
///
/// The heading text will be used as the scene ID unless a [SceneId] tech is
/// found within the heading element.
CompiledScene? compileSceneAtHeading(Paragraph heading) {
  var sceneId = Tech.parse<SceneId>(heading);

  if (sceneId == null) {
    return null;
  }

  var scene = Scene();

  // now parse elements until next heading
  for (var el = heading.getNextSibling();
      el != null;
      el = el.getNextSibling()) {
    if (el.getType() != DocumentApp.ElementType.PARAGRAPH) {
      continue;
    }

    var p = el.asParagraph();

    if (p.getHeading() != DocumentApp.ParagraphHeading.NORMAL) {
      log.f(e('parsed_scene_end_from_heading', {'heading': p.getText()}));
      break;
    }

    // todo: how to order dialog vs tech?
    var d = parseDialog(p);
    if (d != null) {
      log.f(e('parsed_dialog', {
        'speaker': d.speaker.toString(),
        'spans': d.spans.map((e) => {'text': e.text, 'italic': e.italic})
      }));
      scene.addEvent(d);
    }

    var event = Tech.parse<Event>(p);
    if (event != null) {
      log.f(
          e('parsed_event', {'event': event.toString(), 'text': p.getText()}));
      scene.addEvent(event);
    }
  }

  return CompiledScene(sceneId, scene.toAsm());
}

final RegExp _pause = RegExp(r'.*[Pp]auses? for (\d+) seconds?.*');
Pause? parsePause(Paragraph p) {
  var text = p.getText();
  var match = _pause.firstMatch(text);
  if (match == null) return null;
  var seconds = match.group(1);
  if (seconds == null) return null;
  return Pause(Duration(milliseconds: (double.parse(seconds) * 1000).toInt()));
}

Dialog? parseDialog(Paragraph p) {
  if (p.getNumChildren() < 2) {
    if (p.getText().isNotEmpty) {
      log.f(e('not_dialog', {
        'reason': 'not enough children',
        'text': p.getText(),
        'children#': p.getNumChildren()
      }));
    }
    return null;
  }

  var portrait = p.getChild(0)!;
  var speech = p.getChild(1)!;

  if (portrait.getType() != DocumentApp.ElementType.INLINE_IMAGE) {
    log.f(e('not_dialog', {
      'reason': 'first child is not an image',
      'firstChild': portrait.toString(),
    }));
    return null;
  }

  if (speech.getType() != DocumentApp.ElementType.TEXT) {
    log.f(e('not_dialog', {
      'reason': 'second child is not text',
      'secondChild': speech.toString(),
    }));
    return null;
  }

  portrait = portrait as InlineImage;
  speech = speech as Text;

  var speaker = portrait.getAltTitle();
  var text = speech.getText();

  if (speaker == null) {
    log.f(e('not_dialog', {
      'reason': 'missing alt text on portrait image for dialog',
      'text': text
    }));
    return null;
  }

  if (speaker.startsWith('tech:')) {
    log.f(e('not_dialog',
        {'reason': 'inline image is tech', 'text': text, 'tech': speaker}));
    return null;
  }

  var offset = text.length - text.trimLeft().length;
  var characters = text.trim().characters;
  var spans = <Span>[];
  var italic = false;
  var buffer = StringBuffer();

  for (var i = 0; i < characters.length; i++) {
    if (italic != nullToFalse(speech.isItalic(i + offset))) {
      if (buffer.isNotEmpty) {
        spans.add(Span(buffer.toString(), italic));
        buffer.clear();
      }
      italic = !italic;
    }
    buffer.write(characters.elementAt(i));
  }

  if (buffer.isNotEmpty) {
    spans.add(Span(buffer.toString(), italic));
  }

  var character = Character.byName(speaker);
  return Dialog(speaker: character, spans: spans);
}

bool nullToFalse(bool? b) => b ?? false;

abstract class Tech {
  static final _inlineTechP = RegExp(r'---\ntech:(\w+)\n---\n');

  static final _techs = <String, Object Function(String?)>{
    'scene_id': (c) => SceneId(c!),
    'asm_event': (c) => AsmEvent(Asm.fromRaw(c!)),
    'pause_seconds': (c) =>
        Pause(Duration(milliseconds: (double.parse(c!) * 1000).toInt())),
    'event': (c) => parseEvent(c!),
    'aggregate': (c) {
      var events = <Event>[];

      for (var match in _inlineTechP.allMatches(c!)) {
        var type = match.group(1);
        var remaining = c.substring(match.end);

        var nextMatch = _inlineTechP.firstMatch(remaining);
        if (nextMatch != null) {
          remaining = remaining.substring(0, nextMatch.start);
        }

        var tech = _techForType(type!, remaining);
        // TODO: else
        if (tech is Event) {
          events.add(tech);
        }
      }

      return AggregateEvent(events);
    }
  };

  const Tech();

  static T? parse<T>(ContainerElement container) {
    var techs = <Object>[];

    for (var i = 0; i < container.getNumChildren(); i++) {
      var child = container.getChild(i);

      if (child?.getType() == DocumentApp.ElementType.INLINE_IMAGE) {
        var img = child!.asInlineImage();
        if (img.getAltTitle()?.startsWith('tech:') == true) {
          var type = img.getAltTitle()!.substring(5).trim();

          log.f(e('found_tech',
              {'type': type.toString(), 'container': container.toString()}));

          var content = img.getAltDescription();
          techs.add(_techForType(type, content));
        }
      }
    }

    if (techs.length == 1 && techs.first is T) {
      log.f(e('parsed_tech', {'type': T.toString()}));
      return techs.first as T;
    }

    if (AggregateEvent is T && techs.every((t) => t is Event)) {
      return AggregateEvent(techs.cast<Event>()) as T;
    }
  }

  static Object _techForType(String type, String? content) {
    var factory = _techs[type];
    if (factory == null) {
      throw ArgumentError.value(type, 'type',
          'unsupported tech type. expected one of: ${_techs.keys}');
    }
    return factory(content);
  }
}

// todo: move this somewhere else? used by scene_source
class SceneId {
  final String id;

  SceneId(this.id) {
    // todo validate filesafe
  }

  SceneId.fromString(String id) : id = _toFileSafe(id);

  @override
  String toString() => id;
}

class AsmEvent implements Event {
  final Asm asm;

  AsmEvent(this.asm);

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    // raw asm a bit fragile! ctx not updated
    return asm;
  }
}

String _toFileSafe(String name) {
  return name.replaceAll(RegExp('[\s().]'), '_');
}

class UnsupportedTechException implements Exception {
  final String tech;

  UnsupportedTechException(this.tech);

  @override
  String toString() {
    return 'UnsupportedTechException{tech: $tech}';
  }
}
