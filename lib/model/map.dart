import 'model.dart';

// generator will need to track a vram tile number offset to start storing art
// pointers
// note that many events refer to map objects address in memory, which means
// ordering must be maintained for existing objects unless we find and edit
// those addresses.
abstract class GameMap {
  final objects = <MapObject>[];
  final onMove = <Event>[];

  void addObject(MapObject obj) {
    objects.add(obj);
  }
}

class Aiedo extends GameMap {}

class Piata extends GameMap {}

class MapObject extends FieldObject {
  // note: can only be in multiples of 8 pixels
  final Position startPosition;
  final List<Event> onInteract;
  final MapObjectSpec spec;

  MapObject(
      {required this.startPosition,
      required this.spec,
      List<Event> onInteract = const []})
      : onInteract = List.unmodifiable(onInteract);

  @override
  int? slot(EventContext c) => null;
}

// generator will need to track labels corresponding to each sprite
abstract class Sprite {
  const Sprite();

  static const palmanMan1 = PalmanMan1();
  static const palmanMan2 = PalmanMan2();
  static const palmanMan3 = PalmanMan3();
  static const palmanOldMan1 = PalmanOldMan1();
  static const palmanFighter1 = PalmanFighter1();
  static const palmanFighter2 = PalmanFighter2();
  static const palmanFighter3 = PalmanFighter3();
  static const palmanWoman1 = PalmanWoman1();
  static const palmanWoman2 = PalmanWoman2();
  static const palmanWoman3 = PalmanWoman3();
}

class PalmanMan1 extends Sprite {
  const PalmanMan1();
}

class PalmanMan2 extends Sprite {
  const PalmanMan2();
}

class PalmanMan3 extends Sprite {
  const PalmanMan3();
}

class PalmanOldMan1 extends Sprite {
  const PalmanOldMan1();
}

class PalmanFighter1 extends Sprite {
  const PalmanFighter1();
}

class PalmanFighter2 extends Sprite {
  const PalmanFighter2();
}

class PalmanFighter3 extends Sprite {
  const PalmanFighter3();
}

class PalmanWoman1 extends Sprite {
  const PalmanWoman1();
}

class PalmanWoman2 extends Sprite {
  const PalmanWoman2();
}

class PalmanWoman3 extends Sprite {
  const PalmanWoman3();
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
  const AlysWaiting() : super.constant();

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
}
