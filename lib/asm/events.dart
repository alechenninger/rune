// ignore_for_file: constant_identifier_names

import 'package:rune/numbers.dart';

import 'asm.dart';

/*
; Properties and constants applicable to both field and battle objects
obj_id = 0
render_flags = 2	; byte	; bit 2 = if set, animation is finished
mappings_addr = 8	; longword
mappings = $C		; longword
mappings_duration = $11	; byte
timer = $1C			; word

obj_size = $40
next_obj = $40
prev_obj = -$40
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Common field object properties
facing_dir = 6	; word ; 0 = DOWN;    4 = UP;     8 = RIGHT;    $C = LEFT
mappings_idx = $10	; byte ; index for Sprite mappings
offscreen_flag = $12 ; byte ; 0 = on-screen; 1 = off-screen
dialogue_id = $14 ; byte ; ID of dialogue
art_tile = $16		; word ; tile number in VRAM
art_ptr = $18		; longword ; ROM art pointer
x_step_constant = $20	; longword ; constant that changes objects' x position when moving; value is generally 2 or $FFFE
y_step_constant = $24	; longword ; constant that changes objects' y position when moving; value is generally 2 or $FFFE
x_step_duration = $28	; word ; updates characters' x position (one step) automatically until it becomes 0; it's generally 16 when moving from one tile to another
y_step_duration = $2A	; word ; updates characters' y position (one step) automatically until it becomes 0; it's generally 16 when moving from one tile to another
sprite_x_pos = $2C	; word	; used for the Sprite table
sprite_y_pos = $2E	; word	; used for the Sprite table
curr_x_pos = $30	; longword
curr_y_pos = $34	; longword
dest_x_pos = $38	; word ; used as destination when updating objects' x position
dest_y_pos = $3A	; word ; used as destination when updating objects' y position
x_max_move_boundary = $3C	; byte ; boundary which NPC's cannot move past when randomly updating their x position
y_max_move_boundary = $3D	; byte ; boundary which NPC's cannot move past when randomly updating their y position
x_move_boundary = $3E	; byte ; number of steps NPC's can take between 0 and the max boundary (x position)
y_move_boundary = $3F	; byte ; number of steps NPC's can take between 0 and the max boundary (y position)
 */

const facing_dir = Constant('facing_dir');
const art_tile = Constant('art_tile');
const dest_x_pos = Constant('dest_x_pos');
const dest_y_pos = Constant('dest_y_pos');
const curr_x_pos = Constant('curr_x_pos');
const curr_y_pos = Constant('curr_y_pos');

/// bitfield
/// bit 0 = follow lead character
/// bit 1 = update movement order (X first, Y second or viceversa)
/// bit 2 = lock camera
const Char_Move_Flags = Constant('Char_Move_Flags');

final popdlg = cmd('popdlg', []);

Asm vIntPrepareLoop(Word frames) {
  return Asm([move.w(frames.i, d0), jsr(Label('VInt_PrepareLoop').l)]);
}

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

Asm getAndRunDialog3(Address dialogId) {
  return Asm([
    moveq(dialogId, d0),
    jsr(Label('Event_GetAndRunDialogue3').l),
  ]);
}

Asm returnFromDialogEvent() {
  /*
	move.w	#0, (Game_Mode_Routine).w
	movea.l	(Map_Chunk_Addr).w, a0
	jsr	(Map_LoadChunks).l
	rts
   */
  return Asm([
    move.w(0.toWord.i, Constant('Game_Mode_Routine').w),
    movea.l(Constant('Map_Chunk_Addr').w, a0),
    jsr(Label('Map_LoadChunks').l),
    rts,
  ]);
}

/// Use after F7 (see TextCtrlCode_Terminate2 and 3)
final popAndRunDialog = Asm([
  // appears around popdlg in one scene for some reason
  //clr.b(Label('Render_Sprites_In_Cutscenes').w),
  cmd('popdlg', []),
  jsr(Label('Event_RunDialogue').l),
]);

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

Asm followLeader(bool follow) {
  return (follow ? bclr : bset)(Byte.zero.i, Char_Move_Flags.w);
}

Asm moveAlongXAxisFirst(bool xFirst) {
  return (xFirst ? bclr : bset)(Byte.one.i, Char_Move_Flags.w);
}

Asm lockCamera(bool lock) {
  return (lock ? bset : bclr)(Byte.two.i, Char_Move_Flags.w);
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

Asm addCharacterBySlot({required Address charId, required int slot}) {
  return Asm([
    move.b(charId, 'Current_Party_Slot_$slot'.toConstant.w),
    moveq(charId, d0),
    jsr('Event_AddMacro'.toLabel.l)
  ]);
}

/*
load map
	move.w	#MapID_Motavia, (Field_Map_Index).w
	move.w	#$FFFF, (Field_Map_Index_2).w
	move.w	#$EE, (Map_Start_X_Pos).w
	move.w	#$136, (Map_Start_Y_Pos).w
	move.w	#0, (Map_Start_Facing_Dir).w
	move.w	#0, (Map_Start_Char_Align).w
	bclr	#3, (Map_Load_Flags).w
	jsr	(RefreshMap).l
 */

Asm addCharacterToParty({
  required Address charId,
  required int slot,
  required Address charRoutineIndex,
  required Address charRoutine,
  required Address facingDir,
  required Address artTile,
  required Address x,
  required Address y,
}) {
  return Asm([
    move.b(charId, 'Current_Party_Slot_$slot'.toConstant.w),
    lea('Character_$slot'.toConstant.w, a4),
    move.w(charRoutineIndex, a4.indirect),
    move.w(facingDir, facing_dir(a4)),
    move.w(artTile, art_tile(a4)),
    move.w(x, curr_x_pos(a4)),
    move.w(y, curr_y_pos(a4)),
    jsr(charRoutine),
    moveq(charId, d0),
    jsr('Event_AddMacro'.toLabel.l)
  ]);
}

/// Clear the addresses from [clear] to [clear] plus [range] (not inclusive I
/// think).
Asm clearUninterrupted({required Address clear, required Address range}) {
  return Asm([lea(clear, a0), move.w(range, d7), trap(0.toByte.i)]);
}

Asm branchIfEventFlagSet(Address flag, Address to, {bool short = false}) {
  return Asm([
    moveq(flag, d0),
    jsr(Label('EventFlags_Test').l),
    if (short) bne.s(to) else bne.w(to)
  ]);
}

Asm branchIfEvenfFlagNotSet(Address flag, Address to, {bool short = false}) {
  return Asm([
    moveq(flag, d0),
    jsr(Label('EventFlags_Test').l),
    if (short) beq.s(to) else beq.w(to)
  ]);
}
