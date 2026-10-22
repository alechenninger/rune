import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  final story = EventFlag('Story');
  final first = EventFlag('FirstPlayed');
  final second = EventFlag('SecondPlayed');

  test('a reconstructed scene can extend its prefix without extra state', () {
    final original = Dialog.parse('Original');
    final p = Dialog.parse('P');
    final q = Dialog.parse('Q');
    final scene = Scene([original]);
    scene.addPrefix([p, ReturnControl()], storyEvent: story);
    final reconstructed = Scene(scene.events);
    reconstructed.addSequence([q, ReturnControl()],
        whenSet: first, asOf: Condition({story: true}));

    expect(
        reconstructed,
        Scene([
          IfFlag(story, isSet: [
            IfFlag(first, isSet: [
              q,
              ReturnControl()
            ], isUnset: [
              SetFlag(first),
              p,
              ReturnControl(),
            ]),
          ]),
          original,
        ]));
  });

  test('a third prefix step advances only from the second step', () {
    final original = Dialog.parse('Original');
    final p = Dialog.parse('P');
    final q = Dialog.parse('Q');
    final r = Dialog.parse('R');
    final scene = Scene([original]);
    scene.addPrefix([p, ReturnControl()], storyEvent: story);
    scene.addSequence([q, ReturnControl()],
        whenSet: first, asOf: Condition({story: true}));
    scene.addSequence([r, ReturnControl()],
        whenSet: second, asOf: Condition({first: true}));

    expect(
        scene,
        Scene([
          IfFlag(story, isSet: [
            IfFlag(first, isSet: [
              IfFlag(second, isSet: [
                r,
                ReturnControl()
              ], isUnset: [
                SetFlag(second),
                q,
                ReturnControl(),
              ]),
            ], isUnset: [
              SetFlag(first),
              p,
              ReturnControl(),
            ]),
          ]),
          original,
        ]));
  });

  test('copy retains the prefix boundary and can be extended independently',
      () {
    final original = IfFlag(story, isSet: [Dialog.parse('Original')]);
    final prefix = Dialog.parse('P');
    final scene = Scene([original]);
    scene.addPrefix([prefix], storyEvent: story);
    final before = scene.events;
    final copy = scene.copy();
    copy.addSequence([Dialog.parse('Q')],
        whenSet: first, asOf: Condition({story: true}));

    expect(scene.events, before);
    expect(copy.last, same(original));
    expect(copy.length, 2);
    expect(copy.hasBranchOn(first), isTrue);
    expect(scene.hasBranchOn(first), isFalse);
  });

  test('a normal sequence records its predecessor before its early return', () {
    final p = Dialog.parse('P');
    final q = Dialog.parse('Q');
    final scene = Scene([
      IfFlag(story, isSet: [p, ReturnControl()])
    ]);
    scene.addSequence([q], whenSet: first, asOf: Condition({story: true}));

    expect(
        scene,
        Scene([
          IfFlag(story, isSet: [
            IfFlag(first, isSet: [
              q
            ], isUnset: [
              SetFlag(first),
              p,
              ReturnControl(),
            ]),
          ]),
        ]));
  });

  test('prior recording stays outside sequences in the prefix and original',
      () {
    final prior = EventFlag('InteractedEarly');
    final original = Dialog.parse('Original');
    final p = Dialog.parse('P');
    final q = Dialog.parse('Q');
    final scene = Scene([original]);
    scene.addSequence([Dialog.parse('Original again')], whenSet: first);
    final originalSequence = scene.events.single;
    scene.addPrefix([p], storyEvent: story, priorInteractionFlag: prior);
    scene.addSequence([q], whenSet: second, asOf: Condition({story: true}));

    expect(
        scene,
        Scene([
          IfFlag(story, isSet: [
            IfFlag(second, isSet: [q], isUnset: [SetFlag(second), p]),
          ], isUnset: [
            SetFlag(prior)
          ]),
          originalSequence,
        ]));
  });

  test('bookkeeping can reach a sequence inside another story condition', () {
    final q = Dialog.parse('Q');
    final scene = Scene([
      IfFlag(story, isSet: [
        IfFlag(first, isSet: [q, ReturnControl()])
      ]),
    ]);
    scene.addEventToBranches(SetFlag(second), Condition({first: true}));

    expect(
        scene,
        Scene([
          IfFlag(story, isSet: [
            IfFlag(first, isSet: [SetFlag(second), q, ReturnControl()]),
          ]),
        ]));
  });
}
