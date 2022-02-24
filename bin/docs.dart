@JS()
library rune_docs;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:js/js.dart';
import 'package:logging/logging.dart';
import 'package:rune/gapps/console.dart';
import 'package:rune/gapps/document.dart' hide Logger;
import 'package:rune/gapps/drive.dart';
import 'package:rune/gapps/lock.dart';
import 'package:rune/gapps/script.dart';
import 'package:rune/gapps/urlfetch.dart';
import 'package:rune/gapps/utilities.dart';
import 'package:rune/parser/gdocs.dart' as gdocs;
import 'package:rune/src/logging.dart';

@JS()
external set compileSceneLib(value);

@JS()
external set onOpenLib(value);

void onOpenDart(e) {
  DocumentApp.getUi()
      .createMenu('Rune')
      .addItem('Compile scene', 'compileScene')
      .addToUi();

  initLogging();
}

void main(List<String> arguments) {
  onOpenLib = allowInterop(onOpenDart);
  compileSceneLib = allowInterop(compileSceneDart);
}

void initLogging() {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen(googleCloudLogging(consolePrinter));
}

void consolePrinter(object, Level level) {
  if (level >= Level.SEVERE) {
    console.error(object);
  } else if (level >= Level.WARNING) {
    console.warn(object);
  } else if (level >= Level.CONFIG) {
    console.info(object);
  } else {
    console.log(object);
  }
}

var log = Logger('docs');

void compileSceneDart() {
  var cursor = DocumentApp.getActiveDocument().getCursor();

  if (cursor == null) return;

  // find the starting element;
  var heading = findHeadingForCursor(cursor);

  if (heading == null) {
    log.i(e('no_heading'));
    return;
  }

  var scene = gdocs.compileScene(heading.asParagraph());

  var lock = LockService.getDocumentLock();
  lock.waitLock(30 * 1000);

  var folder = DriveApp.getFolderById('__RUNE_DRIVE_FOLDER_ID__');

  var dialogAsm = scene.asm.dialog.toString();
  var eventAsm = scene.asm.event.toString();

  var dialogFile = updateFile(folder, '${scene.id}_dialog.asm', dialogAsm);
  var eventFile = updateFile(folder, '${scene.id}_event.asm', eventAsm);

  var checksums = [hash(dialogFile, dialogAsm), hash(eventFile, eventAsm)];

  var response = UrlFetchApp.fetch(
      '__RUNE_BUILD_SERVER__',
      Options(
          method: 'post',
          contentType: 'application/json',
          payload: jsonEncode(checksums),
          headers: Headers(
              authorization: 'Bearer ${ScriptApp.getIdentityToken()}')));

  var text = response.getContentText('UTF-8');

  var object = json.decode(text);
  var url = object['uri'];
  var template = HtmlService.createTemplateFromFile('download.html')..url = url;
  var html = template.evaluate().setWidth(400).setHeight(75);
  DocumentApp.getUi().showModalDialog(html, 'Build complete');

  lock.releaseLock();
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

Checksum hash(File file, String content) {
  var digest = Utilities.computeDigest(Utilities.DigestAlgorithm.MD5, content);
  return Checksum(fileId: file.getId(), md5: Digest(digest).toString());
}

class Checksum {
  final String fileId;
  final String md5;

  Checksum({required this.fileId, required this.md5});

  Map toJson() {
    return {'fileId': fileId, 'md5': md5};
  }
}
