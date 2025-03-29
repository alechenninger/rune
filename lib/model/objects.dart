import 'package:collection/collection.dart';

import '../asm/data.dart';
import 'model.dart';

class Party extends Moveable {
  const Party();

  RelativePartyMove move(RelativeMovement m) => RelativePartyMove(m);
  AbsoluteMoves moveTo(Position destination) => AbsoluteMoves()
    ..destinations[BySlot(1)] = destination
    ..followLeader = true;
}

sealed class Moveable {
  const Moveable();

  /// Throws [ResolveException] if cannot resolve.
  Moveable resolve(EventState state) => this;
}

class ResolveException implements Exception {
  final dynamic message;

  ResolveException([this.message]);

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "ResolveException";
    return "ResolveException: $message";
  }
}

sealed class FieldObject extends Moveable {
  const FieldObject();

  bool get isResolved => false;
  bool get isNotResolved => !isResolved;

  int compareTo(FieldObject other, EventState ctx) {
    var thisSlot = slotAsOf(ctx);
    var otherSlot = other.slotAsOf(ctx);

    if (thisSlot != null && otherSlot != null) {
      return thisSlot.compareTo(otherSlot);
    }

    return toString().compareTo(other.toString());
  }

  int? slotAsOf(EventState c);

  bool get isCharacter => false;
  bool get isNotCharacter => !isCharacter;

  // TODO(refactor): this api stinks; should not be on same type as "real" thing
  //   consider removing this or return null if we cannot resovle.
  @override
  FieldObject resolve(EventState state) => this;

  /// All `FieldObject` instances which we _know_ this refers to.
  ///
  /// Includes the reference object itself even if it is not resolved.
  /// Additionally includes the resolved object if known.
  /// That is, this only ever returns 1 or 2 objects.
  Iterable<FieldObject> knownObjects(EventState state) sync* {
    yield this;
    if (isNotResolved) {
      var obj = resolve(state);
      if (obj.isResolved) {
        yield obj;
      }
    }
  }

  /// All `FieldObject` instances which this _may_ refer to.
  ///
  /// Does not include objects we know it cannot refer to.
  ///
  /// Does not include the reference object itself if it is not resolved.
  Iterable<FieldObject> unknownObjects(EventState state);
}

abstract class ResolvedFieldObject extends FieldObject {
  const ResolvedFieldObject();
  @override
  bool get isResolved => true;
  @override
  Iterable<FieldObject> unknownObjects(EventState state) => const [];
  @override
  ResolvedFieldObject resolve(EventState state) => this;
}

class MapObjectById extends FieldObject {
  final MapObjectId id;

  MapObjectById(this.id);

  MapObjectById.of(String id) : id = MapObjectId(id);

  MapObject? inMap(GameMap map) => map.object(id);

  @override
  MapObject resolve(EventState state) {
    var map = state.currentMap;
    if (map == null) {
      throw ResolveException('got field obj in map, but map was null. '
          'this=$this');
    }
    var obj = inMap(map);
    if (obj == null) {
      throw ResolveException('got field obj in map, '
          'but <$this> is not in <$map>');
    }
    return obj;
  }

  @override
  Iterable<FieldObject> unknownObjects(EventState state) {
    var map = state.currentMap;
    if (map == null) {
      throw ResolveException('got field obj in map, but map was null. '
          'this=$this');
    }
    // Either it resolves to a known object or fails.
    return const [];
  }

  @override
  int? slotAsOf(EventState c) => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapObjectById &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MapObjectById{$id}';
  }
}

/// Object being interacted with.
class InteractionObject extends FieldObject {
  const InteractionObject();

  static FacePlayer facePlayer() => FacePlayer(const InteractionObject());

  @override
  Iterable<FieldObject> unknownObjects(EventState state) sync* {
    var map = state.currentMap;
    if (map == null) {
      throw ResolveException('got field obj in map, but map was null. '
          'this=$this');
    }
    // All objects we might have interacted with.
    // TODO(interactions): we might want to save interacted object in event state
    // when it is known.
    // We also know to limit the objects by the scene they share.
    // So many times this can actually be known.
    for (var obj in map.objects) {
      if (obj.isInteractive) yield obj;
    }
  }

  @override
  int? slotAsOf(EventState c) => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InteractionObject && runtimeType == other.runtimeType;

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    return 'InteractionObject{}';
  }
}

