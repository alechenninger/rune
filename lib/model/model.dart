import 'dart:collection';
import 'dart:core';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:quiver/check.dart';
import 'package:quiver/collection.dart';
import 'package:rune/model/battle.dart';

import '../generator/generator.dart';
import '../src/iterables.dart';
import 'animate.dart';
import 'camera.dart';
import 'palette.dart';
import 'guild.dart';
import 'behavior.dart';
import 'conditional.dart';
import 'cutscenes.dart';
import 'dialog.dart';
import 'events.dart';
import 'expressions.dart';
import 'map.dart';
import 'movement.dart';
import 'objects.dart';
import 'party.dart';
import 'sound.dart';
import 'text.dart';

export 'animate.dart';
export 'battle.dart';
export 'camera.dart';
export 'behavior.dart';
export 'conditional.dart';
export 'cutscenes.dart';
export 'dialog.dart';
export 'events.dart';
export 'expressions.dart';
export 'palette.dart';
export 'map.dart';
export 'movement.dart';
export 'objects.dart';
export 'party.dart';
export 'sound.dart';
export 'text.dart';
export 'guild.dart';
export 'item.dart';

class Game {
  // todo: should also include non-interaction Scenes?
  // see DocsParser

  final _maps =
      SplayTreeMap<MapId, GameMap>((a, b) => a.index.compareTo(b.index));

  List<GameMap> get maps => _maps.values.toList(growable: false);

  final HuntersGuildInteractions huntersGuild = HuntersGuildInteractions();

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
        map.asmEvents.forEach(mapSubset.addAsmEvent);
      });

      for (var area in map.areas) {
        var gameSubset =
            interactions.putIfAbsent(area.onInteract, () => Game());
        var mapSubset = gameSubset.getOrStartMap(map.id);
        // todo: if map has any objects, error?
        // to start at least we won't support objects sharing scenes with areas
        mapSubset.addArea(area);
        map.asmEvents.forEach(mapSubset.addAsmEvent);
      }
    }

    return interactions;
  }

  // TODO(interaction elements): may want to move this to be per-map
  //  rather thangame-level
  MapElement? interaction(InteractionId id) {
    // Right now, the only event interactions
    // are modeled by the HuntersGuild.
    // If there are others in the future,
    // handle in this method.
    return huntersGuild.interactionById(id);
  }

  bool containsMap(MapId id) {
    return _maps.containsKey(id);
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

/// Events should never be mutated once included in a Scene.
abstract class Event {
  const Event();

  @Deprecated('does not fit all events')
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    throw UnimplementedError('generateAsm');
  }

  // Use visitor instead of sealed types,
  // so that types need not all be in the same library.
  void visit(EventVisitor visitor);
}

abstract interface class RunnableInDialog extends Event {
  /// If [state] not provided, assumes state is compatible with running the
  /// event in dialog.
  bool canRunInDialog([EventState? state]);
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
  void dialogCodes(DialogCodes dialogCodes);
  void dialog(Dialog dialog);
  void displayText(DisplayText text);
  void facePlayer(FacePlayer face);
  void overlapCharacters(OverlapCharacters overlap);
  void individualMoves(IndividualMoves moves);
  void absoluteMoves(AbsoluteMoves moves);
  void waitForMovements(WaitForMovements wait);
  void instantMoves(InstantMoves moves);
  void stepObject(StepObject step);
  void stepObjects(StepObjects step);
  void lockCamera(LockCamera lock);
  void unlockCamera(UnlockCamera unlock);
  void moveCamera(MoveCamera move);
  void partyMove(RelativePartyMove move);
  void pause(Pause pause);
  void setContext(SetContext set);
  void ifFlag(IfFlag ifFlag);
  void setFlag(SetFlag setFlag);
  void ifValue(IfValue ifValue);
  void yesOrNoChoice(YesOrNoChoice choice);
  void showPanel(ShowPanel showPanel);
  void hideTopPanels(HideTopPanels hidePanels);
  void hideAllPanels(HideAllPanels hidePanels);
  void fadeOut(FadeOut fadeOut);
  void fadeInField(FadeInField fadeIn);
  void increaseTone(IncreaseTone increase);
  void flashScreen(FlashScreen flash);
  void prepareMap(PrepareMap prepareMap);
  void loadMap(LoadMap changeMap);
  void playSound(PlaySound playSound);
  void playMusic(PlayMusic playMusic);
  void stopMusic(StopMusic stopMusic);
  void addMoney(AddMoney addMoney);
  void resetObjectRoutine(ResetObjectRoutine resetRoutine);
  void changeObjectRoutine(ChangeObjectRoutine change);
  void changeParty(ChangePartyOrder changeParty);
  void restoreSavedParty(RestoreSavedPartyOrder restoreParty);
  void onExitRunBattle(OnExitRunBattle setExit);
  void onNextInteraction(OnNextInteraction onNext);
}

