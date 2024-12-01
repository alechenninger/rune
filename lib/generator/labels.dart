import '../asm/data.dart';

class Labeller {
  /// A context which can be ommitted if using a local label.
  ///
  /// See [nextLocal].
  final String? _localTo;
  final List<String> _contexts;
  var _counter = -1;

  Labeller()
      : _contexts = const [],
        _localTo = null;

  Labeller.localTo(Object localTo)
      : _localTo = _labelSafeString(localTo),
        _contexts = const [];

  Labeller.withContext(Object context, {String? localTo})
      : _contexts = List.of([_labelSafeString(context)], growable: false),
        _localTo = localTo;

  Labeller.plusContexts(Labeller base, List<Object> context)
      : _contexts = List.from(
            [...base._contexts, ...context.map(_labelSafeString)],
            growable: false),
        _localTo = base._localTo;

  Labeller.combineContexts(Labeller base, Labeller other)
      : _contexts =
            List.from([...base._contexts, ...other._contexts], growable: false),
        _localTo = base._localTo;

  Labeller withContext(Object context) {
    return Labeller.plusContexts(this, [context]);
  }

  Labeller withContextsFrom(Labeller other) {
    return Labeller.combineContexts(this, other);
  }

  /// Get the next top-level label.
  Label next() {
    var label = _nextLabelParts().join('_');
    return Label(label);
  }

  /// Get the next local label for the current top-level context.
  ///
  /// Local labels are prefixed with '.'
  /// and do not include the top-level context.
  Label nextLocal() {
    var parts = _nextLabelParts(includeLocalTo: false);
    var label = [
      '.${parts.first}',
      ...parts.skip(1),
    ].join('_');
    return Label(label);
  }

  String suffixLocal() {
    return '_${_nextLabelParts(includeLocalTo: false).join('_')}';
  }

  List<Object> _nextLabelParts({bool includeLocalTo = true}) {
    return [
      if (_localTo != null && includeLocalTo) _localTo,
      ..._contexts,
      if (_counter++ > -1) _counter,
    ];
  }
}

String _labelSafeString(Object obj) {
  return obj.toString().replaceAll(RegExp(r'[{}:,]'), '');
}
