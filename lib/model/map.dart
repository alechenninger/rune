// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:quiver/check.dart';

import '../asm/asm.dart';
import 'model.dart';

// generator will need to track a vram tile number offset to start storing art
// pointers
// note that many events refer to map objects address in memory, which means
// ordering must be maintained for existing objects unless we find and edit
// those addresses.
class GameMap {
  final MapId id;

  // limited to 64 objects in ram currently
  final _objects = <MapObjectId, _MapObjectAt>{};
  final _indexedObjects = <MapObject?>[];

  GameMap(this.id);

  // TODO: we may want a way to retrieve back
  //  whether an object was explicitly assigned an index or not

  Iterable<MapObject> get objects =>
      UnmodifiableListView(_objects.values.map((o) => o.object));

  List<MapObject> get orderedObjects =>
      _iterateIndexedObjects().mapIndexed((i, indexed) {
        if (indexed == null) {
          return placeholderMapObject(i);
        }
        return indexed.object;
      }).toList(growable: false);

  Iterable<IndexedMapObject> get indexedObjects =>
      _iterateIndexedObjects().whereNotNull();

  bool get isNotEmpty => _objects.isNotEmpty;
  bool get isEmpty => _objects.isEmpty;

  //final onMove = <Event>[];

  bool containsObject(MapObjectId id) => _objects.containsKey(id);

  MapObject? object(MapObjectId id) => _objects[id]?.object;

  int? indexOf(MapObjectId id) => _iterateIndexedObjects()
      .whereNotNull()
      .firstWhereOrNull((indexed) => indexed.object.id == id)
      ?.index;

  /// Iterates through all objects with indexes, where each object's position
  /// in the iterable == its index.
  Iterable<IndexedMapObject?> _iterateIndexedObjects() sync* {
    var objects = Queue.of(_objects.values);
    var limit = max(_objects.length, _indexedObjects.length);

    forobjects:
    for (var i = 0; i < limit; i++) {
      var indexed = i < _indexedObjects.length ? _indexedObjects[i] : null;
      if (indexed != null) {
        yield IndexedMapObject(i, indexed);
      } else if (objects.isEmpty) {
        yield null;
      } else {
        var obj = objects.removeFirst();
        while (obj.index != null) {
          if (objects.isEmpty) {
            yield null;
            continue forobjects;
          } else {
            obj = objects.removeFirst();
          }
        }
        yield IndexedMapObject(i, obj.object);
      }
    }
  }

  void addObject(MapObject obj, {int? at}) {
    if (_objects.containsKey(obj.id)) {
      throw ArgumentError('map already contains object with id: ${obj.id}');
    }
    if (at != null) {
      if (at < _indexedObjects.length) {
        var existing = _indexedObjects[at];
        if (existing != null) {
          throw ArgumentError.value(obj.id.value, 'obj.id',
              'map already contains object at index $at: ${existing.id}');
        }
        _indexedObjects[at] = obj;
      } else {
        _indexedObjects.length = at + 1;
        _indexedObjects[at] = obj;
      }
    }
    _objects[obj.id] = _MapObjectAt(obj, at);
  }

  void addIndexedObject(IndexedMapObject obj) {
    addObject(obj.object, at: obj.index);
  }

  @override
  String toString() {
    return 'GameMap{id: $id, _indexedObjects: $_indexedObjects}';
  }
}

class _MapObjectAt {
  final int? index;
  final MapObject object;

  _MapObjectAt(this.object, [this.index]);
}

class IndexedMapObject {
  final int index;
  final MapObject object;

  IndexedMapObject(this.index, this.object);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexedMapObject &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          object == other.object;

  @override
  int get hashCode => index.hashCode ^ object.hashCode;

  @override
  String toString() {
    return 'IndexedMapObject{index: $index, object: $object}';
  }
}

enum Area {
  Test('Test Area'),
  Piata,
  Mile,
  Zema,
  Krup,
  BirthValley('Birth Valley'),
  Tonoe,
  ValleyMaze('Valley Maze'),
  BioPlant,
  Nalya,
  Wreckage,
  Aiedo,
  Kadary,
  ZioFort("Zio's Fort"),
  Monsen,
  PlateSystem,
  Termi,
  LadeaTower('Ladea Tower'),
  Nurvus,
  Zelan,
  Ryuon,
  Tyler,
  Kuran,
  Zosa,
  MystVale('Myst Vale'),
  Reshel,
  Jut,
  Meese,
  EsperMansion('Esper Mansion'),
  GumbiousTemple('Gumbious Temple'),
  AirCastle('Air Castle'),
  GuaronTower('Guaron Tower'),
  Torinco,
  Uzo,
  VahalFort('Vahal Fort'),
  SoldiersShrine("Soldier's Shrine"),
  TowerOfCourage('Tower of Courage'),
  TowerOfStrength('Tower of Strength'),
  TowerOfAnger('Tower of Anger'),
  SacellumOfQuietude('Sacellum of Quietude'),
  ElsydeonCave('Elsydeon Cave'),
  ;

