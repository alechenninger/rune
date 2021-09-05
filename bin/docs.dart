@JS()
library rune_docs;

import 'package:js/js.dart';
import 'package:rune/gapps/document.dart';
import 'package:rune/gapps/drive.dart';
import 'package:rune/parser/gdocs.dart';

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
  var heading = findHeadingForCursor(cursor);

  if (heading == null) {
    Logger.log('no starting heading found');
    return;
  }

  var scene = parseScene(heading.asParagraph());

  var folder = DriveApp.getFolderById('__RUNE_DRIVE_FOLDER_ID__');
  updateFile(folder, '${scene.id}_dialog.asm', scene.asm.dialog.toString());
  // event asm
}

Paragraph? findHeadingForCursor(Position cursor) {
  Paragraph? found;

  for (Element? heading = cursor.getElement();
      heading != null;
      heading = heading.getPreviousSibling() ?? heading.getParent()) {
    if (heading.getType() != DocumentApp.ElementType.PARAGRAPH) {
      continue;
    }

    var p = heading.asParagraph();

    if (p.getHeading() != DocumentApp.ParagraphHeading.NORMAL) {
      found = p;
      break;
    }
  }

  return found;
}

File updateFile(Folder folder, String name, String content) {
  var files = folder.getFilesByName(name);
  if (files.hasNext()) {
    return files.next().setContent(content);
  }
  return folder.createFile(name, content);
}

Folder folderByName(Folder parent, String name) {
  var folders = parent.getFoldersByName(name);
  if (folders.hasNext()) {
    return folders.next();
  }
  return parent.createFolder(name);
}
