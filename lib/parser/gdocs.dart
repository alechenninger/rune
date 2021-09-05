import 'package:characters/src/extensions.dart';

import '../asm/asm.dart';
import '../gapps/document.dart';
import '../generator/dialog.dart';
import '../generator/event.dart';
import '../model/model.dart';

class CompiledScene {
  final SceneId id;
  final SceneAsm asm;

  CompiledScene(this.id, this.asm);
}

CompiledScene parseScene(Paragraph heading) {
  var sceneId = Tech.parseFirst<SceneId>(heading) ??
      SceneId.fromString(heading.getText());
  var dialog = <Dialog>[];

  // now parse elements until next heading
  for (var e = heading.getNextSibling(); e != null; e = e.getNextSibling()) {
    if (e.getType() != DocumentApp.ElementType.PARAGRAPH) {
      continue;
    }

    var p = e.asParagraph();

    if (p.getNumChildren() < 2) {
      if (p.getText().isNotEmpty) {
        Logger.log('not dialog; not enough children: "${p.getText()}"');
      }

      // Is there relevant tech though?
      var event = Tech.parseFirst<AsmEvent>(p);
      if (event != null) {}

      continue;
    }

    var portrait = p.getChild(0)!;
    var speech = p.getChild(1)!;

    if (portrait.getType() != DocumentApp.ElementType.INLINE_IMAGE) {
      Logger.log('First child is not an image: $portrait');
      continue;
    }

    if (speech.getType() != DocumentApp.ElementType.TEXT) {
      Logger.log('Second child is not text: $speech');
      continue;
    }

    portrait = portrait as InlineImage;
    speech = speech as Text;

    var speaker = portrait.getAltTitle();
    var text = speech.getText();

    if (speaker == null) {
      Logger.log('Missing alt text on portrait image for dialog: "$text"');
      continue;
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
    var d = Dialog(speaker: character, spans: spans);
    Logger.log('${d.speaker}: ${d.spans}');
    dialog.add(d);
  }

  var dialogAsm = Asm.empty();
  dialog.forEach((d) => dialogAsm.add(d.toAsm()));

  var scene = CompiledScene(sceneId, SceneAsm(Asm.empty(), dialogAsm));
  return scene;
}

bool nullToFalse(bool? b) => b ?? false;

abstract class Tech {
  static final _techs = <String, Tech Function(String?)>{
    'scene_id': (c) => SceneId(c!),
    'asm_event': (c) => AsmEvent(Asm.fromMultiline(c!))
  };

  const Tech();

  static T? parseFirst<T extends Tech>(ContainerElement container) {
    for (var i = 0; i < container.getNumChildren(); i++) {
      Tech? tech;

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
        return tech;
      }
    }
  }

  static Tech _techForType(String type, String? content) {
    var factory = _techs[type];
    if (factory == null) {
      throw ArgumentError.value(type, 'type',
          'unsupported tech type. expected one of: ${_techs.keys}');
    }
    return factory(content);
  }
}

class SceneId extends Tech {
  final String id;

  SceneId(this.id) {
    // todo validate filesafe
  }

  SceneId.fromString(String id) : id = _toFileSafe(id);

  @override
  String toString() => id;
}

class AsmEvent extends Tech {
  final Asm asm;

  AsmEvent(this.asm);
}

String _toFileSafe(String name) {
  return name.replaceAll(RegExp('[\s().]'), '_');
}