  final String? _readableName;
  String get readableName => _readableName ?? name;

  const Area([String? readableName]) : _readableName = readableName;
}

enum MapId {
  Test(Area.Test),
  Test_Part2(Area.Test),

  Dezolis,
  Motavia,
  Rykros,

  PiataAcademy(Area.Piata),
  PiataAcademyF1(Area.Piata),
  //PiataAcademy_F1(Area.Piata),
  PiataAcademyPrincipalOffice(Area.Piata),
  //AcademyPrincipalOffice(Area.Piata),
  PiataAcademyNearBasement(Area.Piata),
  PiataAcademyBasement(Area.Piata),
  //AcademyBasement(Area.Piata),
  PiataAcademyBasementB1(Area.Piata),
  //AcademyBasement_B1(Area.Piata),
  PiataAcademyBasementB2(Area.Piata),
  //AcademyBasement_B2(Area.Piata),
  Piata(Area.Piata),
  PiataDorm(Area.Piata),
  PiataInn(Area.Piata),
  PiataHouse1(Area.Piata),
  PiataHouse2(Area.Piata),
  PiataItemShop(Area.Piata),

  Mile(Area.Mile),
  MileWeaponShop(Area.Mile),
  MileHouse1(Area.Mile),
  MileItemShop(Area.Mile),
  MileHouse2(Area.Mile),
  MileInn(Area.Mile),

  Zema(Area.Zema),
  ZemaHouse1(Area.Zema),
  ZemaWeaponShop(Area.Zema),
  ZemaInn(Area.Zema),
  ZemaHouse2(Area.Zema),
  ZemaHouse2_B1(Area.Zema),
  ZemaItemShop(Area.Zema),

  BirthValley(Area.BirthValley),
  BirthValley_B1(Area.BirthValley),

  Molcum,

  Krup(Area.Krup),
  KrupKindergarten(Area.Krup),
  KrupWeaponShop(Area.Krup),
  KrupItemShop(Area.Krup),
  KrupHouse(Area.Krup),
  KrupInn(Area.Krup),
  KrupInn_F1(Area.Krup),

  ValleyMazeOutside(Area.ValleyMaze),
  ValleyMaze(Area.ValleyMaze),
  ValleyMaze_Part2(Area.ValleyMaze),
  ValleyMaze_Part3(Area.ValleyMaze),
  ValleyMaze_Part4(Area.ValleyMaze),
  ValleyMaze_Part5(Area.ValleyMaze),
  ValleyMaze_Part6(Area.ValleyMaze),
  ValleyMaze_Part7(Area.ValleyMaze),
  ValleyMazeUnused(Area.ValleyMaze),
  ValleyMazeOutside2(Area.ValleyMaze),

  Tonoe(Area.Tonoe),
  TonoeStorageRoom(Area.Tonoe),
  TonoeGryzHouse(Area.Tonoe),
  TonoeHouse1(Area.Tonoe),
  TonoeHouse2(Area.Tonoe),
  TonoeInn(Area.Tonoe),
  TonoeBasement(Area.Tonoe),
  TonoeBasement_B1(Area.Tonoe),
  TonoeBasement_B2(Area.Tonoe),
  TonoeBasement_B3(Area.Tonoe),

  // Return to Zema...

  BioPlant(Area.BioPlant),
  BioPlant_Part2(Area.BioPlant),
  BioPlant_Part3(Area.BioPlant),
  BioPlant_B1(Area.BioPlant),
  BioPlant_B2(Area.BioPlant),
  BioPlant_B2_Part2(Area.BioPlant),
  BioPlant_B3(Area.BioPlant),
  BioPlant_B3_Part2(Area.BioPlant),
  BioPlant_B4(Area.BioPlant),
  BioPlant_B4_Part2(Area.BioPlant),
  BioPlant_B4_Part3(Area.BioPlant),

  // Return to Piata...

  Nalya(Area.Nalya),
  NalyaHouse1(Area.Nalya),
  NalyaHouse2(Area.Nalya),
  NalyaItemShop(Area.Nalya),
  NalyaHouse3(Area.Nalya),
  NalyaHouse4(Area.Nalya),
  NalyaHouse5(Area.Nalya),
  NalyaInn(Area.Nalya),
  NalyaInn_F1(Area.Nalya),

