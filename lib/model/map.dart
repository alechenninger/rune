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

  void addObject(MapObject obj) {
    if (_objects.containsKey(obj.id)) {
      throw ArgumentError('map already contains object with id: ${obj.id}');
    }
    _objects[obj.id] = obj;
  }
}

// ignore: constant_identifier_names
enum MapId { Aiedo, Piata, PiataAcademyF1, PiataAcademyPrincipalOffice }

class MapObject extends FieldObject {
  // note: can only be in multiples of 8 pixels
  final MapObjectId id;
  final Position startPosition;
  final MapObjectSpec spec;
  Scene onInteract;

  MapObject(
      {String? id,
      required this.startPosition,
      required this.spec,
      this.onInteract = const Scene.none()})
      : id = id == null ? MapObjectId.random() : MapObjectId(id);

  // todo: additive conditional on interact

  @override
  int? slot(EventState c) => null;
}

// generator will need to track labels corresponding to each sprite
enum Sprite {
  palmanMan1,
  palmanMan2,
  palmanMan3,
  palmanOldMan1,
  palmanFighter1,
  palmanFighter2,
  palmanFighter3,
  palmanWoman1,
  palmanWoman2,
  palmanWoman3,
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

abstract class MapObjectSpec {
  MapObjectSpec();

  const MapObjectSpec.constant();

  Direction get startFacing;
}

class Npc extends MapObjectSpec {
  final Sprite sprite;
  final NpcBehavior behavior;

  @override
  Direction get startFacing => behavior.startFacing;

  Npc(this.sprite, this.behavior);
}

class AlysWaiting extends MapObjectSpec {
  factory AlysWaiting() {
    return const AlysWaiting._();
  }
  const AlysWaiting._() : super.constant();

  @override
  final startFacing = Direction.down;
}

abstract class NpcBehavior {
  const NpcBehavior();

  Direction get startFacing;
}

class FacingDown extends NpcBehavior {
  const FacingDown();

  @override
  final startFacing = Direction.down;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FacingDown && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
