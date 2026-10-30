import '../asm/asm.dart';

class EventAsm extends Asm {
  EventAsm(super.asm);

  EventAsm.of(Asm asm) : this([asm]);

  EventAsm.empty() : super.empty();

  EventAsm.fromInstruction(super.line) : super.fromInstruction();

  EventAsm.fromInstructions(List<Instruction> super.lines)
      : super.fromInstructions();

  EventAsm.fromRaw(String raw) : super.empty() {
    add(Asm.fromRaw(raw));
  }
}

EventPointers eventPtrs() => EventPointers(_eventPtrs);

EventPointers cutscenePtrs() =>
    EventPointers(_cutscenePtrs, offset: Word(0x8000));

JumpTable<Byte> runEventsJmpTbl() {
  return JumpTable.sparse(
    jump: withNoop(Label.known('RunEvent_NoEvent'), bra.w),
    labels: _runEventsTable,
    newIndex: (i) => Byte(i),
    capacity: 0xff, // $FF terminates the map's run-event list.
  );
}

const _eventPtrs = Array.wrap(Size.l, [
  Label.known('Event_NoEvent'),
  Label.known('Event_NoEvent2'),
  Label.known('Event_NoEvent3'),
  Label.known('Event_AlysFound'),
  Label.known('Event_MeetingHahn'),
  Label.known('Event_NoEvent4'),
  Label.known('Event_MachineCenterAppearing'),
  Label.known('Event_MotaSpaceportAppearing'),
  Label.known('Event_BioPlantDoorOpening'),
  Label.known('Event_BoardingLandRover'),
  Label.known('Event_BoardingIceDigger'),
  Label.known('Event_BoardingHydrofoil'),
  Label.known('Event_BasementContainers'),
  Label.known('Event_MeetingSaya'),
  Label.known('Event_AiedoManCrushOnAlys'),
  Label.known('Event_SuspicionOnPrincipal'),
  Label.known('Event_GettingOffVehicle'),
  Label.known('Event_DezoSpaceportAppearing'),
  Label.known('Event_BioPlantAlarm'),
  Label.known('Event_ElevatorDoorOpening'),
  Label.known('Event_RidingElevator'),
  Label.known('Event_VahFortMovingPlatform1'),
  Label.known('Event_VahFortMovingPlatform2'),
  Label.known('Event_WpnPlntMovingPlatform1'),
  Label.known('Event_WpnPlntMovingPlatform2'),
  Label.known('Event_WpnPlntMovingPlatform3'),
  Label.known('Event_WpnPlntMovingPlatform4'),
  Label.known('Event_VahalFortTerminal'),
  Label.known('Event_WeaponPlantTerminal'),
  Label.known('Event_ConveyorBeltDown'),
  Label.known('Event_ConveyorBeltUp'),
  Label.known('Event_ConveyorBeltRight'),
  Label.known('Event_ConveyorBeltLeft'),
  Label.known('Event_Recovery'),
  Label.known('Event_AiedoManSavings'),
  Label.known('Event_GirlsSneakingOut'),
  Label.known('Event_FaintingPriest'),
  Label.known('Event_AfterIgglanova'),
  Label.known('Event_PrincipalConfession'),
  Label.known('Event_RuneFlaeli'),
  Label.known('Event_AlshlineFound'),
  Label.known('Event_WreckageEngine'),
  Label.known('Event_CancellerReminder'),
  Label.known('Event_GettingLandRover'),
  Label.known('Event_MonsenEarthquake'),
  Label.known('Event_PlateSysEngine'),
  Label.known('Event_RuneLadeaTower'),
  Label.known('Event_PsycoWandChest'),
  Label.known('Event_ZioFortBarrier'),
  Label.known('Event_ZioFanatic'),
  Label.known('Event_MeetingDorin'),
  Label.known('Event_TonoeBasementDoor'),
  Label.known('Event_ZioNurvus'),
  Label.known('Event_GaruberkTwDoorOpening1'),
  Label.known('Event_GaruberkTwDoorOpening2'),
  Label.known('Event_GaruberkTwDoorEntered1'),
  Label.known('Event_GaruberkTwDoorEntered2'),
  Label.known('Event_GaruberkTwEyeAction1'),
  Label.known('Event_GaruberkTwEyeAction2'),
  Label.known('Event_ChazHouse'),
  Label.known('Event_LeavingChazHouse'),
  Label.known('Event_KuranArrival'),
  Label.known('Event_NearDarkForce1'),
  Label.known('Event_DarkForce1'),
  Label.known('Event_Juza'),
  Label.known('Event_JuzaDefeated'),
  Label.known('Event_SilenceTmDoorOpening'),
  Label.known('Event_OutsideRajaTemple'),
  Label.known('Event_TylerGraveOpening'),
  Label.known('Event_PersistentEsperGuards'),
  Label.known('Event_EclipseTorchStolen'),
  Label.known('Event_EclipseTorchUsed'),
  Label.known('Event_MeetingLeRoof'),
  Label.known('Event_MuskCatsGuarding'),
  Label.known('Event_MuskCatElder'),
  Label.known('Event_PenguinOwner'),
  Label.known('Event_CarnivorousTrees'),
  Label.known('Event_SavingKyra'),
  Label.known('Event_DarkForce2'),
  Label.known('Event_EsperGuardPermission'),
  Label.known('Event_DarkForce3Defeated'),
  Label.known('Event_InnerSanctGuard'),
  Label.known('Event_InnerSanctGuardBeforeElsydeon'),
  Label.known('Event_ReshelBattle'),
  Label.known('Event_ClmCenterForcedBattle'),
  Label.known('Event_ClmCenterAfterBattle'),
  Label.known('Event_DElmLars'),
  Label.known('Event_AfterDElmLarsBattle'),
  Label.known('Event_AirCastleArrival'),
  Label.known('Event_XeAThoulBeforeBattle'),
  Label.known('Event_AirCastleFakeChest'),
  Label.known('Event_RajaSick'),
  Label.known('Event_Gyuna'),
  Label.known('Event_LashiecAppearance'),
  Label.known('Event_StrengthTowerTop'),
  Label.known('Event_CourageTowerTop'),
  Label.known('Event_DeVars'),
  Label.known('Event_SaLews'),
  Label.known('Event_AngerTowerAlys'),
  Label.known('Event_ReFaze'),
  Label.known('Event_DeVarsDefeated'),
  Label.known('Event_SaLewsDefeated'),
  Label.known('Event_HuntersGuild'),
  Label.known('Event_RuneHealingChaz'),
  Label.known('Event_PickingFifthCharacter'),
  Label.known('Event_AngerTowerTop'),
  Label.known('Event_AngerTowerExitTop'),
  Label.known('Event_IgglanovaBattle'),
  Label.known('Event_Phonon'),
  Label.known('Event_Hijammer'),
  Label.known('Event_Burstroc'),
  Label.known('Event_PosiBolt'),
  Label.known('Event_RanchOwner'),
  Label.known('Event_MileSandWormBattle'),
  Label.known('Event_RanchOwnerAfterBattle'),
  Label.known('Event_RockyFound'),
  Label.known('Event_CatchingRocky'),
  Label.known('Event_RockyOwner'),
  Label.known('Event_PiataDormOwner'),
  Label.known('Event_MissingStudentFound'),
  Label.known('Event_OldManNearMissingStudent'),
  Label.known('Event_MissingStudentInBed'),
  Label.known('Event_TallasMom'),
  Label.known('Event_TallasMomAfterRescue'),
  Label.known('Event_InsideMonsenHole'),
  Label.known('Event_FractOozeFound'),
  Label.known('Event_TallasRescued'),
  Label.known('Event_LostGirlsMother'),
  Label.known('Event_GirlPrison'),
  Label.known('Event_GirlsBail'),
  Label.known('Event_PayingGirlsBail'),
  Label.known('Event_GirlsBailedOut'),
  Label.known('Event_DyingBoyFather'),
  Label.known('Event_FatherAfterBoyRecovery'),
  Label.known('Event_DyingBoy'),
  Label.known('Event_MeetingSekreas'),
  Label.known('Event_KingRappy'),
  Label.known('Event_KingRappyDefeated'),
  Label.known('Event_ZemaServantBattle'),
  Label.known('Event_ZemaOldMan'),
  Label.known('Event_ZemaOldManAfterMission'),
  Label.known('Event_VahalFortEntrance'),
  Label.known('Event_VahalFortMidway'),
  Label.known('Event_DaughterTerminal'),
  Label.known('Event_VahalFortBarrier'),
  Label.known('Event_DominatorsDefeated'),
  Label.known('Event_WeaponPlantArrival'),
  Label.known('Event_MeeseClinicSickWoman'),
  Label.known('Event_StrippersAppearing'),
  Label.known('Event_ExitingStripClub'),
  Label.known('Event_PenguinFeedStolen'),
  Label.known('Event_Pennant'),
  Label.known('Event_WoodCarving'),
  Label.known('Event_EnterAngerTower'),
  Label.known('Event_SoldiersTempleCaveDialogue1'),
  Label.known('Event_SoldiersTempleCaveDialogue2'),
  Label.known('Event_SoldiersTempleReached'),
  Label.known('Event_AeroPrismFound'),
  Label.known('Event_PiataGuardsReprimand'),
  Label.known('Event_GameStart'),
  Label.known('Event_PiataChazAlone'),
  Label.known('Event_FortuneTeller'),
  Label.known('Event_AfterFortuneTeller'),
]);

