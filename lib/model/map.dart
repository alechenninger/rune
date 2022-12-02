// ignore_for_file: constant_identifier_names

import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:quiver/check.dart';

import 'model.dart';

// generator will need to track a vram tile number offset to start storing art
// pointers
// note that many events refer to map objects address in memory, which means
// ordering must be maintained for existing objects unless we find and edit
// those addresses.
class GameMap {
  final MapId id;

  // limited to 64 objects in ram currently
  final _objects = <MapObjectId, MapObject>{};

  GameMap(this.id);

  List<MapObject> get objects => UnmodifiableListView(_objects.values);

  //final onMove = <Event>[];

  bool containsObject(MapObjectId id) => _objects.containsKey(id);

  MapObject? object(MapObjectId id) => _objects[id];

  void addObject(MapObject obj) {
    if (_objects.containsKey(obj.id)) {
      throw ArgumentError('map already contains object with id: ${obj.id}');
    }
    _objects[obj.id] = obj;
  }
}

enum MapId {
  Dezolis,
  Motavia,
  Rykros,
  Piata,
  PiataAcademy,
  PiataAcademyF1,
  //PiataAcademy_F1,
  PiataAcademyPrincipalOffice,
  //AcademyPrincipalOffice,
  PiataAcademyNearBasement,
  PiataAcademyBasement,
  //AcademyBasement,
  PiataAcademyBasementB1,
  //AcademyBasement_B1,
  PiataAcademyBasementB2,
  //AcademyBasement_B2,
  PiataDorm,
  PiataInn,
  PiataHouse1,
  PiataHouse2,
  PiataItemShop,
  Aiedo,
  ShayHouse,
  //ChazHouse,
  Tonoe,
  Test,
  Mile,
  MileDead,
  MileWeaponShop,
  MileHouse1,
  MileItemShop,
  MileHouse2,
  MileInn,
  Zema,
  ZemaHouse1,
  ZemaWeaponShop,
  ZemaInn,
  ZemaHouse2,
  ZemaHouse2_B1,
  ZemaItemShop,
  BirthValley,
  BirthValley_B1,
  ValleyMazeUnused,
  Krup,
  KrupKindergarten,
  KrupWeaponShop,
  KrupItemShop,
  KrupHouse,
  KrupInn,
  KrupInn_F1,
  Molcum,
  TonoeStorageRoom,
  TonoeGryzHouse,
  TonoeHouse1,
  TonoeHouse2,
  TonoeInn,
  TonoeBasement,
  TonoeBasement_B1,
  TonoeBasement_B2,
  TonoeBasement_B3,
  Nalya,
  NalyaHouse1,
  NalyaHouse2,
  NalyaItemShop,
  NalyaHouse3,
  NalyaHouse4,
  NalyaHouse5,
  NalyaInn,
  NalyaInn_F1,
  AiedoBakery,
  AiedoBakery_B1,
  HuntersGuild,
  HuntersGuildStorage,
  StripClubDressingRoom,
  StripClub,
  AiedoWeaponShop,
  AiedoPrison,
  AiedoHouse1,
  AiedoHouse2,
  AiedoHouse3,
  AiedoHouse4,
  AiedoHouse5,
  AiedoSupermarket,
  AiedoPub,
  RockyHouse,
  AiedoHouse6,
  AiedoHouse7,
  Kadary,
  KadaryChurch,
  KadaryPub,
  KadaryPub_F1,
  KadaryStorageRoom,
  KadaryHouse1,
  KadaryHouse2,
  KadaryHouse3,
  KadaryItemShop,
  KadaryInn,
  KadaryInn_F1,
  Monsen,
  MonsenInn,
  MonsenHouse1,
  MonsenHouse2,
  MonsenHouse3,
  MonsenHouse4,
  MonsenHouse5,
  MonsenItemShop,
  Termi,
  TermiItemShop,
  TermiHouse1,
  TermiWeaponShop,
  TermiInn,
  TermiHouse2,
  Passageway,
  ZioFort,
  ZioFort_Part2,
  ZioFort_F1,
  ZioFort_F2West,
  ZioFortWestTunnel,
  ZioFortJuzaRoom,
  ZioFortEastTunnel,
  ZioFort_F2East,
  ZioFort_F3,
  ZioFort_F4,
  LadeaTower,
  LadeaTower_F1,
  LadeaTower_F2,
  LadeaTower_F3,
  LadeaTower_F4,
  LadeaTower_F5,
  IslandCave,
  IslandCave_F1,
  IslandCave_F1_Part2,
  IslandCave_Part2,
  IslandCave_B1,
  IslandCave_F2,
  IslandCave_F3,
  SoldiersTempleOutside,
  SoldiersTemple,
  ValleyMaze,
  ValleyMaze_Part2,
  ValleyMaze_Part3,
  ValleyMaze_Part4,
  ValleyMaze_Part5,
  ValleyMaze_Part6,
  ValleyMaze_Part7,
  BioPlant,
  BioPlant_Part2,
  BioPlant_Part3,
  BioPlant_B1,
  BioPlant_B2,
  BioPlant_B2_Part2,
  BioPlant_B3,
  BioPlant_B3_Part2,
  BioPlant_B4,
  BioPlant_B4_Part2,
  BioPlant_B4_Part3,
  Wreckage,
  Wreckage_Part2,
  Wreckage_Part3,
  Wreckage_F1,
  Wreckage_F1_Part2,
  Wreckage_F2,
  Wreckage_F2_Part2,
  Wreckage_F2_Part3,
  Wreckage_F2_Part4,
  MachineCenter,
  MachineCenter_B1,
  MachineCenter_B1_Part2,
  PlateSystem,
  PlateSystem_F1,
  PlateSystem_F2,
  PlateSystem_F3,
  PlateSystem_F4,
  MotaSpaceport,
  ClimCenter,
  ClimCenter_F1,
  ClimCenter_F2,
  ClimCenter_F3,
  WeaponPlant,
  WeaponPlant_F1,
  WeaponPlant_F2,
  WeaponPlant_F3,
  VahalFort,
  VahalFort_F1,
  VahalFort_F2,
  VahalFort_F3,
  Nurvus_Part2,
  Nurvus_Part3,
  Nurvus_B1,
  Nurvus_B2,
  Nurvus_B3,
  Nurvus_B1Tunnel,
  Nurvus_B4,
  Nurvus_B4_Part2,
  DezoSpaceport,
  Nurvus_B5,
  Nurvus_B3Tunnel,
  Nurvus,
  ValleyMazeOutside,
  ValleyMazeOutside2,
  PassagewayNearAiedo,
  PassagewayNearKadary,
  Uzo,
  UzoHouse1,
  UzoHouse2,
  UzoInn,
  UzoHouse3,
  UzoItemShop,
  Torinco,
  CulversHouse,
  TorincoHouse1,
  TorincoHouse2,
  TorincoItemShop,
  TorincoInn,
  MonsenCave,
  RappyCave,
  LeRoofRoom,
  SilenceTm,
  StrengthTower,
  StrengthTower_F1,
  StrengthTower_F2,
  StrengthTower_F3,
  StrengthTower_F4,
  CourageTower,
  CourageTower_F1,
  CourageTower_F2,
  CourageTower_F3,
  CourageTower_F4,
  AngerTower,
  AngerTower_F1,
  AngerTower_F2,
  TheEdge,
  TheEdge_Part2,
  TheEdge_Part3,
  TheEdge_Part4,
  TheEdge_Part5,
  TheEdge_Part6,
  TheEdge_Part7,
  TheEdge_Part8,
  TheEdge_Part9,
  Tyler,
  TylerHouse1,
  TylerWeaponShop,
  TylerItemShop,
  TylerHouse2,
  TylerInn,
  Zosa,
  ZosaHouse1,
  ZosaHouse2,
  ZosaWeaponShop,
  ZosaItemShop,
  ZosaInn,
  ZosaHouse3,
  Meese,
  MeeseHouse1,
  MeeseItemShop2,
  MeeseItemShop1,
  MeeseWeaponShop,
  MeeseInn,
  MeeseClinic,
  MeeseClinic_F1,
  Jut,
  JutHouse1,
  JutHouse2,
  JutHouse3,
  JutHouse4,
  JutHouse5,
  JutWeaponShop,
  JutItemShop,
  JutHouse6,
  JutHouse6_F1,
  JutHouse7,
  JutHouse8,
  JutInn,
  JutChurch,
  Ryuon,
  RyuonItemShop,
  RyuonWeaponShop,
  RyuonHouse1,
  RyuonHouse2,
  RyuonHouse3,
  RyuonPub,
  RyuonInn,
  RajaTemple,
  Reshel1,
  Reshel2,
  Reshel3,
  Reshel2House,
  Reshel2WeaponShop,
  Reshel3House1,
  Reshel3ItemShop,
  Reshel3House2,
  Reshel3WeaponShop,
  Reshel3Inn,
  Reshel3House3,
  MystVale,
  MystVale_Part2,
  MystVale_Part3,
  MystVale_Part4,
  MystVale_Part5,
  ElsydeonCave,
  ElsydeonCave_B1,
  Hangar,
  GumbiousEntrance,
  Gumbious,
  Gumbious_F1,
  Gumbious_B1,
  Gumbious_B2,
  Gumbious_B2_Part2,
  EspMansionEntrance,
  EspMansion,
  EspMansionWestRoom,
  EspMansionEastRoom,
  EspMansionNorth,
  EspMansionNorthEastRoom,
  EspMansionNorthWestRoom,
  EspMansionCourtyard,
  InnerSanctuary,
  InnerSanctuary_B1,
  AirCastle_Part6,
  AirCastle,
  AirCastle_Part2,
  AirCastle_Part3,
  AirCastle_Part4,
  AirCastle_Part5,
  AirCastle_F1_Part9,
  AirCastle_F1_Part5,
  AirCastle_F1_Part2,
  AirCastle_F1_Part10,
  AirCastleInner,
  AirCastle_F1_Part11,
  AirCastle_F1_Part12,
  AirCastle_F1_Part13,
  AirCastle_Part8,
  AirCastle_Part7,
  AirCastle_F1_Part4,
  AirCastle_F1,
  AirCastle_F1_Part3,
  AirCastle_F2,
  AirCastleXeAThoulRoom,
  AirCastleInner_B1,
  AirCastleInner_B1_Part2,
  AirCastleInner_B1_Part3,
  AirCastleInner_B2,
  AirCastleInner_B3,
  AirCastleInner_B4,
  AirCastleInner_B5,
  ZelanSpace,
  Zelan,
  Zelan_F1,
  KuranSpace,
  Kuran,
  Kuran_F1,
  Kuran_F2,
  Kuran_F1_Part2,
  Kuran_F1_Part3,
  Kuran_F1_Part5,
  Kuran_F2_Part2,
  Kuran_F1_Part4,
  Kuran_F3,
  GaruberkTower,
  GaruberkTower_Part2,
  GaruberkTower_Part3,
  GaruberkTower_Part4,
  GaruberkTower_Part5,
  GaruberkTower_Part6,
  GaruberkTower_Part7,
  AirCastleSpace,
}