  Wreckage(Area.Wreckage),
  Wreckage_Part2(Area.Wreckage),
  Wreckage_Part3(Area.Wreckage),
  Wreckage_F1(Area.Wreckage),
  Wreckage_F1_Part2(Area.Wreckage),
  Wreckage_F2(Area.Wreckage),
  Wreckage_F2_Part2(Area.Wreckage),
  Wreckage_F2_Part3(Area.Wreckage),
  Wreckage_F2_Part4(Area.Wreckage),

  Aiedo(Area.Aiedo),
  ShayHouse(Area.Aiedo),
  //ChazHouse(Area.Aiedo),
  AiedoBakery(Area.Aiedo),
  AiedoBakery_B1(Area.Aiedo),
  AiedoWeaponShop(Area.Aiedo),
  AiedoPrison(Area.Aiedo),
  AiedoHouse1(Area.Aiedo),
  AiedoHouse2(Area.Aiedo),
  AiedoHouse3(Area.Aiedo),
  AiedoHouse4(Area.Aiedo),
  AiedoHouse5(Area.Aiedo),
  AiedoHouse6(Area.Aiedo),
  AiedoHouse7(Area.Aiedo),
  RockyHouse(Area.Aiedo),
  AiedoSupermarket(Area.Aiedo),
  AiedoPub(Area.Aiedo),
  HuntersGuild(Area.Aiedo),
  HuntersGuildStorage(Area.Aiedo),
  StripClub(Area.Aiedo),
  StripClubDressingRoom(Area.Aiedo),

  PassagewayNearAiedo,
  Passageway,
  PassagewayNearKadary,

  Kadary(Area.Kadary),
  KadaryChurch(Area.Kadary),
  KadaryPub(Area.Kadary),
  KadaryPub_F1(Area.Kadary),
  KadaryStorageRoom(Area.Kadary),
  KadaryHouse1(Area.Kadary),
  KadaryHouse2(Area.Kadary),
  KadaryHouse3(Area.Kadary),
  KadaryItemShop(Area.Kadary),
  KadaryInn(Area.Kadary),
  KadaryInn_F1(Area.Kadary),

  ZioFort(Area.ZioFort),
  ZioFort_Part2(Area.ZioFort),
  ZioFort_F1(Area.ZioFort),
  ZioFort_F2East(Area.ZioFort),
  ZioFort_F2West(Area.ZioFort),
  ZioFortEastTunnel(Area.ZioFort),
  ZioFortWestTunnel(Area.ZioFort),
  ZioFortJuzaRoom(Area.ZioFort),
  ZioFort_F3(Area.ZioFort),
  ZioFort_F4(Area.ZioFort),

  // Return to Krup
  MachineCenter,
  MachineCenter_B1,
  MachineCenter_B1_Part2,

  MonsenCave(Area.Monsen),
  Monsen(Area.Monsen),
  MonsenInn(Area.Monsen),
  MonsenHouse1(Area.Monsen),
  MonsenHouse2(Area.Monsen),
  MonsenHouse3(Area.Monsen),
  MonsenHouse4(Area.Monsen),
  MonsenHouse5(Area.Monsen),
  MonsenItemShop(Area.Monsen),

  PlateSystem(Area.PlateSystem),
  PlateSystem_F1(Area.PlateSystem),
  PlateSystem_F2(Area.PlateSystem),
  PlateSystem_F3(Area.PlateSystem),
  PlateSystem_F4(Area.PlateSystem),

  Termi(Area.Termi),
  TermiHouse1(Area.Termi),
  TermiHouse2(Area.Termi),
  TermiItemShop(Area.Termi),
  TermiWeaponShop(Area.Termi),
  TermiInn(Area.Termi),

  LadeaTower(Area.LadeaTower),
  LadeaTower_F1(Area.LadeaTower),
  LadeaTower_F2(Area.LadeaTower),
  LadeaTower_F3(Area.LadeaTower),
  LadeaTower_F4(Area.LadeaTower),
  LadeaTower_F5(Area.LadeaTower),

  Nurvus(Area.Nurvus),
  Nurvus_Part2(Area.Nurvus),
  Nurvus_Part3(Area.Nurvus),
  Nurvus_B1(Area.Nurvus),
  Nurvus_B1Tunnel(Area.Nurvus),
  Nurvus_B2(Area.Nurvus),
  Nurvus_B3(Area.Nurvus),
  Nurvus_B3Tunnel(Area.Nurvus),
  Nurvus_B4(Area.Nurvus),
  Nurvus_B4_Part2(Area.Nurvus),
  Nurvus_B5(Area.Nurvus),

  MotaSpaceport,

  ZelanSpace(Area.Zelan),
  Zelan(Area.Zelan),
  Zelan_F1(Area.Zelan),

  RajaTemple,

