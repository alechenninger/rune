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
import 'objects.dart';
import 'conditional.dart';
import 'cutscenes.dart';
import 'dialog.dart';
import 'events.dart';
import 'expressions.dart';
import 'map.dart';
import 'movement.dart';
import 'party.dart';
import 'sound.dart';
import 'text.dart';

export 'animate.dart';
export 'battle.dart';
export 'camera.dart';
export 'objects.dart';
export 'conditional.dart';
export 'cutscenes.dart';
export 'dialog.dart';
export 'events.dart';
export 'expressions.dart';
export 'palette.dart';
export 'map.dart';
export 'movement.dart';
export 'party.dart';
export 'sound.dart';
export 'text.dart';
export 'guild.dart';

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
      ..isFieldShown = isFieldShown
      ..dialogPortrait = dialogPortrait
      ..keepDialog = keepDialog
      ..currentMap = currentMap
      ..panelsShown = panelsShown
      .._routines.addAll(_routines);
  }

  late final Positions _positions;
  Positions get positions => _positions;

  /// Character field objects by slot. 1-indexed (zero is invalid).
  final Slots slots = Slots._();

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

  int? panelsShown = 0;
  void addPanel() {
    if (panelsShown != null) panelsShown = panelsShown! + 1;
  }

  void removePanels([int n = 1]) {
    if (panelsShown != null) panelsShown = panelsShown! - n;
  }

  final _facing = <FieldObject, Direction>{};
  DirectionExpression? getFacing(FieldObject obj) => _facing[obj.resolve(this)];
  void setFacing(FieldObject obj, Direction dir) =>
      _facing[obj.resolve(this)] = dir;

  void clearFacing(FieldObject obj) => _facing.remove(obj.resolve(this));

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
  void setRoutine(FieldObject obj, SpecModel? r) => r == null
      ? _routines.remove(obj.resolve(this))
      : _routines[obj.resolve(this)] = r;
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
  final _fieldObjects = BiMap<int, Character>();

  /// Party order (not necessarily the same as field objects).
  final _party = BiMap<int, Character>();
  IMap<int, Character>? _priorParty;
  bool get partyOrderMaintained => _partyOrderMaintained;
  bool _partyOrderMaintained = false;

  static const all = [1, 2, 3, 4, 5];

  Slots._();

  /// Whether or not field objects order is consistent with party order.
  bool get isConsistent =>
      const MapEquality<int, Character>().equals(_fieldObjects, _party);
  bool get isNotConsistent => !isConsistent;

  void addAll(Slots slots) {
    _fieldObjects.addAll(slots._fieldObjects);
  }

  void forEach(Function(int, Character) func) {
    _fieldObjects.forEach(func);
  }

  /// 1-indexed (first slot is 1, there is no slot 0).
  Character? operator [](int slot) => _fieldObjects[slot];

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
    if (_priorParty != null) {
      for (var i = 1; i <= 5; i++) {
        var prior = _priorParty![i];
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
  }

  /// 1-indexed (first slot is 1, there is no slot 0).
  void operator []=(int slot, Character? c) {
    if (c == null) {
      _fieldObjects.remove(slot);
      _party.remove(slot);
    } else {
      _fieldObjects[slot] = c;
      _party[slot] = c;
    }
  }

  /// 1-indexed (first slot is 1, there is no slot 0).
  int? slotFor(Character c) => _fieldObjects.inverse[c];

  int get numCharacters => _fieldObjects.keys.reduce(max);

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

  /// Resets character objects from party order.
  void reloadObjects() {
    _fieldObjects.clear();
    _fieldObjects.addAll(_party);
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

  Scene asOf(Condition asOf) {
    return Scene(_asOf(_events, asOf, Condition.empty()));
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
            var spans = <DialogSpan>[..._justPanels(d)];
            var j = i + 1;

            loop:
            for (; j < events.length; j++) {
              switch (events[j]) {
                case Pause _:
                  events.removeAt(j);
                  j--;
                  break;
                case Dialog d:
                  spans.addAll(_justPanels(d));
                  break;
                default:
                  break loop;
              }
            }

            events.replaceRange(i, j, [
              Dialog(
                spans: [
                  DialogSpan.fromSpan(dialogTo,
                      panel: spans.firstOrNull?.panel),
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
                b.condition: condenseRecursively([...b.events])
            };
            events[i] = IfValue(
              e.operand1,
              comparedTo: e.operand2,
              equal: branches[BranchCondition.eq] ?? [],
              greater: branches[BranchCondition.gt] ?? [],
              less: branches[BranchCondition.lt] ?? [],
              greaterOrEqual: branches[BranchCondition.gte] ?? [],
              lessOrEqual: branches[BranchCondition.lte] ?? [],
              notEqual: branches[BranchCondition.neq] ?? [],
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

  /// Find all branches recursively, including [events],
  /// that satisfy the [matching] Condition with [current].
  /// Visit each branch with [visitor].
  ///
  /// A branch is not recursed further once it matches the [matching] condition.
  ///
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
  /// Advancing to the next branch in sequence can be controlled however
  /// by setting the [advanceSequenceWhenSet] flag. If provided, advancing the
  /// sequence will be conditional on the `advanceSequenceWhenSet` flag.
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

      var spans = <DialogSpan>[..._justPanels(e)];
      var j = i + 1;

      for (; j < length; j++) {
        e = this[j];
        if (e is! Dialog) break;
        spans.addAll(_justPanels(e));
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

Iterable<DialogSpan> _justPanels(Dialog d) {
  return d.spans
      .map((s) => s.panel)
      .whereNotNull()
      .map((p) => DialogSpan('', panel: p));
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

// TODO(refactor): should just be an enum?
class BySlot extends FieldObject {
  final int index;

  const BySlot(this.index);

  static const one = BySlot(1);
  static const two = BySlot(2);
  static const three = BySlot(3);
  static const four = BySlot(4);
  static const five = BySlot(5);

  @override
  FieldObject resolve(EventState state) {
    var inSlot = state.slots[index];
    if (inSlot == null) {
      return this;
    }
    return inSlot;
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
  int? slotAsOf(EventState c) => c.slotFor(this);

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
