import 'package:quiver/check.dart';

import 'model.dart';

sealed class GuildInteraction {}

enum ClerkInteraction implements GuildInteraction {
  welcome,
  jobBoard,
  alreadyCompleted,
  noJobsAvailable,
  farewell,
  jobNotYetAvailable,
  firstJobNoLongerAvailable,
  firstJobMileDead,
  jobNoLongerAvailable
}

class JobInteraction implements GuildInteraction {
  final JobId id;
  final JobScene scene;
  const JobInteraction(this.id, this.scene);
}

enum JobScene {
  prompt,
  accept,
  decline,
  talk,
  complete;

  JobInteraction forJob(JobId id) => JobInteraction(id, this);
}

extension GuildInteractionExtension on GuildInteraction {
  GuildInteractionId get id => GuildInteractionId(this);
  EventInteraction interaction(Scene scene) => EventInteraction(scene, id: id);
}

class GuildInteractionId extends InteractionId {
  final GuildInteraction interaction;

  const GuildInteractionId(this.interaction);

  @override
  String get value {
    var suffix = switch (interaction) {
      ClerkInteraction i => i.name,
      JobInteraction i => 'job_${i.id}_${i.scene.name}'
    };

    return 'guild_$suffix';
  }

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuildInteractionId &&
          runtimeType == other.runtimeType &&
          interaction == other.interaction;
}

abstract interface class HuntersGuild {
  Scene get onWelcome;
  Scene get onJobBoard;
  Scene get onAlreadyCompleted;
  Scene get onNoJobsAvailable;
  Scene get onFarewell;
  Scene get onJobNotYetAvailable;
  Scene get onFirstJobNoLongerAvailable;
  Scene get onFirstJobMileDead;
  Scene get onJobNoLongerAvailable;

  JobListing get pendingJob;

  List<GuildJob> get jobsByIndex;
  GuildJob jobById(JobId id);
}

class HuntersGuildInteractions implements HuntersGuild {
  HuntersGuildInteractions();

  EventInteraction? interactionById(InteractionId id) {
    if (id is GuildInteractionId) {
      return switch (id.interaction) {
        ClerkInteraction i => clerkInteraction(i),
        JobInteraction i => jobById(i.id).interaction(i.scene)
      };
    }
    return null;
  }

  Iterable<EventInteraction> get interactions => [
        for (var i in ClerkInteraction.values) clerkInteraction(i),
        ...jobsByIndex
            .expand((j) => [for (var s in JobScene.values) j.interaction(s)])
      ];

  EventInteraction clerkInteraction(ClerkInteraction interaction) =>
      switch (interaction) {
        ClerkInteraction.welcome => _welcome,
        ClerkInteraction.jobBoard => _jobBoard,
        ClerkInteraction.alreadyCompleted => _alreadyCompleted,
        ClerkInteraction.noJobsAvailable => _noJobsAvailable,
        ClerkInteraction.farewell => _farewell,
        ClerkInteraction.jobNotYetAvailable => _jobNotYetAvailable,
        ClerkInteraction.firstJobNoLongerAvailable =>
          _firstJobNoLongerAvailable,
        ClerkInteraction.firstJobMileDead => _firstJobMileDead,
        ClerkInteraction.jobNoLongerAvailable => _jobNoLongerAvailable
      };

  final _welcome = ClerkInteraction.welcome.interaction(
      Scene([Dialog.parse('(welcome)', speaker: Speaker.HuntersGuildClerk)]));

  final _jobBoard = ClerkInteraction.jobBoard.interaction(
      Scene([Dialog.parse('(job board)', speaker: Speaker.HuntersGuildClerk)]));

  final _alreadyCompleted = ClerkInteraction.alreadyCompleted.interaction(
      Scene([
    Dialog.parse('(already completed)', speaker: Speaker.HuntersGuildClerk)
  ]));

  final _noJobsAvailable = ClerkInteraction.noJobsAvailable.interaction(
      Scene([Dialog.parse('(no jobs)', speaker: Speaker.HuntersGuildClerk)]));

  final _farewell = ClerkInteraction.farewell.interaction(
      Scene([Dialog.parse('(farewell)', speaker: Speaker.HuntersGuildClerk)]));

  final _jobNotYetAvailable = ClerkInteraction.jobNotYetAvailable.interaction(
      Scene([
    Dialog.parse('(not available yet)', speaker: Speaker.HuntersGuildClerk)
  ]));

  final _firstJobNoLongerAvailable =
      ClerkInteraction.firstJobNoLongerAvailable.interaction(Scene([
    Dialog.parse('(first job no longer available)',
        speaker: Speaker.HuntersGuildClerk)
  ]));

  final _firstJobMileDead = ClerkInteraction.firstJobMileDead.interaction(
      Scene([
    Dialog.parse('(first job mile dead)', speaker: Speaker.HuntersGuildClerk)
  ]));

  final _jobNoLongerAvailable = ClerkInteraction.jobNoLongerAvailable
      .interaction(Scene([
    Dialog.parse('(no longer available)', speaker: Speaker.HuntersGuildClerk)
  ]));