  Ryuon(Area.Ryuon),
  RyuonItemShop(Area.Ryuon),
  RyuonWeaponShop(Area.Ryuon),
  RyuonHouse1(Area.Ryuon),
  RyuonHouse2(Area.Ryuon),
  RyuonHouse3(Area.Ryuon),
  RyuonPub(Area.Ryuon),
  RyuonInn(Area.Ryuon),

  // Tyler
  Tyler(Area.Tyler),
  TylerHouse1(Area.Tyler),
  TylerWeaponShop(Area.Tyler),
  TylerItemShop(Area.Tyler),
  TylerHouse2(Area.Tyler),
  TylerInn(Area.Tyler),
  Hangar(Area.Tyler),

  // Kuran
  KuranSpace(Area.Kuran),
  Kuran(Area.Kuran),
  Kuran_F1(Area.Kuran),
  Kuran_F1_Part2(Area.Kuran),
  Kuran_F1_Part3(Area.Kuran),
  Kuran_F1_Part4(Area.Kuran),
  Kuran_F1_Part5(Area.Kuran),
  Kuran_F2(Area.Kuran),
  Kuran_F2_Part2(Area.Kuran),
  Kuran_F3(Area.Kuran),

  // Return to Zelan

  // Zosa
  Zosa(Area.Zosa),
  ZosaHouse1(Area.Zosa),
  ZosaHouse2(Area.Zosa),
  ZosaWeaponShop(Area.Zosa),
  ZosaItemShop(Area.Zosa),
  ZosaInn(Area.Zosa),
  ZosaHouse3(Area.Zosa),

  // Myst Value
  MystVale(Area.MystVale),
  MystVale_Part2(Area.MystVale),
  MystVale_Part3(Area.MystVale),
  MystVale_Part4(Area.MystVale),
  MystVale_Part5(Area.MystVale),

  // Climate Center
  ClimCenter,
  ClimCenter_F1,
  ClimCenter_F2,
  ClimCenter_F3,

  // Reshel
  Reshel1(Area.Reshel),
  Reshel2(Area.Reshel),
  Reshel3(Area.Reshel),
  Reshel2House(Area.Reshel),
  Reshel2WeaponShop(Area.Reshel),
  Reshel3House1(Area.Reshel),
  Reshel3ItemShop(Area.Reshel),
  Reshel3House2(Area.Reshel),
  Reshel3WeaponShop(Area.Reshel),
  Reshel3Inn(Area.Reshel),
  Reshel3House3(Area.Reshel),

  // Jut
  Jut(Area.Jut),
  JutHouse1(Area.Jut),
  JutHouse2(Area.Jut),
  JutHouse3(Area.Jut),
  JutHouse4(Area.Jut),
  JutHouse5(Area.Jut),
  JutWeaponShop(Area.Jut),
  JutItemShop(Area.Jut),
  JutHouse6(Area.Jut),
  JutHouse6_F1(Area.Jut),
  JutHouse7(Area.Jut),
  JutHouse8(Area.Jut),
  JutInn(Area.Jut),
  JutChurch(Area.Jut),

  // Weapon plant
  WeaponPlant,
  WeaponPlant_F1,
  WeaponPlant_F2,
  WeaponPlant_F3,

  // Meese
  Meese(Area.Meese),
  MeeseHouse1(Area.Meese),
  MeeseItemShop2(Area.Meese),
  MeeseItemShop1(Area.Meese),
  MeeseWeaponShop(Area.Meese),
  MeeseInn(Area.Meese),
  MeeseClinic(Area.Meese),
  MeeseClinic_F1(Area.Meese),

  // Carnivorous forest

  // Esper mansion
  EspMansionEntrance(Area.EsperMansion),
  EspMansion(Area.EsperMansion),
  EspMansionWestRoom(Area.EsperMansion),
  EspMansionEastRoom(Area.EsperMansion),
  EspMansionNorth(Area.EsperMansion),
  EspMansionNorthEastRoom(Area.EsperMansion),
  EspMansionNorthWestRoom(Area.EsperMansion),
  EspMansionCourtyard(Area.EsperMansion),
  InnerSanctuary(Area.EsperMansion),
  InnerSanctuary_B1(Area.EsperMansion),

  // Gumbious temple
  GumbiousEntrance(Area.GumbiousTemple),
  Gumbious(Area.GumbiousTemple),
  Gumbious_F1(Area.GumbiousTemple),
  Gumbious_B1(Area.GumbiousTemple),
  Gumbious_B2(Area.GumbiousTemple),
  Gumbious_B2_Part2(Area.GumbiousTemple),

  // Tyler spaceport
  DezoSpaceport,

