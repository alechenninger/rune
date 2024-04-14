// ignore_for_file: constant_identifier_names

import 'package:quiver/check.dart';
import 'package:quiver/collection.dart';

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
const dialogue_id = Constant('dialogue_id');
const art_tile = Constant('art_tile');
const dest_x_pos = Constant('dest_x_pos');
const dest_y_pos = Constant('dest_y_pos');
const curr_x_pos = Constant('curr_x_pos');
const curr_y_pos = Constant('curr_y_pos');
const x_step_constant = Constant('x_step_constant');
const y_step_constant = Constant('y_step_constant');
const x_step_duration = Constant('x_step_duration');
const y_step_duration = Constant('y_step_duration');

/// bitfield
/// bit 0 = follow lead character (set = false, clr = true)
/// bit 1 = update movement order (X first, Y second or viceversa)
/// bit 2 = lock camera
const Char_Move_Flags = Constant('Char_Move_Flags');
const Field_Map_Index = Constant('Field_Map_Index');
const Field_Map_Index_2 = Constant('Field_Map_Index_2');
const Map_Start_X_Pos = Constant('Map_Start_X_Pos');
const Map_Start_Y_Pos = Constant('Map_Start_Y_Pos');
const Map_Start_Facing_Dir = Constant('Map_Start_Facing_Dir');

const Current_Party_Slots = Constant('Current_Party_Slots');
const Current_Party_Slot_5 = Constant('Current_Party_Slot_5');

/// alignment of the characters relative to the lead character
/// 0 = Characters overlap
/// 4 = Characters below lead character
/// 8 = Characters above lead character
/// $C = Characters on the left of lead character
/// $10 = Characters on the right of lead character
const Map_Start_Char_Align = Constant('Map_Start_Char_Align');
const Map_Load_Flags = Constant('Map_Load_Flags');

const Event_Index = Constant('Event_Index');
const Sound_Index = Constant('Sound_Index');

const RunEvent_NoEvent = Label.known('RunEvent_NoEvent');

const Pal_IncreaseTone = Label.known('Pal_IncreaseTone');
const Pal_DecreaseToneToPal2 = Label.known('Pal_DecreaseToneToPal2');

