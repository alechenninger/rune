// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:quiver/check.dart';

import '../asm/asm.dart';
import 'model.dart';

class GameMap {
  final MapId id;

  // limited to 64 objects in ram currently
  final _objects = <MapObjectId, _MapObjectAt>{};
  final _indexedObjects = <MapObject?>[];

  // doesn't appear to be a limit other than ROM size
  final _areas = <MapAreaId, MapArea>{};

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

  bool get isNotEmpty => _objects.isNotEmpty || _areas.isNotEmpty;
  bool get isEmpty => _objects.isEmpty && _areas.isEmpty;

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
          throw ArgumentError.value(
              obj.id.value,
              'obj.id',
              'map already contains object at index. '
                  'index[$at]=${existing.id} map=$id');
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

  Iterable<MapArea> get areas => UnmodifiableListView(_areas.values);

  void addArea(MapArea area) {
    if (_areas.containsKey(area.id)) {
      throw ArgumentError('map already contains area with id: ${area.id}');
    }
    _areas[area.id] = area;
  }

  MapArea? area(MapAreaId id) => _areas[id];

  @override
  String toString() {
    return 'GameMap{id: $id, '
        '_objects: $_objects, '
        '_areas: $_areas}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameMap &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          const MapEquality().equals(_objects, other._objects) &&
          const MapEquality().equals(_areas, other._areas);

  @override
  int get hashCode =>
      id.hashCode ^
      const MapEquality().hash(_objects) ^
      const MapEquality().hash(_areas);
}

class _MapObjectAt {
  final int? index;
  final MapObject object;

  _MapObjectAt(this.object, [this.index]);