const _cutscenePtrs = Array.wrap(Size.l, [
  Label.known('Event_NoEvent'),
  Label.known('Cutscene_PiataPrincipal'),
  Label.known('Cutscene_ProfHolt'),
  Label.known('Cutscene_MeetingRune'),
  Label.known('Cutscene_Dorin'),
  Label.known('Cutscene_Alshline'),
  Label.known('Cutscene_ZemaIgglanovaDefeated'),
  Label.known('Cutscene_MeetingRika'),
  Label.known('Cutscene_DemiRescue'),
  Label.known('Cutscene_AlysWounded'),
  Label.known('Cutscene_PsycoWand'),
  Label.known('Cutscene_ZioDefeated'),
  Label.known('Cutscene_MeetingWren'),
  Label.known('Cutscene_InsideSpaceship'),
  Label.known('Cutscene_SpaceshipSabotage'),
  Label.known('Cutscene_CrashLanding'),
  Label.known('Cutscene_Landale'),
  Label.known('Cutscene_DarkForce1Defeated'),
  Label.known('Cutscene_RajaSick'),
  Label.known('Cutscene_MeetingKyra'),
  Label.known('Cutscene_LutzRevelation'),
  Label.known('Cutscene_FindingAirCastle'),
  Label.known('Cutscene_LashiecDefeated'),
  Label.known('Cutscene_DarkForce2Defeated'),
  Label.known('Cutscene_GumbiousBishop'),
  Label.known('Cutscene_MeetingSeth'),
  Label.known('Cutscene_AeroPrism'),
  Label.known('Cutscene_Rykros'),
  Label.known('Cutscene_LeRoofAgain'),
  Label.known('Cutscene_BeforeElsydeonCave'),
  Label.known('Cutscene_Elsydeon'),
  Label.known('Cutscene_Reunion'),
  Label.known('Cutscene_ProfoundDarkness'),
  Label.known('Cutscene_Ending'),
]);