class EventState {
  EventState() : slots = Slots._() {
    _positions = Positions._(this);
  }

  EventState._branch(EventState from) : slots = from.slots.branch() {
    _positions = Positions._(this);
    positions.addAll(from.positions);
    startingAxis = from.startingAxis;
    followLead = from.followLead;
    cameraLock = from.cameraLock;
    isFieldShown = from.isFieldShown;
    onExitRunBattle = from.onExitRunBattle;
    dialogPortrait = from.dialogPortrait;
    keepDialog = from.keepDialog;
    currentMap = from.currentMap;
    stepSpeed = from.stepSpeed;
    dialogTriggered = from.dialogTriggered;
    panelsShown = from.panelsShown;
    _facing.addAll(from._facing);
    _routines.addAll(from._routines);
  }

  EventState branch() {
    return EventState._branch(this);
  }

  late final Positions _positions;
  Positions get positions => _positions;

  /// Character field objects by slot. 1-indexed (zero is invalid).
  final Slots slots;

  Axis? startingAxis = Axis.x;

  /// Whether or not to follow character at slot[0]
  bool? followLead = true;

  bool? cameraLock = false;

  bool? isFieldShown = true;

  bool? onExitRunBattle = false;

  Portrait? dialogPortrait = Portrait.none;

  /// Whether or not dialog windows are kept during event loop.
  bool? keepDialog = false;

  GameMap? currentMap;

  StepSpeed? stepSpeed = StepSpeed.fast;

  Iterable<Character> get possibleCharacters {
    // TODO: correct this based on story state
    return Character.allCharacters;
  }

  bool? dialogTriggered = false;

  int? panelsShown = 0;
  void addPanel() {
    if (panelsShown != null) panelsShown = panelsShown! + 1;
  }

  void removePanels([int n = 1]) {
    if (panelsShown != null) panelsShown = panelsShown! - n;
  }

  final _facing = <FieldObject, Direction>{};
  DirectionExpression? getFacing(FieldObject obj) => _facing[obj.resolve(this)];
  void setFacing(FieldObject obj, Direction dir) {
    for (var obj in obj.knownObjects(this)) {
      _facing[obj] = dir;
    }

    for (var obj in obj.unknownObjects(this)) {
      _facing.remove(obj);
    }
  }

  void clearFacing(FieldObject obj) {
    for (var obj in obj.knownObjects(this)) {
      _facing.remove(obj);
    }
    for (var obj in obj.unknownObjects(this)) {
      _facing.remove(obj);
    }
  }

  /// 1-indexed (first slot is 1, there is no slot 0).
  int? slotFor(Character c) => slots.slotFor(c);

  /// 1-indexed (first slot is 1, there is no slot 0).
  void setSlot(int slot, Character c) {
    slots[slot] = c;
  }

  /// 1-indexed (first slot is 1, there is no slot 0).
  void clearSlot(int slot) => slots[slot] = null;

  /// FIXME: this is not reliable
  int get numCharacters => slots.numCharacters;

