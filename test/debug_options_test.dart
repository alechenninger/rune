import 'package:rune/debug/options.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
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
