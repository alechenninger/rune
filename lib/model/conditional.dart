import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'model.dart';

class EventFlag {
  final String name;

  EventFlag(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventFlag &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return 'EventFlag{$name}';
  }
}

var beginning = Condition({for (var flag in storyEvents) flag: false});

bool isStoryEvent(EventFlag flag) => storyEvents.contains(flag);

// TODO: order these properly
// not sure if these are well known / hard code-able
// or should be property of the script / model.
// we can change later if need be.
/// Story event flags, in order of occurrence.
///
/// Story event flags are those which:
/// - Are set as the story progresses
/// - Are only ever set in this order
/// - Can only be set when all preceeding story event flags have been set.
final storyEvents = [
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
  EventFlag('HoltPetrified'),
  EventFlag('RuneJoined'),
  //EventFlag('Saya'), // May occur in different order
  EventFlag('TonoePathOpen'),
  //EventFlag('TheRanchOwner'),
  //EventFlag('MileRanchOwner'),
  //EventFlag('MileSandWorm'),
  //EventFlag('RanchOwnerAfterBattle'),
  //EventFlag('RanchOwnerFee'),
  //EventFlag('TinkerbellsDog'),
  //EventFlag('RockyOwner'),
  //EventFlag('RockyFound'),
  //EventFlag('RockyTermiEscape'),
  //EventFlag('RockyKrupEscape'),
  //EventFlag('RockyMonsenEscape'),
  //EventFlag('RockyHome'),
  //EventFlag('RockyFee'),
  //EventFlag('MissingStudent'),
  //EventFlag('DormOwner'),
  //EventFlag('StudentSick'),
  //EventFlag('Perolymate'),
  //EventFlag('StudentRecovered'),
  //EventFlag('StudentFee'),
  //EventFlag('FissureOfFear'),
  //EventFlag('TallasMother'),
  //EventFlag('InsideCave'),
  //EventFlag('FractOoze'),
  EventFlag('Dorin'),
  EventFlag('GryzJoined'),
  EventFlag('TonoeDoorOpen'),
  EventFlag('AlshlineFound'),
  // This one is weird. Linked to IgglanovaZema.
  // Effectively it is *set* until IgglanovaZema is set.
  // We could just key off of IgglanovaZema instead?
  // See MapDataMan_ZemaPetrifiedFlag
  EventFlag('ZemaPetrified'),
  EventFlag('IgglanovaZema'),
  EventFlag('AfterIgglanovaZema'),
  EventFlag('BioPlantEscape'),
  EventFlag('RikaJoined'),
  //EventFlag('AfterCrevice'),
  //EventFlag('FissureOfFearFee'),
  //EventFlag('TallasSaved'),
  //EventFlag('WreckageSystem'), - optional dungeon
  EventFlag('Juza'),
  EventFlag('JuzaDefeated'),
  EventFlag('DemiJoined'),
  EventFlag('Zio'),
  EventFlag('MachineCenter'),
  EventFlag('LandRover'),
  //EventFlag('FortuneTeller'),
  //EventFlag('GirlsCaught'),
  //EventFlag('Hijammer'),
  //EventFlag('PlateSystem'), - optional
  //EventFlag('PlateEngine'), - optional
  EventFlag('RuneJoinedAgain'),
  EventFlag('GyLaguiah'),
  EventFlag('AfterAlysDeath'),
  EventFlag('AfterAlysDeath2'),
  EventFlag('ZioFortBarrier'),
  EventFlag('ZioNurvus'),
  EventFlag('MotaSpaceport'),
  EventFlag('GryzGone'),
  EventFlag('WrenJoined'),
  EventFlag('ChaosSorcr'),
  //EventFlag('Canceller'),
  //EventFlag('CancellerReminder'),
  //EventFlag('Burstroc'),
  //EventFlag('StainInLife'),
  //EventFlag('MissingGirlsMom'),
  //EventFlag('GirlPrison'),
  //EventFlag('PrisonGuard'),
  //EventFlag('BailPaid'),
  //EventFlag('GirlsBailedOut'),
  //EventFlag('StainInLifeFee'),
  //EventFlag('Bail'),
  EventFlag('RajaTemple'),
  EventFlag('RajaJoined'),
  EventFlag('Snowstorm'),
  //EventFlag('LandaleWhereabouts'), // optional Gyuna
  EventFlag('TylerGrave'),
  EventFlag('DezoSpaceport'),
  EventFlag('Kuran'),
  EventFlag('NearDarkForce1'),
  EventFlag('DarkForce1'),
  EventFlag('IceDigger'),
  //EventFlag('Penguin'),
  //EventFlag('Reshel'),
  //EventFlag('PenguinNoMoney'),
  //EventFlag('MuskCats'),
  //EventFlag('SilverTusk'),
  EventFlag('RajaSick'),
  EventFlag('CarnivorousTrees'),
  EventFlag('KyraJoined'),
  EventFlag('InnerSanctuary'),
  //EventFlag('InnerSanctGuard1'),
  EventFlag('LutzRevelation'),
  EventFlag('EclipseTorchStolen'),
  EventFlag('AirCastleFound'),
  EventFlag('AirCastle'),
  EventFlag('XeAThoul'),
  EventFlag('Lashiec'),
  EventFlag('EclipseTorch'),
  EventFlag('DarkForce2'),
  EventFlag('SnowstormGone'),
  EventFlag('Hydrofoil'),
  //EventFlag('DezoGyLaguiah'), - optional
  //EventFlag('ClimateCenter'), - optional
  //EventFlag('DElmLars'), - optional
  //EventFlag('DElmLarsDefeated'), - optional

  //EventFlag('Spector'),
  //EventFlag('DyingBoy'),
  //EventFlag('Culvers'),
  //EventFlag('AlisSword'),
  //EventFlag('CulversAfterRecovery'),
  //EventFlag('DyingBoyFee'),
  //EventFlag('ManWithTwist'),
  //EventFlag('Sekreas'),
  //EventFlag('KingRappy'),
  //EventFlag('ManWithTwistFee'),
  //EventFlag('SilverSoldier'),
  //EventFlag('Servants'),
  //EventFlag('ZemaOldMan'),
  //EventFlag('VahalFort'),
  //EventFlag('VahalFortMidway'),
  //EventFlag('Dominators'),
  //EventFlag('OldManZemaAfterDaughter'),
  //EventFlag('SilverSoldierFee'),
  //EventFlag('VahFortBarrier'),
  //EventFlag('SekreasReason'),
  //EventFlag('DaughterShutDown'),
  EventFlag('Hydrofoil2'),
  EventFlag('SethJoined'),
  EventFlag('SethConversation1'),
  EventFlag('SethConversation2'),
  EventFlag('SoldiersTemple'),
  EventFlag('DarkForce3'),
  EventFlag('DarkForce3Defeated'),
  //EventFlag('WeaponPlant'),
  EventFlag('AeroPrism1'),
  EventFlag('AeroPrism2'),
  EventFlag('Rykros'),
  EventFlag('LeRoof'),
  EventFlag('StrengthTowerTop'),
  EventFlag('DeVars'),
  EventFlag('DeVarsDefeated'),
  EventFlag('StrengthTowerChests'),
  EventFlag('CourageTowerTop'),
  EventFlag('SaLews'),
  EventFlag('SaLewsDefeated'),
  EventFlag('CourageTowerChests'),
  EventFlag('LeRoofStory1'),
  EventFlag('LeRoofStory2'),
  //EventFlag('InnerSanctGuard2'),
  EventFlag('ElsydeonCave'),
  EventFlag('Elsydeon'),
  EventFlag('Reunion'),
  //EventFlag('HahnPicked'),
  //EventFlag('GryzPicked'),
  //EventFlag('DemiPicked'),
  //EventFlag('RajaPicked'),
  //EventFlag('KyraPicked'),
  //EventFlag('AngerTower'),
  //EventFlag('ReFaze'),
  //EventFlag('AlysFight'),
  //EventFlag('AngerTowerEnd'),
  EventFlag('ProfoundDarkness'),
  //EventFlag('GuildPlaceholder'),
];

