import 'package:collection/collection.dart';
import 'package:quiver/check.dart';

import 'model.dart';

class ChangeParty extends Event {
  final List<Character> party;

  /// Allows the current party to be later restored via [RestoreSavedParty].
  final bool saveCurrentParty;

  ChangeParty(this.party, {this.saveCurrentParty = true}) {
    checkArgument(party.isNotEmpty && party.length <= 5,
        message: 'Party must have between 1 and 5 characters');
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.changeParty(this);
  }

  @override
  String toString() {
    return 'ChangeParty{$party}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangeParty &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(party, other.party);

  @override
  int get hashCode => const ListEquality().hash(party);
}

class RestoreSavedParty extends Event {
  @override
  void visit(EventVisitor visitor) {
    visitor.restoreSavedParty(this);
  }

  @override
  String toString() {
    return 'RestoreParty{}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestoreSavedParty && runtimeType == other.runtimeType;

  @override
  int get hashCode => toString().hashCode;
}
