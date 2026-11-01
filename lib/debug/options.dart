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
    final target = _enum(MapId.values, map!);
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
    if (items.length > 40) {
      throw ArgumentError('Inventory holds at most 40 items');
    }
    return (
      eventFlags: flags.toSet().toList(),
      party: partyFromEventFlags(flags),
      loadMap: LoadMap(
          map: GameMap(target),
          startingPosition: coordinates,
          facing: entrance?.direction ?? Direction.down),
      items: items.map((name) => _enum(ItemId.values, name)).toList()
    );
  }
}

T _enum<T extends Enum>(List<T> values, String name) =>
    values.firstWhere((value) => value.name.toLowerCase() == name.toLowerCase(),
        orElse: () => throw ArgumentError('Unknown name: $name'));