  void addCharacter(Character c,
      {int? slot, Position? position, Direction? facing}) {
    if (slot != null) {
      slots[slot] = c;
    }
    if (position != null) positions[c] = position;
    if (facing != null) _facing[c] = facing;
  }

  final _routines = <FieldObject, SpecModel>{};
  SpecModel? getRoutine(FieldObject obj) => _routines[obj.resolve(this)];
  void setRoutine(FieldObject obj, SpecModel? r) {
    var update = r == null
        ? (obj) => _routines.remove(obj)
        : (obj) => _routines[obj] = r;

    for (var obj in obj.knownObjects(this)) {
      update(obj);
    }

    for (var obj in obj.unknownObjects(this)) {
      _routines.remove(obj);
    }
  }

  void resetRoutines() {
    _routines.clear();
  }

  @override
  String toString() {
    return 'EventState{'
        'slots: $slots, '
        'startingAxis: $startingAxis, '
        'followLead: $followLead, '
        'cameraLock: $cameraLock, '
        'isFieldShown: $isFieldShown, '
        'onExitRunBattle: $onExitRunBattle, '
        'dialogPortrait: $dialogPortrait, '
        'keepDialog: $keepDialog, '
        'currentMap: ${currentMap?.id}, '
        'stepSpeed: $stepSpeed, '
        'panelsShown: $panelsShown, '
        'facing: $_facing, '
        'positions: ${positions._positions}, '
        'routines: $_routines'
        '}';
  }
}

class Positions {
  final EventState _ctx;
  final _positions = <FieldObject, Position>{};

  Positions._(this._ctx);

  void clear() {
    _positions.clear();
  }

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
    var update = p == null
        ? (obj) => _positions.remove(obj)
        : (obj) => _positions[obj] = p;

    for (var obj in obj.knownObjects(_ctx)) {
      update(obj);
    }

    for (var obj in obj.unknownObjects(_ctx)) {
      _positions.remove(obj);
    }
  }
}

class Slots {
  /// Party order (not necessarily the same as field objects).
  final _party = BiMap<int, Character>();
  IMap<int, Character>? _priorParty;
  bool get partyOrderMaintained => _partyOrderMaintained;
  bool _partyOrderMaintained = false;

  static const all = [1, 2, 3, 4, 5];

  Slots._();

  Slots branch() {
    var newSlots = Slots._();
    newSlots._party.addAll(_party);
    newSlots._priorParty = _priorParty;
    newSlots._partyOrderMaintained = _partyOrderMaintained;
    return newSlots;
  }

  void addAll(Slots slots) {
    _party.addAll(slots._party);
  }

  void forEach(Function(int, Character) func) {
    _party.forEach(func);
  }

  /// 1-indexed (first slot is 1, there is no slot 0).
  Character? operator [](int slot) => _party[slot];

  Character? party(int slot) => _party[slot];

  void setPartyOrder(List<Character?> party,
      {bool saveCurrent = false, bool maintainOrder = false}) {
    if (saveCurrent) {
      _priorParty = _party.toIMap();
    }

    _party.clear();
    _partyOrderMaintained = maintainOrder;

    for (var i = 0; i < party.length; i++) {
      var member = party[i];
      if (member == null) continue;
      _party[i + 1] = member;
    }
  }

  void restorePreviousParty(
      [Function(int index, Character? prior, Character? current)? onRestore]) {
    // This previously only iterated if priorParty was set,
    // but has been altered to fire callbacks in case
    // we need to restore, but the prior party is not known.
    // This can happen, e.g., if a prior scene saves the party,
    // and the next scene immediately follows.
    for (var i = 1; i <= 5; i++) {
      var prior = _priorParty?[i];
      var current = _party[i];
      onRestore?.call(i, prior, current);
      if (prior == null) {
        _party.remove(i);
      } else {
        _party.inverse.remove(prior);
        _party[i] = prior;
      }
    }
    _priorParty = null;
  }

  /// 1-indexed (first slot is 1, there is no slot 0).
  void operator []=(int slot, Character? c) {
    if (c == null) {
      _party.remove(slot);
    } else {
      _party[slot] = c;
    }
  }

