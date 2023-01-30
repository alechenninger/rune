import 'model.dart';

class PlaySound extends Event {
  final Sound sound;

  PlaySound(this.sound);

  @override
  void visit(EventVisitor visitor) {
    visitor.playSound(this);
  }

  @override
  String toString() {
    return 'PlaySound{sound: $sound}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaySound &&
          runtimeType == other.runtimeType &&
          sound == other.sound;

  @override
  int get hashCode => sound.hashCode;
}

enum Sound { selection, surprise }

enum Music { mystery }

/*
SFXID_Rod = id(PtrSFX_Rod)	; $B5
SFXID_Shot = id(PtrSFX_Shot)	; $B6
SFXID_Slasher = id(PtrSFX_Slasher)	; $B7
SFXID_AttackMiss = id(PtrSFX_AttackMiss)	; $B8
SFXID_EnemyKilled = id(PtrSFX_EnemyKilled)	; $B9
SFXID_EnemyAttack1 = id(PtrSFX_EnemyAttack1)	; $BA
SFXID_TechCast = id(PtrSFX_TechCast)	; $BB
SFXID_BuffCast = id(PtrSFX_BuffCast)	; $BC
SFXID_HealTechCast = id(PtrSFX_HealTechCast)	; $BD
SFXID_Foi = id(PtrSFX_Foi)	; $BE
SFXID_Legeon = id(PtrSFX_Legeon)	; $BF
SFXID_Megid = id(PtrSFX_Megid)	; $C0
SFXID_Phonon = id(PtrSFX_Phonon)	; $C1
SFXID_FireBreath = id(PtrSFX_FireBreath)	; $C2
SFXID_Efess = id(PtrSFX_Efess)	; $C3
SFXID_Moonshad = id(PtrSFX_Moonshad)	; $C4
SFXID_LaserAttack = id(PtrSFX_LaserAttack)	; $C5
SFXID_Zan = id(PtrSFX_Zan)	; $C6
SFXID_Gra = id(PtrSFX_Gra)	; $C7
SFXID_Vol = id(PtrSFX_Vol)	; $C8
SFXID_Saner = id(PtrSFX_Saner)	; $C9
SFXID_Rimit = id(PtrSFX_Rimit)	; $CA
SFXID_Brose = id(PtrSFX_Brose)	; $CB
SFXID_Res = id(PtrSFX_Res)	; $CC
SFXID_Recovery = id(PtrSFX_Recovery)	; $CD
SFXID_Tandle = id(PtrSFX_Tandle)	; $CE
SFXID_AndroidSkillImplant = id(PtrSFX_AndroidSkillImplant)	; $CF
SFXID_Rifle = id(PtrSFX_Rifle)	; $D0
SFXID_SleepGas = id(PtrSFX_SleepGas)	; $D1
SFXID_Eliminat = id(PtrSFX_Eliminat)	; $D2
SFXID_Spark = id(PtrSFX_Spark)	; $D3
SFXID_WarCry = id(PtrSFX_WarCry)	; $D4
SFXID_MoleAttack = id(PtrSFX_MoleAttack)	; $D5
SFXID_MechEnemyAlarm = id(PtrSFX_MechEnemyAlarm)	; $D6
SFXID_EnemyAttack3 = id(PtrSFX_EnemyAttack3)	; $D7
SFXID_EnemyAttack4 = id(PtrSFX_EnemyAttack4)	; $D8
SFXID_Fusion = id(PtrSFX_Fusion)	; $D9
SFXID_EnemyAttack5 = id(PtrSFX_EnemyAttack5)	; $DA
SFXID_Alarm = id(PtrSFX_Alarm)	; $DB
SFXID_Deban = id(PtrSFX_Deban)	; $DC
SFXID_GraveOpening = id(PtrSFX_GraveOpening)	; $DD
SFXID_Teleport = id(PtrSFX_Teleport)	; $DE
SFXID_Stairs = id(PtrSFX_Stairs)	; $DF
SFXID_RidingElevator = id(PtrSFX_RidingElevator)	; $E0
SFXID_ChestOpened = id(PtrSFX_ChestOpened)	; $E1
SFXID_DoorOpened = id(PtrSFX_DoorOpened)	; $E2
SFXID_SpaceshipPropelled = id(PtrSFX_SpaceshipPropelled)	; $E3
SFXID_PowerDown = id(PtrSFX_PowerDown)	; $E4
SFXID_ElevatorOpen = id(PtrSFX_ElevatorOpen)	; $E5
SFXID_BarrierBroken = id(PtrSFX_BarrierBroken)	; $E6
SFXID_ConveyorBelt = id(PtrSFX_ConveyorBelt)	; $E7
SFXID_Claw = id(PtrSFX_Claw)	; $E8
SFXID_Unused1 = id(PtrSFX_Unused1)	; $E9
SFXID_BlackWave = id(PtrSFX_BlackWave)	; $EA
SFXID_EnemySpellCast = id(PtrSFX_EnemySpellCast)	; $EB
SFXID_Lightning = id(PtrSFX_Lightning)	; $EC
SFXID_AnotherGate = id(PtrSFX_AnotherGate)	; $ED
SFXID_IceBroken = id(PtrSFX_IceBroken)	; $EE
SFXID_FallingIntoHole = id(PtrSFX_FallingIntoHole)	; $EF
SFXID_Telepipe = id(PtrSFX_Telepipe)	; $F0
SFXID_Souvenir = id(PtrSFX_Souvenir)	; $F1
SFXID_MovingCursor = id(PtrSFX_MovingCursor)	; $F2
SFXID_Selection = id(PtrSFX_Selection)	; $F3
SFXID_Surprise = id(PtrSFX_Surprise)	; $F4
SFXID_Sword = id(PtrSFX_Sword)	; $F5
SFXID_Nothing = id(PtrSFX_Nothing)	; $F6
SFXID_Unused2 = id(PtrSFX_Unused2)	; $F7
 */