  @override
  String toString() {
    return '_MapObjectAt{index: $index, object: $object}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MapObjectAt &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          object == other.object;

  @override
  int get hashCode => index.hashCode ^ object.hashCode;
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

enum Zone {
  Test(World.Motavia, 'Test Area'),
  Motavia(World.Motavia),
  Piata(World.Motavia),
  Mile(World.Motavia),
  Zema(World.Motavia),
  Krup(World.Motavia),
  BirthValley(World.Motavia, 'Birth Valley'),
  Molcum(World.Motavia),
  Tonoe(World.Motavia),
  ValleyMaze(World.Motavia, 'Valley Maze'),
  BioPlant(World.Motavia),
  Nalya(World.Motavia),
  Wreckage(World.Motavia),
  Aiedo(World.Motavia),
  Passageway(World.Motavia),
  Kadary(World.Motavia),
  ZioFort(World.Motavia, "Zio's Fort"),
  MachineCenter(World.Motavia, 'Machine Center'),
  Monsen(World.Motavia),
  PlateSystem(World.Motavia),
  Termi(World.Motavia),
  LadeaTower(World.Motavia, 'Ladea Tower'),
  Nurvus(World.Motavia),
  MotaviaSpaceport(World.Motavia, 'Motavia Spaceport'),
  Zelan(World.Zelan),
  RajaTemple(World.Dezolis, 'Raja Temple'),
  Dezolis(World.Dezolis),
  Ryuon(World.Dezolis),
  Tyler(World.Dezolis),
  Kuran(World.Kuran),
  Zosa(World.Dezolis),
  MystVale(World.Dezolis, 'Myst Vale'),
  ClimateCenter(World.Dezolis, 'Climate Center'),
  Reshel(World.Dezolis),
  Jut(World.Dezolis),
  WeaponPlant(World.Dezolis, 'Weapon Plant'),
  Meese(World.Dezolis),
  EsperMansion(World.Dezolis, 'Esper Mansion'),
  GumbiousTemple(World.Dezolis, 'Gumbious Temple'),
  TylerSpaceport(World.Dezolis, 'Tyler Spaceport'),
  AirCastle(World.AirCastle, 'Air Castle'),
  GuaronTower(World.Dezolis, 'Guaron Tower'),
  Torinco(World.Motavia),
  Uzo(World.Motavia),
  VahalFort(World.Motavia, 'Vahal Fort'),
  RappyCave(World.Motavia, 'Rappy Cave'),
  SoldiersShrine(World.Motavia, "Soldier's Shrine"),
  Rykros(World.Rykros),
  TowerOfCourage(World.Rykros, 'Tower of Courage'),
  TowerOfStrength(World.Rykros, 'Tower of Strength'),
  TowerOfAnger(World.Rykros, 'Tower of Anger'),
  SacellumOfQuietude(World.Rykros, 'Sacellum of Quietude'),
  ElsydeonCave(World.Dezolis, 'Elsydeon Cave'),
  TheEdge(World.Dezolis, 'The Edge');

  final World world;

  final String? _readableName;
  String get readableName => _readableName ?? name;

  const Zone(this.world, [String? readableName]) : _readableName = readableName;
}

enum World { Motavia, Dezolis, Rykros, Zelan, Kuran, AirCastle }

enum MapId {
  Test(Zone.Test),
  Test_Part2(Zone.Test),

  Motavia(Zone.Motavia),
  Dezolis(Zone.Dezolis),
  Rykros(Zone.Rykros),

  PiataAcademy(Zone.Piata),
  PiataAcademyF1(Zone.Piata),
  //PiataAcademy_F1(Area.Piata),
  PiataAcademyPrincipalOffice(Zone.Piata),
  //AcademyPrincipalOffice(Area.Piata),
  PiataAcademyNearBasement(Zone.Piata),
  PiataAcademyBasement(Zone.Piata),
  //AcademyBasement(Area.Piata),
  PiataAcademyBasementB1(Zone.Piata),
  //AcademyBasement_B1(Area.Piata),
  PiataAcademyBasementB2(Zone.Piata),
  //AcademyBasement_B2(Area.Piata),
  Piata(Zone.Piata),
  PiataDorm(Zone.Piata),
  PiataInn(Zone.Piata),
  PiataHouse1(Zone.Piata),
  PiataHouse2(Zone.Piata),
  PiataItemShop(Zone.Piata),

  Mile(Zone.Mile),
  MileWeaponShop(Zone.Mile),
  MileHouse1(Zone.Mile),
  MileItemShop(Zone.Mile),
  MileHouse2(Zone.Mile),
  MileInn(Zone.Mile),

  Zema(Zone.Zema),
  ZemaHouse1(Zone.Zema),
  ZemaWeaponShop(Zone.Zema),
  ZemaInn(Zone.Zema),
  ZemaHouse2(Zone.Zema),
  ZemaHouse2_B1(Zone.Zema),
  ZemaItemShop(Zone.Zema),

  BirthValley(Zone.BirthValley),
  BirthValley_B1(Zone.BirthValley),

  Molcum(Zone.Molcum),

  Krup(Zone.Krup),
  KrupKindergarten(Zone.Krup),
  KrupWeaponShop(Zone.Krup),
  KrupItemShop(Zone.Krup),
  KrupHouse(Zone.Krup),
  KrupInn(Zone.Krup),
  KrupInn_F1(Zone.Krup),

  ValleyMazeOutside(Zone.ValleyMaze),
  ValleyMaze(Zone.ValleyMaze),
  ValleyMaze_Part2(Zone.ValleyMaze),
  ValleyMaze_Part3(Zone.ValleyMaze),
  ValleyMaze_Part4(Zone.ValleyMaze),
  ValleyMaze_Part5(Zone.ValleyMaze),
  ValleyMaze_Part6(Zone.ValleyMaze),
  ValleyMaze_Part7(Zone.ValleyMaze),
  ValleyMazeUnused(Zone.ValleyMaze),
  ValleyMazeOutside2(Zone.ValleyMaze),

  Tonoe(Zone.Tonoe),
  TonoeStorageRoom(Zone.Tonoe),
  TonoeGryzHouse(Zone.Tonoe),
  TonoeHouse1(Zone.Tonoe),
  TonoeHouse2(Zone.Tonoe),
  TonoeInn(Zone.Tonoe),
  TonoeBasement(Zone.Tonoe),
  TonoeBasement_B1(Zone.Tonoe),
  TonoeBasement_B2(Zone.Tonoe),
  TonoeBasement_B3(Zone.Tonoe),

  // Return to Zema...

  BioPlant(Zone.BioPlant),
  BioPlant_Part2(Zone.BioPlant),
  BioPlant_Part3(Zone.BioPlant),
  BioPlant_B1(Zone.BioPlant),
  BioPlant_B2(Zone.BioPlant),
  BioPlant_B2_Part2(Zone.BioPlant),
  BioPlant_B3(Zone.BioPlant),
  BioPlant_B3_Part2(Zone.BioPlant),
  BioPlant_B4(Zone.BioPlant),
  BioPlant_B4_Part2(Zone.BioPlant),
  BioPlant_B4_Part3(Zone.BioPlant),

  // Return to Piata...

  Nalya(Zone.Nalya),
  NalyaHouse1(Zone.Nalya),
  NalyaHouse2(Zone.Nalya),
  NalyaItemShop(Zone.Nalya),
  NalyaHouse3(Zone.Nalya),
  NalyaHouse4(Zone.Nalya),
  NalyaHouse5(Zone.Nalya),
  NalyaInn(Zone.Nalya),
  NalyaInn_F1(Zone.Nalya),

  Wreckage(Zone.Wreckage),
  Wreckage_Part2(Zone.Wreckage),
  Wreckage_Part3(Zone.Wreckage),
  Wreckage_F1(Zone.Wreckage),
  Wreckage_F1_Part2(Zone.Wreckage),
  Wreckage_F2(Zone.Wreckage),
  Wreckage_F2_Part2(Zone.Wreckage),
  Wreckage_F2_Part3(Zone.Wreckage),
  Wreckage_F2_Part4(Zone.Wreckage),

  Aiedo(Zone.Aiedo),
  ShayHouse(Zone.Aiedo),
  //ChazHouse(Area.Aiedo),
  AiedoBakery(Zone.Aiedo),
  AiedoBakery_B1(Zone.Aiedo),
  AiedoWeaponShop(Zone.Aiedo),
  AiedoPrison(Zone.Aiedo),
  AiedoHouse1(Zone.Aiedo),
  AiedoHouse2(Zone.Aiedo),
  AiedoHouse3(Zone.Aiedo),
  AiedoHouse4(Zone.Aiedo),
  AiedoHouse5(Zone.Aiedo),
  AiedoHouse6(Zone.Aiedo),
  AiedoHouse7(Zone.Aiedo),
  RockyHouse(Zone.Aiedo),
  AiedoSupermarket(Zone.Aiedo),
  AiedoPub(Zone.Aiedo),
  HuntersGuild(Zone.Aiedo),
  HuntersGuildStorage(Zone.Aiedo),
  StripClub(Zone.Aiedo),
  StripClubDressingRoom(Zone.Aiedo),

  PassagewayNearAiedo(Zone.Passageway),
  Passageway(Zone.Passageway),
  PassagewayNearKadary(Zone.Passageway),

  Kadary(Zone.Kadary),
  KadaryChurch(Zone.Kadary),
  KadaryPub(Zone.Kadary),
  KadaryPub_F1(Zone.Kadary),
  KadaryStorageRoom(Zone.Kadary),
  KadaryHouse1(Zone.Kadary),
  KadaryHouse2(Zone.Kadary),
  KadaryHouse3(Zone.Kadary),
  KadaryItemShop(Zone.Kadary),
  KadaryInn(Zone.Kadary),
  KadaryInn_F1(Zone.Kadary),

  ZioFort(Zone.ZioFort),
  ZioFort_Part2(Zone.ZioFort),
  ZioFort_F1(Zone.ZioFort),
  ZioFort_F2East(Zone.ZioFort),
  ZioFort_F2West(Zone.ZioFort),
  ZioFortEastTunnel(Zone.ZioFort),
  ZioFortWestTunnel(Zone.ZioFort),
  ZioFortJuzaRoom(Zone.ZioFort),
  ZioFort_F3(Zone.ZioFort),
  ZioFort_F4(Zone.ZioFort),

  // Return to Krup
  MachineCenter(Zone.MachineCenter),
  MachineCenter_B1(Zone.MachineCenter),
  MachineCenter_B1_Part2(Zone.MachineCenter),

  MonsenCave(Zone.Monsen),
  Monsen(Zone.Monsen),
  MonsenInn(Zone.Monsen),
  MonsenHouse1(Zone.Monsen),
  MonsenHouse2(Zone.Monsen),
  MonsenHouse3(Zone.Monsen),
  MonsenHouse4(Zone.Monsen),
  MonsenHouse5(Zone.Monsen),
  MonsenItemShop(Zone.Monsen),

  PlateSystem(Zone.PlateSystem),
  PlateSystem_F1(Zone.PlateSystem),
  PlateSystem_F2(Zone.PlateSystem),
  PlateSystem_F3(Zone.PlateSystem),
  PlateSystem_F4(Zone.PlateSystem),

  Termi(Zone.Termi),
  TermiHouse1(Zone.Termi),
  TermiHouse2(Zone.Termi),
  TermiItemShop(Zone.Termi),
  TermiWeaponShop(Zone.Termi),
  TermiInn(Zone.Termi),

  LadeaTower(Zone.LadeaTower),
  LadeaTower_F1(Zone.LadeaTower),
  LadeaTower_F2(Zone.LadeaTower),
  LadeaTower_F3(Zone.LadeaTower),
  LadeaTower_F4(Zone.LadeaTower),
  LadeaTower_F5(Zone.LadeaTower),

  Nurvus(Zone.Nurvus),
  Nurvus_Part2(Zone.Nurvus),
  Nurvus_Part3(Zone.Nurvus),
  Nurvus_B1(Zone.Nurvus),
  Nurvus_B1Tunnel(Zone.Nurvus),
  Nurvus_B2(Zone.Nurvus),
  Nurvus_B3(Zone.Nurvus),
  Nurvus_B3Tunnel(Zone.Nurvus),
  Nurvus_B4(Zone.Nurvus),
  Nurvus_B4_Part2(Zone.Nurvus),
  Nurvus_B5(Zone.Nurvus),

  MotaSpaceport(Zone.MotaviaSpaceport),

  ZelanSpace(Zone.Zelan),
  Zelan(Zone.Zelan),
  Zelan_F1(Zone.Zelan),

  RajaTemple(Zone.RajaTemple),

  Ryuon(Zone.Ryuon),
  RyuonItemShop(Zone.Ryuon),
  RyuonWeaponShop(Zone.Ryuon),
  RyuonHouse1(Zone.Ryuon),
  RyuonHouse2(Zone.Ryuon),
  RyuonHouse3(Zone.Ryuon),
  RyuonPub(Zone.Ryuon),
  RyuonInn(Zone.Ryuon),

  // Tyler
  Tyler(Zone.Tyler),
  TylerHouse1(Zone.Tyler),
  TylerWeaponShop(Zone.Tyler),
  TylerItemShop(Zone.Tyler),
  TylerHouse2(Zone.Tyler),
  TylerInn(Zone.Tyler),
  Hangar(Zone.Tyler),

  // Kuran
  KuranSpace(Zone.Kuran),
  Kuran(Zone.Kuran),
  Kuran_F1(Zone.Kuran),
  Kuran_F1_Part2(Zone.Kuran),
  Kuran_F1_Part3(Zone.Kuran),
  Kuran_F1_Part4(Zone.Kuran),
  Kuran_F1_Part5(Zone.Kuran),
  Kuran_F2(Zone.Kuran),
  Kuran_F2_Part2(Zone.Kuran),
  Kuran_F3(Zone.Kuran),

  // Return to Zelan

  // Zosa
  Zosa(Zone.Zosa),
  ZosaHouse1(Zone.Zosa),
  ZosaHouse2(Zone.Zosa),
  ZosaWeaponShop(Zone.Zosa),
  ZosaItemShop(Zone.Zosa),
  ZosaInn(Zone.Zosa),
  ZosaHouse3(Zone.Zosa),

  // Myst Value
  MystVale(Zone.MystVale),
  MystVale_Part2(Zone.MystVale),
  MystVale_Part3(Zone.MystVale),
  MystVale_Part4(Zone.MystVale),
  MystVale_Part5(Zone.MystVale),

  // Climate Center
  ClimCenter(Zone.ClimateCenter),
  ClimCenter_F1(Zone.ClimateCenter),
  ClimCenter_F2(Zone.ClimateCenter),
  ClimCenter_F3(Zone.ClimateCenter),

  // Reshel
  Reshel1(Zone.Reshel),
  Reshel2(Zone.Reshel),
  Reshel3(Zone.Reshel),
  Reshel2House(Zone.Reshel),
  Reshel2WeaponShop(Zone.Reshel),
  Reshel3House1(Zone.Reshel),
  Reshel3ItemShop(Zone.Reshel),
  Reshel3House2(Zone.Reshel),
  Reshel3WeaponShop(Zone.Reshel),
  Reshel3Inn(Zone.Reshel),
  Reshel3House3(Zone.Reshel),

  // Jut
  Jut(Zone.Jut),
  JutHouse1(Zone.Jut),
  JutHouse2(Zone.Jut),
  JutHouse3(Zone.Jut),
  JutHouse4(Zone.Jut),
  JutHouse5(Zone.Jut),
  JutWeaponShop(Zone.Jut),
  JutItemShop(Zone.Jut),
  JutHouse6(Zone.Jut),
  JutHouse6_F1(Zone.Jut),
  JutHouse7(Zone.Jut),
  JutHouse8(Zone.Jut),
  JutInn(Zone.Jut),
  JutChurch(Zone.Jut),

  // Weapon plant
  WeaponPlant(Zone.WeaponPlant),
  WeaponPlant_F1(Zone.WeaponPlant),
  WeaponPlant_F2(Zone.WeaponPlant),
  WeaponPlant_F3(Zone.WeaponPlant),

  // Meese
  Meese(Zone.Meese),
  MeeseHouse1(Zone.Meese),
  MeeseItemShop2(Zone.Meese),
  MeeseItemShop1(Zone.Meese),
  MeeseWeaponShop(Zone.Meese),
  MeeseInn(Zone.Meese),
  MeeseClinic(Zone.Meese),
  MeeseClinic_F1(Zone.Meese),

  // Carnivorous forest

  // Esper mansion
  EspMansionEntrance(Zone.EsperMansion),
  EspMansion(Zone.EsperMansion),
  EspMansionWestRoom(Zone.EsperMansion),
  EspMansionEastRoom(Zone.EsperMansion),
  EspMansionNorth(Zone.EsperMansion),
  EspMansionNorthEastRoom(Zone.EsperMansion),
  EspMansionNorthWestRoom(Zone.EsperMansion),
  EspMansionCourtyard(Zone.EsperMansion),
  InnerSanctuary(Zone.EsperMansion),
  InnerSanctuary_B1(Zone.EsperMansion),

  // Gumbious temple
  GumbiousEntrance(Zone.GumbiousTemple),
  Gumbious(Zone.GumbiousTemple),
  Gumbious_F1(Zone.GumbiousTemple),
  Gumbious_B1(Zone.GumbiousTemple),
  Gumbious_B2(Zone.GumbiousTemple),
  Gumbious_B2_Part2(Zone.GumbiousTemple),

  // Tyler spaceport
  DezoSpaceport(Zone.TylerSpaceport),

  // Air castle
  AirCastleSpace(Zone.AirCastle),
  AirCastle(Zone.AirCastle),
  AirCastle_Part2(Zone.AirCastle),
  AirCastle_Part3(Zone.AirCastle),
  AirCastle_Part4(Zone.AirCastle),
  AirCastle_Part5(Zone.AirCastle),
  AirCastle_Part6(Zone.AirCastle),
  AirCastle_Part7(Zone.AirCastle),
  AirCastle_Part8(Zone.AirCastle),
  AirCastle_F1(Zone.AirCastle),
  AirCastle_F1_Part2(Zone.AirCastle),
  AirCastle_F1_Part3(Zone.AirCastle),
  AirCastle_F1_Part4(Zone.AirCastle),
  AirCastle_F1_Part9(Zone.AirCastle),
  AirCastle_F1_Part5(Zone.AirCastle),
  AirCastle_F1_Part10(Zone.AirCastle),
  AirCastle_F1_Part11(Zone.AirCastle),
  AirCastle_F1_Part12(Zone.AirCastle),
  AirCastle_F1_Part13(Zone.AirCastle),
  AirCastle_F2(Zone.AirCastle),
  AirCastleXeAThoulRoom(Zone.AirCastle),
  AirCastleInner(Zone.AirCastle),
  AirCastleInner_B1(Zone.AirCastle),
  AirCastleInner_B1_Part2(Zone.AirCastle),
  AirCastleInner_B1_Part3(Zone.AirCastle),
  AirCastleInner_B2(Zone.AirCastle),
  AirCastleInner_B3(Zone.AirCastle),
  AirCastleInner_B4(Zone.AirCastle),
  AirCastleInner_B5(Zone.AirCastle),

  // Guaron tower
  GaruberkTower(Zone.GuaronTower),
  GaruberkTower_Part2(Zone.GuaronTower),
  GaruberkTower_Part3(Zone.GuaronTower),
  GaruberkTower_Part4(Zone.GuaronTower),
  GaruberkTower_Part5(Zone.GuaronTower),
  GaruberkTower_Part6(Zone.GuaronTower),
  GaruberkTower_Part7(Zone.GuaronTower),

  // Torinco
  Torinco(Zone.Torinco),
  CulversHouse(Zone.Torinco),
  TorincoHouse1(Zone.Torinco),
  TorincoHouse2(Zone.Torinco),
  TorincoItemShop(Zone.Torinco),
  TorincoInn(Zone.Torinco),

  // Uzo
  Uzo(Zone.Uzo),
  UzoHouse1(Zone.Uzo),
  UzoHouse2(Zone.Uzo),
  UzoInn(Zone.Uzo),
  UzoHouse3(Zone.Uzo),
  UzoItemShop(Zone.Uzo),

  // Vahal Fort
  VahalFort(Zone.VahalFort),
  VahalFort_F1(Zone.VahalFort),
  VahalFort_F2(Zone.VahalFort),
  VahalFort_F3(Zone.VahalFort),

  RappyCave(Zone.RappyCave),

  // Soldier's Shrine
  SoldiersTempleOutside(Zone.SoldiersShrine),
  SoldiersTemple(Zone.SoldiersShrine),
  IslandCave(Zone.SoldiersShrine),
  IslandCave_F1(Zone.SoldiersShrine),
  IslandCave_F1_Part2(Zone.SoldiersShrine),
  IslandCave_Part2(Zone.SoldiersShrine),
  IslandCave_B1(Zone.SoldiersShrine),
  IslandCave_F2(Zone.SoldiersShrine),
  IslandCave_F3(Zone.SoldiersShrine),

  // Courage
  CourageTower(Zone.TowerOfCourage),
  CourageTower_F1(Zone.TowerOfCourage),
  CourageTower_F2(Zone.TowerOfCourage),
  CourageTower_F3(Zone.TowerOfCourage),
  CourageTower_F4(Zone.TowerOfCourage),

  // Grace
  StrengthTower(Zone.TowerOfStrength),
  StrengthTower_F1(Zone.TowerOfStrength),
  StrengthTower_F2(Zone.TowerOfStrength),
  StrengthTower_F3(Zone.TowerOfStrength),
  StrengthTower_F4(Zone.TowerOfStrength),

  // Wrath
  AngerTower(Zone.TowerOfAnger),
  AngerTower_F1(Zone.TowerOfAnger),
  AngerTower_F2(Zone.TowerOfAnger),

  // Sacellum
  SilenceTm(Zone.SacellumOfQuietude),
  LeRoofRoom(Zone.SacellumOfQuietude),

  // Elysdeon
  ElsydeonCave(Zone.ElsydeonCave),
  ElsydeonCave_B1(Zone.ElsydeonCave),

  MileDead(Zone.Mile),

  TheEdge(Zone.TheEdge),
  TheEdge_Part2(Zone.TheEdge),
  TheEdge_Part3(Zone.TheEdge),
  TheEdge_Part4(Zone.TheEdge),
  TheEdge_Part5(Zone.TheEdge),
  TheEdge_Part6(Zone.TheEdge),
  TheEdge_Part7(Zone.TheEdge),
  TheEdge_Part8(Zone.TheEdge),
  TheEdge_Part9(Zone.TheEdge);

  final Zone zone;
  World get world => zone.world;

  const MapId(this.zone);
}

sealed class MapElement {}

sealed class InteractiveMapElement implements MapElement, Interactive {}

class MapArea extends MapElement {
  factory MapArea(
      {required MapAreaId id,
      required Position at,
      required AreaRange range,
      required AreaSpec spec}) {
    if (spec is InteractiveAreaSpec) {
      return InteractiveMapArea._(id: id, at: at, range: range, spec: spec);
    } else {
      return MapArea._(id: id, at: at, range: range, spec: spec);
    }
  }

  MapArea._(
      {required this.id,
      required Position at,
      required this.range,
      required this.spec})
      : position = at;

  final MapAreaId id;
  final Position position;
  final AreaRange range;
  final AreaSpec spec;

  Scene get onInteract {
    if (isInteractive) {
      return (spec as Interactive).onInteract;
    }
    return Scene.none();
  }

  bool get isInteractive => spec is Interactive;

  @override
  String toString() {
    return 'MapArea{id: $id, position: $position, range: $range, spec: $spec}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapArea &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          position == other.position &&
          range == other.range &&
          spec == other.spec;

  @override
  int get hashCode =>
      id.hashCode ^ position.hashCode ^ range.hashCode ^ spec.hashCode;
}

class InteractiveMapArea extends MapArea implements InteractiveMapElement {
  InteractiveMapArea._(
      {required super.id,
      required super.at,
      required super.range,
      required InteractiveAreaSpec spec})
      : super._(spec: spec);

  @override
  InteractiveAreaSpec get spec => super.spec as InteractiveAreaSpec;

  @override
  set onInteract(Scene onInteract) => spec.onInteract = onInteract;
}

class MapAreaId extends MapElementId {
  final String value;

  MapAreaId(this.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapAreaId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

enum AreaRange {
  x10y20, // 0xC
  x10y60, // 0xA
  x20y10, // 9
  x20y20, // 2
  x40y10, // 0xE
  x40y20, // 0xB
  x60y10, // 0xD
  x40y40, // 1
  xyExact, // 3
  xLower, // 4
  xHigher, // 5
  yLower, // 6
  yHigher, // 7
  xyLowerAndYLessOrEqualTo_Y_0x2A0, // 8
}

abstract class AreaSpec {}

class InteractiveAreaSpec extends AreaSpec with Interactive {
  // other flag types are modelable in ASM
  // however they are never used with interaction types we care about.
  // hence this is here and not in the MapArea model
  /// Interactions may be conditional on whether [doNotInteractIf] is set.
  ///
  /// If set, the interaction won't take place.
  final EventFlag? doNotInteractIf;

  InteractiveAreaSpec(
      {this.doNotInteractIf, Scene onInteract = const Scene.none()}) {
    this.onInteract = onInteract;
  }

  @override
  String toString() {
    return 'InteractiveArea{doNotInteractIf: $doNotInteractIf, '
        'onInteract: $onInteract}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InteractiveAreaSpec &&
          runtimeType == other.runtimeType &&
          doNotInteractIf == other.doNotInteractIf &&
          onInteract == other.onInteract;

  @override
  int get hashCode => doNotInteractIf.hashCode ^ onInteract.hashCode;
}

class AsmArea extends AreaSpec {
  final Byte eventType;
  final Byte eventFlag;
  final Byte interactionRoutine;
  final Sized interactionParameter;

  AsmArea(
      {required this.eventType,
      required this.eventFlag,
      required this.interactionRoutine,
      required this.interactionParameter});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsmArea &&
          runtimeType == other.runtimeType &&
          eventType == other.eventType &&
          eventFlag == other.eventFlag &&
          interactionRoutine == other.interactionRoutine &&
          interactionParameter == other.interactionParameter;

  @override
  int get hashCode =>
      eventType.hashCode ^
      eventFlag.hashCode ^
      interactionRoutine.hashCode ^
      interactionParameter.hashCode;

  @override
  String toString() {
    return 'AsmArea{eventType: $eventType, '
        'eventFlag: $eventFlag, '
        'interactionRoutine: $interactionRoutine, '
        'interactionParameter: $interactionParameter}';
  }
}

// todo: 'with UnnamedSpeaker' – aren't some objects named speakers?
class MapObject extends FieldObject implements MapElement, UnnamedSpeaker {
  final MapObjectId id;
  // note: can only be in multiples of 8 pixels
  final Position startPosition;
  final MapObjectSpec spec;

  @override
  final name = const UnnamedSpeaker().name;

  @override
  final portrait = null;

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

  factory MapObject(
      {String? id,
      required Position startPosition,
      required MapObjectSpec spec,
      // todo: maybe use event list instead of Scene model?
      // issue is modifying scene w/ onInteractFacePlayer
      // –it's a misleading API
      // -> or maybe get rid of onInteractFacePlayer now that
      // it is not necessary to use reference to object itself
      @Deprecated("use spec") Scene onInteract = const Scene.none(),
      bool onInteractFacePlayer = true}) {
    if (spec is InteractiveMapObjectSpec) {
      return InteractiveMapObject._(
          id: id,
          startPosition: startPosition,
          spec: spec,
          onInteract: onInteract,
          onInteractFacePlayer: onInteractFacePlayer);
    }
    return MapObject._(
        id: id,
        startPosition: startPosition,
        spec: spec,
        onInteract: onInteract,
        onInteractFacePlayer: onInteractFacePlayer);
  }

  MapObject._(
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

class InteractiveMapObject extends MapObject implements InteractiveMapElement {
  @override
  InteractiveMapObjectSpec get spec => super.spec as InteractiveMapObjectSpec;

  InteractiveMapObject._(
      {super.id,
      required super.startPosition,
      required InteractiveMapObjectSpec spec,
      // todo: maybe use event list instead of Scene model?
      // issue is modifying scene w/ onInteractFacePlayer
      // –it's a misleading API
      // -> or maybe get rid of onInteractFacePlayer now that
      // it is not necessary to use reference to object itself
      super.onInteract = const Scene.none(),
      super.onInteractFacePlayer = true})
      : super._(spec: spec);
}

/// Constructs an object which doesn't do anything, but does collide.
MapObject placeholderMapObject(int index) {
  return MapObject(
      id: 'placeholder_$index',
      startPosition: Position(0, 0),
      spec: InvisibleBlock());
}

final _random = Random();

sealed class MapElementId {}

class MapObjectId extends MapElementId {
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

abstract mixin class Interactive {
  Scene onInteract = Scene.none();
}

abstract class InteractiveMapObjectSpec extends MapObjectSpec
    with Interactive {}

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

class InteractiveNpc extends Npc implements InteractiveMapObjectSpec {
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

class AlysWaiting extends InteractiveMapObjectSpec {
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
class AiedoShopperWithBags extends InteractiveMapObjectSpec {
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
class AiedoShopperMom extends InteractiveMapObjectSpec {
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

class InvisibleBlock extends InteractiveMapObjectSpec {
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

class InteractiveAsmSpec extends AsmSpec
    with Interactive
    implements InteractiveMapObjectSpec {
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
