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
    Logger.log(heading);

    if (heading.getType() != DocumentApp.ElementType.PARAGRAPH) {
      continue;
    }

    var p = heading.asParagraph();
    Logger.log(p);
    Logger.log(p.getHeading());

    if (p.getHeading() != DocumentApp.ParagraphHeading.NORMAL) {
      break;
    }
  }

  if (heading == null) {
    Logger.log('no starting heading found');
    return;
  }

  var dialog = <Dialog>[];

  // now parse elements until next heading
  for (var e = heading.getNextSibling(); e != null; e = e.getNextSibling()) {
    if (e.getType() != DocumentApp.ElementType.PARAGRAPH) {
      continue;
    }

    var p = e.asParagraph();

    if (p.getNumChildren() < 2) {
      Logger.log('Not enough children: "${p.editAsText().toString()}"');
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
    Logger.log('speaker: $speaker, character: $character');
    var d = Dialog(speaker: character, spans: spans);
    Logger.log(d);
    dialog.add(d);
  }

  var dialogAsm = Asm.empty();
  dialog.forEach((d) => dialogAsm.add(d.toAsm()));

  var folder = DriveApp.getFolderById('secret');
  var scene = folderByName(folder, 'name');
  updateFile(scene, 'dialog.asm', dialogAsm.toString());
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