  @override
  Scene get onWelcome => _welcome.onInteract;
  @override
  Scene get onJobBoard => _jobBoard.onInteract;
  @override
  Scene get onAlreadyCompleted => _alreadyCompleted.onInteract;
  @override
  Scene get onNoJobsAvailable => _noJobsAvailable.onInteract;
  @override
  Scene get onFarewell => _farewell.onInteract;
  @override
  Scene get onJobNotYetAvailable => _jobNotYetAvailable.onInteract;
  @override
  Scene get onFirstJobNoLongerAvailable =>
      _firstJobNoLongerAvailable.onInteract;
  @override
  Scene get onFirstJobMileDead => _firstJobMileDead.onInteract;
  @override
  Scene get onJobNoLongerAvailable => _jobNoLongerAvailable.onInteract;

  @override
  JobListing pendingJob = JobListing('Listing pending...');

  final Map<JobId, GuildJob> _jobs = {
    for (var id in JobId.all) id: GuildJob.placeholder(id)
  };

  @override
  List<GuildJob> get jobsByIndex => [for (var id in JobId.all) _jobs[id]!];

  @override
  GuildJob jobById(JobId id) => _jobs[id]!;
}

typedef ThousandMeseta = int;

class JobId {
  static final Set<JobId> all = {for (var i = 0; i < 8; i++) JobId(i)};

  final int value;
  JobId(this.value) {
    checkArgument(value >= 0 && value < 8,
        message: 'job id must be between 0 and 7 but got $value');
  }
  @override
  String toString() => value.toString();
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobId &&
          runtimeType == other.runtimeType &&
          value == other.value;
  @override
  int get hashCode => value.hashCode;
}

class JobListing {
  final String value;
  JobListing(this.value) {
    checkArgument(value.length <= 19,
        message: 'title must be no more than 19 characters but got "$value"');
  }
  @override
  String toString() => value;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobListing &&
          runtimeType == other.runtimeType &&
          value == other.value;
  @override
  int get hashCode => value.hashCode;
}

class GuildJob {
  final JobId id;

  JobListing title;

  EventFlag startFlag;
  EventFlag endFlag;
  EventFlag rewardedFlag;
  EventFlag availableWhen;
  EventFlag unavailableWhen;

  ThousandMeseta reward;

  EventInteraction interaction(JobScene scene) => switch (scene) {
        JobScene.prompt => _prompt,
        JobScene.accept => _accept,
        JobScene.decline => _decline,
        JobScene.talk => _talk,
        JobScene.complete => _complete
      };

  final EventInteraction _prompt;
  final EventInteraction _accept;
  final EventInteraction _decline;
  final EventInteraction _talk;
  final EventInteraction _complete;

  Scene get onPrompt {
    /// Scene for when the job is selected.
    var onAccept = _onlyDialog(_accept.onInteract);
    var onDecline = _onlyDialog(_decline.onInteract);
    return Scene([
      ..._prompt.onInteract,
      YesOrNoChoice(ifYes: onAccept, ifNo: onDecline)
    ]);
  }

  /// Scene upon talking to receptionist when the job is started,
  /// but not completed.
  // Remember, this can use IfFlag to have different dialog
  // throughout the quest
  Scene get onTalk => _talk.onInteract;

  /// Scene upon talking to to receptionist once the job is completed.
  Scene get onComplete => _complete.onInteract;

  GuildJob(
      {required this.id,
      JobListing? title,
      EventFlag? startFlag,
      EventFlag? endFlag,
      EventFlag? rewardedFlag,
      EventFlag? availableWhen,
      EventFlag? unavailableWhen,
      List<Event> prompt = const [],
      List<Dialog> onAccept = const [],
      List<Dialog> onDecline = const [],
      Scene onTalk = const Scene.none(),
      Scene onComplete = const Scene.none(),
      this.reward = 0})
      : _prompt = JobScene.prompt.forJob(id).interaction(Scene(prompt)),
        _accept = JobScene.accept.forJob(id).interaction(Scene(onAccept)),
        _decline = JobScene.decline.forJob(id).interaction(Scene(onDecline)),
        _talk = JobScene.talk.forJob(id).interaction(onTalk),
        _complete = JobScene.complete.forJob(id).interaction(onComplete),
        title = title ?? JobListing('job $id'),
        startFlag = startFlag ?? _defaultJobFlags[id.value].start,
        endFlag = endFlag ?? _defaultJobFlags[id.value].end,
        rewardedFlag = rewardedFlag ?? _defaultJobFlags[id.value].completed,
        availableWhen =
            availableWhen ?? _defaultJobFlags[id.value].availableWhen,
        unavailableWhen =
            unavailableWhen ?? _defaultJobFlags[id.value].unavailableWhen;

