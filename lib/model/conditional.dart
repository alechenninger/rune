import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../src/iterables.dart';
import 'model.dart';

class EventFlag {
  final String name;

  const EventFlag(this.name);

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
const storyEvents = [
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
  EventFlag('Zio'),
  EventFlag('DemiJoined'),
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
  //EventFlag('LandaleWhereabouts'), // optional Gyuna ... or not?
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
  EventFlag('Spector'),
  EventFlag('Lashiec'),
  EventFlag('EclipseTorch'),
  EventFlag('DarkForce2'),
  EventFlag('SnowstormGone'),
  EventFlag('Hydrofoil'),
  //EventFlag('DezoGyLaguiah'), - optional
  //EventFlag('ClimateCenter'), - optional
  //EventFlag('DElmLars'), - optional
  //EventFlag('DElmLarsDefeated'), - optional

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
  //EventFlag('WeaponPlant'),
  EventFlag('AeroPrism1'),
  EventFlag('AeroPrism2'),
  EventFlag('DarkForce3'),
  EventFlag('DarkForce3Defeated'),
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

final subplots = {
  ranchOwnerEvents,
  tinkerbellsDogEvents,
  missingStudentEvents,
  fissureOfFearEvents,
  stainInLifeEvents,
  dyingBoyEvents,
  manWithTwistEvents,
  silverSoliderEvents,
  // Treat these as subplots since they are optional
  [EventFlag('HahnPicked')],
  [EventFlag('GryzPicked')],
  [EventFlag('DemiPicked')],
  [EventFlag('RajaPicked')],
  [EventFlag('KyraPicked')],
};

// TODO: these flags might not be ordered correctly

final ranchOwnerEvents = [
  EventFlag('TheRanchOwner'),
  EventFlag('MileRanchOwner'),
  EventFlag('MileSandWorm'),
  EventFlag('RanchOwnerAfterBattle'),
  EventFlag('RanchOwnerFee'),
];

final tinkerbellsDogEvents = [
  EventFlag('TinkerbellsDog'),
  EventFlag('RockyOwner'),
  EventFlag('RockyFound'),
  EventFlag('RockyTermiEscape'),
  EventFlag('RockyKrupEscape'),
  EventFlag('RockyMonsenEscape'),
  EventFlag('RockyHome'),
  EventFlag('RockyFee'),
];

final missingStudentEvents = [
  EventFlag('MissingStudent'),
  EventFlag('DormOwner'),
  EventFlag('StudentSick'),
  EventFlag('Perolymate'),
  EventFlag('StudentRecovered'),
  EventFlag('StudentFee'),
];

final fissureOfFearEvents = [
  EventFlag('FissureOfFear'),
  EventFlag('TallasMother'),
  EventFlag('InsideCave'),
  EventFlag('FractOoze'),
  EventFlag('TallasSaved'),
  EventFlag('AfterCrevice'),
  EventFlag('FissureOfFearFee'),
];

final stainInLifeEvents = [
  EventFlag('StainInLife'),
  EventFlag('MissingGirlsMom'),
  EventFlag('GirlPrison'),
  EventFlag('PrisonGuard'),
  EventFlag('Bail'),
  EventFlag('BailPaid'),
  EventFlag('GirlsBailedOut'),
  EventFlag('StainInLifeFee'),
];

final dyingBoyEvents = [
  EventFlag('DyingBoy'),
  EventFlag('Culvers'),
  EventFlag('AlisSword'),
  EventFlag('CulversAfterRecovery'),
  EventFlag('DyingBoyFee'),
];

final manWithTwistEvents = [
  EventFlag('ManWithTwist'),
  EventFlag('Sekreas'),
  EventFlag('KingRappy'),
  EventFlag('SekreasReason'),
  EventFlag('ManWithTwistFee'),
];

final silverSoliderEvents = [
  EventFlag('SilverSoldier'),
  EventFlag('Servants'),
  EventFlag('ZemaOldMan'),
  EventFlag('VahFortBarrier'),
  EventFlag('VahalFort'),
  EventFlag('VahalFortMidway'),
  EventFlag('Dominators'),
  EventFlag('DaughterShutDown'),
  EventFlag('OldManZemaAfterDaughter'),
  EventFlag('SilverSoldierFee'),
];

typedef Values = (ModelExpression, ModelExpression);

class Condition {
  final IMap<EventFlag, bool> _flags;
  final IMap<Values, BranchCondition> _values;

  Condition(Map<EventFlag, bool> flags, {Map<Values, BranchCondition>? values})
      : _flags = flags.lock,
        _values = (values ?? {}).lock;

  const Condition.empty()
      : _flags = const IMapConst({}),
        _values = const IMapConst({});

  Iterable<EventFlag> get flagsSet => _flags.where((_, isSet) => isSet).keys;

  EventFlagCondition get flags => EventFlagCondition(this);
  ValueCondition get values => ValueCondition(this);

  Condition withFlag(EventFlag flag, bool isSet) {
    if (this[flag] == isSet) return this;
    return Condition(_flags.unlock
      ..[flag] = isSet
      ..lock);
  }

  Condition withFlags(Map<EventFlag, bool> flags) => Condition(_flags.unlock
    ..addAll(flags)
    ..lock);

  Condition withSet(EventFlag flag) => withFlag(flag, true);

  Condition withNotSet(EventFlag flag) => withFlag(flag, false);

  Condition without(EventFlag flag) => Condition(_flags.unlock
    ..remove(flag)
    ..lock);

  Iterable<MapEntry<EventFlag, bool>> get entries => _flags.entries;

  bool? operator [](EventFlag flag) => _flags[flag];

  bool isKnownSet(EventFlag flag) => this[flag] == true;

  bool isKnownUnset(EventFlag flag) => this[flag] == false;

  BranchCondition? branchFor(Values operand) {
    return _values[operand];
  }

  Condition withBranch(Values operand, BranchCondition branch) {
    if (branchFor(operand) == branch) return this;
    return Condition({},
        values: _values.unlock
          ..[operand] = branch
          ..lock);
  }

  /// This condition is satisfied by another condition
  /// if the [other] condition has the same value
  /// as every flag in this condition,
  /// and has the same branch condition
  /// as every value in this condition.
  ///
  /// The other condition may contain additional flags or values.
  ///
  /// An empty condition only satisfies another empty condition
  /// (but an empty condition *is satisfied by* every condition).
  bool isSatisfiedBy(Condition other) {
    for (var MapEntry(key: flag, value: state) in _flags.entries) {
      if (other[flag] != state) return false;
    }
    for (var MapEntry(key: values, value: branch) in _values.entries) {
      // TODO: is equal comparison appropriate?
      // does eq or lt satisfy lte?
      if (other.branchFor(values) != branch) return false;
    }
    return true;
  }

  /// This condition conflicts with another condition
  /// if this condition contains a flag with a different value
  /// than any flag in the [other] condition,
  /// or contains a value with a different branch condition
  /// than any pair of values in the [other] condition.
  ///
  /// The other condition may contain additional flags or values
  /// and not necessarily conflit.
  ///
  /// An empty condition never conflicts with another condition.
  bool conflictsWith(Condition other) {
    for (var MapEntry(key: flag, value: state) in other._flags.entries) {
      var current = this[flag];
      if (current != null && current != state) return true;
    }
    for (var MapEntry(key: values, value: branch) in other._values.entries) {
      var current = branchFor(values);
      if (current != null && current != branch) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Condition &&
          runtimeType == other.runtimeType &&
          _flags == other._flags &&
          _values == other._values;

  @override
  int get hashCode => _flags.hashCode;

  @override
  String toString() {
    return 'Condition{$_flags, $_values}';
  }
}

sealed class SingleTypeCondition<T, U> {
  U? branchFor(T operand);
  SingleTypeCondition<T, U> withBranch(T operand, U branch);
}

class ValueCondition extends SingleTypeCondition<Values, BranchCondition> {
  final Condition condition;

  ValueCondition(this.condition);

  EventFlagCondition get flags => EventFlagCondition(condition);

  @override
  BranchCondition? branchFor(Values operand) {
    return condition._values[operand];
  }

  @override
  ValueCondition withBranch(Values operand, BranchCondition branch) {
    if (branchFor(operand) == branch) return this;
    return ValueCondition(Condition({},
        values: condition._values.unlock
          ..[operand] = branch
          ..lock));
  }
}

class EventFlagCondition extends SingleTypeCondition<EventFlag, bool> {
  final Condition condition;

  EventFlagCondition(this.condition);

  ValueCondition get values => ValueCondition(condition);

  @override
  bool? branchFor(EventFlag operand) => condition[operand];

  @override
  SingleTypeCondition<EventFlag, bool> withBranch(
          EventFlag operand, bool branch) =>
      EventFlagCondition(condition.withFlag(operand, branch));
}

class IfFlag extends Event {
  final EventFlag flag;
  final List<Event> isSet;
  final List<Event> isUnset;

  IfFlag(this.flag,
      {Iterable<Event> isSet = const [], Iterable<Event> isUnset = const []})
      : isSet = Scene(isSet).asOf(Condition({flag: true})).events,
        isUnset = Scene(isUnset).asOf(Condition({flag: false})).events;

  @override
  void visit(EventVisitor visitor) {
    visitor.ifFlag(this);
  }

  @override
  String toString() {
    return 'IfFlag{$flag, \n'
        'isSet:\n'
        '${toIndentedString(isSet, '         ')}\n'
        'isUnset:\n'
        '${toIndentedString(isUnset, '         ')}\n'
        '}';
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

class IfExpression extends Event {
  final BooleanExpression expression;
  final List<Event> isTrue;
  final List<Event> isFalse;

  IfExpression(this.expression,
      {this.isTrue = const [], this.isFalse = const []});

  @override
  void visit(EventVisitor visitor) {
    // TODO: implement visit
  }

  @override
  String toString() {
    return 'IfExpression{$expression, \n'
        'isTrue:\n'
        '${toIndentedString(isTrue, '         ')}\n'
        'isFalse:\n'
        '${toIndentedString(isFalse, '         ')}\n'
        '}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IfExpression &&
          runtimeType == other.runtimeType &&
          expression == other.expression &&
          const ListEquality<Event>().equals(isTrue, other.isTrue) &&
          const ListEquality<Event>().equals(isFalse, other.isFalse);

  @override
  int get hashCode =>
      expression.hashCode ^
      const ListEquality<Event>().hash(isTrue) ^
      const ListEquality<Event>().hash(isFalse);

  IfExpression withoutSetContextInBranches() {
    return IfExpression(expression,
        isTrue: isTrue
            .whereNot((e) => e is SetContext)
            .map((e) => e is IfFlag ? e.withoutSetContextInBranches() : e)
            .toList(),
        isFalse: isFalse
            .whereNot((e) => e is SetContext)
            .map((e) => e is IfFlag ? e.withoutSetContextInBranches() : e)
            .toList());
  }
}

final class IfValue<T extends ModelExpression> extends Event {
  final T op1, op2;

  final _branches = <Branch>[];
  BranchCondition? emptyBranch;

  /// [comparedTo] is subtracted from [op1] (`op1 - comparedTo`)
  IfValue(
    this.op1, {
    List<Event> equal = const [],
    List<Event> notEqual = const [],
    List<Event> greater = const [],
    List<Event> greaterOrEqual = const [],
    List<Event> less = const [],
    List<Event> lessOrEqual = const [],
    required T comparedTo,
  }) : op2 = comparedTo {
    var conditions = <BranchCondition>{};

    void addBranch(BranchCondition condition, List<Event> events) {
      if (events.isEmpty) return;
      for (var c in condition.parts) {
        if (!conditions.add(c)) {
          throw ModelException('condition already defined: $c');
        }
      }
      _branches.add(Branch(condition, events));
    }

    addBranch(eq, equal);
    addBranch(neq, notEqual);
    addBranch(gt, greater);
    addBranch(gte, greaterOrEqual);
    addBranch(lt, less);
    addBranch(lte, lessOrEqual);

    if (conditions.isEmpty) {
      throw ArgumentError('must provide at least one branch with events');
    }

    emptyBranch = BranchCondition.canonical
        .difference(conditions)
        .reduceOrNull((value, element) => value.or(element));
  }

  /// Branches which have any events.
  List<Branch> get branches => List.unmodifiable(_branches);

  @override
  void visit(EventVisitor visitor) {
    visitor.ifValue(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IfValue &&
          // runtimeType check intentionally omitted
          // to prevent generic type from being checked
          op1 == other.op1 &&
          op2 == other.op2 &&
          const ListEquality<Branch>().equals(_branches, other._branches);

  @override
  int get hashCode =>
      op1.hashCode ^
      op2.hashCode ^
      const ListEquality<Branch>().hash(_branches);

  @override
  String toString() {
    return 'IfValue{$op1, $op2, $_branches}';
  }
}

const gte = BranchCondition.gte;
const lte = BranchCondition.lte;
const neq = BranchCondition.neq;
const eq = BranchCondition.eq;
const gt = BranchCondition.gt;
const lt = BranchCondition.lt;

enum BranchCondition {
  gte,
  lte,
  neq,
  eq,
  gt,
  lt;

  static const canonical = {gt, eq, lt};

  BranchCondition or(BranchCondition other) {
    var parts = {...this.parts, ...other.parts};

    if (parts.containsAll(const [gt, eq])) return gte;
    if (parts.containsAll(const [lt, eq])) return lte;
    if (parts.containsAll(const [gt, lt])) return neq;

    throw ArgumentError('invalid combination: $this, $other');
  }

  /// Decomposes a condition into canonical set of positive "parts":
  /// one or more of [gt], [eq], or [lt] (see [canonical]).
  Set<BranchCondition> get parts => switch (this) {
        gte => {gt, eq},
        lte => {lt, eq},
        neq => {gt, lt},
        _ => {this}
      };

  BranchCondition get invert {
    return switch (this) {
      gte => lt,
      lte => gt,
      neq => eq,
      eq => neq,
      gt => lte,
      lt => gte
    };
  }
}

class Branch {
  final BranchCondition condition;
  final List<Event> events;

  Branch(this.condition, this.events);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Branch &&
          runtimeType == other.runtimeType &&
          condition == other.condition &&
          const ListEquality<Event>().equals(events, other.events);

  @override
  int get hashCode =>
      condition.hashCode ^ const ListEquality<Event>().hash(events);

  @override
  String toString() {
    return 'Branch{$condition, $events}';
  }
}
