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
// ignore: camel_case_types
class console {
  external static void error(formatOrObject, [val1, val2, val4, val5, val6]);
  external static void info(formatOrObject, [val1, val2, val4, val5, val6]);
  external static void log(formatOrObject, [val1, val2, val4, val5, val6]);
  external static void warn(formatOrObject, [val1, val2, val4, val5, val6]);
  external static void time(String label);
  external static void timeEnd(String label);
}
