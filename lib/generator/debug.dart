import 'package:rune/asm/events.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/map.dart';

import '../model/model.dart' as model;
import '../asm/asm.dart';
import 'event.dart';
import 'movement.dart';

/// Generate a game start event
EventAsm debugStart({
  required List<model.Character> party,
  required List<model.EventFlag> flagsSet,
  required EventFlags eventFlags,
  required model.LoadMap map,
}) {
  var startingMap = map.map.id;
  var x = map.startingPosition.x ~/ 8;
  var y = map.startingPosition.y ~/ 8;
  var facing = map.facing.constant;
  var alignByte = map.arrangement.toAsm;

  var event = EventAsm([
    fadeOut(),
    newLine(),
    _loadParty(party),
    newLine(),
    comment('to avoid rest dialog'),
    moveq(Constant('TempEveFlag_ChazHouse').i, d0),
    jsr(Label('TempEveFlags_Set').l),
    newLine(),
    for (var f in flagsSet) ...[
      setEventFlag(eventFlags.toConstantValue(f)),
    ],
    newLine(),
    move.w(startingMap.toAsm.i, Field_Map_Index.w),
    // TODO(debug): set previous map
    // probably just do this when adding previous map support to LoadMap
    //move.w(previousMap.toAsm.i, Field_Map_Index_2.w),
    move.w(x.toByte.i, Map_Start_X_Pos.w),
    move.w(y.toByte.i, Map_Start_Y_Pos.w),
    move.w(facing.i, Map_Start_Facing_Dir.w),
    move.w(alignByte.i, Map_Start_Char_Align.w),
    bclr(3.i, Map_Load_Flags.w, comment: "Don't delete objects"),
    move.w(8.i, Constant('Game_Mode_Index').w),
    newLine(),
    // End scene early and give control to player
    rts
  ]);

  return event;
}

Asm _loadParty(List<model.Character> party) {
  var asm = Asm.empty();

  asm.add(move.l((model.shay.charId << 24.toValue | 0xffffff.toLongword).i,
      Constant('Current_Party_Slots').w));
  asm.addNewline();

  for (int i = 0; i < party.length; i++) {
    var c = party[i];
    if (c == model.shay) continue;
    asm.add(Asm([
      // + 2 (starts at second character; first is Shay)
      move.b(c.charIdAddress, Constant('Current_Party_Slot_${i + 2}').w),
      moveq(c.charIdAddress, d0),
      jsr(Label('Event_AddMacro').l)
    ]));
  }
  return asm;
}

List<model.Character> partyFromEventFlags(List<model.EventFlag> flagsSet) {
  // todo: make dynamic
  return [model.alys, model.hahn];
}
