import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:quiver/collection.dart';

import 'data.dart';

/// Routines which are noninteractive therefore do not have any interactive
/// scene to parse, regardless of what dialog ID refers to in the tree.
///
/// These objects are kept mainly to retain their presence in the compiled
/// assembly. They may be converted to modeled object specs as needed.
final _noninteractiveAsmSpecRoutines = const [
  0x1f8, // FieldObj_ChestBarrier
  0x1fc, // FieldObj_ChestBarrierSplinter
  0x184, // FieldObj_Xanafalgue
  0x18, // FieldObj_Rika
  0x16C, // FieldObj_Mouse
  0x30c, // FieldObj_PrisonDoor
  0x1b0, // FieldObj_DorinChair,
  0xA4, // FieldObj_Fire
  0x154, // FieldObj_BigFire,
  0x158, // FieldObj_FireplaceFire
  0x98, // FieldObj_CaveWallPiece
  // 0x94, // loc_4AF38 - not in map
  0x90, // FieldObj_Statue
  0x188, // FieldObj_Igglanova
  0x1E8, // FieldObj_Zio
  // loc_49502 - already accounted for in specs
  // loc_489D6 - man running away, ignore
  // FieldObj_XeAThoulMoving - not used in map
  // FieldObj_LightCircle2 - not used in map
  // FieldObj_LightCircle - not used in map
  // FieldObj_XeAThoulDisappearing - not used in map
  // FieldObj_XeAThoul - not used in map
  // FieldObj_XeAThoulAppearing - not used in map
  0x340, // FieldObj_LutzMirror
  // FieldObj_Lashiec - not in map
  // loc_4FAE0 - not in map
  0x300, // FieldObj_TonoeBasementDoor
  0x2C4, // FieldObj_ZemaRocks
  // FieldObj_ExplDust - not in map
  // FieldObj_BlastedRock - not in map
  // FieldObj_Flaeli - not in map
  // FieldObj_NPCRuneFlaeli - not in map
  // FieldObj_GyLaguiah - not in map
  // FieldObj_ZioBeam - not in map
  // FieldObj_LandingSpaceship - not in map
  // FieldObj_PropulsiveJet - not in map
  // FieldObj_Spaceship - not in map
  // FieldObj_LandingLandaleJets - not in map
  // FieldObj_LandingLandale - not in map
  // FieldObj_LandaleBeam - not in map
  // FieldObj_LandalePropulsionJets - not in map
  // FieldObj_LandaleRearWings - not in map
  // FieldObj_LandaleWings - not in map
  // FieldObj_Landale - not in map
  // loc_4D48C - not in map
  // FieldObj_NPCAlysTonoe - not in map
  // loc_4D3DE - not in map
  // FieldObj_SayaStars - not in map
  // FieldObj_Dust - not in map
  // loc_4D2D0 - not in map
  // FieldObj_DancingStripper3 - not in map
  // FieldObj_DancingStripper2 - not in map
  // FieldObj_DancingStripper1 - not in map
  // FieldObj_StripperCoat - not in map
  // FieldObj_Stripper - not in map
  // FieldObj_ChazAlisSword - not in map
  0x32C, // FieldObj_KingRappyFlyingAway
  0x324, // FieldObj_StudentInBed
  0x320, // FieldObj_RajaInBed
  0x31C, // loc_4BE80
  0x318, // loc_4BE38
  0x314, // loc_4BDF0
  0x308, // FieldObj_DemiTrapped
  0x304, // FieldObj_TrappingRopes
  // loc_4BC80 - not in map
  0x25C, // FieldObj_Barrier
  0x238, // FieldObj_MuskCatChiefBottomHalf
  0x234, // FieldObj_MuskCatChiefTopHalf
  0x1E4, // FieldObj_BarrierBeam4
  0x1E0, // FieldObj_BarrierBeam3
  0x1DC, // FieldObj_BarrierBeam2
  0x1D8, // FieldObj_BarrierBeam1
  // loc_4B30C - not in map
  // loc_4B16A - not in map
  // loc_4B0D6 - not in map
];

