import 'dart:collection';
import 'dart:core';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/check.dart';
import 'package:quiver/collection.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/conditional.dart';
import 'package:rune/model/cutscenes.dart';
import 'package:rune/model/text.dart';

import '../src/iterables.dart';
import 'dialog.dart';
import 'map.dart';
import 'movement.dart';
import 'sound.dart';
import 'events.dart';

export 'cutscenes.dart';
export 'dialog.dart';
export 'map.dart';
export 'movement.dart';
export 'sound.dart';
export 'events.dart';

class Game {
  // todo: should also include non-interaction Scenes?
  // see DocsParser

  final _maps =
      SplayTreeMap<MapId, GameMap>((a, b) => a.index.compareTo(b.index));

  List<GameMap> get maps => _maps.values.toList(growable: false);

  /// Returns the [Game] split into subsets based on what objects in the game
  /// share the same [Scene].
  ///
  /// The resulting map keys (scenes) are sorted by [MapId] of the first object
  /// referring to that scene.
  Map<Scene, Game> byInteraction() {
    // todo: return type might be misleading
    // a scene should probably not be reused across object
    // which span multiple maps.
    // technically possible?
    // but probably doesn't make much sense?
    // well it could i guess depending on what's in the scene.
    // let's keep this and roll with it.

    var interactions = Map<Scene, Game>.identity();

    for (var map in _maps.values) {
      map.orderedObjects.forEachIndexed((i, obj) {
        var maps = interactions.putIfAbsent(obj.onInteract, () => Game());
        var objects = maps.getOrStartMap(map.id);
        // keep original index in new maps
        objects.addObject(obj, at: i);
      });
    }

    return interactions;
  }

  GameMap getOrStartMap(MapId id) {
    return _maps.putIfAbsent(id, () => GameMap(id));
  }

  int countObjects() =>
      _maps.values.map((e) => e.orderedObjects.length).reduce(sum);

  void addMap(GameMap map) => _maps[map.id] = map;

  void addMaps(Iterable<GameMap> maps) => maps.forEach(addMap);
}

// todo: use sealed type once supported in dart
abstract class Event {
  const Event();

  @Deprecated('does not fit all events')
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    throw UnimplementedError('generateAsm');
  }

  void visit(EventVisitor visitor);
}

class ModelException implements Exception {
  final dynamic message;

  ModelException([this.message]);

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "ModelException";
    return "ModelException: $message";
  }
}

abstract class EventVisitor {
  void asm(AsmEvent asm);
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
  void loadMap(LoadMap changeMap);
  void playSound(PlaySound playSound);
  void playMusic(PlayMusic playMusic);
  void stopMusic(StopMusic stopMusic);
  void addMoney(AddMoney addMoney);
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

  Speaker? dialogPortrait;

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

  void forEach(Function(FieldObject obj, Position pos) func) {
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
  final List<Event> events;

  Scene([Iterable<Event> events = const []]) : events = [] {
    this.events.addAll(events);
  }

  Scene.forNpcInteraction([Iterable<Event> events = const []])
      : this([InteractionObject.facePlayer(), ...events]);

  const Scene.none() : events = const [];

  // note:
  // because these return new scenes, they kind of break the memory model if
  // we are treating the identity of a scene as the instance itself in memory
  // that is, we may actually want to modify the same scene, but are instead
  // producing a new one.

  Scene startingWith(Iterable<Event> events) {
    return Scene([...events, ...this.events]);
  }

  Scene unlessSet(EventFlag flag, {required List<Event> then}) {
    return Scene([IfFlag(flag, isSet: then, isUnset: events)]);
  }

  /// Returns [true] if the scene has no game-state-changing events.
  bool get isEmpty => events
      .whereNot((e) => e is SetContext || _isIfFlagWithEmptyBranches(e))
      .isEmpty;
  bool get isNotEmpty => !isEmpty;

  // see TODO on SetContext
  // have to hack around it
  Scene withoutSetContext() {
    return Scene(events
        .whereNot((e) => e is SetContext)
        .map((e) => e is IfFlag ? e.withoutSetContextInBranches() : e));
  }

  void addEvent(Event event) {
    events.add(event);
  }

  void addEvents(Iterable<Event> events) {
    this.events.addAll(events);
  }

  @override
  String toString() {
    return 'Scene{events: $events}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Scene &&
          runtimeType == other.runtimeType &&
          const ListEquality<Event>().equals(events, other.events);

  @override
  int get hashCode => const ListEquality<Event>().hash(events);
}

bool _isIfFlagWithEmptyBranches(Event e) {
  if (e is! IfFlag) return false;
  return Scene(e.isSet).isEmpty & Scene(e.isUnset).isEmpty;
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
  int? slot(EventState c) => c.slotFor(this);
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
const saya = Saya();
const holt = Holt();

class Alys extends Character {
  const Alys();

  @override
  final name = 'Alys';

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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Seth && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Saya extends Character {
  const Saya();
  @override
  final name = 'Saya';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Saya && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}

class Holt extends Character {
  const Holt();
  @override
  final name = 'Holt';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Holt && runtimeType == other.runtimeType;
  @override
  int get hashCode => name.hashCode;
}