final eventFlags = BiMap<Constant, Byte>()
  ..addAll({
    Constant('EventFlag_PiataFirstTime'):
        Byte(7), // Set when Chaz is alone in Piata at the start of the game
    Constant('EventFlag_AlysFound'):
        Byte(8), // Set when Chaz finds Alys in Piata
    Constant('EventFlag_PrincipalMeeting'):
        Byte(9), // Set after talking to the principal the first time
    Constant('EventFlag_HahnJoined'):
        Byte(0xA), // Set when Hahn joins your party for the first time
    Constant('EventFlag_Igglanova'):
        Byte(0xB), // Set when you fight the Igglanova in the Piata basement
    Constant('EventFlag_PrincipalConfession'): Byte(
        0xC), // Set after talking to the principal revealing the cause of the monsters' outbreak
    Constant('EventFlag_BasementContainers'):
        Byte(0xD), // Set when you arrive at the room with the containers
    Constant('EventFlag_PrincipalSuspicious'):
        Byte(0xE), // Set after Alys brings up the principal being suspicious
    Constant('EventFlag_AfterIgglanova'): Byte(
        0xF), // Set after the Igglanova fight and the discussion about the monsters
    Constant('EventFlag_HoltPetrified'):
        Byte(0x10), // Set after discovering that professor Holt is petrified
    Constant('EventFlag_RuneJoined'):
        Byte(0x11), // Set after Rune joins the party the first time
    Constant('EventFlag_Saya'): Byte(0x12), // Set after meeting Saya
    Constant('EventFlag_TonoePathOpen'): Byte(
        0x13), // Set after Rune destroys the rocks blocking the passageway to Tonoe
    Constant('EventFlag_ZemaPetrified'):
        Byte(0x14), // Set when the people of Zema are petrified
    Constant('EventFlag_PiataChazControl'): Byte(
        0x15), // Set when you gain control of Chaz in Piata at the start of the game
    Constant('EventFlag_TheRanchOwner'):
        Byte(0x19), // Set when you take on the Ranch Owner commission
    Constant('EventFlag_MileRanchOwner'):
        Byte(0x1A), // Set after talking to the ranch owner and he moves left
    Constant('EventFlag_MileSandWorm'):
        Byte(0x1B), // Set when you fight the Mile Sand Worm
    Constant('EventFlag_RanchOwnerAfterBattle'): Byte(
        0x1C), // Set when you talk to the ranch owner after defeating the Sand Worm
    Constant('EventFlag_RanchOwnerFee'): Byte(
        0x1D), // Set when you accept the fee from the guild for the Ranch Owner commission
    Constant('EventFlag_TinkerbellsDog'):
        Byte(0x1E), // Set when you take on the Tinkerbell's Dog commission
    Constant('EventFlag_RockyOwner'):
        Byte(0x1F), // Set when you talk to Rocky's owner
    Constant('EventFlag_RockyFound'): Byte(0x20), // Set when you find Rocky
    Constant('EventFlag_RockyTermiEscape'): Byte(
        0x21), // Set when Rocky runs out of Termi if you don't have the shortcake
    Constant('EventFlag_RockyKrupEscape'): Byte(
        0x22), // Set when Rocky runs out of Krup if you don't have the shortcake
    Constant('EventFlag_RockyMonsenEscape'): Byte(
        0x23), // Set when Rocky runs out of Monsen if you don't have the shortcake
    Constant('EventFlag_RockyHome'):
        Byte(0x24), // Set when you bring Rocky back to his house
    Constant('EventFlag_RockyFee'): Byte(
        0x25), // Set when you accept the fee from the guild for the Rocky commission
    Constant('EventFlag_MissingStudent'):
        Byte(0x26), // Set when you take on the Missing Student commission
    Constant('EventFlag_DormOwner'): Byte(
        0x27), // Set when you talk to the Piata dorm owner about the missing student
    Constant('EventFlag_StudentSick'): Byte(
        0x28), // Set when you talk to the missing student and she falls sick
    Constant('EventFlag_Perolymate'): Byte(
        0x29), // Set when you talk to the old man when you have the Perolymate
    Constant('EventFlag_StudentRecovered'): Byte(
        0x2A), // Set when you talk to the student in bed after giving her the perolymate
    Constant('EventFlag_StudentFee'): Byte(
        0x2B), // Set when you accept the fee from the guild after the Missing Student mission
    Constant('EventFlag_FissureOfFear'):
        Byte(0x2C), // Set when you take on the Fissure of Fear commission
    Constant('EventFlag_TallasMother'): Byte(
        0x2D), // Set when you talk to Tallas' mother before going to the crevice
    Constant('EventFlag_InsideCave'): Byte(
        0x2E), // Set when you fall through the crevice and end up in the cave under Monsen
    Constant('EventFlag_FractOoze'):
        Byte(0x2F), // Set when you fight the Fract Ooze in the Monsen cave
    Constant('EventFlag_GryzJoined'):
        Byte(0x30), // Set after the conversation with Dorin and Rune leaves
    Constant('EventFlag_TonoeDoorOpen'):
        Byte(0x31), // Set when Gryz opens the door leading to the basement
    Constant('EventFlag_AlshlineFound'): Byte(
        0x32), // Set after finding the Alshline and having the conversation about it
    Constant('EventFlag_IgglanovaZema'):
        Byte(0x33), // Set when you fight the Igglanova in Zema
    Constant('EventFlag_BioPlantEscape'):
        Byte(0x34), // Set after escaping the Bio Plant
    Constant('EventFlag_RikaJoined'):
        Byte(0x35), // Set when you're outside Zema after the Bio Plant events
    Constant('EventFlag_Dorin'):
        Byte(0x36), // Set right before the cutscene with Dorin starts
    Constant('EventFlag_AfterIgglanovaZema'): Byte(
        0x37), // Set after defeating the Igglanova and deciding to go to Birth Valley
    Constant('EventFlag_AfterCrevice'): Byte(
        0x3C), // Set when you talk to Tallas' mother after defeating Fract Ooze
    Constant('EventFlag_FissureOfFearFee'): Byte(
        0x3D), // Set when you accept the fee from the guild after the Fissure of Fear commission
    Constant('EventFlag_TallasSaved'):
        Byte(0x3E), // Set after the Fract Ooze battle and you save Tallas
    Constant('EventFlag_WreckageSystem'):
        Byte(0x40), // Set when you analyze the system in the wreckage
    Constant('EventFlag_Juza'): Byte(0x41), // Set when you fight Juza
    Constant('EventFlag_Zio'):
        Byte(0x42), // Set when you fight Zio for the first time
    Constant('EventFlag_MachineCenter'):
        Byte(0x43), // Set after Machine Center appears
    Constant('EventFlag_LandRover'):
        Byte(0x44), // Set when you get the Land Rover
    Constant('EventFlag_FortuneTeller'):
        Byte(0x45), // Set when talking to the fortune teller in Aiedo with Alys
    Constant('EventFlag_GirlsCaught'): Byte(
        0x46), // Set after resting in the Aiedo supermarket and the girls get arrested
    Constant('EventFlag_DemiJoined'):
        Byte(0x47), // Set after Zio wounds Alys and you decide to go find Rune
    Constant('EventFlag_JuzaDefeated'):
        Byte(0x48), // Set after the battle against Juza and the stairs appear
    Constant('EventFlag_Hijammer'): Byte(0x5E), // Set after getting Hijammer
    Constant('EventFlag_PlateSystem'): Byte(
        0x60), // Set when you take on the mission of stopping the earthquakes from happening
    Constant('EventFlag_PlateEngine'):
        Byte(0x61), // Set when you analyze the engine in the Plate System
    Constant('EventFlag_RuneJoinedAgain'):
        Byte(0x62), // Set when Rune joins in the Ladea Tower
    Constant('EventFlag_AfterAlysDeath'):
        Byte(0x63), // Set after the cutscene with Alys dying
    Constant('EventFlag_ZioFortBarrier'): Byte(
        0x64), // Set after breaking the invisible barrier blocking the way to Nurvus
    Constant('EventFlag_ZioNurvus'):
        Byte(0x65), // Set when you fight Zio in Nurvus
    Constant('EventFlag_MotaSpaceport'):
        Byte(0x66), // Set after the spaceport in Motavia appears
    Constant('EventFlag_AfterAlysDeath2'):
        Byte(0x67), // Set after the cutscene with Alys dying
    Constant('EventFlag_GryzGone'):
        Byte(0x68), // Set after Gryz leaves the party
    Constant('EventFlag_GyLaguiah'):
        Byte(0x69), // Set when you fight Gy-Laguiah in the Ladea Tower
    Constant('EventFlag_WrenJoined'):
        Byte(0x70), // Set when Wren joins your party
    Constant('EventFlag_ChaosSorcr'):
        Byte(0x71), // Set when you fight the Chaos Sorcr in the spaceship
    Constant('EventFlag_Canceller'):
        Byte(0x72), // Set when you get the Canceller
    Constant('EventFlag_CancellerReminder'):
        Byte(0x73), // Set when Wren reminds you to get the Canceller
    Constant('EventFlag_Burstroc'): Byte(0x74), // Set after getting Burstroc
    Constant('EventFlag_StainInLife'):
        Byte(0x78), // Set when you take on the Stain in Life commission
    Constant('EventFlag_MissingGirlsMom'):
        Byte(0x79), // Set when you talk to the mom of the missing girls
    Constant('EventFlag_GirlPrison'):
        Byte(0x7A), // Set when you talk to one of the girl in the Aiedo prison
    Constant('EventFlag_PrisonGuard'): Byte(
        0x7B), // Set when you talk to the guard in the prison regarding the girls
    Constant('EventFlag_BailPaid'):
        Byte(0x7C), // Set after accepting to pay for the girls' bail
    Constant('EventFlag_GirlsBailedOut'):
        Byte(0x7D), // Set after bringing the girls back home
    Constant('EventFlag_StainInLifeFee'): Byte(
        0x7E), // Set after accepting the fee from the guild for the Stain in Life commision
    Constant('EventFlag_Bail'): Byte(
        0x7F), // Set when you talk to the guard in the prison regarding the bail
    Constant('EventFlag_Snowstorm'): Byte(
        0x80), // Set when you step out of the Raja's temple and have the conversation about the snowstorm
    Constant('EventFlag_LandaleWhereabouts'):
        Byte(0x81), // Set after Gyuna tells you about the Landale
    Constant('EventFlag_DezoSpaceport'):
        Byte(0x82), // Set after the Dezolis spaceport appears
    Constant('EventFlag_DarkForce1'):
        Byte(0x83), // Set when you fight the 1st Dark Force
    Constant('EventFlag_TylerGrave'):
        Byte(0x84), // Set after you open Tyler's grave for the first time
    Constant('EventFlag_RajaTemple'):
        Byte(0x85), // Set after the crash landing on Raja's temple
    Constant('EventFlag_Kuran'):
        Byte(0x86), // Set when you reach Kuran for the first time
    Constant('EventFlag_NearDarkForce1'):
        Byte(0x87), // Set when you are approaching the 1st Dark Force
    Constant('EventFlag_RajaJoined'): Byte(0x88), // Set when Raja joins
    Constant('EventFlag_IceDigger'): Byte(
        0x89), // Set after defeating the 1st Dark Force and getting the Ice Digger
    Constant('EventFlag_Penguin'): Byte(
        0x8A), // Set when you have the Penguin in Zosa follow you// cleared when you enter Zosa or come out of a building in Zosa
    Constant('EventFlag_Reshel'): Byte(
        0x8B), // Set when you fight the zombies as you enter Reshel for the first time
    Constant('EventFlag_PenguinNoMoney'): Byte(
        0x8C), // Set if you talk to the Penguin guy when you don't have enough money// cleared otherwise
    Constant('EventFlag_MuskCats'): Byte(
        0x90), // Set when you talk to the 2 musk cats guarding the room entrance
    Constant('EventFlag_SilverTusk'):
        Byte(0x91), // Set when you receive the Silver Tusk
    Constant('EventFlag_DezoGyLaguiah'): Byte(
        0x92), // Set when you fight a Gy Laguiah in the Dezolis climate center
    Constant('EventFlag_DElmLars'): Byte(
        0x93), // Set when you fight the D-Elm-Lars in the Dezolis climate center
    Constant('EventFlag_RajaSick'): Byte(0x94), // Set when Raja falls sick
    Constant('EventFlag_CarnivorousTrees'): Byte(
        0x95), // Set when you fight the carnivorous trees when you go save Kyra
    Constant('EventFlag_InnerSanctuary'): Byte(
        0x96), // Set when rune convinces the esper guards to let you enter the Inner Sanctuary
    Constant('EventFlag_LutzRevelation'): Byte(
        0x97), // Set after Rune reveals that he's Lutz and then you decide to go to the Garuberk Tower
    Constant('EventFlag_EclipseTorchStolen'):
        Byte(0x98), // Set when the Eclipse Torch is stolen
    Constant('EventFlag_AirCastleFound'):
        Byte(0x99), // Set when you locate the Air Castle
    Constant('EventFlag_XeAThoul'):
        Byte(0x9A), // Set when you fight the 3 Xe-A-Thouls in the Air Castle
    Constant('EventFlag_Lashiec'): Byte(0x9B), // Set when you fight Lashiec
    Constant('EventFlag_EclipseTorch'): Byte(
        0x9C), // Set when you use the Eclipse Torch to destroy the carnivorous trees
    Constant('EventFlag_Hydrofoil'): Byte(
        0x9D), // Set after giving the Eclipse Torch back and you get the Hydrofoil
    Constant('EventFlag_DarkForce2'):
        Byte(0x9E), // Set when you fight the 2nd Dark Force
    Constant('EventFlag_AirCastle'):
        Byte(0x9F), // Set when you arrive at the Air Castle
    Constant('EventFlag_KyraJoined'):
        Byte(0xA0), // Set when Kyra joins the party
    Constant('EventFlag_SnowstormGone'):
        Byte(0xA1), // Set after defeating the 2nd Dark Force
    Constant('EventFlag_InnerSanctGuard1'): Byte(
        0xA2), // Set when talking to the old man in the Inner Sanctuary the first time
    Constant('EventFlag_InnerSanctGuard2'): Byte(
        0xA3), // Set when talking to the old man in the Inner Sanctuary before getting Elsydeon
    Constant('EventFlag_ClimateCenter'): Byte(
        0xA4), // Set after the fight with the Gy Laguiah in the Dezolis climate center
    Constant('EventFlag_DElmLarsDefeated'): Byte(
        0xA5), // Set after the fight with the D-Elm-Lars in the Dezolis climate center
    Constant('EventFlag_Spector'): Byte(
        0xA6), // Set when you fight the Spector after opening the chest with the fake Eclipse Torch
    Constant('EventFlag_DyingBoy'):
        Byte(0xA8), // Set when you take on the Dying Boy commission
    Constant('EventFlag_Culvers'):
        Byte(0xA9), // Set after talking to Culvers, the dying boy's father
    Constant('EventFlag_AlisSword'):
        Byte(0xAA), // Set after using the Alis sword to help the boy recover
    Constant('EventFlag_CulversAfterRecovery'):
        Byte(0xAB), // Set when you talk to Culvers after the boy recovers
    Constant('EventFlag_DyingBoyFee'):
        Byte(0xAC), // Set after accepting the Dying Boy fee from the guild
    Constant('EventFlag_ManWithTwist'):
        Byte(0xAD), // Set when you take on the Man with twist commission
    Constant('EventFlag_Sekreas'):
        Byte(0xAE), // Set when you talk to Sekreas during the commission
    Constant('EventFlag_KingRappy'):
        Byte(0xAF), // Set when you fight the King Rappy
    Constant('EventFlag_ManWithTwistFee'): Byte(
        0xB0), // Set after talking to the Hunters' Guild receptionist after ending the Man with Twist commission
    Constant('EventFlag_SilverSoldier'):
        Byte(0xB1), // Set when you take on the Silver Soldier commission
    Constant('EventFlag_Servants'):
        Byte(0xB2), // Set when you fight the Servants as you enter Zema
    Constant('EventFlag_ZemaOldMan'): Byte(
        0xB3), // Set after talking to the old man in Zema explaining the robots situation
    Constant('EventFlag_VahalFort'): Byte(
        0xB4), // Set when you enter Vahal Fort and have the conversation about the robots
    Constant('EventFlag_VahalFortMidway'): Byte(
        0xB5), // Set when you enter the room with the conveyor belts and have the conversation in Vahal Fort
    Constant('EventFlag_Dominators'):
        Byte(0xB6), // Set when you fight the Dominators in Vahal Fort
    Constant('EventFlag_OldManZemaAfterDaughter'): Byte(
        0xB7), // Set after talking to the old man in Zema after shutting down Daughter
    Constant('EventFlag_SilverSoldierFee'): Byte(
        0xB8), // Set after accepting the fee from the guild for the Silver Soldier mission
    Constant('EventFlag_VahFortBarrier'): Byte(
        0xB9), // Set after you have the conversation about the barrier in Vahal Fort
    Constant('EventFlag_SekreasReason'): Byte(
        0xBA), // Set after defeating King Rappy and Sekreas explains why he commissioned hunters
    Constant('EventFlag_DaughterShutDown'):
        Byte(0xBB), // Set after shutting down Daughter in Vahal Fort
    Constant('EventFlag_Hydrofoil2'): Byte(
        0xC0), // Set after giving the Eclipse Torch back and you get the Hydrofoil
    Constant('EventFlag_SethJoined'):
        Byte(0xC1), // Set when Seth joins your party
    Constant('EventFlag_SethConversation1'):
        Byte(0xC2), // Set when you have a conversation with Seth on the way up
    Constant('EventFlag_SethConversation2'):
        Byte(0xC3), // Set when you have a conversation with Seth on the way up
    Constant('EventFlag_SoldiersTemple'): Byte(
        0xC4), // Set when you exit the cave leading to the Soldier's Temple
    Constant('EventFlag_DarkForce3'):
        Byte(0xC5), // Set when you fight Dark Force 3
    Constant('EventFlag_DarkForce3Defeated'):
        Byte(0xC6), // Set after defeating Dark Force 3
    Constant('EventFlag_WeaponPlant'):
        Byte(0xC7), // Set when you enter the Weapon Plant on Dezolis
    Constant('EventFlag_AeroPrism1'):
        Byte(0xC8), // Set when you find the Aero-Prism
    Constant('EventFlag_AeroPrism2'):
        Byte(0xC9), // Set when you find the Aero-Prism
    Constant('EventFlag_Rykros'): Byte(0xD0), // Set when you find Rykros
    Constant('EventFlag_LeRoof'):
        Byte(0xD1), // Set when you talk to Le Roof for the first time
    Constant('EventFlag_SaLews'): Byte(0xD2), // Set when you fight Sa-Lews
    Constant('EventFlag_CourageTowerChests'): Byte(
        0xD3), // Set after you open all the chests at the top of the Courage Tower
    Constant('EventFlag_DeVars'): Byte(0xD4), // Set when you fight De-Vars
    Constant('EventFlag_StrengthTowerChests'): Byte(
        0xD5), // Set after you open all the chests at the top of the Strength Tower
    Constant('EventFlag_LeRoofStory1'):
        Byte(0xD6), // Set after Le Roof tells you the story of Algo's origin
    Constant('EventFlag_LeRoofStory2'):
        Byte(0xD7), // Set after Le Roof tells you the story of Algo's origin
    Constant('EventFlag_ElsydeonCave'): Byte(
        0xD8), // Set when Rune tells you about Elsydeon and opens the cave to it
    Constant('EventFlag_Elsydeon'):
        Byte(0xD9), // Set when you trigger the Elsydeon cutscene
    Constant('EventFlag_Reunion'): Byte(
        0xDA), // Set when everyone gathers together before the final dungeon
    Constant('EventFlag_HahnPicked'): Byte(
        0xDB), // Set when you choose Hahn as the 5th character// cleared when you choose someone else
    Constant('EventFlag_GryzPicked'): Byte(
        0xDC), // Set when you choose Gryz as the 5th character// cleared when you choose someone else
    Constant('EventFlag_DemiPicked'): Byte(
        0xDD), // Set when you choose Demi as the 5th character// cleared when you choose someone else
    Constant('EventFlag_RajaPicked'): Byte(
        0xDE), // Set when you choose Raja as the 5th character// cleared when you choose someone else
    Constant('EventFlag_KyraPicked'): Byte(
        0xDF), // Set when you choose Kyra as the 5th character// cleared when you choose someone else
    Constant('EventFlag_AngerTower'):
        Byte(0xE0), // Set when you are allowed to enter the Anger Tower
    Constant('EventFlag_ReFaze'):
        Byte(0xE1), // Set when you either choose to learn about Megid or not
    Constant('EventFlag_StrengthTowerTop'): Byte(
        0xE2), // Set when you reach the top of the Strength Tower and De-Vars kills the monsters
    Constant('EventFlag_CourageTowerTop'): Byte(
        0xE3), // Set when you reach the top of the Courage Tower and Sa-Lews kills the monsters
    Constant('EventFlag_AlysFight'):
        Byte(0xE4), // Set when you fight Alys in the Anger Tower
    Constant('EventFlag_DeVarsDefeated'):
        Byte(0xE5), // Set after defeating De-Vars
    Constant('EventFlag_SaLewsDefeated'):
        Byte(0xE6), // Set after defeating Sa-Lews
    Constant('EventFlag_AngerTowerEnd'): Byte(
        0xE7), // Set when you exit the top of the Anger Tower and Chaz reunites with his friends
    Constant('EventFlag_ProfoundDarkness'):
        Byte(0xE8), // Set when you fight Profound Darkness
    Constant('EventFlag_GuildPlaceholder'): Byte(
        0xEB), // Always cleared// used as a placeholder in the Hunters' Guild section to mean that, once a request is available,
  });

