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

library document;

import 'package:rune/gapps/document.dart';

import '../ui.dart';

export '../html.dart';
export '../ui.dart';

class DocumentApp {
  static UI getUi() => throw UnsupportedError('');
  static Document create(String name) => throw UnsupportedError('');
  static Document getActiveDocument() => throw UnsupportedError('');
  static HorizontalAlignmentContainer get HorizontalAlignment =>
      throw UnsupportedError('');
  static ParagraphHeadingContainer get ParagraphHeading =>
      throw UnsupportedError('');
  static ElementTypeContainer get ElementType => throw UnsupportedError('');
}

class Document {
  Body getBody() => throw UnsupportedError('');
  String getId() => throw UnsupportedError('');
  Range? getSelection() => throw UnsupportedError('');
  Position? getCursor() => throw UnsupportedError('');
}

class Element {
  Element? getPreviousSibling() => throw UnsupportedError('');
  Element? getNextSibling() => throw UnsupportedError('');
  ElementType getType() => throw UnsupportedError('');
  ContainerElement? getParent() => throw UnsupportedError('');
  Paragraph asParagraph() => throw UnsupportedError('');
  Text asText() => throw UnsupportedError('');
  InlineImage asInlineImage() => throw UnsupportedError('');
  Footnote asFootnote() => throw UnsupportedError('');
}

class Body extends Element {
  Paragraph appendParagraph(String text) => throw UnsupportedError('');
  PageBreak appendPageBreak() => throw UnsupportedError('');
  Table appendTable([List<List<String>>? cells]) => throw UnsupportedError('');
  Element getChild(int childIndex) => throw UnsupportedError('');
}

class Paragraph extends ContainerElement {
  Paragraph([ParagraphHeading? heading]);
  void addChild(Element element) => throw UnsupportedError('');
  String getText() => throw UnsupportedError('');
  Paragraph setAlignment(HorizontalAlignment alignment) =>
      throw UnsupportedError('');
  Text editAsText() => throw UnsupportedError('');
  void setText(String text) => throw UnsupportedError('');
  Paragraph setHeading(ParagraphHeading heading) => throw UnsupportedError('');
  ParagraphHeading getHeading() => throw UnsupportedError('');
}

// This class doesn't really exist in JS. Not sure if this will lead to
// problems.
class HorizontalAlignmentContainer {
  HorizontalAlignment get LEFT => throw UnsupportedError('');
  HorizontalAlignment get CENTER => throw UnsupportedError('');
  HorizontalAlignment get RIGHT => throw UnsupportedError('');
  HorizontalAlignment get JUSTIFY => throw UnsupportedError('');
}

class HorizontalAlignment {}

// This class doesn't really exist in JS. Not sure if this will lead to
// problems.
class ParagraphHeadingContainer {
  ParagraphHeading get NORMAL => throw UnsupportedError('');
  ParagraphHeading get HEADING1 => throw UnsupportedError('');
  ParagraphHeading get HEADING2 => throw UnsupportedError('');
  ParagraphHeading get HEADING3 => throw UnsupportedError('');
  ParagraphHeading get HEADING4 => throw UnsupportedError('');
  ParagraphHeading get HEADING5 => throw UnsupportedError('');
  ParagraphHeading get HEADING6 => throw UnsupportedError('');
  ParagraphHeading get TITLE => throw UnsupportedError('');
  ParagraphHeading get SUBTITLE => throw UnsupportedError('');
}

class ParagraphHeading {}

class ElementTypeContainer {
  ElementType get PARAGRAPH => throw UnsupportedError('');
  ElementType get INLINE_IMAGE => throw UnsupportedError('');
  ElementType get TEXT => throw UnsupportedError('');
  ElementType get FOOTNOTE => throw UnsupportedError('');
  ElementType get FOOTNOTE_SECTION => throw UnsupportedError('');
}

class ElementType {}

class Text extends Element {
  Text(String text, {bool isItalic = false});
  Text.of(List<Text> texts);
  Text setFontSize(int sizeOrStart, [int? endInclusive, int? size]) =>
      throw UnsupportedError('');
  Text setBold(dynamic valueOrStart, [int? endInclusive, bool? value]) =>
      throw UnsupportedError('');
  String getText() => throw UnsupportedError('');
  bool? isItalic(int offset) => throw UnsupportedError('');
}

class Table extends Element {
  TableCell getCell(int rowIndex, int cellIndex) => throw UnsupportedError('');
  Table setBorderColor(String color) => throw UnsupportedError('');
}

class TableCell extends Element {
  Element getChild(int childIndex) => throw UnsupportedError('');
  Text editAsText() => throw UnsupportedError('');
}

class PageBreak extends Element {}

class Range {
  List<RangeElement> getRangeElements() => throw UnsupportedError('');
}

class RangeElement {
  Element getElement() => throw UnsupportedError('');
  int getEndOffsetInclusive() => throw UnsupportedError('');
  int getStartOffset() => throw UnsupportedError('');
  bool isPartial() => throw UnsupportedError('');
}

class Position {
  Element getElement() => throw UnsupportedError('');
  int getOffset() => throw UnsupportedError('');
}

class Logger {
  static void log(Object? data,
          [Object? val1,
          Object? val2,
          Object? val3,
          Object? val5,
          Object? val6]) =>
      throw UnsupportedError('');
}

class ContainerElement extends Element {
  Element? getChild(int childIndex) => throw UnsupportedError('');
  int getChildIndex(Element child) => throw UnsupportedError('');
  int getNumChildren() => throw UnsupportedError('');
}

class InlineImage extends Element {
  InlineImage({String? altTitle, String? altDescription});

  String? getAltTitle() => throw UnsupportedError('');
  String? getAltDescription() => throw UnsupportedError('');
}

class Footnote extends Element {
  Footnote(FootnoteSection section);
  FootnoteSection getFootnoteContents() => throw UnsupportedError('');
}

class FootnoteSection extends ContainerElement {
  String getText() => throw UnsupportedError('');
  void setText(String text) => throw UnsupportedError('');
}
