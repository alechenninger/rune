import 'package:quiver/check.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/map.dart';

import '../model/model.dart' as model;
import 'event.dart';
import 'movement.dart';

/// Generate a game start event
EventAsm debugStart({
  required List<model.Character> party,
  required List<model.EventFlag> flagsSet,
  required EventFlags eventFlags,
  required model.LoadMap loadMap,
  List<model.ItemId> items = const [],
}) {
  var event = EventAsm([
    fadeOut(),
    newLine(),
    _loadParty(party),
    newLine(),
    _avoidRestDialog(),
    newLine(),
    for (var f in flagsSet) ...[
      setEventFlag(eventFlags.toConstantValue(f)),
    ],
    if (flagsSet.isNotEmpty) newLine(),
    if (items.isNotEmpty) ...[
      _addItems(items),
      newLine(),
    ],
    _loadMap(loadMap),
    newLine(),
    // End scene early and give control to player
    rts
  ]);

  return event;
}

/// Replace the state controlled by a debug start, then schedule its map load.
///
/// Unlike [debugStart], this is repeatable in an initialized field session. Both
/// event-flag banks, all five party slots, and the 40-slot inventory are replaced.
/// Battle macros are reset to one attack macro for the new party. Character
/// stats/equipment, money, chest/town flags and other temporary state are retained.
/// Returning schedules the map transition; it does not mean the map has loaded.
EventAsm debugPreset({
  required List<model.Character> party,
  required List<model.EventFlag> flagsSet,
  required EventFlags eventFlags,
  required model.LoadMap loadMap,
  List<model.ItemId> items = const [],
}) {
  checkArgument(party.isNotEmpty && party.length <= 5,
      message: 'Party must have between 1 and 5 characters');
  checkArgument(party.toSet().length == party.length,
      message: 'Party must have unique characters');
  checkArgument(items.length <= 40,
      message: 'Inventory holds at most 40 items');

  final flags = _flagBitmap(flagsSet, eventFlags);

  return EventAsm([
    fadeOut(),
    // Trap 0 clears longwords; trap 1 copies words. Both counts are inclusive.
    lea(Constant('Macro_Data').w, a0),
    moveq(39.i, d7),
    trap(0.i),
    // Keep the embedded data relocatable; the address model lacks PC-relative LEA.
    Asm.fromRaw('\tlea\t.preset_data(pc), a0'),
    lea(Constant('Event_Flags').w, a1),
    moveq(31.i, d7),
    trap(1.i),
    // Five slots, their $FF sentinel, then the contiguous 40 inventory bytes.
    lea(Constant('Current_Party_Slots').w, a1),
    moveq(22.i, d7),
    trap(1.i),
    lea(Constant('Macro_Data').w, a1),
    moveq((party.length * 2 - 1).i, d7),
    trap(1.i),
    _avoidRestDialog(),
    _loadMap(loadMap),
    rts,
    label(Label('.preset_data')),
    dc.b(flags.map(Byte.new).toList()),
    dc.b([
      for (final character in party) character.charId,
      ...List.filled(6 - party.length, Byte(0xff)),
    ]),
    dc.b([
      for (final item in items) Constant(item.toConstant),
      ...List.filled(40 - items.length, Byte.zero),
    ]),
    dc.b([
      for (final character in party) ...[
        character.charId,
        Constant('Command_Attack'),
        Byte.zero,
        Byte.zero,
      ],
    ]),
  ]);
}

/// Add story flags and reconcile party membership without resetting game state.
/// Macro commands for retained characters survive; departing characters are
/// removed and new members receive attack commands in existing nonempty macros.
/// The caller must verify that [previousParty] still describes the live party.
EventAsm debugAdvance({
  required List<model.Character> previousParty,
  required List<model.Character> party,
  required List<model.EventFlag> flagsSet,
  required EventFlags eventFlags,
  required model.LoadMap loadMap,
}) {
  for (final members in [previousParty, party]) {
    checkArgument(
        members.isNotEmpty &&
            members.length <= 5 &&
            members.toSet().length == members.length,
        message: 'Expected 1..5 unique party members');
  }
  final flags = _flagBitmap(flagsSet, eventFlags);
  return EventAsm([
    fadeOut(),
    // Merge at execution time: unlisted flags, including optional progress and
    // custom flags in the extended bank, are never cleared.
    Asm.fromRaw('\tlea\t.advance_flags(pc), a0'),
    lea(Constant('Event_Flags').w, a1),
    moveq(31.i, d7),
    label(Label('.advance_merge')),
    move.w(a0.postIncrement(), d0),
    or.w(d0, a1.postIncrement()),
    dbf(d7, Label('.advance_merge')),
    _advanceMacros(previousParty, party),
    loadPartySlots(party.map((member) => member.charId).toList(),
        Constant('Current_Party_Slots').w, Constant('Current_Party_Slot_5').w),
    _loadMap(loadMap),
    rts,
    label(Label('.advance_flags')),
    dc.b(flags.map(Byte.new).toList()),
  ]);
}