  /// 1-indexed (first slot is 1, there is no slot 0).
  int? slotFor(Character c) => _party.inverse[c];

  int get numCharacters => _party.keys.reduce(max);

  void unknownPartyOrder() {
    _party.clear();
  }

  void unknownPriorPartyOrder() {
    _priorParty = null;
  }

  bool hasPartyOrder(Map<int, Character?> order) {
    for (var MapEntry(key: slot, value: character) in order.entries) {
      if (_party[slot] != character) return false;
    }
    return true;
  }

  bool priorSameAsCurrent() {
    if (_priorParty == null) return false;
    if (_priorParty!.length != _party.length) return false;
    return const MapEquality<int, Character>()
        .equals(_priorParty!.unlockView, _party);
  }

  @override
  String toString() {
    return 'Slots{party: $_party, priorParty: $_priorParty, partyOrderMaintained: $_partyOrderMaintained}';
  }
}

class Scene extends IterableBase<Event> {
  final List<Event> _events;

  Scene([Iterable<Event> events = const []]) : _events = [] {
    addEvents(events);
  }

  Scene.forNpcInteraction([Iterable<Event> events = const []])
      : this([InteractionObject.facePlayer(), ...events]);

  const Scene.none() : _events = const [];

  Scene.empty() : _events = [];

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

