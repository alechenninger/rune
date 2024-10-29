import 'package:quiver/iterables.dart';

import 'model.dart';

class PlaySound extends Event implements RunnableInDialog {
  final SoundEffect sound;

  PlaySound(this.sound);

  @override
  bool canRunInDialog([EventState? state]) => true;

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

class PlayMusic extends Event implements RunnableInDialog {
  final Music music;

  PlayMusic(this.music);

  @override
  bool canRunInDialog([EventState? state]) => true;

  @override
  void visit(EventVisitor visitor) {
    visitor.playMusic(this);
  }

  @override
  String toString() {
    return 'PlayMusic{music: $music}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayMusic &&
          runtimeType == other.runtimeType &&
          music == other.music;

  @override
  int get hashCode => music.hashCode;
}

class StopMusic extends Event implements RunnableInDialog {
  @override
  bool canRunInDialog([EventState? state]) => true;

  @override
  void visit(EventVisitor visitor) {
    visitor.stopMusic(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StopMusic && runtimeType == other.runtimeType;

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    return 'StopMusic{}';
  }
}

sealed class Sound implements Enum {
  // todo: another analyzer bug; this is a compile error without cast
  static final List<Sound> values =
      concat([SoundEffect.values, Music.values]).cast<Sound>().toList();
}

// generated using
// cat sound_ids | gsed -E 's/[^_]*_(\S+).*/\1,/' | gsed -E 's/\w/\L&/'
enum SoundEffect implements Sound {
  rod,
  shot,
  slasher,
  attackMiss,
  enemyKilled,
  enemyAttack1,
  techCast,
  buffCast,
  healTechCast,
  foi,
  legeon,
  megid,
  phonon,
  fireBreath,
  efess,
  moonshad,
  laserAttack,
  zan,
  gra,
  vol,
  saner,
  rimit,
  brose,
  res,
  recovery,
  tandle,
  androidSkillImplant,
  rifle,
  sleepGas,
  eliminat,
  spark,
  warCry,
  moleAttack,
  mechEnemyAlarm,
  enemyAttack3,
  enemyAttack4,
  fusion,
  enemyAttack5,
  alarm,
  deban,
  graveOpening,
  teleport,
  stairs,
  ridingElevator,
  chestOpened,
  doorOpened,
  spaceshipPropelled,
  powerDown,
  elevatorOpen,
  barrierBroken,
  conveyorBelt,
  claw,
  unused1,
  blackWave,
  enemySpellCast,
  lightning,
  anotherGate,
  iceBroken,
  fallingIntoHole,
  telepipe,
  souvenir,
  movingCursor,
  selection,
  surprise,
  sword,
  nothing,
  unused2,

  spaceshipRadar,
  landRover,
  hydrofoil,

  stopMusic,
  stopSFX,
  stopSpcSFX,
  stopAll,
}

// generated using
// cat musicids | gsed -E 's/MusicID_(\S+).*/\1,/' | gsed -E 's/\w/\L&/'
enum Music implements Sound {
  tonoeDePon,
  inn,
  motaviaVillage,
  motaviaTown,
  organicBeat,
  dezorisTown1,
  nowOnSale,
  behindTheCircuit,
  machineCenter,
  inTheCave,
  winners,
  fieldMotabia,
  landMaster,
  requiemForLutz,
  meetThemHeadOn,
  ryucrossField,
  dungeonArrange1,
  fal,
  templeNgangbius,
  thray,
  defeatAtABlow,
  cyberneticCarnival,
  terribleSight,
  edgeOfDarkness,
  dezorisField1,
  tower,
  takeOffLandeel,
  dezorisTown2,
  dezorisField2,
  aHappySettlement,
  suspicion,
  theKingOfTerrors,
  theAgeOfFables,
  abyss,
  enemyAppearance,
  herLastBreath,
  pain,
  jijyNoRag,
  dungeonArrange2Cont,
  theBlackBlood,
  redAlert,
  laughter,
  mystery,
  endOfTheMillennium,
  explosion,
  staffRoll,
  thePromisingFuture1,
  paoPao,
  dungeonArrange2,
  thePromisingFuture2,
  dezorisDeDon,
  ooze,
}
