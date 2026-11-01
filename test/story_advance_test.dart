import 'package:rune/debug/options.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  test(
      'advancement adds the story prefix and only applies new party transitions',
      () {
    final current =
        storyEvents.takeWhile((flag) => flag.name != 'DemiJoined').toSet();
    final resolved = StoryAdvanceOptions(storyAfter: 'DemiJoined', map: 'Krup')
        .resolve(
            currentFlags: current,
            currentParty: [rika, shay, gryz, hahn, alys]);
    expect(resolved.party, [rika, shay, gryz, demi]);
    expect(resolved.eventFlags.last, const EventFlag('DemiJoined'));
    expect(resolved.loadMap.startingPosition, Position(0x260, 0x360));
  });

  test('earlier and repeated milestones do not rewind or reorder the party',
      () {
    for (final milestone in ['HahnJoined', 'RikaJoined']) {
      final resolved = StoryAdvanceOptions(storyAfter: milestone, map: 'Krup')
          .resolve(
              currentFlags: {const EventFlag('RikaJoined')},
              currentParty: [rika, shay, hahn, gryz, alys]);
      expect(resolved.party, [rika, shay, hahn, gryz, alys]);
    }
  });

  test('joining an existing custom party member does not duplicate them', () {
    final resolved = StoryAdvanceOptions(storyAfter: 'HahnJoined', map: 'Krup')
        .resolve(
            currentFlags: {const EventFlag('AlysFound')},
            currentParty: [hahn, shay, alys]);
    expect(resolved.party, [hahn, shay, alys]);
  });

  test('advancement validates input and final party before compilation', () {
    for (final value in <Object?>[
      null,
      {},
      {'storyAfter': 'HahnJoined'},
      {'map': 'Krup'},
      {'storyAfter': 1, 'map': 'Krup'},
      {'storyAfter': 'Typo', 'map': 'Krup'},
      {'storyAfter': 'HahnJoined', 'map': 'Krup', 'items': []},
    ]) {
      expect(
          () => StoryAdvanceOptions.fromJson(value)
              .resolve(currentFlags: {}, currentParty: [shay]),
          throwsArgumentError);
    }
    expect(
        () => StoryAdvanceOptions(storyAfter: 'HahnJoined', map: 'Krup')
            .resolve(
                currentFlags: {const EventFlag('AlysFound')},
                currentParty: [shay, alys, rika, gryz, rune]),
        throwsArgumentError);
    expect(
        StoryAdvanceOptions.fromJson({
          'storyAfter': 'hahnjoined',
          'map': 'Krup',
          'position': '0x160,0xe0',
          'facing': 'left'
        }).resolve(currentFlags: {}, currentParty: [shay]).loadMap.facing,
        Direction.left);
  });
}