  // Air castle
  AirCastleSpace(Area.AirCastle),
  AirCastle(Area.AirCastle),
  AirCastle_Part2(Area.AirCastle),
  AirCastle_Part3(Area.AirCastle),
  AirCastle_Part4(Area.AirCastle),
  AirCastle_Part5(Area.AirCastle),
  AirCastle_Part6(Area.AirCastle),
  AirCastle_Part7(Area.AirCastle),
  AirCastle_Part8(Area.AirCastle),
  AirCastle_F1(Area.AirCastle),
  AirCastle_F1_Part2(Area.AirCastle),
  AirCastle_F1_Part3(Area.AirCastle),
  AirCastle_F1_Part4(Area.AirCastle),
  AirCastle_F1_Part9(Area.AirCastle),
  AirCastle_F1_Part5(Area.AirCastle),
  AirCastle_F1_Part10(Area.AirCastle),
  AirCastle_F1_Part11(Area.AirCastle),
  AirCastle_F1_Part12(Area.AirCastle),
  AirCastle_F1_Part13(Area.AirCastle),
  AirCastle_F2(Area.AirCastle),
  AirCastleXeAThoulRoom(Area.AirCastle),
  AirCastleInner(Area.AirCastle),
  AirCastleInner_B1(Area.AirCastle),
  AirCastleInner_B1_Part2(Area.AirCastle),
  AirCastleInner_B1_Part3(Area.AirCastle),
  AirCastleInner_B2(Area.AirCastle),
  AirCastleInner_B3(Area.AirCastle),
  AirCastleInner_B4(Area.AirCastle),
  AirCastleInner_B5(Area.AirCastle),

  // Guaron tower
  GaruberkTower(Area.GuaronTower),
  GaruberkTower_Part2(Area.GuaronTower),
  GaruberkTower_Part3(Area.GuaronTower),
  GaruberkTower_Part4(Area.GuaronTower),
  GaruberkTower_Part5(Area.GuaronTower),
  GaruberkTower_Part6(Area.GuaronTower),
  GaruberkTower_Part7(Area.GuaronTower),

  // Torinco
  Torinco(Area.Torinco),
  CulversHouse(Area.Torinco),
  TorincoHouse1(Area.Torinco),
  TorincoHouse2(Area.Torinco),
  TorincoItemShop(Area.Torinco),
  TorincoInn(Area.Torinco),

  // Uzo
  Uzo(Area.Uzo),
  UzoHouse1(Area.Uzo),
  UzoHouse2(Area.Uzo),
  UzoInn(Area.Uzo),
  UzoHouse3(Area.Uzo),
  UzoItemShop(Area.Uzo),

  // Vahal Fort
  VahalFort(Area.VahalFort),
  VahalFort_F1(Area.VahalFort),
  VahalFort_F2(Area.VahalFort),
  VahalFort_F3(Area.VahalFort),

  RappyCave,

  // Soldier's Shrine
  SoldiersTempleOutside(Area.SoldiersShrine),
  SoldiersTemple(Area.SoldiersShrine),
  IslandCave(Area.SoldiersShrine),
  IslandCave_F1(Area.SoldiersShrine),
  IslandCave_F1_Part2(Area.SoldiersShrine),
  IslandCave_Part2(Area.SoldiersShrine),
  IslandCave_B1(Area.SoldiersShrine),
  IslandCave_F2(Area.SoldiersShrine),
  IslandCave_F3(Area.SoldiersShrine),

  // Courage
  CourageTower(Area.TowerOfCourage),
  CourageTower_F1(Area.TowerOfCourage),
  CourageTower_F2(Area.TowerOfCourage),
  CourageTower_F3(Area.TowerOfCourage),
  CourageTower_F4(Area.TowerOfCourage),

  // Grace
  StrengthTower(Area.TowerOfStrength),
  StrengthTower_F1(Area.TowerOfStrength),
  StrengthTower_F2(Area.TowerOfStrength),
  StrengthTower_F3(Area.TowerOfStrength),
  StrengthTower_F4(Area.TowerOfStrength),

  // Wrath
  AngerTower(Area.TowerOfAnger),
  AngerTower_F1(Area.TowerOfAnger),
  AngerTower_F2(Area.TowerOfAnger),

  // Sacellum
  SilenceTm(Area.SacellumOfQuietude),
  LeRoofRoom(Area.SacellumOfQuietude),

  // Elysdeon
  ElsydeonCave(Area.ElsydeonCave),
  ElsydeonCave_B1(Area.ElsydeonCave),

  MileDead(Area.Mile),

  TheEdge,
  TheEdge_Part2,
  TheEdge_Part3,
  TheEdge_Part4,
  TheEdge_Part5,
  TheEdge_Part6,
  TheEdge_Part7,
  TheEdge_Part8,
  TheEdge_Part9;

  final Area? area;
  final MapId? outer;