const _runEventsTable = [
  Label.known('RunEvent_Null00'),
  Label.known('RunEvent_Null01'),
  Label.known('RunEvent_Null02'),
  Label.known('RunEvent_FindingAlys'),
  Label.known('RunEvent_Null04'),
  Label.known('RunEvent_Null05'),
  Label.known('RunEvent_MachineCenter'),
  Label.known('RunEvent_Null07'),
  Label.known('RunEvent_BasementContainers'),
  Label.known('RunEvent_MeetingSayaUnused'),
  Label.known('RunEvent_SuspicionOnPrincipal'),
  Label.known('RunEvent_Null0B'),
  Label.known('RunEvent_BioPlantAlarm'),
  Label.known('RunEvent_RidingElevator'),
  Label.known('RunEvent_VahFortMovingPlatform'),
  Label.known('RunEvent_WpnPlntMovingPlatform'),
  Label.known('RunEvent_VahFortConveyorBelt'),
  Label.known('RunEvent_WpnPlntConveyorBelt'),
  Label.known('RunEvent_Recovery'),
  Label.known('RunEvent_AfterIgglanova'),
  Label.known('RunEvent_Dorin'),
  Label.known('RunEvent_UsingAlshline'),
  Label.known('RunEvent_MeetingSaya'),
  Label.known('RunEvent_ZemaIgglanovaDefeated'),
  Label.known('RunEvent_FindingAlshline'),
  Label.known('RunEvent_RuneLadeaTower'),
  Label.known('RunEvent_MeetingRika'),
  Label.known('RunEvent_GettingLandRover'),
  Label.known('RunEvent_SavingDemi'),
  Label.known('RunEvent_AlysWounded'),
  Label.known('RunEvent_PsycoWandFound'),
  Label.known('RunEvent_ZioNurvus'),
  Label.known('RunEvent_ZioDefeated'),
  Label.known('RunEvent_EnterSpaceship'),
  Label.known('RunEvent_EnterGrbkTwDoor'),
  Label.known('RunEvent_KuranEnterSpaceship'),
  Label.known('RunEvent_AirCstlEnterSpaceship'),
  Label.known('RunEvent_SilenceTmEnterSpaceship'),
  Label.known('RunEvent_ChazHouseRest'),
  Label.known('RunEvent_ClrChazHouseRest'),
  Label.known('RunEvent_SpaceshipSabotage'),
  Label.known('RunEvent_CrashLanding'),
  Label.known('RunEvent_FindingPsycoWand'),
  Label.known('RunEvent_FindingLandale'),
  Label.known('RunEvent_EnterKuran'),
  Label.known('RunEvent_NearDarkForce'),
  Label.known('RunEvent_FindDarkForce'),
  Label.known('RunEvent_JuzaDefeated'),
  Label.known('RunEvent_RuneFlaeli'),
  Label.known('RunEvent_OutsideRajaTemple'),
  Label.known('RunEvent_DarkForce1Defeated'),
  Label.known('RunEvent_MeetingLeRoof'),
  Label.known('RunEvent_LeRoofAgain'),
  Label.known('RunEvent_CarnivorousTrees'),
  Label.known('RunEvent_EclipseTorchUsed'),
  Label.known('RunEvent_FindDarkForce2'),
  Label.known('RunEvent_DarkForce2Defeated'),
  Label.known('RunEvent_LutzRevelation'),
  Label.known('RunEvent_MeetingSeth'),
  Label.known('RunEvent_AeroPrism'),
  Label.known('RunEvent_DarkForce3Defeated'),
  Label.known('RunEvent_ReshelBattle'),
  Label.known('RunEvent_ClmCenterForcedBattle'),
  Label.known('RunEvent_ClmCenterAfterBattle'),
  Label.known('RunEvent_FightingDElmLars'),
  Label.known('RunEvent_DElmLarsDefeated'),
  Label.known('RunEvent_FindingAirCastle'),
  Label.known('RunEvent_EnterAirCastle'),
  Label.known('RunEvent_FindXeAThoul'),
  Label.known('RunEvent_AirCstlFakeChest'),
  Label.known('RunEvent_LashiecAppearing'),
  Label.known('RunEvent_LashiecDefeated'),
  Label.known('RunEvent_GumbiousBishop'),
  Label.known('RunEvent_StrengthTowerTop'),
  Label.known('RunEvent_CourageTowerTop'),
  Label.known('RunEvent_DeVarsDefeated'),
  Label.known('RunEvent_SaLewsDefeated'),
  Label.known('RunEvent_Null4D'),
  Label.known('RunEvent_ReFaze'),
  Label.known('RunEvent_BeforeElsydeonCave'),
  Label.known('RunEvent_Reunion'),
  Label.known('RunEvent_AngerTowerTop'),
  Label.known('RunEvent_AngerTowerExitTop'),
  Label.known('RunEvent_ProfoundDarkness'),
  Label.known('RunEvent_Ending'),
  Label.known('RunEvent_CancellerReminder'),
  Label.known('RunEvent_EnterAngerTower'),
  Label.known('RunEvent_SoldiersTempleCaveDialogue1'),
  Label.known('RunEvent_SoldiersTempleCaveDialogue2'),
  Label.known('RunEvent_SoldiersTempleReached'),
  Label.known('RunEvent_FindingAeroPrism'),
  Label.known('RunEvent_ReenterPiata'),
  Label.known('RunEvent_FortuneTeller'),
  Label.known('RunEvent_AfterFortuneTeller'),
  null, //	bra.w	RunEvent_MileSandWorm	; $5E -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $5F -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $60 -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $61 -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $62 -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $63 -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $64 -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $65 -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $66 -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $67 -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $68 -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $69 -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $6A -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $6B -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $6C -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $6D -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $6E -- Unused
  null, //	bra.w	RunEvent_MileSandWorm	; $6F -- Unused
  Label.known('RunEvent_MileSandWorm'),
  Label.known('RunEvent_InsideMonsenCave'),
  Label.known('RunEvent_SavingTallas'),
  Label.known('RunEvent_KingRappyDefeated'),
  Label.known('RunEvent_ZemaServantBattle'),
  Label.known('RunEvent_EnterVahalFort'),
  Label.known('RunEvent_VahalFortMidway'),
  Label.known('RunEvent_DominatorsDefeated'),
  Label.known('RunEvent_EnterWeaponPlant'),
  Label.known('RunEvent_StrippersDance'),
  Label.known('RunEvent_ClrStrippersDance'),
  Label.known('RunEvent_PenguFeedStolen'),
  Label.known('RunEvent_PiataChazAlone'),
  Label.known('RunEvent_NoEvent'),
  Label.known('RunEvent_NoEvent'),
  Label.known('RunEvent_NoEvent'),
];

