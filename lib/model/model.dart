import 'dart:collection';
import 'dart:core';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/check.dart';
import 'package:quiver/collection.dart';

import '../generator/generator.dart';
import '../src/iterables.dart';
import 'conditional.dart';
import 'cutscenes.dart';
import 'dialog.dart';
import 'events.dart';
import 'map.dart';
import 'movement.dart';
import 'sound.dart';
import 'text.dart';

export 'conditional.dart';
export 'cutscenes.dart';
export 'dialog.dart';
export 'events.dart';
export 'map.dart';
export 'movement.dart';
export 'sound.dart';

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
        // Get the game subset for this interaction
        var gameSubset = interactions.putIfAbsent(obj.onInteract, () => Game());
        var mapSubset = gameSubset.getOrStartMap(map.id);
        // keep original index in new maps
        mapSubset.addObject(obj, at: i);
      });

      for (var area in map.areas) {
        var gameSubset =
            interactions.putIfAbsent(area.onInteract, () => Game());
        var mapSubset = gameSubset.getOrStartMap(map.id);
        // todo: if map has any objects, error?
        // to start at least we won't support objects sharing scenes with areas
        mapSubset.addArea(area);
      }
    }

    return interactions;
  }

  GameMap? getMap(MapId id) {
    return _maps[id];
  }

  GameMap getOrStartMap(MapId id) {
    return _maps.putIfAbsent(id, () => GameMap(id));
  }

  int countObjects() =>
      _maps.values.map((e) => e.orderedObjects.length).reduce(sum);

  void addMap(GameMap map) => _maps[map.id] = map;

  void addMaps(Iterable<GameMap> maps) => maps.forEach(addMap);

  @override
  String toString() {
    return 'Game{maps: ${_maps.values}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Game &&
          runtimeType == other.runtimeType &&
          const MapEquality<MapId, GameMap>().equals(_maps, other._maps);

  @override
  int get hashCode => const MapEquality<MapId, GameMap>().hash(_maps);

  Scene interactionForElements(Iterable<FindsGameElement> elements) {
    Scene? scene;
    for (var id in elements) {
      var element = id.findInGame(this);
      if (element == null) {
        throw ArgumentError.value(id, 'elements', 'not found in game');
      }
      if (element is InteractiveMapElement) {
        if (scene == null) {
          scene = element.onInteract;
        } else if (!identical(scene, element.onInteract)) {
          throw ArgumentError.value(
              element, 'elements', 'must all share the same scene');
        }
      } else {
        throw ArgumentError.value(
            element, 'elements', 'must be InteractiveMapElement');
      }
    }
    if (scene == null) {
      throw ArgumentError.value(elements, 'elements', 'must not be empty');
    }
    return scene;
  }
}

abstract class FindsGameElement {
  MapElement? findInGame(Game game);
}

// todo: use sealed type once supported in dart
// it might remove need for visitor pattern?
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

  Portrait? dialogPortrait;

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

class Scene extends IterableBase<Event> {
  final List<Event> _events;
  List<Event> get events => List.unmodifiable(_events);

  Scene([Iterable<Event> events = const []]) : _events = [] {
    addEvents(events);
  }

  Scene.forNpcInteraction([Iterable<Event> events = const []])
      : this([InteractionObject.facePlayer(), ...events]);

  const Scene.none() : _events = const [];

  // note:
  // because these return new scenes, they kind of break the memory model if
  // we are treating the identity of a scene as the instance itself in memory
  // that is, we may actually want to modify the same scene, but are instead
  // producing a new one.

  Scene startingWith(Iterable<Event> events) {
    return Scene([...events, ..._events]);
  }

  Scene unlessSet(EventFlag flag, {required List<Event> then}) {
    return Scene([IfFlag(flag, isSet: then, isUnset: _events)]);
  }

  @override
  Iterator<Event> get iterator => _events.iterator;

  /// Returns [true] if the scene has no game-state-changing events.
  bool get isEffectivelyEmpty => _events
      .whereNot((e) => e is SetContext || _isIfFlagWithEmptyBranches(e))
      .isEmpty;
  bool get isEffectivelyNotEmpty => !isEffectivelyEmpty;

  // see TODO on SetContext
  // have to hack around it
  Scene withoutSetContext() {
    return Scene(_events
        .whereNot((e) => e is SetContext)
        .map((e) => e is IfFlag ? e.withoutSetContextInBranches() : e));
  }

  Set<EventFlag> flagsSet() {
    return _events.whereType<SetFlag>().map((e) => e.flag).toSet();
  }

  bool setsFlag(EventFlag flag) {
    return _events.any((e) => e is SetFlag && e.flag == flag);
  }

  void addEvent(Event event) {
    _addEvent(_events, event);
  }

  void addEvents(Iterable<Event> events) {
    events.forEach(addEvent);
  }

  void addEventToBranches(Event event, Condition condition) {
    _addEventToBranches(_events, event, Condition.empty(), condition);
  }

