import 'package:collection/collection.dart';

import 'asm.dart';

class JumpTable<T extends Label?> {
  final Jump<T> _jump;
  final _labels = <T>[];

  JumpTable({required Jump<T> jump, List<T> labels = const []}) : _jump = jump {
    _labels.addAll(labels);
  }

  Word add(T name) {
    _labels.add(name);
    return Word(_labels.length - 1);
  }

  Asm toAsm({bool comment = true}) => _labels
      .mapIndexed(
          (i, e) => _jump(e, comment: comment ? Word(i).toString() : null))
      .reduce((asm, r) => asm..add(r));
}

typedef Jump<T extends Label?> = Asm Function(T, {String? comment});

Jump<Label?> withNoop(Label noop, Jump<Label> jump) =>
    (Label? label, {String? comment}) => jump(label ?? noop, comment: comment);
