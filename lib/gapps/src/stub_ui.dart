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

library ui;

import '../html.dart';

export '../html.dart';

class UI {
  ButtonSetContainer get ButtonSet => throw UnsupportedError('');

  void prompt(String msg) => throw UnsupportedError('');
  void alert(String titleOrPrompt,
          [dynamic promptOrButtonSet, ButtonSetEnum? buttonSet]) =>
      throw UnsupportedError('');
  Menu createMenu(String caption) => throw UnsupportedError('');
  Menu createAddonMenu() => throw UnsupportedError('');
  void showModalDialog(HtmlOutput userInterface, String title) =>
      throw UnsupportedError('');
  void showSidebar(HtmlOutput userInterface) => throw UnsupportedError('');
}

class Menu {
  Menu addItem(String caption, String functionName) =>
      throw UnsupportedError('');
  Menu addSeparator() => throw UnsupportedError('');
  Menu addSubMenu(Menu menu) => throw UnsupportedError('');
  void addToUi() => throw UnsupportedError('');
}

class ButtonSetContainer {
  ButtonSetEnum get OK => throw UnsupportedError('');
  ButtonSetEnum get OK_CANCEL => throw UnsupportedError('');
  ButtonSetEnum get YES_NO => throw UnsupportedError('');
  ButtonSetEnum get YES_NO_CANCEL => throw UnsupportedError('');
}

class ButtonSetEnum {}

class Button {}
