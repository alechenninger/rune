import 'package:characters/characters.dart';
import 'package:logging/logging.dart';
import 'package:rune/parser/movement.dart';

import '../gapps/document.dart'
    if (dart.library.io) '../gapps/src/fake_document.dart' hide Logger;
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
  var sceneId = Tech.parse<SceneId>(heading)?.onlyOne();

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

    Tech.parse<Event>(p)?.forEach((event) {
      log.f(
          e('parsed_event', {'event': event.toString(), 'text': p.getText()}));
      scene.addEvent(event);
    });
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

const narrativeTextPrefix = 'narrative text:';
Dialog? parseDialog(Paragraph p) {
  if (p.getNumChildren() < 2) {
    var text = p.getText();
    if (text.isNotEmpty) {
      if (p.getNumChildren() == 1 &&
          text.trimLeft().toLowerCase().startsWith(narrativeTextPrefix)) {
        var speech = p.getChild(0)!;
        return dialogForText(speech.asText(), skip: narrativeTextPrefix.length);
      }

      log.f(e('not_dialog', {
        'reason':
            'not enough children and did not start with "$narrativeTextPrefix"',
        'text': p.getText(),
        'children#': p.getNumChildren()
      }));
    }
    return null;
  }

  var portrait = p.getChild(0)!;
  var speech = p.getChild(1)!;

  return dialogFromPortrait(portrait, speech);
}

Dialog? dialogFromPortrait(Element portrait, Element speech) {
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

  if (speaker == null) {
    log.f(e('not_dialog', {
      'reason': 'missing alt text on portrait image for dialog',
      'text': speech.getText()
    }));
    return null;
  }

  if (speaker.startsWith('tech:')) {
    log.f(e('not_dialog', {
      'reason': 'inline image is tech',
      'text': speech.getText(),
      'tech': speaker
    }));
    return null;
  }

  return dialogForText(speech, speaker: speaker);
}

Dialog dialogForText(Text speech, {String? speaker, int skip = 0}) {
  var text = speech.getText();
  var skippedText = text.substring(skip);
  var offset = skip + skippedText.length - skippedText.trimLeft().length;
  var characters = text.characters;
  var spans = <Span>[];
  var italic = false;
  var buffer = StringBuffer();

  for (var i = offset; i < characters.length; i++) {
    if (italic != nullToFalse(speech.isItalic(i))) {
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

  var character = speaker != null ? Character.byName(speaker) : null;
  return Dialog(speaker: character, spans: spans);
}

bool nullToFalse(bool? b) => b ?? false;

class Tech {
  static final _inlineTechP = RegExp(r'---\ntech:(\w+)\n---\n');

  static final _techs = <String, List<Object> Function(String?)>{
    'scene_id': (c) => [SceneId(c!)],
    'asm_event': (c) => [AsmEvent(Asm.fromRaw(c!))],
    'pause_seconds': (c) =>
        [Pause(Duration(milliseconds: (double.parse(c!) * 1000).toInt()))],
    'event': (c) => parseEvents(c!),
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
        if (tech.every((t) => t is Event)) {
          events.addAll(tech.cast<Event>());
        }
      }

      return events;
    }
  };

  const Tech();

  static List<T>? parse<T>(ContainerElement container) {
    var techs = <T>[];

    for (var i = 0; i < container.getNumChildren(); i++) {
      var child = container.getChild(i)!;
      var parsed = <Object>[];

      if (child.getType() == DocumentApp.ElementType.INLINE_IMAGE) {
        var img = child.asInlineImage();
        parsed = _fromInlineImage(img);
      } else if (child.getType() == DocumentApp.ElementType.FOOTNOTE) {
        var fn = child.asFootnote();
        parsed = _fromFootnote(fn);
      }

      if (parsed.every((t) => t is T)) {
        techs.addAll(parsed.cast<T>());
      }
    }

    log.f(e('parsed_tech',
        {'type': '$T', 'techs': techs.map((t) => t.toString())}));

    return techs;
  }

  static List<Object> _fromInlineImage(InlineImage img) {
    if (img.getAltTitle()?.startsWith('tech:') == true) {
      var type = img.getAltTitle()!.substring(5).trim();

      log.f(e('found_tech',
          {'type': type.toString(), 'container': 'inline_image'}));

      var content = img.getAltDescription();

      return _techForType(type, content);
    }

    return [];
  }

  static List<Object> _fromFootnote(Footnote fn) {
    return _techForType('event', fn.getFootnoteContents().getText());
  }

  static List<Object> _techForType(String type, String? content) {
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
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    // raw asm a bit fragile! ctx not updated
    return asm;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsmEvent && runtimeType == other.runtimeType && asm == other.asm;

  @override
  int get hashCode => asm.hashCode;
}

String _toFileSafe(String name) {
  return name.replaceAll(RegExp(r'[\s().]'), '_');
}

class UnsupportedTechException implements Exception {
  final String tech;

  UnsupportedTechException(this.tech);

  @override
  String toString() {
    return 'UnsupportedTechException{tech: $tech}';
  }
}

extension OnlyOne<T> on List<T> {
  T onlyOne({Object Function() errorIfTooMany = _tooManyElements}) {
    if (length > 1) {
      throw errorIfTooMany();
    }
    return first;
  }
}

Object _tooManyElements() {
  return "too many elements";
}
