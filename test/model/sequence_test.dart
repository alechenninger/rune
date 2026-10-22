import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  final story = EventFlag('Story');
  final first = EventFlag('FirstPlayed');
  final second = EventFlag('SecondPlayed');
  final p = Dialog.parse('P');
  final q = Dialog.parse('Q');
  final r = Dialog.parse('R');

  test('an empty condition forks the whole scene', () {
    final scene = Scene([p, ReturnControl()]);
    scene.addSequence([q], whenSet: first);

    expect(
        scene,
        Scene([
          IfFlag(first,
              isSet: [q], isUnset: [SetFlag(first), p, ReturnControl()]),
        ]));
  });

  for (final hasElse in [false, true]) {
    test('a story condition preserves its else and following events: $hasElse',
        () {
      final before = Dialog.parse('Before');
      final after = IfFlag(story, isSet: [Dialog.parse('After')]);
      final scene = Scene([after])
        ..prependEvents([
          IfFlag(story, isSet: [p], isUnset: [if (hasElse) before]),
        ]);
      scene.addSequence([q], whenSet: first, asOf: Condition({story: true}));

      expect(scene.events, [
        IfFlag(story, isSet: [
          IfFlag(first, isSet: [q], isUnset: [SetFlag(first), p]),
        ], isUnset: [
          if (hasElse) before
        ]),
        after,
      ]);
      expect(scene.last, same(after));
    });
  }

  test('a later step forks its condition inside the existing story gate', () {
    final scene = Scene([
      IfFlag(story, isSet: [
        IfFlag(first, isSet: [q], isUnset: [SetFlag(first), p]),
      ], isUnset: [
        Dialog.parse('Before')
      ]),
      Dialog.parse('After'),
    ]);
    scene.addSequence([r], whenSet: second, asOf: Condition({first: true}));

    expect(
        scene,
        Scene([
          IfFlag(story, isSet: [
            IfFlag(first, isSet: [
              IfFlag(second, isSet: [r], isUnset: [SetFlag(second), q]),
            ], isUnset: [
              SetFlag(first),
              p
            ]),
          ], isUnset: [
            Dialog.parse('Before')
          ]),
          Dialog.parse('After'),
        ]));
  });

  test('a missing condition does not invent a sequence branch', () {
    final scene = Scene([p]);
    expect(
        () => scene
            .addSequence([q], whenSet: first, asOf: Condition({story: true})),
        throwsArgumentError);
    expect(scene, Scene([p]));
  });
}
