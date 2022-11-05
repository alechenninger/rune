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
  Aiedo,
  Piata,
  PiataAcademyF1,
  PiataAcademyPrincipalOffice,
  ShayHouse,
  Test
}

class MapObject extends FieldObject {
  final MapObjectId id;
  // note: can only be in multiples of 8 pixels
  final Position startPosition;
  final MapObjectSpec spec;
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

  // todo: additive conditional on interact

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

enum Sprite {
  PalmanMan1,
  PalmanMan2,
  PalmanMan3,
  PalmanOldMan1,
  PalmanFighter1,
  PalmanFighter2,
  PalmanFighter3,
  PalmanWoman1,
  PalmanWoman2,
  PalmanWoman3,
  PalmanStudent1,
  Kroft,

  /// Old professor.
  PalmanProfessor1,

  /// Old professor humped over with hands behind his back.
  PalmanProfessor2,
}

Sprite? spriteByName(String name) {
  name = name.trim().toLowerCase();
  for (var s in Sprite.values) {
    if (s.name.toLowerCase() == name) return s;
  }
  return null;
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