class BySlot extends FieldObject {
  final int index;

  const BySlot(this.index);

  static const one = BySlot(1);
  static const two = BySlot(2);
  static const three = BySlot(3);
  static const four = BySlot(4);
  static const five = BySlot(5);
  static const all = [one, two, three, four, five];

  @override
  final isCharacter = true;

  @override
  FieldObject resolve(EventState state) {
    var inSlot = state.slots[index];
    if (inSlot == null) {
      return this;
    }
    return inSlot;
  }

  @override
  Iterable<FieldObject> unknownObjects(EventState state) sync* {
    // If this slot is not known
    if (state.slots[index] == null) {
      // Include all characters whose slot is not known
      for (var c in state.possibleCharacters) {
        if (state.slotFor(c) == null) {
          yield c;
        }
      }
    }
  }

  @override
  String toString() {
    return 'Slot{$index}';
  }

  @override
  int slotAsOf(EventState c) => index;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BySlot &&
          runtimeType == other.runtimeType &&
          index == other.index;

  @override
  int get hashCode => index.hashCode;
}

sealed class Character extends ResolvedFieldObject with Speaker {
  const Character();

  static Character? byName(String name) {
    switch (name.toLowerCase()) {
      case 'alys':
        return alys;
      case 'shay':
        return shay;
      case 'hahn':
        return hahn;
      case 'rune':
        return rune;
      case 'gryz':
        return gryz;
      case 'rika':
        return rika;
      case 'demi':
        return demi;
      case 'wren':
        return wren;
      case 'raja':
        return raja;
      case 'kyra':
        return kyra;
      case 'seth':
        return seth;
    }
    return null;
  }

  static final allCharacters = [
    alys,
    shay,
    hahn,
    rune,
    gryz,
    rika,
    demi,
    wren,
    raja,
    kyra,
    seth
  ];

  @override
  final isCharacter = true;

  @override
  int? slotAsOf(EventState c) => c.slotFor(this);

  @override
  Iterable<FieldObject> knownObjects(EventState state) sync* {
    yield this;
    if (state.slotFor(this) case var slot?) {
      yield BySlot(slot);
    }
  }

  @override
  Iterable<FieldObject> unknownObjects(EventState state) sync* {
    if (state.slotFor(this) == null) {
      // Include all slots which do not have a character
      for (var slot in Slots.all) {
        if (state.slots[slot] == null) {
          yield BySlot(slot);
        }
      }
    }
  }

  SlotOfCharacter slot() => SlotOfCharacter(this);
}

const alys = Alys();
const shay = Shay();
const hahn = Hahn();
const rune = Rune();
const gryz = Gryz();
const rika = Rika();
const demi = Demi();
const wren = Wren();
const raja = Raja();
const kyra = Kyra();
const seth = Seth();

class Alys extends Character {
  const Alys();
  @override
  final name = 'Alys';
  @override
  final portrait = Portrait.Alys;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Alys && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Shay extends Character {
  const Shay();
  @override
  final name = 'Shay';
  @override
  final portrait = Portrait.Shay;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shay && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Hahn extends Character {
  const Hahn();
  @override
  final name = 'Hahn';
  @override
  final portrait = Portrait.Hahn;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hahn && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Rune extends Character {
  const Rune();
  @override
  final name = 'Rune';
  @override
  final portrait = Portrait.Rune;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rune && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Gryz extends Character {
  const Gryz();
  @override
  final name = 'Gryz';
  @override
  final portrait = Portrait.Gryz;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Gryz && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Rika extends Character {
  const Rika();
  @override
  final name = 'Rika';
  @override
  final portrait = Portrait.Rika;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rika && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Demi extends Character {
  const Demi();
  @override
  final name = 'Demi';
  @override
  final portrait = Portrait.Demi;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Demi && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Wren extends Character {
  const Wren();
  @override
  final name = 'Wren';
  @override
  final portrait = Portrait.Wren;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wren && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Raja extends Character {
  const Raja();
  @override
  final name = 'Raja';
  @override
  final portrait = Portrait.Raja;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Raja && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Kyra extends Character {
  const Kyra();
  @override
  final name = 'Kyra';
  @override
  final portrait = Portrait.Kyra;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Kyra && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Seth extends Character {
  const Seth();
  @override
  final name = 'Seth';
  @override
  final portrait = Portrait.Seth;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Seth && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}
