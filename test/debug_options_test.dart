import 'package:rune/debug/options.dart';
import 'package:rune/debug/map_transitions.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('map loading shares preset destinations without resolving party state',
      () {
    final destination = LoadMapOptions(map: 'krup').resolve();
    expect(destination, DebugStartOptions(map: 'Krup').resolve().loadMap);
    expect(destination.updateParty, isNull);
    expect(destination.refreshObjects, isTrue);
    final explicit = LoadMapOptions.fromJson({
      'map': 'ShayHouse',
      'position': r'$1f0,0x280',
      'facing': 'LEFT',
    });
    expect(explicit.resolve().startingPosition, Position(496, 640));
    expect(explicit.resolve().facing, Direction.left);
    expect(explicit.toJson(), {
      'map': 'ShayHouse',
      'position': r'$1f0,0x280',
      'facing': 'LEFT',
    });
  });

  test('map loading rejects malformed destinations and state-changing options',
      () {
    for (final value in <Object?>[
      null,
      {},
      {'map': 1},
      {'map': 'Typo'},
      {'map': 'Krup', 'position': 1},
      {'map': 'Krup', 'position': '1,2'},
      {'map': 'Krup', 'position': '-8,0'},
      {'map': 'Krup', 'position': '0x8000,0'},
      {'map': 'Krup', 'position': '8'},
      {'map': 'Krup', 'facing': 1},
      {'map': 'Krup', 'facing': 'Typo'},
      {'map': 'Krup', 'items': []},
      {'map': 'Krup', 'storyAfter': 'HahnJoined'},
    ]) {
      expect(
          () => LoadMapOptions.fromJson(value).resolve(), throwsArgumentError,
          reason: '$value');
    }
    final noEntrance =
        MapId.values.firstWhere((map) => entrypointsToMap(map).isEmpty);
    expect(() => LoadMapOptions(map: noEntrance.name).resolve(),
        throwsArgumentError);
    expect(
        LoadMapOptions(map: noEntrance.name, position: '8,16')
            .resolve()
            .startingPosition,
        Position(8, 16));
  });

  test('saved configuration resolves story, party and position', () {
    final saved = DebugStartOptions.fromJson({
      'storyAfter': 'HahnJoined',
      'map': 'Krup',
      'position': '0x160,0xe0',
      'setFlags': ['Custom'],
      'items': ['Monomate'],
    }).resolve();
    expect(saved.party, [alys, shay, hahn]);
    expect(saved.eventFlags.last, const EventFlag('Custom'));
    expect(saved.loadMap.startingPosition, Position(352, 224));
    expect(saved.items, [ItemId.Monomate]);
  });

  test('map-only options resolve default entrypoint and party', () {
    final resolved = DebugStartOptions(map: 'krup').resolve();
    expect(resolved.party, [alys, shay]);
    expect(resolved.loadMap.startingPosition, Position(0x260, 0x360));
    expect(resolved.loadMap.facing, Direction.up);
  });

  test('bad milestones, positions and unsupported fields are rejected', () {
    expect(() => DebugStartOptions(map: 'Krup', storyAfter: 'Typo').resolve(),
        throwsArgumentError);
    expect(() => DebugStartOptions(map: 'Krup', position: '1,2').resolve(),
        throwsArgumentError);
    expect(
        () => DebugStartOptions.fromJson({
              'map': 'Krup',
              'fastForwardScenes': ['x']
            }),
        throwsArgumentError);
  });
}
