@JS()
library rune_docs;

import 'package:characters/src/extensions.dart';
import 'package:js/js.dart';
import 'package:rune/asm/asm.dart';
import 'package:rune/gapps/document.dart';
import 'package:rune/gapps/drive.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/model/model.dart';

@JS()
external set compileSceneLib(value);

@JS()
external set onOpenLib(value);

void onOpenDart(e) {
  DocumentApp.getUi()
      .createMenu('Rune')
      .addItem('Compile scene', 'compileScene')
      .addToUi();
}

void main(List<String> arguments) {
  onOpenLib = allowInterop(onOpenDart);
  compileSceneLib = allowInterop(compileSceneDart);
}

void compileSceneDart() {
  var cursor = DocumentApp.getActiveDocument().getCursor();

  if (cursor == null) return;

  // find the starting element;
  Element? heading;

  for (heading = cursor.getElement();
      heading != null;
      heading = heading.getPreviousSibling() ?? heading.getParent()) {
    if (heading.getType() != DocumentApp.ElementType.PARAGRAPH) {
      continue;
    }

    var p = heading.asParagraph();

    if (p.getHeading() != DocumentApp.ParagraphHeading.NORMAL) {
      break;
    }
  }

  if (heading == null) {
    Logger.log('no starting heading found');
    return;
  }

  var sceneId = Tech.parseFirst<SceneId>(heading.asParagraph())?.id ??
      toFileSafe(heading.asParagraph().getText());
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

  var folder = DriveApp.getFolderById('__RUNE_DRIVE_FOLDER_ID__');
  updateFile(folder, '${sceneId}_dialog.asm', dialogAsm.toString());
  // event asm
}

bool isContainer(Element e) {
  return [DocumentApp.ElementType.PARAGRAPH].contains(e.getType());
}

bool nullToFalse(bool? b) => b ?? false;

Folder folderByName(Folder parent, String name) {
  var folders = parent.getFoldersByName(name);
  if (folders.hasNext()) {
    return folders.next();
  }
  return parent.createFolder(name);
}

File updateFile(Folder folder, String name, String content) {
  var files = folder.getFilesByName(name);
  if (files.hasNext()) {
    return files.next().setContent(content);
  }
  return folder.createFile(name, content);
}

abstract class Tech {
  static final _techs = <String, Tech Function(String?)>{
    'scene_id': (c) => SceneId(c!)
  };

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

  SceneId(this.id);
}

String toFileSafe(String name) {
  return name.replaceAll(RegExp('[\s().]'), '_');
}