  /// Find the first branch, including top-level,
  /// that satisfies the [matching] Condition.
  /// Add [event] to that branch.
  /// If the branch is not top-level,
  /// the corresponding [IfFlag] event will be replaced.
  ///
  /// See [Condition.isSatisfiedBy].
  bool _addEventToBranches(
      List<Event> events, Event event, Condition current, Condition matching) {
    if (matching.isSatisfiedBy(current)) {
      _addEvent(events, event);
      return true;
    }

    var added = false;

    for (int i = 0; i < events.length; i++) {
      var e = events[i];
      if (e is IfFlag) {
        var replace = false;
        // Check set branch
        var ifSet = current.withSet(e.flag);
        var isSetBranch = [...e.isSet];
        var isUnsetBranch = [...e.isUnset];

        if (!ifSet.conflictsWith(matching)) {
          replace = _addEventToBranches(isSetBranch, event, ifSet, matching);
        }

        var ifUnset = current.withNotSet(e.flag);
        if (!ifUnset.conflictsWith(matching)) {
          replace =
              _addEventToBranches(isUnsetBranch, event, ifUnset, matching);
        }

        if (replace) {
          added = true;
          events[i] =
              IfFlag(e.flag, isSet: isSetBranch, isUnset: isUnsetBranch);
        }
      }
    }

    return added;
  }

  /// Adds a conditional [branch] to the scene.
  ///
  /// The `branch` is played instead of the current scene if the [whenSet] flag
  /// is set. If the flag is not set, the current scene is played.
  ///
  /// If [createSequence] is `true`, `whenSet` will be set with the current
  /// scene, thus creating a sequence if the scene is played again.
  ///
  /// Advancing to the next branch in sequence can be controlled however
  /// by setting the [advanceSequenceWhenSet] flag. If provided, advancing the
  /// sequence will be conditional on the `createSequenceWhenSet` flag.
  void addBranch(Iterable<Event> branch,
      {required EventFlag whenSet,
      bool createSequence = false,
      EventFlag? advanceSequenceWhenSet,
      Condition? asOf}) {
    /*
    is asOf is set
    we need to find the corresponding branch
    however instead of just adding an event to that branch
    we need to fork it based on [whenSet],
    where the branch becomes the isUnset of a new IfFlag at that point
     */

    if (createSequence) {
      if (advanceSequenceWhenSet == null) {
        addEvent(SetFlag(whenSet));
      } else {
        addEvent(IfFlag(advanceSequenceWhenSet, isSet: [SetFlag(whenSet)]));
      }
    }

    var withBranch = <Event>[];
    _addEvent(withBranch, IfFlag(whenSet, isSet: branch, isUnset: _events));
    _events.replaceRange(0, _events.length, withBranch);
  }

  void _addEvent(List<Event> events, Event event) {
    var last = events.lastOrNull;
    // todo: should IfFlag branches just be Scenes? would simplify this class
    // todo: i started to use Scenes to set up branches;
    //  but im not sure what that simplifies here?
    if (last is IfFlag && event is IfFlag && last.flag == event.flag) {
      // normalize conditionals
      events.removeLast();
      var isSet = [...last.isSet];
      var isUnset = [...last.isUnset];
      for (var e in event.isSet) {
        _addEvent(isSet, e);
      }
      for (var e in event.isUnset) {
        _addEvent(isUnset, e);
      }
      events.add(IfFlag(last.flag, isSet: isSet, isUnset: isUnset));
    } else if (events.isNotEmpty && event == InteractionObject.facePlayer()) {
      // special case, must retain this first when normalizing
      // todo: consider changing how some events work
      // face player, set flag, set context - these are not perceptible
      // set context is still a little different,
      // since order changes semantics
      // however face player must always be first
      // and set flag doesn't matter where it is in a branch
      // so those are more properties of branches, than events per se
      // or we can consider handling in generator
      // for now we are sort of treating it as a property of the scene by
      // virtue of this reording logic
      events.insert(0, event);
    } else if (event is SetFlag) {
      // Is this flag already set? If so, we can skip this event.
      if (events.any((e) => e is SetFlag && e.flag == event.flag)) {
        return;
      }

      // This reordering results in an optimization.
      // Setting the flag shouldn't matter where it is.
      // But if we do it last, we have to generate in event code.
      if (events.firstOrNull == InteractionObject.facePlayer()) {
        events.insert(1, event);
      } else {
        events.insert(0, event);
      }
    } else {
      events.add(event);
    }
  }

  @override
  String toString() {
    return 'Scene{events: $_events}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Scene &&
          runtimeType == other.runtimeType &&
          const ListEquality<Event>().equals(_events, other._events);

  @override
  int get hashCode => const ListEquality<Event>().hash(_events);
}

bool _isIfFlagWithEmptyBranches(Event e) {
  if (e is! IfFlag) return false;
  return Scene(e.isSet).isEffectivelyEmpty &
      Scene(e.isUnset).isEffectivelyEmpty;
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

sealed class Character extends FieldObject with Speaker {
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
