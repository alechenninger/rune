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

var _jsonEncoder = JsonEncoder.withIndent(null, (o) {
  if (o is Iterable) return o.toList(growable: false);
  return o.toJson();
});
void _printPrinter(object, _) => print(_jsonEncoder.convert(object));

void Function(LogRecord) googleCloudLogging(
    [void Function(Object, Level) printer = _printPrinter]) {
  return (LogRecord r) {
    var object = _toJson(r.object);
    var error = _errToJson(r.error);
    var stack = r.stackTrace;

    var out = {
      'seq': r.sequenceNumber,
      'logger': r.loggerName,
      'time': r.time.toIso8601String(),
      'message': r.message,
      'severity': _gcpSeverity(r.level),
      if (object != null) ...object,
      if (error != null) 'error': error,
      if (stack != null)
        'stack': LineSplitter.split(Chain.forTrace(stack).terse.toString())
            .toList(growable: false)
    };

    printer(out, r.level);
  };
}

String _gcpSeverity(Level l) {
  /*
DEFAULT	(0) The log entry has no assigned severity level.
DEBUG	(100) Debug or trace information.
INFO	(200) Routine information, such as ongoing status or performance.
NOTICE	(300) Normal but significant events, such as start up, shut down, or a configuration change.
WARNING	(400) Warning events might cause problems.
ERROR	(500) Error events are likely to cause problems.
CRITICAL	(600) Critical events cause more severe problems or outages.
ALERT	(700) A person must take an action immediately.
EMERGENCY	(800) One or more systems are unusable.
   */

  if (l >= Level.SHOUT) {
    return 'EMERGENCY';
  }

  if (l >= Level.SEVERE) {
    return 'CRITICAL';
  }

  if (l >= Level.WARNING) {
    return 'WARNING';
  }

  if (l >= Level.CONFIG) {
    return 'INFO';
  }

  if (l >= Level.FINE) {
    return 'DEBUG';
  }

  return 'DEFAULT';
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