// generated from asm using
// sed 's/\tbra.w\t//' | gsed -E 's/(\w+)\s;\s\$?(\w+).*/Label('"'"'\1'"'"'): Word(0x\2),/'
// could also consider passing externally from parsed ASM
final _fieldObjectsJmpTbl = BiMap<Label, Word>()
  ..addAll({
    Label('FieldObj_None'): Word(0x0),
    Label('FieldObj_Chaz'): Word(0x4),
    Label('FieldObj_Alys'): Word(0x8),
    Label('FieldObj_Hahn'): Word(0xC),
    Label('FieldObj_Rune'): Word(0x10),
    Label('FieldObj_Gryz'): Word(0x14),
    Label('FieldObj_Rika'): Word(0x18),
    Label('FieldObj_Demi'): Word(0x1C),
    Label('FieldObj_Wren'): Word(0x20),
    Label('FieldObj_Raja'): Word(0x24),
    Label('FieldObj_Kyra'): Word(0x28),
    Label('FieldObj_Seth'): Word(0x2C),
    Label('FieldObj_ScrollTextArrow'): Word(0x30),
    Label('FieldObj_RedCursor'): Word(0x34),
    Label('FieldObj_NPCType1'): Word(0x38),
    Label('FieldObj_NPCType2'): Word(0x3C),
    Label('FieldObj_NPCType3'): Word(0x40),
    Label('FieldObj_NPCType4'): Word(0x44),
    Label('FieldObj_NPCType5'): Word(0x48),
    Label('FieldObj_NPCType6'): Word(0x4C),
    Label('FieldObj_NPCType7'): Word(0x50),
    Label('FieldObj_NPCType8'): Word(0x54),
    Label('FieldObj_NPCType9'): Word(0x58),
    Label('FieldObj_NPCType10'): Word(0x5C),
    Label('FieldObj_NPCType11'): Word(0x60),
    Label('FieldObj_NPCType12'): Word(0x64),
    Label('FieldObj_NPCAlysPiata'): Word(0x68),
    Label('FieldObj_NPCHahnNearBasement'): Word(0x6C),
    Label('FieldObj_NPCRune'): Word(0x70),
    Label('FieldObj_InvisibleBlock'): Word(0x74),
    Label('FieldObj_DividingSandOrSnow'): Word(0x78),
    Label('FieldObj_LiftingSandOrSnow'): Word(0x7C),
    Label('loc_4D1D2'): Word(0x80),
    Label('FieldObj_PlaceFadeIn'): Word(0x84),
    Label('FieldObj_NPCType13'): Word(0x88),
    Label('FieldObj_NPCType14'): Word(0x8C),
    Label('FieldObj_Statue'): Word(0x90),
    Label('loc_4AF38'): Word(0x94),
    Label('FieldObj_CaveWallPiece'): Word(0x98),
    Label('FieldObj_Penguin'): Word(0x9C),
    Label('FieldObj_TreasureChest'): Word(0xA0),
    Label('FieldObj_Fire'): Word(0xA4),
    Label('loc_4B0D6'): Word(0xA8),
    Label('loc_4B16A'): Word(0xAC),
    Label('FieldObj_LandRover'): Word(0xB0),
    Label('FieldObj_IceDigger'): Word(0xB4),
    Label('FieldObj_Hydrofoil'): Word(0xB8),
    Label('loc_489D6'): Word(0xBC),
    Label('FieldObj_NPCType16'): Word(0xC0),
    Label('FieldObj_NPCType17'): Word(0xC4),
    Label('FieldObj_NPCType18'): Word(0xC8),
    Label('FieldObj_NPCType19'): Word(0xCC),
    Label('FieldObj_NPCType20'): Word(0xD0),
    Label('FieldObj_NPCType21'): Word(0xD4),
    Label('FieldObj_NPCType22'): Word(0xD8),
    Label('FieldObj_NPCType23'): Word(0xDC),
    Label('FieldObj_NPCType24'): Word(0xE0),
    Label('FieldObj_NPCType25'): Word(0xE4),
    Label('FieldObj_NPCType26'): Word(0xE8),
    Label('FieldObj_NPCHahn'): Word(0xEC),
    Label('FieldObj_NPCGryz'): Word(0xF0),
    Label('FieldObj_NPCType27'): Word(0xF4),
    Label('FieldObj_NPCType28'): Word(0xF8),
    Label('FieldObj_NPCType29'): Word(0xFC),
    Label('FieldObj_NPCType30'): Word(0x100),
    Label('FieldObj_NPCType31'): Word(0x104),
    Label('FieldObj_NPCType32'): Word(0x108),
    Label('FieldObj_NPCType33'): Word(0x10C),
    Label('FieldObj_NPCType34'): Word(0x110),
    Label('FieldObj_Prisoner'): Word(0x114),
    Label('FieldObj_NPCType35'): Word(0x118),
    Label('FieldObj_NPCType36'): Word(0x11C),
    Label('FieldObj_Elevator'): Word(0x120),
    Label('loc_4D2D0'): Word(0x124),
    Label('loc_48F36'): Word(0x128),
    Label('loc_48F96'): Word(0x12C),
    Label('loc_48FF4'): Word(0x130),
    Label('FieldObj_Pana'): Word(0x134),
    Label('loc_490B8'): Word(0x138),
    Label('loc_49128'): Word(0x13C),
    Label('loc_49502'): Word(0x140),
    Label('loc_49192'): Word(0x144),
    Label('loc_49212'): Word(0x148),
    Label('loc_49542'): Word(0x14C),
    Label('FieldObj_Dust'): Word(0x150),
    Label('FieldObj_BigFire'): Word(0x154),
    Label('FieldObj_FireplaceFire'): Word(0x158),
    Label('FieldObj_EclipseTorch'): Word(0x15C),
    Label('FieldObj_MileSandWorm'): Word(0x160),
    Label('loc_4B4B4'): Word(0x164),
    Label('FieldObj_Rocky'): Word(0x168),
    Label('FieldObj_Mouse'): Word(0x16C),
    Label('FieldObj_Butterfly'): Word(0x170),
    Label('FieldObj_BigDuck'): Word(0x174),
    Label('FieldObj_SmallWhiteDuck'): Word(0x178),
    Label('FieldObj_SmallBrownDuck'): Word(0x17C),
    Label('FieldObj_FaintedPriest'): Word(0x180),
    Label('FieldObj_Xanafalgue'): Word(0x184),
    Label('FieldObj_Igglanova'): Word(0x188),
    Label('FieldObj_ProfHoltPetrified'): Word(0x18C),
    Label('FieldObj_NPCRuneSequence'): Word(0x190),
    Label('FieldObj_NPCScriptMove'): Word(0x194),
    Label('loc_483DC'): Word(0x198),
    Label('loc_469D4'): Word(0x19C),
    Label('FieldObj_SayaStars'): Word(0x1A0),
    Label('loc_4D3DE'): Word(0x1A4),
    Label('FieldObj_NPCAlysTonoe'): Word(0x1A8),
    Label('loc_4D48C'): Word(0x1AC),
    Label('FieldObj_DorinChair'): Word(0x1B0),
    Label('FieldObj_Juza'): Word(0x1B4),
    Label('FieldObj_Landale'): Word(0x1B8),
    Label('FieldObj_LandaleWings'): Word(0x1BC),
    Label('FieldObj_LandaleRearWings'): Word(0x1C0),
    Label('FieldObj_LandalePropulsionJets'): Word(0x1C4),
    Label('FieldObj_LandaleBeam'): Word(0x1C8),
    Label('FieldObj_LandingLandale'): Word(0x1CC),
    Label('FieldObj_LandingLandaleJets'): Word(0x1D0),
    Label('FieldObj_WhiteTreasureChest'): Word(0x1D4),
    Label('FieldObj_BarrierBeam1'): Word(0x1D8),
    Label('FieldObj_BarrierBeam2'): Word(0x1DC),
    Label('FieldObj_BarrierBeam3'): Word(0x1E0),
    Label('FieldObj_BarrierBeam4'): Word(0x1E4),
    Label('FieldObj_Zio'): Word(0x1E8),
    Label('FieldObj_ZioBeam'): Word(0x1EC),
    Label('FieldObj_NPCWren'): Word(0x1F0),
    Label('FieldObj_Snow'): Word(0x1F4),
    Label('FieldObj_ChestBarrier'): Word(0x1F8),
    Label('FieldObj_ChestBarrierSplinter'): Word(0x1FC),
    Label('FieldObj_Spaceship'): Word(0x200),
    Label('FieldObj_PropulsiveJet'): Word(0x204),
    Label('FieldObj_LandingSpaceship'): Word(0x208),
    Label('FieldObj_GyLaguiah'): Word(0x20C),
    Label('FieldObj_World'): Word(0x210),
    Label('FieldObj_NPCRuneFlaeli'): Word(0x214),
    Label('FieldObj_Flaeli'): Word(0x218),
    Label('FieldObj_BlastedRock'): Word(0x21C),
    Label('FieldObj_ExplDust'): Word(0x220),
    Label('FieldObj_GravestoneHalf'): Word(0x224),
    Label('FieldObj_MuskCat'): Word(0x228),
    Label('FieldObj_MuskCatGuardMoved'): Word(0x22C),
    Label('FieldObj_LyingDownMuskCat'): Word(0x230),
    Label('FieldObj_MuskCatChiefTopHalf'): Word(0x234),
    Label('FieldObj_MuskCatChiefBottomHalf'): Word(0x238),
    Label('FieldObj_MuskCatGuard'): Word(0x23C),
    Label('FieldObj_FellowPenguin'): Word(0x240),
    Label('loc_496C6'): Word(0x244),
    Label('loc_49746'): Word(0x248),
    Label('loc_497A8'): Word(0x24C),
    Label('loc_4980A'): Word(0x250),
    Label('FieldObj_NPCKyra'): Word(0x254),
    Label('loc_4986C'): Word(0x258),
    Label('FieldObj_Barrier'): Word(0x25C),
    Label('loc_498CA'): Word(0x260),
    Label('FieldObj_NPCRika'): Word(0x264),
    Label('FieldObj_EsperGuard'): Word(0x268),
    Label('FieldObj_InnerEsperGuards'): Word(0x26C),
    Label('FieldObj_FractOoze'): Word(0x270),
    Label('FieldObj_DElmLars'): Word(0x274),
    Label('FieldObj_DarkForce1'): Word(0x278),
    Label('FieldObj_DarkForce2'): Word(0x27C),
    Label('FieldObj_XeAThoulAppearing'): Word(0x280),
    Label('FieldObj_XeAThoul'): Word(0x284),
    Label('FieldObj_XeAThoulDisappearing'): Word(0x288),
    Label('FieldObj_LightCircle'): Word(0x28C),
    Label('FieldObj_LightCircle2'): Word(0x290),
    Label('FieldObj_XeAThoulMoving'): Word(0x294),
    Label('FieldObj_NPCAlysInBed'): Word(0x298),
    Label('FieldObj_XeAThoulAirCastle'): Word(0x29C),
    Label('FieldObj_DeVars'): Word(0x2A0),
    Label('FieldObj_DeVarsFire'): Word(0x2A4),
    Label('FieldObj_GiLeFarg'): Word(0x2A8),
    Label('FieldObj_GiLeFargTandil'): Word(0x2AC),
    Label('FieldObj_SaLews'): Word(0x2B0),
    Label('FieldObj_SaLewsRay'): Word(0x2B4),
    Label('FieldObj_Blindheads'): Word(0x2B8),
    Label('FieldObj_BlindheadsRay'): Word(0x2BC),
    Label('FieldObj_ReFaze'): Word(0x2C0),
    Label('FieldObj_ZemaRocks'): Word(0x2C4),
    Label('FieldObj_NPCRajaSpaceport'): Word(0x2C8),
    Label('FieldObj_NPCKyraSpaceport'): Word(0x2CC),
    Label('FieldObj_NPCGryzSpaceport'): Word(0x2D0),
    Label('FieldObj_NPCHahnSpaceport'): Word(0x2D4),
    Label('FieldObj_NPCDemiSpaceport'): Word(0x2D8),
    Label('FieldObj_GryzSpaceportWaiting'): Word(0x2DC),
    Label('FieldObj_HahnSpaceportWaiting'): Word(0x2E0),
    Label('FieldObj_DemiSpaceportWaiting'): Word(0x2E4),
    Label('FieldObj_RajaSpaceportWaiting'): Word(0x2E8),
    Label('FieldObj_KyraSpaceportWaiting'): Word(0x2EC),
    Label('FieldObj_AlysAngerTower'): Word(0x2F0),
    Label('FieldObj_StrayRocky'): Word(0x2F4),
    Label('loc_4BC80'): Word(0x2F8),
    Label('FieldObj_Tallas'): Word(0x2FC),
    Label('FieldObj_TonoeBasementDoor'): Word(0x300),
    Label('FieldObj_TrappingRopes'): Word(0x304),
    Label('FieldObj_DemiTrapped'): Word(0x308),
    Label('FieldObj_PrisonDoor'): Word(0x30C),
    Label('FieldObj_TallasShoes'): Word(0x310),
    Label('loc_4BDF0'): Word(0x314),
    Label('loc_4BE38'): Word(0x318),
    Label('loc_4BE80'): Word(0x31C),
    Label('FieldObj_RajaInBed'): Word(0x320),
    Label('FieldObj_StudentInBed'): Word(0x324),
    Label('FieldObj_KingRappy'): Word(0x328),
    Label('FieldObj_KingRappyFlyingAway'): Word(0x32C),
    Label('FieldObj_Tinkerbell'): Word(0x330),
    Label('FieldObj_ChazAlisSword'): Word(0x334),
    Label('loc_4FAE0'): Word(0x338),
    Label('FieldObj_Lashiec'): Word(0x33C),
    Label('FieldObj_LutzMirror'): Word(0x340),
    Label('FieldObj_Stripper'): Word(0x344),
    Label('FieldObj_StripperCoat'): Word(0x348),
    Label('FieldObj_StripClubCustomer'): Word(0x34C),
    Label('loc_49406'): Word(0x350),
    Label('loc_49442'): Word(0x354),
    Label('FieldObj_SaveSlotCursor'): Word(0x358),
    Label('FieldObj_DancingStripper1'): Word(0x35C),
    Label('FieldObj_DancingStripper2'): Word(0x360),
    Label('FieldObj_DancingStripper3'): Word(0x364),
    Label('loc_4B30C'): Word(0x368),
    Label('FieldObj_Pennant'): Word(0x36C),
    Label('FieldObj_SandWormCarving'): Word(0x370),
    Label('loc_4FA30'): Word(0x374),
  });

Map<Label, Word> get fieldObjectsJmpTbl {
  return _fieldObjectsJmpTbl.lock.unlockView;
}

bool isInteractive(Word routineIndex) {
  return !_noninteractiveAsmSpecRoutines.contains(routineIndex.value);
}

Word? indexOfFieldObjectRoutine(Label routine) {
  return _fieldObjectsJmpTbl[routine];
}

Label? labelOfFieldObjectRoutine(Word index) {
  return _fieldObjectsJmpTbl.inverse[index];
}