class MapObject extends FieldObject with UnnamedSpeaker {
  final MapObjectId id;
  // note: can only be in multiples of 8 pixels
  final Position startPosition;
  final MapObjectSpec spec;

  // todo: should scene really be a part of spec? yes.
  // since some objects effectively don't have interactions?
  // see FaceDownLegsHiddenNoInteraction
  // also elevator routine ($120), others
  late Scene onInteract;

  MapObject(
      {String? id,
      required this.startPosition,
      required this.spec,
      Scene onInteract = const Scene.none(),
      bool onInteractFacePlayer = true})
      : id = id == null ? MapObjectId.random() : MapObjectId(id) {
    this.onInteract = onInteractFacePlayer
        ? onInteract.startingWith([FacePlayer(this)])
        : onInteract;
  }

  @override
  int? slot(EventState c) => null;

  @override
  String toString() {
    return 'MapObject{id: $id}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapObject &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          startPosition == other.startPosition &&
          spec == other.spec &&
          onInteract == other.onInteract;

  @override
  int get hashCode =>
      id.hashCode ^
      startPosition.hashCode ^
      spec.hashCode ^
      onInteract.hashCode;
}

final _random = Random();

class MapObjectId {
  final String id;

  MapObjectId(this.id) {
    checkArgument(onlyWordCharacters.hasMatch(id),
        message: 'id must match $onlyWordCharacters but got $id');
  }

