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
class Utilities {
  external static DigestAlgorithmContainer get DigestAlgorithm;

  external static List<int> computeDigest(
      DigestAlgorithmType algorithm, String value);
  external static String base64Encode(List<int> bytes);
}

@JS()
class DigestAlgorithmContainer {
  external DigestAlgorithmType get MD5;
}

@JS()
class DigestAlgorithmType {}