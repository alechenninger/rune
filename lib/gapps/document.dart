// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@JS()
library document;

import 'package:js/js.dart';

import 'ui.dart';

export 'html.dart';
export 'ui.dart';

@JS()
class DocumentApp {
  external static UI getUi();
  external static Document create(String name);
  external static Document getActiveDocument();
  external static HorizontalAlignmentContainer get HorizontalAlignment;
  external static ParagraphHeadingContainer get ParagraphHeading;
  external static ElementTypeContainer get ElementType;
}

@JS()
class Document {
  external Body getBody();
  external String getId();
  external Range? getSelection();
  external Position? getCursor();
}

@JS()
class Element {
  external Element? getPreviousSibling();
  external Element? getNextSibling();
  external ElementType getType();
  external ContainerElement? getParent();
  external Paragraph asParagraph();
  external Text asText();
  external InlineImage asInlineImage();
}

@JS()
class Body extends Element {
  external Paragraph appendParagraph(String text);
  external PageBreak appendPageBreak();
  external Table appendTable([List<List<String>> cells]);
  external Element getChild(int childIndex);
}

@JS()
class Paragraph extends ContainerElement {
  external Paragraph setAlignment(HorizontalAlignment alignment);
  external Text editAsText();
  external void setText(String text);
  external Paragraph setHeading(ParagraphHeading heading);
  external ParagraphHeading getHeading();
}

// This class doesn't really exist in JS. Not sure if this will lead to
// problems.
@JS()
class HorizontalAlignmentContainer {
  external HorizontalAlignment get LEFT;
  external HorizontalAlignment get CENTER;
  external HorizontalAlignment get RIGHT;
  external HorizontalAlignment get JUSTIFY;
}

@JS()
class HorizontalAlignment {}

// This class doesn't really exist in JS. Not sure if this will lead to
// problems.
@JS()
class ParagraphHeadingContainer {
  external ParagraphHeading get NORMAL;
  external ParagraphHeading get HEADING1;
  external ParagraphHeading get HEADING2;
  external ParagraphHeading get HEADING3;
  external ParagraphHeading get HEADING4;
  external ParagraphHeading get HEADING5;
  external ParagraphHeading get HEADING6;
  external ParagraphHeading get TITLE;
  external ParagraphHeading get SUBTITLE;
}

@JS()
class ParagraphHeading {}

@JS()
class ElementTypeContainer {
  external ElementType get PARAGRAPH;
  external ElementType get INLINE_IMAGE;
  external ElementType get TEXT;
}

@JS()
class ElementType {}

@JS()
class Text extends Element {
  external Text setFontSize(int sizeOrStart, [int endInclusive, int size]);
  external Text setBold(dynamic valueOrStart, [int endInclusive, bool value]);
  external String getText();
}

@JS()
class Table extends Element {
  external TableCell getCell(int rowIndex, int cellIndex);
  external Table setBorderColor(String color);
}

@JS()
class TableCell extends Element {
  external Element getChild(int childIndex);
  external Text editAsText();
}

@JS()
class PageBreak extends Element {}

@JS()
class Range {
  external List<RangeElement> getRangeElements();
}

@JS()
class RangeElement {
  external Element getElement();
  external int getEndOffsetInclusive();
  external int getStartOffset();
  external bool isPartial();
}

@JS()
class Position {
  external Element getElement();
  external int getOffset();
}

@JS()
class Logger {
  external static void log(Object? data,
      [Object? val1, Object? val2, Object? val3, Object? val5, Object? val6]);
}

@JS()
class ContainerElement extends Element {
  external Element? getChild(int childIndex);
  external int getChildIndex(Element child);
  external int getNumChildren();
}

@JS()
class InlineImage extends Element {
  external String getAltTitle();
}
