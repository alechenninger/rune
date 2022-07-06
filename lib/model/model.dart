import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/check.dart';
import 'package:quiver/collection.dart';
import 'package:rune/generator/generator.dart';

import 'dialog.dart';
import 'map.dart';
import 'movement.dart';

export 'dialog.dart';
export 'movement.dart';
export 'map.dart';

abstract class Event {
  // TODO: should probably not have this here? creates dependency on generator
  // from model
  Asm generateAsm(AsmGenerator generator, AsmContext ctx);
}

class EventState {
  late final Positions positions;
  final facing = <FieldObject, Direction>{};

  /// 1-indexed (first is 1; 0 is invalid)
  final slots = BiMap<int, Character>();

  // TODO: might need allow this to be unknown
  var startingAxis = Axis.x;

  /// Whether or not to follow character at slot[0]
  // TODO: might need allow this to be unknown
  bool? followLead = true;

  // TODO: might need allow this to be unknown
  bool? cameraLock = false;

  GameMap? currentMap;

  EventState() {
    positions = Positions._(this);
  }

  int? slotFor(Character c) => slots.inverse[c];

  int get numCharacters => slots.keys.reduce(max);

  Position? positionOfSlot(int s) => positions[slots[s]];

  void addCharacter(Character c,
      {int? slot, Position? position, Direction? facing}) {
    if (slot != null) slots[slot] = c;
    if (position != null) positions[c] = position;
    if (facing != null) this.facing[c] = facing;
  }
}

class Positions {
  final EventState _ctx;
  final _positions = <FieldObject, Position>{};

  Positions._(this._ctx);

  void clear() {
    _positions.clear();
  }

  Position? operator [](FieldObject? m) {
    if (m is Slot) {
      var inSlot = _ctx.slots[m.index];
      if (inSlot == null) return null;
      m = inSlot;
    }

    return _positions[m];
  }

  void operator []=(FieldObject m, Position p) {
    if (m is Slot) {
      var inSlot = _ctx.slots[m.index];
      if (inSlot == null) {
        throw ArgumentError('no character in slot ${m.index}');
      }
      m = inSlot;
    }

    _positions[m] = p;
  }
}

class Scene {
  final String? name;
  final List<Event> events;

  Scene([List<Event> events = const [], this.name]) : events = [] {
    this.events.addAll(events);
  }

  Scene.forNpcInteractionWith(FieldObject npc, [List<Event> events = const []])
      : this([FacePlayer(npc), ...events]);

  const Scene.none({this.name}) : events = const [];

  Scene startingWith(List<Event> events) {
    return Scene([...events, ...this.events], name);
  }

  void addEvent(Event event) {
    events.add(event);
  }

  @override
  String toString() {
    return 'Scene{name: $name, events: $events}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Scene &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          const ListEquality<Event>().equals(events, other.events);

  @override
  int get hashCode => name.hashCode ^ const ListEquality<Event>().hash(events);
}

final onlyWordCharacters = RegExp(r'^\w+$');

class SceneId {
  final String id;

  SceneId(this.id) {
    checkArgument(onlyWordCharacters.hasMatch(id),
        message: 'id must match $onlyWordCharacters but got $id');
  }

  @override
  String toString() => id;
}

class SetContext extends Event {
  final void Function(EventState ctx) _setCtx;

  SetContext(this._setCtx);

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    _setCtx(ctx.state);
    return Asm.empty();
  }

  @override
  String toString() {
    // todo: detect if mirrors avail and output source?
    return 'SetContext{$_setCtx}';
  }
}

class Pause extends Event {
  final Duration duration;

  Pause(this.duration);

  Dialog inDialog() {
    return Dialog(spans: [Span("", pause: duration)]);
  }

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.pauseToAsm(this);
  }

  @override
  String toString() {
    return 'Pause{$duration}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pause &&
          runtimeType == other.runtimeType &&
          duration == other.duration;

  @override
  int get hashCode => duration.hashCode;
}

class LockCamera extends Event {
  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.lockCameraToAsm(ctx);
  }

  @override
  String toString() {
    return 'LockCamera{}';
  }
}

class UnlockCamera extends Event {
  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.unlockCameraToAsm(ctx);
  }

  @override
  String toString() {
    return 'UnlockCamera{}';
  }
}

class Slot extends FieldObject {
  final int index;

  Slot(this.index);

  @override
  String toString() {
    return 'Slot{$index}';
  }

  @override
  int slot(EventState c) => index;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Slot && runtimeType == other.runtimeType && index == other.index;

  @override
  int get hashCode => index.hashCode;
}

abstract class Character extends FieldObject with Speaker {
  const Character();

  static Character? byName(String name) {
    switch (name.toLowerCase()) {
      case 'alys':
        return alys;
      case 'shay':
        return shay;
    }
    return null;
  }

  int? slot(EventState c) => c.slotFor(this);
}

const alys = Alys();
const shay = Shay();

class Alys extends Character {
  const Alys();
  @override
  String toString() => 'Alys';
}

class Shay extends Character {
  const Shay();
  @override
  String toString() => 'Shay';
}
