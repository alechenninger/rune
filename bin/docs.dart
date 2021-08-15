@JS()
library rune_docs;

import 'package:js/js.dart';
import 'package:rune/gapps/document.dart';

@JS()
external set compileScene(value);

@JS()
external set onOpen(value);

void sayHelloDart() {
  DocumentApp.getUi().alert('Hello world');
}

void onOpenDart(e) {
  DocumentApp.getUi()
      .createMenu('Rune')
      .addItem('Compile scene', 'compileScene')
      .addToUi();
}

void main(List<String> arguments) {
  onOpen = allowInterop(onOpenDart);
  compileScene = allowInterop(compileSceneDart);
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

    var p = heading as Paragraph;
    Logger.log(p);
    Logger.log(p.getHeading());

    if (p.getHeading() == DocumentApp.ParagraphHeading.HEADING2) {
      break;
    }
  }

  if (heading == null) {
    Logger.log('no starting heading found');
    return;
  }

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
    var dialog = p.getChild(1)!;

    if (portrait.getType() != DocumentApp.ElementType.INLINE_IMAGE) {
      Logger.log('First child is not an image: $portrait');
      continue;
    }

    if (dialog.getType() != DocumentApp.ElementType.TEXT) {
      Logger.log('Second child is not text: $dialog');
      continue;
    }

    portrait = portrait as InlineImage;
    dialog = dialog as Text;

    var character = portrait.getAltTitle();
    DocumentApp.getUi().alert('$character: ${dialog.getText()}');
  }
}

bool isContainer(Element e) {
  return [DocumentApp.ElementType.PARAGRAPH].contains(e.getType());
}
