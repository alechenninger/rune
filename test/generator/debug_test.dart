import 'package:rune/generator/debug.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('advancement merges flags and preserves retained macro commands', () {
    final asm = debugAdvance(
        previousParty: [shay, alys],
        party: [shay, hahn],
        flagsSet: [EventFlag('First'), EventFlag('Extended')],
        eventFlags: FixedEventFlags({
          Constant('EventFlag_First'): Word(0),
          Constant('EventFlag_Extended'): Word(0x101)
        }),
        loadMap: LoadMap(
            map: GameMap(MapId.ShayHouse),
            startingPosition: Position(0x1f0, 0x280),
            facing: Direction.down));
    expect(
        asm.withoutComments().withoutEmptyLines(),
        Asm([
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          Asm.fromRaw('\tlea\t.advance_flags(pc), a0'),
          lea(Constant('Event_Flags').w, a1),
          moveq(31.i, d7),
          label(Label('.advance_merge')),
          move.w(a0.postIncrement(), d0),
          or.w(d0, a1.postIncrement()),
          dbf(d7, Label('.advance_merge')),
          moveq(Constant('CharID_Alys').i, d0),
          jsr(Label('Event_RemoveCharFromMacros').l),
          moveq(Constant('CharID_Hahn').i, d0),
          jsr(Label('Event_AddMacro').l),
          move.l(
              ((Constant('CharID_Chaz') << 24.toValue) |
                      (Constant('CharID_Hahn') << 16.toValue) |
                      0xffff.toValue)
                  .i,
              Constant('Current_Party_Slots').w),
          move.b(Byte(0xff).i, Constant('Current_Party_Slot_5').w),
          move.b(0.i, Constant('World_Index').w),
          move.w(Constant('MapID_ChazHouse').i, Constant('Field_Map_Index').w),
          move.w(Word(0xffff).i, Constant('Field_Map_Index_2').w),
          move.w(Word(0x3e).i, Constant('Map_Start_X_Pos').w),
          move.w(Word(0x50).i, Constant('Map_Start_Y_Pos').w),
          move.w(
              Constant('FacingDir_Down').i, Constant('Map_Start_Facing_Dir').w),
          clr.w(Constant('Map_Start_Char_Align').w),
          bclr(3.i, Constant('Map_Load_Flags').w),
          move.w(8.i, Constant('Game_Mode_Index').w),
          rts,
          label(Label('.advance_flags')),
          dc.b([
            Byte(0x80),
            ...List.filled(31, Byte.zero),
            Byte(0x40),
            ...List.filled(31, Byte.zero)
          ]),
        ]));
  });

  test('preset replaces both flag banks, all party slots, inventory and macros',
      () {
    final asm = debugPreset(
        party: [shay, hahn],
        flagsSet: [EventFlag('First'), EventFlag('Extended')],
        eventFlags: FixedEventFlags({
          Constant('EventFlag_First'): Word(0),
          Constant('EventFlag_Extended'): Word(0x101),
        }),
        loadMap: LoadMap(
            map: GameMap(MapId.ShayHouse),
            startingPosition: Position(0x1f0, 0x280),
            facing: Direction.down),
        items: [ItemId.Dagger, ItemId.Dagger]);

    expect(
        asm.withoutComments().withoutEmptyLines(),
        Asm([
          jsr(Label('PalFadeOut_ClrSpriteTbl').l),
          lea(Constant('Macro_Data').w, a0),
          moveq(39.i, d7),
          trap(0.i),
          Asm.fromRaw('\tlea\t.preset_data(pc), a0'),
          lea(Constant('Event_Flags').w, a1),
          moveq(31.i, d7),
          trap(1.i),
          lea(Constant('Current_Party_Slots').w, a1),
          moveq(22.i, d7),
          trap(1.i),
          lea(Constant('Macro_Data').w, a1),
          moveq(3.i, d7),
          trap(1.i),
          moveq(Constant('TempEveFlag_ChazHouse').i, d0),
          jsr(Label('TempEveFlags_Set').l),
          move.b(0.i, Constant('World_Index').w),
          move.w(Constant('MapID_ChazHouse').i, Constant('Field_Map_Index').w),
          move.w(Word(0xffff).i, Constant('Field_Map_Index_2').w),
          move.w(Word(0x3e).i, Constant('Map_Start_X_Pos').w),
          move.w(Word(0x50).i, Constant('Map_Start_Y_Pos').w),
          move.w(
              Constant('FacingDir_Down').i, Constant('Map_Start_Facing_Dir').w),
          clr.w(Constant('Map_Start_Char_Align').w),
          bclr(3.i, Constant('Map_Load_Flags').w),
          move.w(8.i, Constant('Game_Mode_Index').w),
          rts,
          label(Label('.preset_data')),
          dc.b([
            Byte(0x80),
            ...List.filled(31, Byte.zero),
            Byte(0x40),
            ...List.filled(31, Byte.zero)
          ]),
          dc.b([
            Constant('CharID_Chaz'),
            Constant('CharID_Hahn'),
            ...List.filled(4, Byte(0xff))
          ]),
          dc.b([
            Constant('ItemID_Dagger'),
            Constant('ItemID_Dagger'),
            ...List.filled(38, Byte.zero)
          ]),
          dc.b([
            Constant('CharID_Chaz'),
            Constant('Command_Attack'),
            Byte.zero,
            Byte.zero,
            Constant('CharID_Hahn'),
            Constant('Command_Attack'),
            Byte.zero,
            Byte.zero
          ]),
        ]));
  });

  test('preset rejects invalid party and overflowing inventory', () {
    Asm generate(List<Character> party, List<ItemId> items) => debugPreset(
        party: party,
        flagsSet: [],
        eventFlags: FixedEventFlags({}),
        loadMap: LoadMap(
            map: GameMap(MapId.ShayHouse),
            startingPosition: Position(0x1f0, 0x280),
            facing: Direction.down),
        items: items);
    expect(() => generate([], []), throwsArgumentError);
    expect(() => generate([shay, shay], []), throwsArgumentError);
    expect(() => generate([shay, alys, hahn, rune, gryz, rika], []),
        throwsArgumentError);
    expect(() => generate([shay], List.filled(41, ItemId.Dagger)),
        throwsArgumentError);
  });

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

	move.l	#CharID_Alys<<24|$00FFFFFF, (Current_Party_Slots).w
	moveq	#CharID_Alys,d0
	jsr	(Event_AddMacro).l

	move.b	#CharID_Chaz, (Current_Party_Slot_2).w

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

	move.b	#0, (World_Index).w	; Motavia
	move.w	#MapID_ChazHouse, (Field_Map_Index).w
	move.w	#$FFFF, (Field_Map_Index_2).w
	move.w	#$003E, (Map_Start_X_Pos).w
	move.w	#$0050, (Map_Start_Y_Pos).w
	move.w	#FacingDir_Down, (Map_Start_Facing_Dir).w
	clr.w	(Map_Start_Char_Align).w
	bclr	#3, (Map_Load_Flags).w	; Don't delete objects
	move.w	#8, (Game_Mode_Index).w

	rts'''));
  });
}
