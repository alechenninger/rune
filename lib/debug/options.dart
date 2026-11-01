import '../generator/generator.dart' show DebugOptions;
import '../model/model.dart';
import 'map_transitions.dart';
import 'party.dart';

/// The debug-start inputs shared by Macro builds and live Demi presets.
/// Build-only source selection and scene rewriting are deliberately separate.
class DebugStartOptions {
  final String? storyAfter;
  final String? map;
  final String? position;
  final List<String> setFlags;
  final List<String> items;

  DebugStartOptions(
      {this.storyAfter,
      this.map,
      this.position,
      List<String> setFlags = const [],
      List<String> items = const []})
      : setFlags = List.unmodifiable(setFlags),
        items = List.unmodifiable(items);

  factory DebugStartOptions.fromJson(Object? value) {
    const keys = {'storyAfter', 'map', 'position', 'setFlags', 'items'};
    if (value is! Map || value.keys.any((key) => !keys.contains(key))) {
      throw ArgumentError(
          'Expected debug-start options: storyAfter, map, position, setFlags, items. Fast-forward options are build-only.');
    }
    for (final key in ['storyAfter', 'map', 'position']) {
      if (value[key] != null && value[key] is! String) {
        throw ArgumentError('$key must be a string');
      }
    }
    List<String> names(String key) {
      final list = value[key] ?? <String>[];
      if (list is! List || list.any((entry) => entry is! String)) {
        throw ArgumentError('$key must be a list of names');
      }
      return list.cast<String>();
    }

    return DebugStartOptions(
        storyAfter: value['storyAfter'] as String?,
        map: value['map'] as String?,
        position: value['position'] as String?,
        setFlags: names('setFlags'),
        items: names('items'));
  }

  bool get isSpecified =>
      storyAfter != null ||
      map != null ||
      position != null ||
      setFlags.isNotEmpty ||
      items.isNotEmpty;

  Map<String, Object?> toJson() => {
        if (storyAfter != null) 'storyAfter': storyAfter,
        if (map != null) 'map': map,
        if (position != null) 'position': position,
        'setFlags': setFlags,
        'items': items,
      };

  DebugOptions resolve() {
    if (map == null) throw ArgumentError('Debug start requires --map');
    final destination = LoadMapOptions(map: map!, position: position).resolve();
    final flags = <EventFlag>[];
    if (storyAfter != null) {
      final index = storyEvents.indexWhere(
          (flag) => flag.name.toLowerCase() == storyAfter!.toLowerCase());
      if (index < 0) {
        throw ArgumentError('Unknown story milestone: $storyAfter');
      }
      flags.addAll(storyEvents.take(index + 1));
    }
    flags.addAll(setFlags.map(EventFlag.new));
    if (items.length > 40) {
      throw ArgumentError('Inventory holds at most 40 items');
    }
    return (
      eventFlags: flags.toSet().toList(),
      party: partyFromEventFlags(flags),
      loadMap: destination,
      items: items.map((name) => _enum(ItemId.values, name)).toList()
    );
  }
}

/// A map destination shared by debug starts and state-preserving live teleports.
/// Coordinates are map pixels; omitted position/facing use the first entrance.
class LoadMapOptions {
  final String map;
  final String? position;
  final String? facing;

  LoadMapOptions({required this.map, this.position, this.facing});

  factory LoadMapOptions.fromJson(Object? value) {
    const keys = {'map', 'position', 'facing'};
    if (value is! Map ||
        value.keys.any((key) => !keys.contains(key)) ||
        value['map'] is! String ||
        (value['position'] != null && value['position'] is! String) ||
        (value['facing'] != null && value['facing'] is! String)) {
      throw ArgumentError(
          'Expected map-loading options: map, position, facing');
    }
    return LoadMapOptions(
        map: value['map'] as String,
        position: value['position'] as String?,
        facing: value['facing'] as String?);
  }

