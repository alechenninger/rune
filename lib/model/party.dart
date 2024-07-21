import 'package:collection/collection.dart';
import 'package:quiver/check.dart';

import 'model.dart';

sealed class PartyEvent extends Event {}

// Adding/removing a party member is different;
// would normally remove from macro.
// See:
// - Event_RemoveCharacter
// - Event_RemoveOrSwapChar
// - Event_RemoveCharFromMacros
// - Event_AddMacro

class ChangePartyOrder extends PartyEvent {
  final List<Character?> party;

  /// Allows the current party to be later restored via [RestoreSavedPartyOrder].
  final bool saveCurrentParty;

  final bool maintainOrder;

  ChangePartyOrder(this.party,
      {this.saveCurrentParty = true, this.maintainOrder = false}) {
    checkArgument(party.isNotEmpty && party.length <= 5,
        message: 'Party must have between 1 and 5 characters');
    checkArgument(
        party.whereNotNull().length == party.whereNotNull().toSet().length,
        message: 'Party must have unique characters');
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.changeParty(this);
  }

  @override
  String toString() {
    return 'ChangePartyOrder{$party, saveCurrentParty: $saveCurrentParty}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangePartyOrder &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(party, other.party);

  @override
  int get hashCode => const ListEquality().hash(party);
}

class RestoreSavedPartyOrder extends PartyEvent {
  @override
  void visit(EventVisitor visitor) {
    visitor.restoreSavedParty(this);
  }

  @override
  String toString() {
    return 'RestoreSavedPartyOrder{}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestoreSavedPartyOrder && runtimeType == other.runtimeType;

  @override
  int get hashCode => toString().hashCode;
}
