import 'package:rune/generator/debug.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('example debug start', () {
    var asm = debugStart(
        party: [
          alys,
          shay,
          hahn
        ],
        flagsSet: [
          EventFlag('PiataFirstTime'),
          EventFlag('PiataChazControl'),
          EventFlag('AlysFound'),
          EventFlag('PrincipalMeeting'),
          EventFlag('PrincipalSuspicious'),
          EventFlag('HahnJoined'),
          EventFlag('BasementContainers'),
          EventFlag('Igglanova'),
          EventFlag('AfterIgglanova'),
          EventFlag('PrincipalConfession'),
        ],
        eventFlags: EventFlags(),
        loadMap: LoadMap(
          map: GameMap(MapId.ShayHouse),
          startingPosition: Position(0x1f0, 0x280),
          facing: Direction.down,
        ));

    expect(asm, Asm.fromRaw(r'''	jsr	(PalFadeOut_ClrSpriteTbl).l

	move.l	#((CharID_Alys<<24)|$00FFFFFF), (Current_Party_Slots).w

	move.b	#CharID_Chaz, (Current_Party_Slot_2).w
	moveq	#CharID_Chaz,d0
	jsr	(Event_AddMacro).l

	move.b	#CharID_Hahn, (Current_Party_Slot_3).w
	moveq	#CharID_Hahn, d0
	jsr	(Event_AddMacro).l

	; to avoid rest dialog
	moveq	#TempEveFlag_ChazHouse, d0
	jsr	(TempEveFlags_Set).l

	moveq	#EventFlag_PiataFirstTime, d0
	jsr	(EventFlags_Set).l
	moveq	#EventFlag_PiataChazControl, d0
	jsr	(EventFlags_Set).l
	moveq	#EventFlag_AlysFound, d0
	jsr	(EventFlags_Set).l
	moveq	#EventFlag_PrincipalMeeting, d0
	jsr	(EventFlags_Set).l
	moveq	#EventFlag_PrincipalSuspicious, d0
	jsr	(EventFlags_Set).l
	moveq	#EventFlag_HahnJoined, d0
	jsr	(EventFlags_Set).l
	moveq	#EventFlag_BasementContainers, d0
	jsr	(EventFlags_Set).l
	moveq	#EventFlag_Igglanova, d0
	jsr	(EventFlags_Set).l
	moveq	#EventFlag_AfterIgglanova, d0
	jsr	(EventFlags_Set).l
	moveq	#EventFlag_PrincipalConfession, d0
	jsr	(EventFlags_Set).l

	move.w	#MapID_ChazHouse, (Field_Map_Index).w
	move.w	#$FFFF, (Field_Map_Index_2).w
	move.w	#$003E, (Map_Start_X_Pos).w
	move.w	#$0050, (Map_Start_Y_Pos).w
	move.w	#FacingDir_Down, (Map_Start_Facing_Dir).w
	move.w	#0, (Map_Start_Char_Align).w
	bclr	#3, (Map_Load_Flags).w	; Don't delete objects
	move.w	#8, (Game_Mode_Index).w

	rts'''));
  });
}