  // todo: this kinda sucks
  MapObjectId.random() : id = _randomId();

  static String _randomId() {
    final b = Uint8List(4);

    for (var i = 0; i < 4; i++) {
      b[i] = _random.nextInt(256);
    }

    return b.map((e) => e.toRadixString(25)).join();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapObjectId &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// Defines an object: how it behaves and how it is displayed.
abstract class MapObjectSpec {
  MapObjectSpec();

  const MapObjectSpec.constant();

  Direction get startFacing;
}

abstract class ExtendableObject {
  // can use MapObject if MapObject is not implicitly Interactable
  // which it shouldn't be, in hindsight
  // then this makes this a potentially elegant solution
  // it still doesn't necessarily de-duplicate interactions, though
  // since MapObjects can still have interactable specs
  List<MapObject> get extendsTo;
}

abstract class Interactive {
  set onInteract(Scene scene);
  Scene get onInteract;
}

/// Spec for class of behaviors with interchangeable sprites.
class Npc extends MapObjectSpec {
  final Sprite sprite;
  final NpcBehavior behavior;

  @override
  Direction get startFacing => behavior.startFacing;

  Npc(this.sprite, this.behavior);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Npc &&
          runtimeType == other.runtimeType &&
          sprite == other.sprite &&
          behavior == other.behavior;

  @override
  int get hashCode => sprite.hashCode ^ behavior.hashCode;
}

enum Sprite {
  /// blue hair, green shirt, white pants
  PalmanMan1,

  /// black hair, gray suit, brown vest
  PalmanMan2,

  /// brown hair, blue shirt, red tie, white pants
  PalmanMan3,

  /// balding, black hair, green shirt, gray pants
  PalmanMan4,
  PalmanOldMan1,

  /// Gray hair, white shirt
  PalmanOldWoman1,

  /// Gray hair, gray suit, blue vest, glasses
  PalmanOldWoman2,

  /// brown shirt, gray pants, walking stick
  PalmanOldMan2,

  /// guard
  PalmanFighter1,

  /// green headband, open vest, white pants, blue shoes
  PalmanFighter2,

  /// white turban and cape
  PalmanFighter3,

  /// brown hair, orange shirt, red pants
  PalmanWoman1,

  /// long orange hair, blue and white dress
  PalmanWoman2,

  /// green hair in pony tail, blue dress
  PalmanWoman3,

  /// black hair yellow vest
  PalmanWoman4,
  PalmanStudent1,
  PalmanStripper1,
  Kroft,

  /// Old professor.
  PalmanProfessor1,

  /// Old professor humped over with hands behind his back.
  PalmanProfessor2,
  PalmanPeddler1,

  /// Tall, light tan robes, green feet
  Motavian1,

  /// Shorter, dark tan robes, green feet
  Motavian2,

  /// Small and blue
  Motavian3,
  GrandfatherDorin,
  GuildReceptionist,

  /// Short blue hair
  ZioWorshipper1,

  /// Long green hair
  ZioWorshipper2,

  /// White hair. Faints.
  ZioPriest,
}

Sprite? spriteByName(String name) {
  name = name.trim().toLowerCase();
  for (var s in Sprite.values) {
    if (s.name.toLowerCase() == name) return s;
  }
  return null;
}

class AlysWaiting extends MapObjectSpec {
  factory AlysWaiting() {
    return const AlysWaiting._();
  }
  const AlysWaiting._() : super.constant();

  @override
  final startFacing = Direction.down;

  @override
  String toString() {
    return 'AlysWaiting{}';
  }
}

// Sprite is currently not configurable (defined in RAM).
// We could technically make it configurable but not needed at this time.
class AiedoShopperWithBags extends MapObjectSpec {
  @override
  final Direction startFacing;

  AiedoShopperWithBags(this.startFacing);

  @override
  String toString() {
    return 'AiedoShopperWithBags{startFacing: $startFacing}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiedoShopperWithBags &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode;
}

// Sprite is currently not configurable (defined in RAM).
// We could technically make it configurable but not needed at this time.
class AiedoShopperMom extends MapObjectSpec {
  factory AiedoShopperMom() {
    return const AiedoShopperMom._();
  }
  const AiedoShopperMom._() : super.constant();

  @override
  final startFacing = Direction.right;

  @override
  String toString() {
    return 'AiedoShopperMom{}';
  }
}

class InvisibleBlock extends MapObjectSpec, Interactable {

}

abstract class NpcBehavior {
  const NpcBehavior();

  Direction get startFacing;
}

class FaceDown extends NpcBehavior {
  factory FaceDown() {
    return const FaceDown._();
  }
  const FaceDown._();

  @override
  final startFacing = Direction.down;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceDown && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class WanderAround extends NpcBehavior {
  @override
  final Direction startFacing;

  WanderAround(this.startFacing);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WanderAround &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode;

  @override
  String toString() {
    return 'WanderAround{startFacing: $startFacing}';
  }
}

class SlowlyWanderAround extends NpcBehavior {
  @override
  final Direction startFacing;

  SlowlyWanderAround(this.startFacing);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlowlyWanderAround &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode;

  @override
  String toString() {
    return 'SlowlyWanderAround{startFacing: $startFacing}';
  }
}

/// Does not collide or trigger dialog interaction.
class FaceDownLegsHiddenNoInteraction extends NpcBehavior {
  @override
  final startFacing = Direction.down;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceDownLegsHiddenNoInteraction &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode;

  @override
  String toString() {
    return 'FaceDownLegsHiddenNoInteraction{}';
  }
}

/// Does not move when spoken to.
class FixedFaceDownLegsHidden extends NpcBehavior {
  @override
  final startFacing = Direction.down;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FixedFaceDownLegsHidden &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode;

  @override
  String toString() {
    return 'FixedFaceDownLegsHidden{}';
  }
}

/// Does not move when spoken to.
class FixedFaceRight extends NpcBehavior {
  @override
  final startFacing = Direction.down;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FixedFaceRight &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode;

  @override
  String toString() {
    return 'FixedFaceRight{}';
  }
}