final popdlg = cmd('popdlg', []);

Asm vIntPrepareLoop(Word additionalFrames) {
  return Asm(
      [move.w(additionalFrames.i, d0), jsr(Label('VInt_PrepareLoop').l)]);
}

Asm doMapUpdateLoop(Word additionalFrames) {
  return Asm([move.w(additionalFrames.i, d0), jsr(Label('DoMapUpdateLoop').l)]);
}

@Deprecated('currently broken, but interesting idea')
Asm doInteractionUpdatesLoop(Word additionalFrames) {
  return Asm([
    move.w(additionalFrames.i, d0),
    jsr(Label('DoInteractionUpdatesLoop').l)
  ]);
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

Asm getAndRunDialog3LowDialogId(Address dialogId) {
  return Asm([
    moveq(dialogId, d0),
    jsr(Label('Event_GetAndRunDialogue3').l),
  ]);
}

Asm returnFromInteractionEvent() {
  /*
	move.w	#0, (Game_Mode_Routine).w
	movea.l	(Map_Chunk_Addr).w, a0
	jsr	(Map_LoadChunks).l
	rts
   */
  return Asm([
    move.w(0.toWord.i, Constant('Game_Mode_Routine').w),
    movea.l(Constant('Map_Chunk_Addr').w, a0),
    jmp(Label('Map_LoadChunks').l),
  ]);
}

/// Use after F7 (see TextCtrlCode_Terminate2 and 3)
final popAndRunDialog = Asm([
  // appears around popdlg in one scene for some reason
  //clr.b(Label('Render_Sprites_In_Cutscenes').w),
  cmd('popdlg', []),
  jsr(Label('Event_RunDialogue').l),
]);

/// Use after F7 (see TextCtrlCode_Terminate2 and 3)
final popAndRunDialog3 = Asm([
  // appears around popdlg in one scene for some reason
  //clr.b(Label('Render_Sprites_In_Cutscenes').w),
  cmd('popdlg', []),
  jsr(Label('Event_RunDialogue3').l),
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
    if (direction != d0) moveq(direction, d0),
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
Asm setDestination(
    {required Address x,
    required Address y,
    DirectAddressRegister object = a4}) {
  return Asm([
    move.w(x, object.indirect.plus(dest_x_pos)),
    move.w(y, object.indirect.plus(dest_y_pos)),
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

/// Moves the object at address A4 by rate ([x] and [y]) and time
/// ([additionalFrames] + 1)).
Asm stepObject(
    {required Address x,
    required Address y,
    required Address additionalFrames}) {
  return Asm([
    move.l(x, d0),
    move.l(y, d1),
    move.l(additionalFrames, d2),
    jsr(Label('Event_StepObject').l),
    setDestination(
        x: a4.indirect.plus(curr_x_pos), y: a4.indirect.plus(curr_y_pos))
  ]);
}

Asm moveCamera(
    {required Address x, required Address y, required Address speed}) {
  return Asm([
    move.w(x, d0),
    move.w(y, d1),
    move.w(speed, d2),
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
  checkArgument(1 <= slot && slot <= 5,
      message: 'slot must be within 1-5 but was $slot');
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

Asm saveCurrentPartySlots() {
  return Asm([
    move.l(Current_Party_Slots.w, Constant('Saved_Char_ID_Mem_1').w),
    move.b(Current_Party_Slot_5.w, Constant('Saved_Char_ID_Mem_5').w)
  ]);
}

Asm restoreSavedPartySlots() {
  return Asm([
    move.l(
        Constant('Saved_Char_ID_Mem_1').w, Constant('Current_Party_Slots').w),
    move.b(
        Constant('Saved_Char_ID_Mem_5').w, Constant('Current_Party_Slot_5').w),
  ]);
}

/// Clear the addresses from [clear] to [clear] plus [range] (not inclusive I
/// think).
Asm clearUninterrupted({required Address clear, required Address range}) {
  return Asm([lea(clear, a0), move.w(range, d7), trap(0.toByte.i)]);
}

Asm branchIfExtendableFlagSet(KnownConstantValue flag, Address to,
    {bool short = false}) {
  if (flag.value > Byte.max) {
    return Asm([
      move.w(flag.constant.i, d0),
      jsr(Label('ExtendedEventFlags_Test').l),
      if (short) bne.s(to) else bne.w(to)
    ]);
  } else {
    return Asm([
      if (flag.value <= Byte(127))
        moveq(flag.constant.i, d0)
      else
        move.b(flag.constant.i, d0),
      jsr(Label('EventFlags_Test').l),
      if (short) bne.s(to) else bne.w(to)
    ]);
  }
}

Asm branchIfExtendableFlagNotSet(KnownConstantValue flag, Address to,
    {bool short = false}) {
  if (flag.value > Byte.max) {
    return Asm([
      move.w(flag.constant.i, d0),
      jsr(Label('ExtendedEventFlags_Test').l),
      if (short) beq.s(to) else beq.w(to)
    ]);
  } else {
    return Asm([
      if (flag.value <= Byte(127))
        moveq(flag.constant.i, d0)
      else
        move.b(flag.constant.i, d0),
      jsr(Label('EventFlags_Test').l),
      if (short) beq.s(to) else beq.w(to)
    ]);
  }
}

Asm refreshMap({bool refreshObjects = true}) {
  return Asm([
    if (refreshObjects)
      bclr(3.i, Map_Load_Flags.w)
    else
      bset(3.i, Map_Load_Flags.w),
    jsr(Label('RefreshMap').l)
  ]);
}

Asm fadeOut({bool initVramAndCram = false}) {
  return initVramAndCram
      ?
      // This calls PalFadeOut_ClrSpriteTbl
      // which is what actually does the fade out,
      // Then it clears plane A and VRAM completely,
      // resets camera position,
      // and resets palette
      // It is used often in cutscenes but maybe does too much.
      jsr(Label('InitVRAMAndCRAM').l)
      : jsr(Label('PalFadeOut_ClrSpriteTbl').l);
}

Asm fadeIn() => jsr(Label('Pal_FadeIn').l);

Asm changeMap(
    {required Address to,
    Address? from,
    required Address startX,
    required Address startY,
    required Address facingDir,
    required Address partyArrangement}) {
  return Asm([
    move.w(to, Field_Map_Index.w),
    if (from != null) move.w(from, Field_Map_Index_2.w),
    move.w(startX, Map_Start_X_Pos.w),
    move.w(startY, Map_Start_Y_Pos.w),
    move.w(facingDir, Map_Start_Facing_Dir.w),
    move.w(partyArrangement, Map_Start_Char_Align.w),
    refreshMap(refreshObjects: true),
  ]);
}

Asm setEventFlag(KnownConstantValue flag) {
  if (flag.value > Byte.max) {
    return Asm(
        [move.w(flag.constant.i, d0), jsr('ExtendedEventFlags_Set'.toLabel.l)]);
  } else {
    return Asm([
      if (flag.value <= Byte(127))
        moveq(flag.constant.i, d0)
      else
        move.b(flag.constant.i, d0),
      jsr('EventFlags_Set'.toLabel.l)
    ]);
  }
}