  const MapId([this.area, this.outer]);
}

// todo: 'with UnnamedSpeaker' – aren't some objects named speakers?
class MapObject extends FieldObject implements UnnamedSpeaker {
  final MapObjectId id;
  // note: can only be in multiples of 8 pixels
  final Position startPosition;
  final MapObjectSpec spec;

  @override
  final name = const UnnamedSpeaker().name;

  Scene get onInteract {
    if (isInteractive) {
      return (spec as Interactive).onInteract;
    }
    return Scene.none();
  }

  bool get isInteractive => spec is Interactive;

  //@Deprecated('check if interactive first')
  set onInteract(Scene scene) {
    var spec = this.spec;
    if (isInteractive) {
      (spec as Interactive).onInteract = scene;
    } else if (scene != const Scene.none()) {
      throw ModelException('object is not interactive; cannot set scene');
    }
  }

  MapObject(
      {String? id,
      required this.startPosition,
      required this.spec,
      // todo: maybe use event list instead of Scene model?
      // issue is modifying scene w/ onInteractFacePlayer
      // –it's a misleading API
      // -> or maybe get rid of onInteractFacePlayer now that
      // it is not necessary to use reference to object itself
      @Deprecated("use spec") Scene onInteract = const Scene.none(),
      bool onInteractFacePlayer = true})
      : id = id == null ? MapObjectId.random() : MapObjectId(id) {
    if (onInteract != Scene.none()) {
      this.onInteract = onInteractFacePlayer
          ? onInteract.startingWith([InteractionObject.facePlayer()])
          : onInteract;
    } /* else if (spec is Interactive && onInteractFacePlayer) {
      var interactive = (spec as Interactive);
      interactive.onInteract =
          interactive.onInteract.startingWith([InteractionObject.facePlayer()]);
    }*/
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
          spec == other.spec;

  @override
  int get hashCode => id.hashCode ^ startPosition.hashCode ^ spec.hashCode;
}

/// Constructs an object which doesn't do anything.
MapObject placeholderMapObject(int index) {
  return MapObject(
      id: 'placeholder_$index',
      startPosition: Position(0, 0),
      // FieldObj_None
      spec: AsmSpec(routine: Word(0), startFacing: Direction.down));
}

final _random = Random();

class MapObjectId {
  final String value;

  MapObjectId(this.value) {
    checkArgument(onlyWordCharacters.hasMatch(value),
        message: 'id must match $onlyWordCharacters but got $value');
  }

  // todo: this kinda sucks
  MapObjectId.random() : value = _randomId();

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
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Defines an object: how it behaves and how it is displayed.
abstract class MapObjectSpec {
  MapObjectSpec();

  const MapObjectSpec.constant();

  Direction get startFacing;
}

abstract class Interactive {
  Scene onInteract = Scene.none();
}

/// Spec for class of behaviors with interchangeable sprites.
class Npc extends MapObjectSpec {
  final Sprite sprite;
  final NpcBehavior behavior;

  @override
  Direction get startFacing => behavior.startFacing;

  factory Npc(Sprite sprite, NpcBehavior behavior) {
    if (behavior is InteractiveNpcBehavior) {
      return InteractiveNpc._(sprite, behavior);
    }
    return Npc._(sprite, behavior);
  }

  Npc._(this.sprite, this.behavior);

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

class InteractiveNpc extends Npc implements Interactive {
  @override
  Scene get onInteract => (behavior as Interactive).onInteract;

  @override
  set onInteract(Scene onInteract) =>
      (behavior as Interactive).onInteract = onInteract;

  InteractiveNpc._(Sprite sprite, InteractiveNpcBehavior behavior)
      : super._(sprite, behavior);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is InteractiveNpc &&
          runtimeType == other.runtimeType &&
          onInteract == other.onInteract;

  @override
  int get hashCode => super.hashCode ^ onInteract.hashCode;
}

class Sprite {
  final String name;

  Sprite(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sprite && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return 'Sprite.$name';
  }

  /// blue hair, green shirt, white pants
  static final PalmanMan1 = byName['PalmanMan1']!;

  /// black hair, gray suit, brown vest
  static final PalmanMan2 = byName['PalmanMan2']!;

  /// brown hair, blue shirt, red tie, white pants
  static final PalmanMan3 = byName['PalmanMan3']!;

  /// balding, black hair, green shirt, gray pants
  static final PalmanMan4 = byName['PalmanMan4']!;
  static final PalmanOldMan1 = byName['PalmanOldMan1']!;

  /// Gray hair, white shirt
  static final PalmanOldWoman1 = byName['PalmanOldWoman1']!;

  /// Gray hair, gray suit, blue vest, glasses
  static final PalmanOldWoman2 = byName['PalmanOldWoman2']!;

