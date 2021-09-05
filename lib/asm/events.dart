import 'asm.dart';

const dest_x_pos = Constant('dest_x_pos');
const dest_y_pos = Constant('dest_y_pos');
const curr_x_pos = Constant('curr_x_pos');
const curr_y_pos = Constant('curr_y_pos');

const Char_Move_Flags = Constant('Char_Move_Flags');

Asm popdlg = cmd('popdlg', []);

Asm dialogTreesToRAM(Address dialogTree) {
  return Asm([
    move.l(dialogTree, d0),
    jsr(Label('DialogueTreesToRAM').l),
  ]);
}

Asm getAndRunDialog(Address dialogId) {
  return Asm([
    moveq(dialogId, d0),
    jsr(Label('Event_GetAndRunDialogue').l),
  ]);
}

/// Use after F7 (see TextCtrlCode_Terminate2 and 3)
Asm popAndRunDialog() {
  return Asm([
    cmd('popdlg', []),
    jsr(Label('Event_RunDialogue').l),
  ]);
}

/// [slot] is 1-indexed
Asm characterBySlotToA4(int slot) {
  return lea(Constant('Character_$slot').w, a4);
}

Asm characterByIdToA4(Address id) {
  return Asm([
    moveq(id, d0),
    jsr(Label('Event_GetCharacter').l),
  ]);
}

Asm characterByNameToA4(String name) {
  return Asm([
    moveq(Constant('CharID_$name').i, d0),
    jsr(Label('Event_GetCharacter').l),
  ]);
}

Asm updateObjFacing(Address direction) {
  return Asm([
    moveq(direction, d0),
    jsr(Label('Event_UpdateObjFacing').l),
  ]);
}

Asm lockCamera(bool lock) {
  return cmd(lock ? 'bset' : 'bclr', [const Byte(2).i, Char_Move_Flags.w]);
}

Asm followLeader(bool follow) {
  return cmd(follow ? 'bclr' : 'bset', [Byte.zero.i, Char_Move_Flags.w]);
}

/// Multiple characters can move with [moveCharacter], but they must be prepared
/// prior to calling. Load each character into a4, call this, and then after
/// loading the last character, call [moveCharacter].
Asm setDestination({required Address x, required Address y}) {
  return Asm([
    move.w(x, a4.indirect.plus(dest_x_pos)),
    move.w(y, a4.indirect.plus(dest_y_pos)),
  ]);
}

/// [x] and [y] should be word size.
Asm moveCharacter({required Address x, required Address y}) {
  return Asm([
    move.w(x, d0),
    move.w(y, d1),
    jsr(Label('Event_MoveCharacter').l),
  ]);
}

/// Moves the object at address A4 by rate ([x] and [y]) and time ([frames])).
Asm stepObject(
    {required Address x, required Address y, required Address frames}) {
  return Asm([
    move.l(x, d0),
    move.l(y, d1),
    move.l(frames, d2),
    jsr(Label('Event_StepObject').l),
    setDestination(
        x: a4.indirect.plus(curr_x_pos), y: a4.indirect.plus(curr_y_pos))
  ]);
}

Asm moveCamera(
    {required Address x, required Address y, required Address speed}) {
  return Asm([
    move.l(x, d0),
    move.l(y, d1),
    move.l(speed, d2),
    jsr(Label('Event_MoveCamera').l),
  ]);
}