class Condition {
  final IMap<EventFlag, bool> _flags;

  Condition(Map<EventFlag, bool> flags) : _flags = flags.lock;
  const Condition.empty() : _flags = const IMapConst({});

  Iterable<EventFlag> get flagsSet => _flags.where((_, isSet) => isSet).keys;

  Condition withFlag(EventFlag flag, bool isSet) {
    if (this[flag] == isSet) return this;
    return Condition(_flags.unlock
      ..[flag] = isSet
      ..lock);
  }

  Condition withSet(EventFlag flag) => withFlag(flag, true);
  Condition withNotSet(EventFlag flag) => withFlag(flag, false);
  Condition without(EventFlag flag) => Condition(_flags.unlock
    ..remove(flag)
    ..lock);

  Iterable<MapEntry<EventFlag, bool>> get entries => _flags.entries;

  bool? operator [](EventFlag flag) => _flags[flag];
  bool isKnownSet(EventFlag flag) => this[flag] == true;
  bool isKnownUnset(EventFlag flag) => this[flag] == false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Condition &&
          runtimeType == other.runtimeType &&
          _flags == other._flags;

  @override
  int get hashCode => _flags.hashCode;

  @override
  String toString() {
    return 'Condition{$_flags}';
  }
}

class IfFlag extends Event {
  final EventFlag flag;
  final List<Event> isSet;
  final List<Event> isUnset;

  IfFlag(this.flag,
      {Iterable<Event> isSet = const [], Iterable<Event> isUnset = const []})
      : isSet = Scene(isSet).events,
        isUnset = Scene(isUnset).events;

  @override
  void visit(EventVisitor visitor) {
    visitor.ifFlag(this);
  }

  @override
  String toString() {
    return 'IfFlag{flag: $flag, isSet: $isSet, isUnset: $isUnset}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IfFlag &&
          runtimeType == other.runtimeType &&
          flag == other.flag &&
          const ListEquality<Event>().equals(isSet, other.isSet) &&
          const ListEquality<Event>().equals(isUnset, other.isUnset);

  @override
  int get hashCode =>
      flag.hashCode ^
      const ListEquality<Event>().hash(isSet) ^
      const ListEquality<Event>().hash(isUnset);

  IfFlag withoutSetContextInBranches() {
    return IfFlag(flag,
        isSet: isSet
            .whereNot((e) => e is SetContext)
            .map((e) => e is IfFlag ? e.withoutSetContextInBranches() : e)
            .toList(),
        isUnset: isUnset
            .whereNot((e) => e is SetContext)
            .map((e) => e is IfFlag ? e.withoutSetContextInBranches() : e)
            .toList());
  }
}

class SetFlag extends Event {
  final EventFlag flag;

  SetFlag(this.flag);

  @override
  void visit(EventVisitor visitor) {
    visitor.setFlag(this);
  }

  @override
  String toString() {
    return 'SetFlag{$flag}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetFlag &&
          runtimeType == other.runtimeType &&
          flag == other.flag;

  @override
  int get hashCode => flag.hashCode;
}