  /// brown shirt, gray pants, walking stick
  static final PalmanOldMan2 = byName['PalmanOldMan2']!;

  /// guard
  static final PalmanFighter1 = byName['PalmanFighter1']!;

  /// green headband, open vest, white pants, blue shoes
  static final PalmanFighter2 = byName['PalmanFighter2']!;

  /// white turban and cape
  static final PalmanFighter3 = byName['PalmanFighter3']!;

  /// brown hair, orange shirt, red pants
  static final PalmanWoman1 = byName['PalmanWoman1']!;

  /// long orange hair, blue and white dress
  static final PalmanWoman2 = byName['PalmanWoman2']!;

  /// green hair in pony tail, blue dress
  static final PalmanWoman3 = byName['PalmanWoman3']!;

  /// black hair yellow vest
  static final PalmanWoman4 = byName['PalmanWoman4']!;
  static final PalmanStudent1 = byName['PalmanStudent1']!;
  static final PalmanStripper1 = byName['PalmanStripper1']!;
  static final Kroft = byName['Kroft']!;

  /// Old professor.
  static final PalmanProfessor1 = byName['PalmanProfessor1']!;

  /// Old professor humped over with hands behind his back.
  static final PalmanProfessor2 = byName['PalmanProfessor2']!;
  static final PalmanPeddler1 = byName['PalmanPeddler1']!;

  /// Tall, light tan robes, green feet
  static final Motavian1 = byName['Motavian1']!;

  /// Shorter, dark tan robes, green feet
  static final Motavian2 = byName['Motavian2']!;

  /// Small and blue
  static final Motavian3 = byName['Motavian3']!;
  static final GrandfatherDorin = byName['GrandfatherDorin']!;
  static final GuildReceptionist = byName['GuildReceptionist']!;

  /// Short blue hair
  static final ZioWorshipper1 = byName['ZioWorshipper1']!;

  /// Long green hair
  static final ZioWorshipper2 = byName['ZioWorshipper2']!;

  /// White hair. Faints.
  static final ZioPriest = byName['ZioPriest']!;

  static final wellKnown = [
    Sprite('PalmanMan1'),
    Sprite('PalmanMan2'),
    Sprite('PalmanMan3'),
    Sprite('PalmanMan4'),
    Sprite('PalmanOldMan1'),
    Sprite('PalmanOldWoman1'),
    Sprite('PalmanOldWoman2'),
    Sprite('PalmanOldMan2'),
    Sprite('PalmanFighter1'),
    Sprite('PalmanFighter2'),
    Sprite('PalmanFighter3'),
    Sprite('PalmanWoman1'),
    Sprite('PalmanWoman2'),
    Sprite('PalmanWoman3'),
    Sprite('PalmanWoman4'),
    Sprite('PalmanStudent1'),
    Sprite('PalmanStripper1'),
    Sprite('Kroft'),
    Sprite('PalmanProfessor1'),
    Sprite('PalmanProfessor2'),
    Sprite('PalmanPeddler1'),
    Sprite('Motavian1'),
    Sprite('Motavian2'),
    Sprite('Motavian3'),
    Sprite('GrandfatherDorin'),
    Sprite('GuildReceptionist'),
    Sprite('ZioWorshipper1'),
    Sprite('ZioWorshipper2'),
    Sprite('ZioPriest'),
  ];
  static final byName = wellKnown.groupFoldBy((s) => s.name, (_, s) => s);
}

Sprite? spriteByName(String name) {
  name = name.trim().toLowerCase();
  for (var s in Sprite.wellKnown) {
    if (s.name.toLowerCase() == name) return s;
  }
  return null;
}

class AlysWaiting extends MapObjectSpec with Interactive {
  @override
  final startFacing = Direction.down;

  @override
  String toString() {
    return 'AlysWaiting{}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlysWaiting && runtimeType == other.runtimeType;

  @override
  int get hashCode => toString().hashCode;
}

// Sprite is currently not configurable (defined in RAM).
// We could technically make it configurable but not needed at this time.
class AiedoShopperWithBags extends MapObjectSpec with Interactive {
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
class AiedoShopperMom extends MapObjectSpec with Interactive {
  @override
  final startFacing = Direction.right;

  @override
  String toString() {
    return 'AiedoShopperMom{}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiedoShopperMom && runtimeType == other.runtimeType;

  @override
  int get hashCode => toString().hashCode;
}

class InvisibleBlock extends MapObjectSpec with Interactive {
  @override
  final startFacing = Direction.down;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvisibleBlock && runtimeType == other.runtimeType;

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    return 'InvisibleBlock{}';
  }
}

class Elevator extends MapObjectSpec {
  @override
  final Direction startFacing;

