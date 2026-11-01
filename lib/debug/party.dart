import 'package:rune/model/model.dart';

// todo: eventually it would probably be better to get this from game model
List<Character> partyFromEventFlags(List<EventFlag> flagsSet) {
  var party = <Character>[alys, shay];
  for (final flag in _partyEvents.keys) {
    if (flagsSet.contains(flag)) {
      applyPartyEventFlag(flag, party);
    }
  }
  return party;
}

/// Applies one story flag's party transition to the current membership.
void applyPartyEventFlag(EventFlag flag, List<Character> party) {
  _partyEvents[flag]?.call(party);
  // Recruitment can be recorded for a member already in the party.
  final seen = <Character>{};
  party.removeWhere((character) => !seen.add(character));
}

final _partyEvents = <EventFlag, Function(List<Character>)>{
  EventFlag('PiataFirstTime'): (p) => p.remove(alys), // 1
  EventFlag('AlysFound'): (p) => p.insert(0, alys), // 2
  EventFlag('HahnJoined'): (p) => p.add(hahn), // 3
  EventFlag('RuneJoined'): (p) => p.add(rune), // 4
  EventFlag('GryzJoined'): (p) => p // 4
    ..add(gryz)
    ..remove(rune),
  EventFlag('RikaJoined'): (p) => p.add(rika), // 5
  EventFlag('DemiJoined'): (p) => p
    ..add(demi)
    ..remove(alys)
    ..remove(hahn), // 4
  EventFlag('RuneJoinedAgain'): (p) => p.add(rune), // 5
  EventFlag('MotaSpaceport'): (p) => p.remove(demi), // 4
  EventFlag('GryzGone'): (p) => p.remove(gryz), // 3
  EventFlag('WrenJoined'): (p) => p.add(wren), // 4
  EventFlag('RajaJoined'): (p) => p.add(raja), // 5
  EventFlag('RajaSick'): (p) => p.remove(raja), // 4
  EventFlag('KyraJoined'): (p) => p.add(kyra), // 5
  EventFlag('SnowstormGone'): (p) => p.remove(kyra), // 4
  EventFlag('SethJoined'): (p) => p.add(seth), // 5
  EventFlag('SethLeaves'): (p) => p.remove(seth), // 4
  // Even though technically unnecessary, SethLeaves is not a story event
  // This approximates.
  EventFlag('SoldiersTemple'): (p) => p.remove(seth), // 4
  EventFlag('ElsydeonCave'): (p) => p
    ..clear()
    ..add(shay), // 1
  EventFlag('Elsydeon'): (p) => p.addAll([rune, rika, wren]), // 4
};
