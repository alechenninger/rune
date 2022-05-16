@JS()
library rune_docs;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:logging/logging.dart' as logging;
import 'package:rune/gapps/console.dart';
import 'package:rune/gapps/document.dart';
import 'package:rune/gapps/drive.dart';
import 'package:rune/gapps/lock.dart';
import 'package:rune/gapps/script.dart';
import 'package:rune/gapps/urlfetch.dart';
import 'package:rune/gapps/utilities.dart';
import 'package:rune/parser/gdocs.dart' as gdocs;
import 'package:rune/src/logging.dart';

@JS()
external set compileSceneAtCursorLib(value);

@JS()
external set onOpenLib(value);

void onOpenDart(e) {
  DocumentApp.getUi()
      .createMenu('Rune')
      .addSubMenu(DocumentApp.getUi()
          .createMenu('Compile')
          .addItem('Scene at cursor', 'compileSceneAtCursor'))
      .addToUi();
}

void main(List<String> arguments) {
  onOpenLib = allowInterop(onOpenDart);
  compileSceneAtCursorLib = allowInterop(compileSceneAtCursorDart);
}

void initLogging() {
  logging.Logger.root.level = logging.Level.FINER;
  logging.Logger.root.onRecord.listen(googleCloudLogging(logger));
}

void logger(object, logging.Level level) {
  Logger.log(jsify(object));
}

void consolePrinter(object, logging.Level level) {
  if (level >= logging.Level.SEVERE) {
    console.error(jsify(object));
  } else if (level >= logging.Level.WARNING) {
    console.warn(jsify(object));
  } else if (level >= logging.Level.CONFIG) {
    console.info(jsify(object));
  } else {
    console.log(jsify(object));
  }
}

var log = logging.Logger('docs');

void compileSceneAtCursorDart() {
  initLogging();

  var cursor = DocumentApp.getActiveDocument().getCursor();

  var ui = DocumentApp.getUi();
  if (cursor == null) {
    log.i(e('no_cursor'));
    ui.alert(
        'No cursor found',
        'Make sure your cursor is placed with a section under a heading with '
            'a "scene_id" tech.',
        ui.ButtonSet.OK);
    return;
  }

  // find the starting element;
  var heading = findHeadingForCursor(cursor);
  gdocs.CompiledScene? scene;

  if (heading == null) {
    log.i(e('no_heading_for_cursor'));
  } else {
    console.time('compile_scene');
    try {
      scene = gdocs.compileSceneAtHeading(heading.asParagraph());
    } finally {
      console.timeEnd('compile_scene');
    }
  }

  if (scene == null) {
    log.i(e('no_scene_at_cursor'));
    ui.alert(
        'No scene found at cursor',
        'Make sure your cursor is placed with a section under a heading with a '
            '"scene_id" tech.',
        ui.ButtonSet.OK);
    return;
  }

  console.time('update_rom');

  String url;
  var lock = LockService.getDocumentLock();

  try {
    lock.waitLock(30 * 1000);

    var checksums = uploadToDrive(scene);
    url = updateRom(checksums);
  } finally {
    console.timeEnd('update_rom');
  }

  showBuildComplete(url);

  lock.releaseLock();
}

void showBuildComplete(url) {
  var template = HtmlService.createTemplateFromFile('download.html')..url = url;
  var html = template.evaluate().setWidth(400).setHeight(75);
  DocumentApp.getUi().showModalDialog(html, 'Build complete');
}

String updateRom(List<Checksum> checksums) {
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

  return url;
}

List<Checksum> uploadToDrive(gdocs.CompiledScene scene) {
  var folder = DriveApp.getFolderById('__RUNE_DRIVE_FOLDER_ID__');

  var dialogAsm = scene.asm.allDialog.toString();
  var eventAsm = scene.asm.event.toString();

  var dialogFile = updateFile(folder, '${scene.id}_dialog.asm', dialogAsm);
  var eventFile = updateFile(folder, '${scene.id}_event.asm', eventAsm);

  var checksums = [hash(dialogFile, dialogAsm), hash(eventFile, eventAsm)];

  return checksums;
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
