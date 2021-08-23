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
library drive;

import 'package:js/js.dart';

@JS()
class DriveApp {
  external static File createFile(String name, String content);
  external static Folder getRootFolder();
  external static File getFileById(String id);
  external static Folder getFolderById(String id);
}

@JS()
class File {
  external String getId();
  external String getDownloadUrl();
  external File setContent(String content);
}

@JS()
class Folder {
  external String getId();
  external Folder createFolder(String name);
  external File createFile(String name, String content);
  external FolderIterator getFoldersByName(String name);
  external FileIterator getFilesByName(String name);
}

@JS()
class FolderIterator {
  external bool hasNext();
  external Folder next();
  external String getContinuationToken();
}

@JS()
class FileIterator {
  external bool hasNext();
  external File next();
  external String getContinuationToken();
}
