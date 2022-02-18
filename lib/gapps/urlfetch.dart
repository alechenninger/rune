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
library script;

import 'package:js/js.dart';

@JS()
class UrlFetchApp {
  external static HTTPResponse fetch(String url, [Options options]);
}

@JS()
class HTTPResponse {
  external String getContentText([String charset]);
  external int getResponseCode();
}

@JS()
@anonymous
class Options {
  external String get method;
  external String get contentType;
  external get payload;

  external factory Options(
      {String method, String contentType, String payload, Headers headers});
}

@JS()
@anonymous
class Headers {
  external get authorization;

  external factory Headers({String authorization});
}
//var digest = Utilities.computeDigest(Utilities.DigestAlgorithm.MD5, "input to hash");