  Elevator(this.startFacing);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Elevator &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode;

  @override
  String toString() {
    return 'Elevator{startFacing: $startFacing}';
  }
}

abstract class NpcBehavior {
  const NpcBehavior();

  Direction get startFacing;
}

abstract class InteractiveNpcBehavior extends NpcBehavior
    implements Interactive {
  @override
  Scene onInteract;

  // todo: maybe use event list instead of Scene model?
  // issue is modifying scene w/ onInteractFacePlayer
  // –it's a misleading API
  InteractiveNpcBehavior({this.onInteract = const Scene.none()});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InteractiveNpcBehavior &&
          runtimeType == other.runtimeType &&
          onInteract == other.onInteract;

  @override
  int get hashCode => onInteract.hashCode;
}

class FaceDown extends InteractiveNpcBehavior {
  @override
  final startFacing = Direction.down;

  FaceDown({super.onInteract});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is FaceDown && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode ^ super.hashCode;

  @override
  String toString() {
    return 'FaceDown{}';
  }
}

class WanderAround extends InteractiveNpcBehavior {
  @override
  final Direction startFacing;

  WanderAround(this.startFacing, {super.onInteract});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is WanderAround &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode ^ super.hashCode;

  @override
  String toString() {
    return 'WanderAround{startFacing: $startFacing}';
  }
}

class SlowlyWanderAround extends InteractiveNpcBehavior {
  @override
  final Direction startFacing;

  SlowlyWanderAround(this.startFacing, {super.onInteract});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is SlowlyWanderAround &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode ^ super.hashCode;

  @override
  String toString() {
    return 'SlowlyWanderAround{startFacing: $startFacing}';
  }
}

/// Does not collide or trigger dialog interaction.
class FaceDownLegsHiddenNonInteractive extends NpcBehavior {
  @override
  final startFacing = Direction.down;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceDownLegsHiddenNonInteractive &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode;

  @override
  String toString() {
    return 'FaceDownLegsHiddenNoInteraction{}';
  }
}

/// Only moves up or down. Does not collide. Relies on desk collision I think.
/// So this should probably really be directly classified as behind desk?
class FaceDownOrUpLegsHidden extends InteractiveNpcBehavior {
  @override
  final startFacing = Direction.down;

  FaceDownOrUpLegsHidden({super.onInteract});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is FaceDownOrUpLegsHidden &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode ^ super.hashCode;

  @override
  String toString() {
    return 'FaceDownOrUpLegsHidden{}';
  }
}

/// Does not move when spoken to.
class FixedFaceRight extends InteractiveNpcBehavior {
  @override
  final startFacing = Direction.right;

  FixedFaceRight({super.onInteract});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is FixedFaceRight &&
          runtimeType == other.runtimeType &&
          startFacing == other.startFacing;

  @override
  int get hashCode => startFacing.hashCode ^ super.hashCode;

  @override
  String toString() {
    return 'FixedFaceRight{}';
  }
}

class AsmSpec extends MapObjectSpec {
  final Label? artLabel;
  final Word routine;
  @override
  final Direction startFacing;

  AsmSpec._({this.artLabel, required this.routine, required this.startFacing});

  factory AsmSpec(
      {Label? artLabel,
      required Word routine,
      required Direction startFacing}) {
    if (isInteractive(routine)) {
      return InteractiveAsmSpec(
          routine: routine, startFacing: startFacing, artLabel: artLabel);
    }
    return AsmSpec._(
        artLabel: artLabel, routine: routine, startFacing: startFacing);
  }

  @override
  String toString() {
    return 'AsmSpec{artLabel: $artLabel, routine: $routine, startFacing: $startFacing}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsmSpec &&
          runtimeType == other.runtimeType &&
          artLabel == other.artLabel &&
          routine == other.routine &&
          startFacing == other.startFacing;

  @override
  int get hashCode =>
      artLabel.hashCode ^ routine.hashCode ^ startFacing.hashCode;
}

class InteractiveAsmSpec extends AsmSpec with Interactive {
  InteractiveAsmSpec(
      {super.artLabel,
      required super.routine,
      required super.startFacing,
      Scene onInteract = const Scene.none()})
      : super._() {
    if (!isInteractive(routine)) {
      throw ArgumentError.value(
          routine.value, 'routine', 'is not an interactive routine');
    }
    this.onInteract = onInteract;
  }

  @override
  String toString() {
    return 'InteractiveAsmSpec{'
        'artLabel: $artLabel, '
        'routine: $routine, '
        'startFacing: $startFacing,'
        'onInteract: $onInteract';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && onInteract == (other as InteractiveAsmSpec).onInteract;

  @override
  int get hashCode => super.hashCode ^ onInteract.hashCode;
}
