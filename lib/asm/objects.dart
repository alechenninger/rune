import 'data.dart';

/// Routines which are noninteractive therefore do not have any interactive
/// scene to parse, regardless of what dialog ID refers to in the tree.
///
/// These objects are kept mainly to retain their presence in the compiled
/// assembly. They may be converted to modeled object specs as needed.
final _noninteractiveAsmSpecRoutines = [
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

bool isInteractive(Word routineIndex) {
  return !_noninteractiveAsmSpecRoutines.contains(routineIndex.value);
}
