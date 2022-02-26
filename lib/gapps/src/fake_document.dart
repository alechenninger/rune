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

class DocumentApp {
  // external static UI getUi();
  // external static Document create(String name);
  // external static Document getActiveDocument();
  // static HorizontalAlignmentContainer get HorizontalAlignment;
  static final ParagraphHeadingContainer ParagraphHeading =
      ParagraphHeadingContainer();
  static final ElementTypeContainer ElementType = ElementTypeContainer();
}

class Element {
  final ElementType _type;

  ContainerElement? _parent;
  int? _indexInParent;

  Element(this._type);

  void setParent(ContainerElement parent, int indexInParent) {
    _parent = parent;
    _indexInParent = indexInParent;
  }

  InlineImage asInlineImage() => this as InlineImage;

  Paragraph asParagraph() => this as Paragraph;

  Footnote asFootnote() => this as Footnote;

  Text asText() => this as Text;

  Element? getNextSibling() {
    var parent = _parent;

    if (parent == null) {
      return null;
    }

    return parent.getChild(_indexInParent! + 1);
  }

  ContainerElement? getParent() {
    return _parent;
  }

  Element? getPreviousSibling() {
    var parent = _parent;

    if (parent == null) {
      return null;
    }

    return parent.getChild(_indexInParent! - 1);
  }

  ElementType getType() {
    return _type;
  }
}

class ContainerElement extends Element {
  final _children = <Element>[];

  ContainerElement(ElementType type) : super(type);

  // TODO: use append* methods instead
  void addChild(Element el) {
    el.setParent(this, _children.length);
    _children.add(el);
  }

  @override
  Element? getChild(int childIndex) {
    return _children[childIndex];
  }

  @override
  int getChildIndex(Element child) {
    return _children.indexOf(child);
  }

  @override
  int getNumChildren() {
    return _children.length;
  }
}

class Paragraph extends ContainerElement {
  Paragraph() : super(DocumentApp.ElementType.PARAGRAPH);

  @override
  Text editAsText() {
    // TODO: implement editAsText
    throw UnimplementedError();
  }

  @override
  ParagraphHeading getHeading() {
    // TODO: implement getHeading
    throw UnimplementedError();
  }

  @override
  String getText() {
    // TODO: implement getText
    throw UnimplementedError();
  }

  @override
  Paragraph setAlignment(HorizontalAlignment alignment) {
    // TODO: implement setAlignment
    throw UnimplementedError();
  }

  @override
  Paragraph setHeading(ParagraphHeading heading) {
    // TODO: implement setHeading
    throw UnimplementedError();
  }

  @override
  void setText(String text) {
    // TODO: implement setText
  }
}

class InlineImage extends Element {
  final String? altTitle;
  final String? altDescription;

  InlineImage({this.altTitle, this.altDescription})
      : super(DocumentApp.ElementType.INLINE_IMAGE);

  @override
  String? getAltDescription() => altDescription;

  @override
  String? getAltTitle() => altTitle;
}

// class Body extends Element {
//   external Paragraph appendParagraph(String text);
//   external PageBreak appendPageBreak();
//   external Table appendTable([List<List<String>> cells]);
//   external Element getChild(int childIndex);
// }

// This class doesn't really exist in JS. Not sure if this will lead to
// problems.
// class HorizontalAlignmentContainer {
//   external HorizontalAlignment get LEFT;
//   external HorizontalAlignment get CENTER;
//   external HorizontalAlignment get RIGHT;
//   external HorizontalAlignment get JUSTIFY;
// }

class HorizontalAlignment {}

// This class doesn't really exist in JS. Not sure if this will lead to
// problems.
class ParagraphHeadingContainer {
  final NORMAL = ParagraphHeading();
  final HEADING1 = ParagraphHeading();
  final HEADING2 = ParagraphHeading();
  final HEADING3 = ParagraphHeading();
  final HEADING4 = ParagraphHeading();
  final HEADING5 = ParagraphHeading();
  final HEADING6 = ParagraphHeading();
  final TITLE = ParagraphHeading();
  final SUBTITLE = ParagraphHeading();
}

class ParagraphHeading {}

class ElementTypeContainer {
  final INLINE_IMAGE = ElementType();
  final PARAGRAPH = ElementType();
  final TEXT = ElementType();
  final FOOTNOTE = ElementType();
  final FOOTNOTE_SECTION = ElementType();
}

class ElementType {}

class Text extends Element {
  Text() : super(DocumentApp.ElementType.TEXT);

  external Text setFontSize(int sizeOrStart, [int endInclusive, int size]);
  external Text setBold(dynamic valueOrStart, [int endInclusive, bool value]);
  external String getText();
  external bool? isItalic(int offset);
}

// class Table extends Element {
//   external TableCell getCell(int rowIndex, int cellIndex);
//   external Table setBorderColor(String color);
// }

// class TableCell extends Element {
//   external Element getChild(int childIndex);
//   external Text editAsText();
// }

// class PageBreak extends Element {}

class Range {
  external List<RangeElement> getRangeElements();
}

class RangeElement {
  external Element getElement();
  external int getEndOffsetInclusive();
  external int getStartOffset();
  external bool isPartial();
}

class Position {
  external Element getElement();
  external int getOffset();
}

class Logger {
  external static void log(Object? data,
      [Object? val1, Object? val2, Object? val3, Object? val5, Object? val6]);
}

class Footnote extends Element {
  final FootnoteSection _contents;

  Footnote(this._contents) : super(DocumentApp.ElementType.FOOTNOTE);

  FootnoteSection getFootnoteContents() => _contents;
}

class FootnoteSection extends ContainerElement {
  String _text = '';

  FootnoteSection() : super(DocumentApp.ElementType.FOOTNOTE);

  String getText() => _text;
  void setText(String text) => _text = text;
}