  Map<String, Object?> toJson() => {
        'map': map,
        if (position != null) 'position': position,
        if (facing != null) 'facing': facing,
      };

  LoadMap resolve() {
    final target = _enum(MapId.values, map);
    final entrances = entrypointsToMap(target);
    final entrance = entrances.isEmpty ? null : entrances.first;
    Position? coordinates = entrance?.position;
    if (position != null) {
      final parts = position!.split(',');
      if (parts.length != 2) throw ArgumentError('Position must be x,y');
      int number(String text) {
        text = text.trim();
        final value = int.tryParse(
            text.startsWith(r'$') ? '0x${text.substring(1)}' : text);
        if (value == null || value < 0 || value > 0x7fff || value % 8 != 0) {
          throw ArgumentError(
              'Position must contain nonnegative map pixels aligned to 8 pixels');
        }
        return value;
      }

      coordinates = Position(number(parts[0]), number(parts[1]));
    }
    if (coordinates == null) {
      throw ArgumentError('No default position for $map; supply --position');
    }
    return LoadMap(
        map: GameMap(target),
        startingPosition: coordinates,
        facing: facing == null
            ? entrance?.direction ?? Direction.down
            : _enum(Direction.values, facing!));
  }
}

/// Advance existing progress through a milestone, applying only new party
/// transitions. An earlier target may fill missing flags but never rewinds party.
class StoryAdvanceOptions {
  final String storyAfter;
  final LoadMapOptions destination;

  StoryAdvanceOptions(
      {required this.storyAfter,
      required String map,
      String? position,
      String? facing})
      : destination =
            LoadMapOptions(map: map, position: position, facing: facing);

  factory StoryAdvanceOptions.fromJson(Object? value) {
    const keys = {'storyAfter', 'map', 'position', 'facing'};
    if (value is! Map ||
        value['storyAfter'] is! String ||
        value.keys.any((key) => !keys.contains(key))) {
      throw ArgumentError(
          'Expected advancement options: storyAfter, map, position, facing');
    }
    final destination = LoadMapOptions.fromJson({
      for (final key in ['map', 'position', 'facing'])
        if (value.containsKey(key)) key: value[key],
    });
    final result = StoryAdvanceOptions(
        storyAfter: value['storyAfter'] as String,
        map: destination.map,
        position: destination.position,
        facing: destination.facing);
    result.validate();
    return result;
  }

  Map<String, Object?> toJson() =>
      {'storyAfter': storyAfter, ...destination.toJson()};

  /// Validate static inputs before capturing a running game's state.
  void validate() {
    _milestoneIndex;
    destination.resolve();
  }

  ({List<Character> party, List<EventFlag> eventFlags, LoadMap loadMap})
      resolve(
          {required Set<EventFlag> currentFlags,
          required List<Character> currentParty}) {
    final target = _milestoneIndex;
    var reached = -1;
    for (var index = 0; index < storyEvents.length; index++) {
      if (currentFlags.contains(storyEvents[index])) reached = index;
    }
    final party = [...currentParty];
    for (var index = reached + 1; index <= target; index++) {
      applyPartyEventFlag(storyEvents[index], party);
    }
    if (party.isEmpty ||
        party.length > 5 ||
        party.toSet().length != party.length) {
      throw ArgumentError('Advancement requires 1..5 unique party members');
    }
    return (
      party: party,
      eventFlags: storyEvents.take(target + 1).toList(),
      loadMap: destination.resolve()
    );
  }

  int get _milestoneIndex {
    final index = storyEvents.indexWhere(
        (flag) => flag.name.toLowerCase() == storyAfter.toLowerCase());
    if (index < 0) throw ArgumentError('Unknown story milestone: $storyAfter');
    return index;
  }
}

T _enum<T extends Enum>(List<T> values, String name) =>
    values.firstWhere((value) => value.name.toLowerCase() == name.toLowerCase(),
        orElse: () => throw ArgumentError('Unknown name: $name'));