  List<Event> get events => List.unmodifiable(this);

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
    return Scene(
        _events.whereNot((e) => e is SetContext).map((e) => switch (e) {
              IfFlag e => e.withoutSetContextInBranches(),
              OnNextInteraction e => e.withoutSetContext(),
              _ => e,
            }));
  }

  /// Returns a new Scene representing the state of this Scene
  /// as of the given [Condition].
  ///
  /// Unreachable branches are pruned.
  ///
  /// To modify the scene in place, use [assume].
  Scene asOf(Condition asOf) {
    return Scene(_asOf(_events, asOf, Condition.empty()));
  }

  Scene copy() {
    return Scene([..._events]);
  }

  /// Advances the scene in place by assuming the given [condition].
  ///
  /// Branches which conflict with the condition are pruned.
  void assume(Condition condition) {
    // Copy to avoid concurrent modification
    var asOf =
        _asOf(_events, condition, Condition.empty()).toList(growable: false);
    _events.clear();
    _events.addAll(asOf);
  }

  Iterable<Event> _asOf(
      Iterable<Event> events, Condition asOf, Condition current) sync* {
    for (var event in events) {
      if (event is IfFlag) {
        var knownVal = asOf[event.flag];
        if (knownVal == true) {
          // We know this is set, so just yield the set branch
          yield* _asOf(event.isSet, asOf, current);
        } else if (knownVal == false) {
          // We know this is not set, so just yield the unset branch
          yield* _asOf(event.isUnset, asOf, current);
        } else {
          // We don't know if this is set or not,
          // so go through each branch
          yield IfFlag(event.flag,
              isSet: _asOf(event.isSet, asOf, current.withSet(event.flag)),
              isUnset:
                  _asOf(event.isUnset, asOf, current.withNotSet(event.flag)));
        }
      } else {
        yield event;
      }
    }
  }

  /// Returns flags which are set unconditionally anywhere in this scene.
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
    _visitBranch(_events, (branch) => _addEvent(branch, event),
        Condition.empty(), condition);
  }

  void addEventsToBranches(Iterable<Event> events, Condition condition) {
    _visitBranch(_events, (branch) {
      for (var e in events) {
        _addEvent(branch, e);
      }
    }, Condition.empty(), condition);
  }

  void replaceBranch(Iterable<Event> events, Condition condition) {
    _visitBranch(_events, (branch) {
      branch.clear();
      branch.addAll(events);
    }, Condition.empty(), condition);
  }

  bool hasBranchOn(EventFlag flag) {
    bool findBranch(List<Event> events) {
      for (var e in events) {
        if (e is IfFlag) {
          if (e.flag == flag) return true;
          if (findBranch(e.isSet)) return true;
          if (findBranch(e.isUnset)) return true;
        }
      }
      return false;
    }

    return findBranch(_events);
  }

  Iterable<Branch> branches() sync* {
    yield* _branches(_events, Condition.empty());
  }

  Iterable<Branch> _branches(Iterable<Event> events, Condition current) sync* {
    IfEvent? conditional;
    for (var event in events) {
      switch (event) {
        case IfEvent e when conditional == null:
          // If we have not yet found a conditional event, set it.
          conditional = e;
          break;
        case SetContext():
          continue;
        default:
          // There is something other than just a single conditional event,
          // so yield this branch and end.
          // We do not recurse further in this case: only return "leaf" branches.
          yield Branch(current, events: events);
          return;
      }
    }

    // There was a single conditional event.
    // In this case, recurse into each of its branches.
    switch (conditional) {
      case IfFlag e:
        yield* _branches(e.isSet, current.withSet(e.flag));
        yield* _branches(e.isUnset, current.withNotSet(e.flag));
      case IfValue e:
        for (var branch in e.branches) {
          yield* _branches(branch.events,
              current.withBranch((e.operand1, e.operand2), branch.comparison));
        }
      case null:
        return;
    }
  }

  /// Recurses through all branches and hastens the scene by...
  ///
  /// - Removing pauses
  /// - Replacing dialog with [dialogTo] (but maintaining panels)
  ///
  /// Further alterations to the scene may be added in the future.
  ///
  /// The intent is to speed up the scene
  /// while keeping meaningful state changes.
  void fastForward({required Span dialogTo, int? upTo}) {
    List<Event> condenseRecursively(List<Event> events) {
      for (var i = 0; i < events.length; i++) {
        var e = events[i];

        switch (e) {
          case Pause _:
            events.removeAt(i);
            i--;
            break;

          case Dialog d:
            var spans = <DialogSpan>[..._justEvents(d)];
            var j = i + 1;

            loop:
            for (; j < events.length; j++) {
              switch (events[j]) {
                case Pause _:
                  events.removeAt(j);
                  j--;
                  break;
                case Dialog d:
                  spans.addAll(_justEvents(d));
                  break;
                default:
                  break loop;
              }
            }

            events.replaceRange(i, j, [
              Dialog(
                spans: [
                  DialogSpan.fromSpan(dialogTo,
                      events: spans.firstOrNull?.events ?? []),
                  ...spans.skip(1)
                ],
              )
            ]);
            break;

          case IfFlag e:
            var isSet = [...e.isSet];
            var isUnset = [...e.isUnset];
            condenseRecursively(isSet);
            condenseRecursively(isUnset);
            events[i] = IfFlag(e.flag, isSet: isSet, isUnset: isUnset);
            break;

          case IfValue e:
            var branches = {
              for (var b in e.branches)
                b.comparison: condenseRecursively([...b.events])
            };
            events[i] = IfValue(
              e.operand1,
              comparedTo: e.operand2,
              equal: branches[Comparison.eq] ?? [],
              greater: branches[Comparison.gt] ?? [],
              less: branches[Comparison.lt] ?? [],
              greaterOrEqual: branches[Comparison.gte] ?? [],
              lessOrEqual: branches[Comparison.lte] ?? [],
              notEqual: branches[Comparison.neq] ?? [],
            );
        }
      }

      return events;
    }

    if (upTo == null) {
      condenseRecursively(_events);
    } else {
      var events = _events.sublist(0, upTo);
      condenseRecursively(events);
      _events.replaceRange(0, upTo, events);
    }
  }

  /// Visits the [events] list with the provided [visitor] if
  /// the [current] condition is satisfied by the [matching] condition.
  ///
  /// Recurses through conditional checks within `events`
  /// to find a matching branch.
  /// Once a matching branch is found, it is visited with the [visitor], and
  /// that event list is no longer recursed.
  ///
  /// The `events` may be mutated by the visitor in order to modify the branch.
  /// If the branch is not top-level (`events`),
  /// the corresponding [IfFlag] event will be replaced.
  ///
  /// Returns `true` if any branches were visited.
  ///
  /// See [Condition.isSatisfiedBy].
  bool _visitBranch(List<Event> events, Function(List<Event> events) visitor,
      Condition current, Condition matching) {
    if (matching.isSatisfiedBy(current)) {
      visitor(events);
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
          replace = _visitBranch(isSetBranch, visitor, ifSet, matching);
        }

        var ifUnset = current.withNotSet(e.flag);
        if (!ifUnset.conflictsWith(matching)) {
          replace = _visitBranch(isUnsetBranch, visitor, ifUnset, matching);
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
  /// Advancing to the next branch in sequence can be conditional, however,
  /// by setting the [advanceSequenceWhenSet] flag. If provided, advancing the
  /// sequence will only happen when the `advanceSequenceWhenSet` flag is set.
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
    if (asOf == null) {
      _addBranch(_events, branch,
          whenSet: whenSet,
          createSequence: createSequence,
          advanceSequenceWhenSet: advanceSequenceWhenSet);
    } else {
      _visitBranch(_events, (events) {
        _addBranch(events, branch,
            whenSet: whenSet,
            createSequence: createSequence,
            advanceSequenceWhenSet: advanceSequenceWhenSet);
      }, Condition.empty(), asOf);
    }
  }

  void _addBranch(List<Event> events, Iterable<Event> branch,
      {required EventFlag whenSet,
      bool createSequence = false,
      EventFlag? advanceSequenceWhenSet}) {
    if (createSequence) {
      if (advanceSequenceWhenSet == null) {
        _addEvent(events, SetFlag(whenSet));
      } else {
        _addEvent(
            events, IfFlag(advanceSequenceWhenSet, isSet: [SetFlag(whenSet)]));
      }
    }

    var withBranch = <Event>[];
    _addEvent(withBranch, IfFlag(whenSet, isSet: branch, isUnset: events));
    events.replaceRange(0, events.length, withBranch);
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
      // and set 'anytime' flag doesn't matter where it is in a branch
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

      if (event.anyTime) {
        // This reordering results in an optimization.
        // Setting the 'anyTime' flag doesn't matter where it is.
        // But if we do it last, we have to generate in event code.
        if (events.firstOrNull == InteractionObject.facePlayer()) {
          events.insert(1, event);
        } else {
          events.insert(0, event);
        }
      } else {
        events.add(event);
      }
    } else {
      events.add(event);
    }
  }

  @override
  String toString() {
    return 'Scene{\n${toIndentedString(_events, '      ')}\n}';
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

extension CollapseDialog on List<Event> {
  /// Remove all [Dialog] text and pauses.
  /// Each consecutive block of dialog will be replaced with the text in [to].
  /// Any panels will be consolidated as spans in a single [Dialog] event.
  void collapseDialog({required Span to}) {
    for (var i = 0; i < length; i++) {
      var e = this[i];

      if (e is! Dialog) continue;

      var spans = <DialogSpan>[..._justEvents(e)];
      var j = i + 1;

      for (; j < length; j++) {
        e = this[j];
        if (e is! Dialog) break;
        spans.addAll(_justEvents(e));
      }

      replaceRange(i, j, [
        Dialog(
          spans: [
            DialogSpan.fromSpan(to, panel: spans.firstOrNull?.panel),
            ...spans.skip(1)
          ],
        )
      ]);
    }
  }
}

extension WithoutSetContext on List<Event> {
  Iterable<Event> withoutSetContext() {
    return whereNot((e) => e is SetContext).map((e) => switch (e) {
          IfFlag e => e.withoutSetContextInBranches(),
          OnNextInteraction e => e.withoutSetContext(),
          _ => e,
        });
  }
}

Iterable<DialogSpan> _justEvents(Dialog d) {
  var events = d.spans.expand((s) => s.events).whereNot((e) => e is Pause);
  return events.isEmpty ? [] : [DialogSpan('', events: events)];
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
