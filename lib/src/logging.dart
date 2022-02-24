import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

extension TerseLog on Logger {
  void i(Object? message, [Object? error, StackTrace? stackTrace, Zone? zone]) {
    log(Level.INFO, message, error, stackTrace, zone);
  }

  void e(Object? message, [Object? error, StackTrace? stackTrace, Zone? zone]) {
    log(Level.SEVERE, message, error, stackTrace, zone);
  }

  void w(Object? message, [Object? error, StackTrace? stackTrace, Zone? zone]) {
    log(Level.WARNING, message, error, stackTrace, zone);
  }

  void f(Object? message, [Object? error, StackTrace? stackTrace, Zone? zone]) {
    log(Level.FINE, message, error, stackTrace, zone);
  }
}

void _printPrinter(object, _) => print(object);

void Function(LogRecord) googleCloudLogging(
    [void Function(Object, Level) printer = _printPrinter]) {
  var jsonEncoder = JsonEncoder.withIndent(null, (o) {
    if (o is Iterable) return o.toList(growable: false);
    return o.toJson();
  });

  return (LogRecord r) {
    var object = _toJson(r.object);
    var error = _errToJson(r.error);
    var stack = r.stackTrace;

    var out = {
      'seq': r.sequenceNumber,
      'logger': r.loggerName,
      'time': r.time.toIso8601String(),
      if (r.message != object?.toString() && r.message != error?.toString())
        'message': r.message,
      if (object != null) ...object,
      if (error != null) 'error': error,
      if (stack != null)
        'stack': LineSplitter.split(Chain.forTrace(stack).terse.toString())
            .toList(growable: false)
    };

    printer(jsonEncoder.convert(out), r.level);
  };
}

Object? _errToJson(Object? error) {
  if (error == null) {
    return null;
  }
  var json = _toJson(error);
  if (json == null) {
    return error.toString();
  }
  return json;
}

Map e(String event, [Object? object]) {
  var jsonO = _toJson(object);
  return {'event': event, if (jsonO != null) 'data': jsonO};
}

Map? _toJson(dynamic o) {
  if (o == null || o is Future || o is String || o is num || o is bool) {
    return null;
  }

  if (o is Map) {
    return o;
  }

  if (o is List) {
    return {'list': o};
  }

  try {
    return _toJson(o.toJson());
  } catch (e) {
    return null;
  }
}