/// Grand Cross (revision 1) baseline with reusable, unreferenced padding slots.
JumpTable<Word> mapDataManagersJmpTbl() => JumpTable<Word>.sparse(
    jump: withNoop(Label.known('GetMapLayoutOffset'), bra.w),
    newIndex: Word.new,
    capacity: 0x2000, // Four-byte offsets must fit a signed word.
    labels: _mapDataManagersTable);

const _mapDataManagersTable = [
  Label.known('MapDataMan_Null'), // $00
  Label.known('MapDataMan_PiataAcademy_F1'), // $01
  Label.known('MapDataMan_PiataNearBasement'), // $02
  Label.known('MapDataMan_PiataBasement'), // $03
  Label.known('MapDataMan_PiataBasementB2_Igglanova'), // $04
  Label.known('MapDataMan_ChkZemaNormal'), // $05
  Label.known('MapDataMan_MolcumCitizens'), // $06
  Label.known('MapDataMan_MolcumRune'), // $07
  Label.known('MapDataMan_UseAlternateColors'), // $08
  Label.known('MapDataMan_ScrollValues'), // $09
  Label.known('MapDataMan_ZioFortTunnels'), // $0A
  Label.known('MapDataMan_BioPlantDoor'), // $0B
  Label.known('MapDataMan_PiataDorm'), // $0C
  Label.known('MapDataMan_ZemaHouse2'), // $0D
  Label.known('MapDataMan_ZemaHouse2_B1'), // $0E
  Label.known('MapDataMan_BrthVllyPetrified'), // $0F
  Label.known('MapDataMan_BrthVllyBackToNormal'), // $10
  Label.known('MapDataMan_BrthVllyAfterExplosion'), // $11
  Label.known('MapDataMan_ZemaHouse2_WomanArt'), // $12
  Label.known('MapDataMan_BioPlantPal'), // $13
  Label.known('MapDataMan_MovingPlatforms'), // $14
  Label.known('MapDataMan_VahFortMovPlatforms'), // $15
  Label.known('MapDataMan_WpnPlntMovPlatforms'), // $16
  Label.known('MapDataMan_Terminals'), // $17
  Label.known('MapDataMan_NearPiataBasement'), // $18
  Label.known('MapDataMan_PiataBasementB2_CharPositions'), // $19
  Label.known('MapDataMan_ZemaPetrifiedFlag'), // $1A
  Label.known('loc_52380'), // $1B
  Label.known('loc_52384'), // $1C
  Label.known('MapDataMan_PrincipalOffice'), // $1D
  Label.known('MapDataMan_PrincipalOffice_Hahn'), // $1E
  Label.known('MapDataMan_KrupKindergarten'), // $1F
  Label.known('MapDataMan_KrupInn_F1'), // $20
  Label.known('MapDataMan_TonoeDorin'), // $21
  Label.known('MapDataMan_TonoeGryz'), // $22
  Label.known('MapDataMan_KadaryChurchPeople'), // $23
  Label.known('MapDataMan_KadaryPubAndInn_F1'), // $24
  Label.known('MapDataMan_KadaryPub'), // $25
  Label.known('MapDataMan_Dezolis'), // $26
  Label.known('MapDataMan_WreckagePalettes'), // $27
  Label.known('MapDataMan_WreckageF1Palettes'), // $28
  Label.known('MapDataMan_WreckageEnginePal'), // $29
  Label.known('MapDataMan_MachCenterPal'), // $2A
  Label.known('MapDataMan_MachCenterB1Pal'), // $2B
  Label.known('MapDataMan_WpnPlntPal'), // $2C
  Label.known('MapDataMan_VahFortPal'), // $2D
  Label.known('MapDataMan_VahFortF2Pal'), // $2E
  Label.known('loc_5277E'), // $2F
  Label.known('MapDataMan_NurvusTunnelsPal'), // $30
  Label.known('MapDataMan_AiedoSupermarket'), // $31
  Label.known('MapDataMan_AiedoPrison'), // $32
  Label.known('MapDataMan_ZelanKuranScrollValues'), // $33
  Label.known('MapDataMan_PiataBasementB2_Palettes'), // $34
  Label.known('MapDataMan_LadeaTowerRune'), // $35
  Label.known('MapDataMan_BioPlantRika'), // $36
  Label.known('MapDataMan_KuranPal'), // $37
  Label.known('MapDataMan_JuzaRoom'), // $38
  Label.known('MapDataMan_AlysGravestone'), // $39
  Label.known('MapDataMan_Kadary'), // $3A
  Label.known('MapDataMan_GaruberkTowerPart2'), // $3B
  Label.known('MapDataMan_GaruberkTowerPart6'), // $3C
  Label.known('MapDataMan_GaruberkTowerPart4'), // $3D
  Label.known('MapDataMan_GaruberkTowerPart5'), // $3E
  Label.known('MapDataMan_GaruberkTower'), // $3F
  Label.known('MapDataMan_PlateSystemPal'), // $40
  Label.known('MapDataMan_ZelanPal'), // $41
  Label.known('MapDataMan_ZioFortBarrier'), // $42
  Label.known('MapDataMan_ZelanWren'), // $43
  Label.known('MapDataMan_RajaTemple'), // $44
  Label.known('MapDataMan_LadeaTower_F5'), // $45
  Label.known('MapDataMan_ZioFort'), // $46
  Label.known('MapDataMan_LeRoofRoom'), // $47
  Label.known('MapDataMan_ValleyMazeOutside'), // $48
  Label.known('MapDataMan_KuranDarkForce'), // $49
  Label.known('MapDataMan_MystValePart2'), // $4A
  Label.known('MapDataMan_MeeseObj'), // $4B
  Label.known('MapDataMan_MeeseHouse1'), // $4C
  Label.known('MapDataMan_MeeseInn'), // $4D
  Label.known('MapDataMan_MeeseClinicKyra'), // $4E
  Label.known('MapDataMan_JutObjs'), // $4F
  Label.known('MapDataMan_JutHouses'), // $50
  Label.known('loc_52C64'), // $51
  Label.known('MapDataMan_JutHouse7'), // $52
  Label.known('MapDataMan_JutChurch'), // $53
  Label.known('MapDataMan_EspMansionNorth'), // $54
  Label.known('MapDataMan_InnerSanctuaryB1Chars'), // $55
  Label.known('MapDataMan_InnerSanctuary'), // $56
  Label.known('MapDataMan_InnerSanctuaryB1Priest'), // $57
  Label.known('MapDataMan_TheEdge'), // $58
  Label.known('MapDataMan_GaruberkTwPart6Tiles'), // $59
  Label.known('MapDataMan_JutObjID'), // $5A
  Label.known('MapDataMan_MonsenCavePal'), // $5B
  Label.known('MapDataMan_ClimCntrDElmLars'), // $5C
  Label.known('MapDataMan_MonsenCaveObjs'), // $5D
  Label.known('MapDataMan_PlateSysBarrier'), // $5E
  Label.known('loc_52E62'), // $5F
  Label.known('MapDataMan_MeeseClinicDialogueID'), // $60
  Label.known('MapDataMan_GrbrkTwDarkForce2'), // $61
  Label.known('MapDataMan_GumbiousF1'), // $62
  Label.known('MapDataMan_AirCastleXeAThoul'), // $63
  Label.known('MapDataMan_StrengthTwTop'), // $64
  Label.known('MapDataMan_CourageTwTop'), // $65
  Label.known('MapDataMan_ZemaRocks'), // $66
  Label.known('MapDataMan_MotaSpaceport'), // $67
  Label.known('MapDataMan_DezoSpaceport'), // $68
  Label.known('MapDataMan_AngerTwTop'), // $69
  Label.known('MapDataMan_ZioFort_F4'), // $6A
  Label.known('MapDataMan_TonoeStorageRoom'), // $6B
  Label.known('MapDataMan_DezoTownsPal'), // $6C
  Label.known('MapDataMan_ZemaWaterfallBase'), // $6D
  Label.known('MapDataMan_ItemShopDoor'), // $6E
  Label.known('MapDataMan_MileBuildings'), // $6F
  Label.known('MapDataMan_RanchOwner'), // $70
  Label.known('MapDataMan_MileSandWorm'), // $71
  Label.known('MapDataMan_KrupRocky'), // $72
  Label.known('MapDataMan_MonsenRocky'), // $73
  Label.known('MapDataMan_Termi'), // $74
  Label.known('MapDataMan_RockyHouse'), // $75
  Label.known('MapDataMan_KadaryInn'), // $76
  Label.known('MapDataMan_MonsenHouse4'), // $77
  Label.known('MapDataMan_MonsenSign'), // $78
  Label.known('MapDataMan_UzoHouse3'), // $79
  Label.known('loc_53356'), // $7A
  Label.known('MapDataMan_VahFortBarrier'), // $7B
  Label.known('MapDataMan_VahFortF3'), // $7C
  Label.known('MapDataMan_CulversHouse'), // $7D
  Label.known('MapDataMan_MeeseClinicRaja'), // $7E
  Label.known('MapDataMan_KadaryChurchStudent'), // $7F
  Label.known('MapDataMan_RappyCave'), // $80
  Label.known('MapDataMan_MileDead'), // $81
  Label.known('MapDataMan_ChazHouse'), // $82
  Label.known('MapDataMan_Aiedo'), // $83
  Label.known('MapDataMan_ClrBioPlantAlarm'), // $84
  Label.known('MapDataMan_RyuonFirstTime'), // $85
  Label.known('MapDataMan_NalyaHouse3'), // $86
  Label.known('MapDataMan_MeeseClinicF1Konrad'), // $87
  Label.known('MapDataMan_MeeseClinicKonrad'), // $88
  Label.known('MapDataMan_SoldiersTempleOutside'), // $89
  Label.known('MapDataMan_SoldiersTemple'), // $8A
  Label.known('MapDataMan_AcademyBasementEncounters'), // $8B
  null, // $8C — Unused; emits GetMapLayoutOffset until assigned.
  null, // $8D — Unused; emits GetMapLayoutOffset until assigned.
  null, // $8E — Unused; emits GetMapLayoutOffset until assigned.
  null, // $8F — Unused; emits GetMapLayoutOffset until assigned.
  null, // $90 — Unused; emits GetMapLayoutOffset until assigned.
  null, // $91 — Unused; emits GetMapLayoutOffset until assigned.
  null, // $92 — Unused; emits GetMapLayoutOffset until assigned.
  null, // $93 — Unused; emits GetMapLayoutOffset until assigned.
  null, // $94 — Unused; emits GetMapLayoutOffset until assigned.
  null, // $95 — Unused; emits GetMapLayoutOffset until assigned.
  null, // $96 — Unused; emits GetMapLayoutOffset until assigned.
  null, // $97 — Unused; emits GetMapLayoutOffset until assigned.
  null, // $98 — Unused; emits GetMapLayoutOffset until assigned.
  null, // $99 — Unused; emits GetMapLayoutOffset until assigned.
  null, // $9A — Unused; emits GetMapLayoutOffset until assigned.
  null, // $9B — Unused; emits GetMapLayoutOffset until assigned.
  null, // $9C — Unused; emits GetMapLayoutOffset until assigned.
  null, // $9D — Unused; emits GetMapLayoutOffset until assigned.
  null, // $9E — Unused; emits GetMapLayoutOffset until assigned.
  null, // $9F — Unused; emits GetMapLayoutOffset until assigned.
];
