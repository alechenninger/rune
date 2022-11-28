import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/check.dart';
import 'package:quiver/collection.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/conditional.dart';
import 'package:rune/model/cutscenes.dart';
import 'package:rune/model/text.dart';

import 'dialog.dart';
import 'map.dart';
import 'movement.dart';
import 'sound.dart';

export 'dialog.dart';
export 'movement.dart';
export 'map.dart';
export 'cutscenes.dart';
export 'sound.dart';

abstract class Event {
  const Event();

  @Deprecated('does not fit all events')
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    throw UnimplementedError('generateAsm');
  }

  void visit(EventVisitor visitor);
}

abstract class EventVisitor {
  void asm(Asm asm); // todo: ?
  void dialog(Dialog dialog);
  void displayText(DisplayText text);
  void facePlayer(FacePlayer face);
  void individualMoves(IndividualMoves moves);
  void lockCamera(LockCamera lock);
  void partyMove(PartyMove move);
  void pause(Pause pause);
  void setContext(SetContext set);
  void unlockCamera(UnlockCamera unlock);
  void ifFlag(IfFlag ifEvent);
  void setFlag(SetFlag setFlag);
  void showPanel(ShowPanel showPanel);
  void hideTopPanels(HideTopPanels hidePanels);
  void hideAllPanels(HideAllPanels hidePanels);
  void fadeOut(FadeOut fadeOut);
  void fadeInField(FadeInField fadeIn);
  void playSound(PlaySound playSound);
}

class EventState {
  final _facing = <FieldObject, Direction>{};

  late final Positions _positions;
  Positions get positions => _positions;

  /// 1-indexed (zero is invalid).
  final Slots slots = Slots._();

  Axis? startingAxis = Axis.x;

  /// Whether or not to follow character at slot[0]
  bool? followLead = true;

  bool? cameraLock = false;

  bool? isFieldShown = true;

  GameMap? currentMap;

  EventState() {
    _positions = Positions._(this);
  }

  EventState branch() {
    return EventState()
      .._facing.addAll(_facing)
      ..positions.addAll(positions)
      ..slots.addAll(slots)
      ..startingAxis = startingAxis
      ..followLead = followLead
      ..cameraLock = cameraLock
      ..currentMap = currentMap
      ..isFieldShown = isFieldShown
      ..panelsShown = panelsShown;
  }

  int? panelsShown = 0;
  void addPanel() {
    if (panelsShown != null) panelsShown = panelsShown! + 1;
  }

  void removePanels([int n = 1]) {
    if (panelsShown != null) panelsShown = panelsShown! - n;
  }

  Direction? getFacing(FieldObject obj) => _facing[obj];
  void setFacing(FieldObject obj, Direction dir) => _facing[obj] = dir;
  void clearFacing(FieldObject obj) => _facing.remove(obj);

  /// 1-indexed (first slot is 1, there is no slot 0).
  int? slotFor(Character c) => slots.slotFor(c);

  /// 1-indexed (first slot is 1, there is no slot 0).
  void setSlot(int slot, Character c) => slots[slot] = c;

  /// 1-indexed (first slot is 1, there is no slot 0).
  void clearSlot(int slot) => slots[slot] = null;

  int get numCharacters => slots.numCharacters;

  void addCharacter(Character c,
      {int? slot, Position? position, Direction? facing}) {
    if (slot != null) slots[slot] = c;
    if (position != null) positions[c] = position;
    if (facing != null) _facing[c] = facing;
  }
}

class Positions {
  final EventState _ctx;
  final _positions = <FieldObject, Position>{};

  Positions._(this._ctx);

  void addAll(Positions p) {
    _positions.addAll(p._positions);
  }

  void forEach(Function(FieldObject, Position) func) {
    _positions.forEach(func);
  }

  Position? operator [](FieldObject obj) {
    try {
      return _positions[obj.resolve(_ctx)];
    } on ResolveException {
      return null;
    }
  }

  void operator []=(FieldObject obj, Position? p) {
    obj = obj.resolve(_ctx);
    if (p == null) {
      _positions.remove(obj);
    } else {
      _positions[obj] = p;
    }
  }
}

class Slots {
  /// 1-indexed (first is 1; 0 is invalid)
  final _slots = BiMap<int, Character>();

  Slots._();

  void addAll(Slots slots) {
    _slots.addAll(slots._slots);
  }

  void forEach(Function(int, Character) func) {
    _slots.forEach(func);
  }

  /// 1-indexed (first slot is 1, there is no slot 0).
  Character? operator [](int slot) => _slots[slot];

  /// 1-indexed (first slot is 1, there is no slot 0).
  void operator []=(int slot, Character? c) {
    if (c == null) {
      _slots.remove(slot);
    } else {
      _slots[slot] = c;
    }
  }

  /// 1-indexed (first slot is 1, there is no slot 0).
  int? slotFor(Character c) => _slots.inverse[c];

  int get numCharacters => _slots.keys.reduce(max);
}

class Scene {
  @Deprecated('unused')
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

  Scene unlessSet(EventFlag flag, {required List<Event> then}) {
    return Scene([IfFlag(flag, isSet: then, isUnset: events)]);
  }

  void addEvent(Event event) {
    events.add(event);
  }

  void addEvents(Iterable<Event> events) {
    this.events.addAll(events);
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SceneId && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SetContext extends Event {
  final void Function(EventState ctx) _setCtx;

  SetContext(this._setCtx);

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    _setCtx(ctx.state);
    return Asm.empty();
  }

  void call(EventState state) {
    _setCtx(state);
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.setContext(this);
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
    return Dialog(spans: [DialogSpan("", pause: duration)]);
  }

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.pauseToAsm(this);
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.pause(this);
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
  void visit(EventVisitor visitor) {
    visitor.lockCamera(this);
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
  void visit(EventVisitor visitor) {
    visitor.unlockCamera(this);
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
  Character resolve(EventState state) {
    var inSlot = state.slots[index];
    if (inSlot == null) {
      throw ResolveException('no character in slot $index');
    }
    return inSlot;
  }

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

  @override
  int? slot(EventState c) => c.slotFor(this);
}

const alys = Alys();
const shay = Shay();

class Alys extends Character {
  const Alys();
  @override
  String toString() => 'Alys';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Alys && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

class Shay extends Character {
  const Shay();
  @override
  String toString() => 'Shay';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shay && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

class Hahn extends Character {
  const Hahn();
  @override
  String toString() => 'Hahn';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hahn && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}

class Rune extends Character {
  const Rune();
  @override
  String toString() => 'Rune';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rune && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}

class Gryz extends Character {
  const Gryz();
  @override
  String toString() => 'Gryz';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Gryz && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}

class Rika extends Character {
  const Rika();
  @override
  String toString() => 'Rika';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rika && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}

class Demi extends Character {
  const Demi();
  @override
  String toString() => 'Demi';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Demi && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}

class Wren extends Character {
  const Wren();
  @override
  String toString() => 'Wren';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wren && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}

class Raja extends Character {
  const Raja();
  @override
  String toString() => 'Raja';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Raja && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}

class Kyra extends Character {
  const Kyra();
  @override
  String toString() => 'Kyra';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Kyra && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}

class Seth extends Character {
  const Seth();
  @override
  String toString() => 'Seth';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Seth && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}

class Saya extends Character {
  const Saya();
  @override
  String toString() => 'Saya';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Saya && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}

class Holt extends Character {
  const Holt();
  @override
  String toString() => 'Holt';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Holt && runtimeType == other.runtimeType;
  @override
  int get hashCode => 0;
}