Asm _advanceMacros(
    List<model.Character> previousParty, List<model.Character> party) {
  final removed =
      previousParty.where((member) => !party.contains(member)).toList();
  final added =
      party.where((member) => !previousParty.contains(member)).toList();
  Asm remove(model.Character member) => Asm([
        moveq(member.charIdAddress, d0),
        jsr(Label('Event_RemoveCharFromMacros').l),
      ]);
  Asm add(model.Character member) => Asm([
        moveq(member.charIdAddress, d0),
        jsr(Label('Event_AddMacro').l),
      ]);
  final asm = Asm.empty();
  if (removed.length == previousParty.length && added.isNotEmpty) {
    // AddMacro skips empty macros. When replacing every member, keep at least
    // one entry alive; free a slot first if the previous party was full.
    if (previousParty.length == 5) asm.add(remove(removed.removeAt(0)));
    asm.add(add(added.removeAt(0)));
  }
  // Remove before adding so no macro temporarily exceeds five characters.
  for (final member in removed) {
    asm.add(remove(member));
  }
  for (final member in added) {
    asm.add(add(member));
  }
  return asm;
}

List<int> _flagBitmap(List<model.EventFlag> flagsSet, EventFlags eventFlags) {
  // A bitmap keeps code size independent of story progress. The two flag banks
  // occupy adjacent 32-byte blocks, with the high bit first in each byte.
  final flags = List.filled(64, 0);
  for (final flag in flagsSet) {
    final id = eventFlags.toId(flag).value;
    checkArgument(id >= 0 && id < 512, message: 'Event flag exceeds \$1FF');
    flags[id >> 3] |= 1 << (7 - (id & 7));
  }
  return flags;
}

Asm _avoidRestDialog() => Asm([
      comment('to avoid rest dialog'),
      moveq(Constant('TempEveFlag_ChazHouse').i, d0),
      jsr(Label('TempEveFlags_Set').l),
    ]);

Asm _loadMap(model.LoadMap loadMap) {
  final startingMap = loadMap.map.id;
  final x = loadMap.startingPosition.x ~/ 8;
  final y = loadMap.startingPosition.y ~/ 8;
  final facing = loadMap.facing.constant;
  final alignByte = loadMap.arrangement.toAsm;
  return Asm([
    move.b(World.values.indexOf(startingMap.world).i, Constant('World_Index').w,
        comment: startingMap.world.name),
    move.w(startingMap.toAsm.i, Field_Map_Index.w),
    move.w(0xFFFF.toWord.i, Field_Map_Index_2.w),
    move.w(x.toWord.i, Map_Start_X_Pos.w),
    move.w(y.toWord.i, Map_Start_Y_Pos.w),
    move.w(facing.i, Map_Start_Facing_Dir.w),
    // The overlapping arrangement is zero. CLR saves two bytes in live events,
    // keeping even a five-for-five party replacement within the RAM buffer.
    if (loadMap.arrangement == model.PartyArrangement.overlapping)
      clr.w(Map_Start_Char_Align.w)
    else
      move.w(alignByte.i, Map_Start_Char_Align.w),
    bclr(3.i, Map_Load_Flags.w, comment: "Don't delete objects"),
    move.w(8.i, Constant('Game_Mode_Index').w),
  ]);
}

Asm _loadParty(List<model.Character> party) {
  checkArgument(party.isNotEmpty, message: 'Party must not be empty');

  var asm = Asm.empty();

  asm.add(move.l((party[0].charId << 24.toValue | 0xffffff.toLongword).i,
      Constant('Current_Party_Slots').w));
  asm.add(_addMacro(party[0]));

  for (int i = 1; i < party.length; i++) {
    var c = party[i];
    asm.addNewline();
    asm.add(Asm([
      // + 1 because slots start at 1, not 0
      move.b(c.charIdAddress, Constant('Current_Party_Slot_${i + 1}').w),
      _addMacro(c),
    ]));
  }
  return asm;
}

Asm _addMacro(model.Character c) {
  if (c == model.shay) return Asm.empty();
  return Asm([moveq(c.charIdAddress, d0), jsr(Label('Event_AddMacro').l)]);
}

Asm _addItems(List<model.ItemId> items) {
  var asm = Asm.empty();
  for (var item in items) {
    asm.add(jsr(Label('GetFreeInventorySlot').l));
    asm.add(move.b(Constant(item.toConstant).i, a0.indirect));
  }
  return asm;
}
