import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/collection.dart';
import 'package:rune/generator/generator.dart';

import 'map.dart';
import 'movement.dart';

export 'dialog.dart';
export 'movement.dart';
export 'map.dart';

abstract class Event {
  // TODO: should probably not have this here? creates dependency on generator
  // from model
  Asm generateAsm(AsmGenerator generator, EventContext ctx);
}

class EventContext {
  late final Positions positions;
  final facing = <FieldObject, Direction>{};

  /// 1-indexed (first is 1; 0 is invalid)
  final slots = BiMap<int, Character>();
  var startingAxis = Axis.x;

  /// Whether or not to follow character at slot[0]
  var followLead = true;

  bool cameraLock = false;

  GameMap? currentMap;

  EventContext() {
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
  final EventContext _ctx;
  final _positions = <FieldObject, Position>{};

  Positions._(this._ctx);

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
  final List<Event> events = [];

  Scene([List<Event> events = const []]) {
    this.events.addAll(events);
  }

  void addEvent(Event event) {
    events.add(event);
  }
}

class AggregateEvent extends Event {
  final List<Event> events = [];

  AggregateEvent(List<Event> events) {
    if (events.isEmpty) {
      throw ArgumentError('empty events', 'events');
    }

    this.events.addAll(events);
  }

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    if (events.isEmpty) {
      return Asm.empty();
    }

    return events
        .map((e) => e.generateAsm(generator, ctx))
        .reduce((value, element) {
      value.add(element);
      return value;
    });
  }

  @override
  String toString() {
    return 'AggregateEvent{events: $events}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AggregateEvent &&
          runtimeType == other.runtimeType &&
          ListEquality().equals(events, other.events);

  @override
  int get hashCode => ListEquality().hash(events);
}

class SetContext extends Event {
  final void Function(EventContext ctx) _setCtx;

  SetContext(this._setCtx);

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    _setCtx(ctx);
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

  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
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
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
    return generator.lockCameraToAsm(ctx);
  }

  @override
  String toString() {
    return 'LockCamera{}';
  }
}

class UnlockCamera extends Event {
  @override
  Asm generateAsm(AsmGenerator generator, EventContext ctx) {
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
  int slot(EventContext c) => index;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Slot && runtimeType == other.runtimeType && index == other.index;

  @override
  int get hashCode => index.hashCode;
}

abstract class Character extends FieldObject {
  const Character();

  /// throws if no character found by name.
  static Character? byName(String name) {
    switch (name.toLowerCase()) {
      case 'alys':
        return alys;
      case 'shay':
        return shay;
    }
    return null;
  }

  int? slot(EventContext c) => c.slotFor(this);
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
