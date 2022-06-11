import 'dart:collection';
import 'dart:math';

import 'model.dart';

// generator will need to track a vram tile number offset to start storing art
// pointers
// note that many events refer to map objects address in memory, which means
// ordering must be maintained for existing objects unless we find and edit
// those addresses.
class GameMap {
  final MapId id;

  // limited to 64 objects in ram currently
  final _objects = <MapObject>[];

  GameMap(this.id);

  List<MapObject> get objects => UnmodifiableListView(_objects);

  //final onMove = <Event>[];

  void addObject(MapObject obj) {
    _objects.add(obj);
  }
}

enum MapId { aiedo, piata, piataAcademyF1, piataAcademyPrincipalOffice }

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

class MapObjectId {
  final String id;

  MapObjectId(this.id);

  MapObjectId.random() : id = _randomId();

  static String _randomId() {
    return Random().nextInt(2 ^ 32).toRadixString(25);
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