  // TODO: possibly use table of existing quest data
  // maybe parse out the dialog? but in that case
  // we'd configure the jobs in the doc and keep something like this.
  GuildJob.placeholder(JobId id)
      : this(
            id: id,
            prompt: [
              Dialog.parse('(job $id)', speaker: Speaker.HuntersGuildClerk)
            ],
            onAccept: [
              Dialog.parse('(accepted $id)', speaker: Speaker.HuntersGuildClerk)
            ],
            onDecline: [
              Dialog.parse('(declined $id)', speaker: Speaker.HuntersGuildClerk)
            ],
            onTalk: Scene([
              Dialog.parse('(talk $id)', speaker: Speaker.HuntersGuildClerk)
            ]),
            onComplete: Scene([
              Dialog.parse('(complete $id)', speaker: Speaker.HuntersGuildClerk)
            ]),
            reward: 1);

  @override
  String toString() => 'GuildJob{id: $id, '
      'title: $title, '
      'startFlag: $startFlag, '
      'endFlag: $endFlag, '
      'rewardedFlag: $rewardedFlag, '
      'availableWhen: $availableWhen, '
      'unavailableWhen: $unavailableWhen, '
      'prompt: $onPrompt, '
      'onTalk: $onTalk, '
      'onComplete: $onComplete, '
      'reward: $reward}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuildJob &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          startFlag == other.startFlag &&
          endFlag == other.endFlag &&
          rewardedFlag == other.rewardedFlag &&
          availableWhen == other.availableWhen &&
          unavailableWhen == other.unavailableWhen &&
          onPrompt == other.onPrompt &&
          onTalk == other.onTalk &&
          onComplete == other.onComplete &&
          reward == other.reward;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      startFlag.hashCode ^
      endFlag.hashCode ^
      rewardedFlag.hashCode ^
      availableWhen.hashCode ^
      unavailableWhen.hashCode ^
      onPrompt.hashCode ^
      onTalk.hashCode ^
      onComplete.hashCode ^
      reward.hashCode;
}

enum JobStage {
  available,
  inProgress,
  completed;

  Scene scene(GuildJob job) => switch (this) {
        JobStage.available => job.onPrompt,
        JobStage.inProgress => job.onTalk,
        JobStage.completed => job.onComplete
      };
}

/// Returns an equivalent to the [scene] as a List of Dialog events.
///
/// If the `scene` contains any other kind of Event, an illegal argument error
/// is thrown.
List<Dialog> _onlyDialog(Scene scene) => scene.events
    .expand((e) => switch (e) {
          Dialog() => [e],
          SetContext() => <Dialog>[],
          _ => throw ArgumentError.value(
              e, 'scene', 'must only contain Dialog events')
        })
    .toList();

typedef _JobFlags = ({
  EventFlag start,
  EventFlag end,
  EventFlag completed,
  EventFlag availableWhen,
  EventFlag unavailableWhen
});

final _defaultJobFlags = <_JobFlags>[
  // 0
  (
    start: EventFlag('TheRanchOwner'),
    end: EventFlag('MileSandWorm'),
    completed: EventFlag('RanchOwnerFee'),
    availableWhen: EventFlag('AlysFound'),
    unavailableWhen: EventFlag('Elsydeon')
  ),
  // 1
  (
    start: EventFlag('TinkerbellsDog'),
    end: EventFlag('RockyHome'),
    completed: EventFlag('RockyFee'),
    availableWhen: EventFlag('LandRover'),
    unavailableWhen: EventFlag('GuildPlaceholder')
  ),
  // 2
  (
    start: EventFlag('MissingStudent'),
    end: EventFlag('StudentRecovered'),
    completed: EventFlag('StudentFee'),
    availableWhen: EventFlag('ZioNurvus'),
    unavailableWhen: EventFlag('GuildPlaceholder')
  ),
  // 3
  (
    start: EventFlag('FissureOfFear'),
    end: EventFlag('FractOoze'),
    completed: EventFlag('FissureOfFearFee'),
    availableWhen: EventFlag('ZioNurvus'),
    unavailableWhen: EventFlag('GuildPlaceholder')
  ),
  // 4
  (
    start: EventFlag('StainInLife'),
    end: EventFlag('GirlsBailedOut'),
    completed: EventFlag('StainInLifeFee'),
    availableWhen: EventFlag('Hydrofoil2'),
    unavailableWhen: EventFlag('GuildPlaceholder')
  ),
  // 5
  (
    start: EventFlag('DyingBoy'),
    end: EventFlag('CulversAfterRecovery'),
    completed: EventFlag('DyingBoyFeee'),
    availableWhen: EventFlag('Hydrofoil2'),
    unavailableWhen: EventFlag('GuildPlaceholder')
  ),
  // 6
  (
    start: EventFlag('ManWithTwist'),
    end: EventFlag('KingRappy'),
    completed: EventFlag('ManWithTwistFee'),
    availableWhen: EventFlag('Hydrofoil2'),
    unavailableWhen: EventFlag('GuildPlaceholder')
  ),
  // 7
  (
    start: EventFlag('SilverSoldier'),
    end: EventFlag('Dominators'),
    completed: EventFlag('SilverSoldierFee'),
    availableWhen: EventFlag('Hydrofoil2'),
    unavailableWhen: EventFlag('Elsydeon')
  ),
];
