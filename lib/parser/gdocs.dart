import 'package:characters/src/extensions.dart';

import '../asm/asm.dart';
import '../gapps/document.dart';
import '../generator/event.dart';
import '../generator/generator.dart';
import '../model/model.dart';

class CompiledScene {
  final SceneId id;
  final SceneAsm asm;

  CompiledScene(this.id, this.asm);
}

// Consider not also doing the generation and just spit out the model instead
/// Parse from the provided [heading] element until the next paragraph heading.
///
/// The heading text will be used as the scene ID unless a [SceneId] tech is
/// found within the heading element.
CompiledScene compileScene(Paragraph heading) {
  var sceneId = Tech.parseFirst<SceneId>(heading) ??
      SceneId.fromString(heading.getText());
  var scene = Scene();

  // now parse elements until next heading
  for (var e = heading.getNextSibling(); e != null; e = e.getNextSibling()) {
    if (e.getType() != DocumentApp.ElementType.PARAGRAPH) {
      continue;
    }

    var p = e.asParagraph();

    if (p.getHeading() != DocumentApp.ParagraphHeading.NORMAL) {
      Logger.log('finishing current scene; new scene detected: ${p.getText()}');
      break;
    }

    if (p.getNumChildren() < 2) {
      if (p.getText().isNotEmpty) {
        Logger.log('not dialog; not enough children: "${p.getText()}"');
      }
      continue;
    }

    // todo: how to order dialog vs tech?

    var d = parseDialog(p);
    if (d != null) {
      Logger.log('${d.speaker}: ${d.spans}');
      scene.addEvent(d);
    }

    var event = Tech.parseFirst<Event>(p);
    if (event != null) {
      Logger.log('found event: "${p.getText()}"');
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
  var portrait = p.getChild(0)!;
  var speech = p.getChild(1)!;

  if (portrait.getType() != DocumentApp.ElementType.INLINE_IMAGE) {
    Logger.log('not dialog; first child is not an image: $portrait');
    return null;
  }

  if (speech.getType() != DocumentApp.ElementType.TEXT) {
    Logger.log('not dialog; second child is not text: $speech');
    return null;
  }

  portrait = portrait as InlineImage;
  speech = speech as Text;

  var speaker = portrait.getAltTitle();
  var text = speech.getText();

  if (speaker == null) {
    Logger.log(
        'not dialog; missing alt text on portrait image for dialog: "$text"');
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
  static final _techs = <String, Object Function(String?)>{
    'scene_id': (c) => SceneId(c!),
    'asm_event': (c) => AsmEvent(Asm.fromMultiline(c!)),
    'pause_seconds': (c) =>
        Pause(Duration(milliseconds: (double.parse(c!) * 1000).toInt()))
  };

  const Tech();

  static T? parseFirst<T>(ContainerElement container) {
    for (var i = 0; i < container.getNumChildren(); i++) {
      Object? tech;

      var child = container.getChild(i);
      if (child?.getType() == DocumentApp.ElementType.INLINE_IMAGE) {
        var img = child!.asInlineImage();
        if (img.getAltTitle()?.startsWith('tech:') == true) {
          var type = img.getAltTitle()!.substring(5).trim();

          Logger.log('found tech. type=$type container=$container');

          var content = img.getAltDescription();
          tech = _techForType(type, content);
        }
      }

      if (tech != null && tech is T) {
        Logger.log('tech is desired type. T=$T');
        return tech as T;
      }
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
