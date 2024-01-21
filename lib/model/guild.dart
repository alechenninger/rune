import 'package:quiver/check.dart';

import 'model.dart';

class HuntersGuild {
  HuntersGuild();

  var welcome = EventInteraction(
      Scene([Dialog.parse('(welcome)', speaker: Speaker.HuntersGuildClerk)]));

  var jobBoard = EventInteraction(
      Scene([Dialog.parse('(job board)', speaker: Speaker.HuntersGuildClerk)]));

  var alreadyCompleted = EventInteraction(Scene([
    Dialog.parse('(already completed)', speaker: Speaker.HuntersGuildClerk)
  ]));

  var noJobsAvailable = EventInteraction(
      Scene([Dialog.parse('(no jobs)', speaker: Speaker.HuntersGuildClerk)]));

  var farewell = EventInteraction(
      Scene([Dialog.parse('(farewell)', speaker: Speaker.HuntersGuildClerk)]));

  var jobNotYetAvailable = EventInteraction(Scene([
    Dialog.parse('(not available yet)', speaker: Speaker.HuntersGuildClerk)
  ]));

  var firstJobNoLongerAvailable = EventInteraction(Scene([
    Dialog.parse('(first job no longer available)',
        speaker: Speaker.HuntersGuildClerk)
  ]));

  var firstJobMileDead = EventInteraction(Scene([
    Dialog.parse('(first job mile dead)', speaker: Speaker.HuntersGuildClerk)
  ]));

  var jobNoLongerAvailable = EventInteraction(Scene([
    Dialog.parse('(no longer available)', speaker: Speaker.HuntersGuildClerk)
  ]));

  Scene get onWelcome => welcome.onInteract;
  Scene get onJobBoard => jobBoard.onInteract;
  Scene get onAlreadyCompleted => alreadyCompleted.onInteract;
  Scene get onNoJobsAvailable => noJobsAvailable.onInteract;
  Scene get onFarewell => farewell.onInteract;
  Scene get onJobNotYetAvailable => jobNotYetAvailable.onInteract;
  Scene get onFirstJobNoLongerAvailable => firstJobNoLongerAvailable.onInteract;
  Scene get onFirstJobMileDead => firstJobMileDead.onInteract;
  Scene get onJobNoLongerAvailable => jobNoLongerAvailable.onInteract;

  JobListing pendingJob = JobListing('Listing pending');

  final Map<JobId, GuildJob> _jobs = {
    for (var i = 0; i < 8; i++) JobId(i): GuildJob.placeholder(JobId(i))
  };

  List<GuildJob> get jobsByIndex =>
      [for (var i = 0; i < 8; i++) _jobs[JobId(i)]!];

  GuildJob? jobById(JobId id) => _jobs[id];

  void configureJob(GuildJob job) {
    _jobs[job.id] = job;
  }
}

typedef ThousandMeseta = int;

class JobId {
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
    checkArgument(value.length <= 16,
        message: 'title must be no more than 16 characters but got "$value"');
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

  EventInteraction prompt;
  EventInteraction accept;
  EventInteraction decline;
  EventInteraction talk;
  EventInteraction complete;

  Scene get onPrompt {
    /// Scene for when the job is selected.
    var onAccept = _onlyDialog(accept.onInteract);
    var onDecline = _onlyDialog(decline.onInteract);
    return Scene([
      ...prompt.onInteract,
      YesOrNoChoice(ifYes: onAccept, ifNo: onDecline)
    ]);
  }

  /// Scene upon talking to receptionist when the job is started,
  /// but not completed.
  // Remember, this can use IfFlag to have different dialog
  // throughout the quest
  Scene get onTalk => talk.onInteract;

  /// Scene upon talking to to receptionist once the job is completed.
  Scene get onComplete => complete.onInteract;

  ThousandMeseta reward;

  GuildJob(
      {required this.id,
      JobListing? title,
      EventFlag? startFlag,
      EventFlag? endFlag,
      EventFlag? rewardedFlag,
      EventFlag? availableWhen,
      this.unavailableWhen = const EventFlag('GuildPlaceholder'),
      List<Event> prompt = const [],
      List<Dialog> onAccept = const [],
      List<Dialog> onDecline = const [],
      Scene onTalk = const Scene.none(),
      Scene onComplete = const Scene.none(),
      this.reward = 0})
      : prompt = EventInteraction(Scene(prompt)),
        accept = EventInteraction(Scene(onAccept)),
        decline = EventInteraction(Scene(onDecline)),
        talk = EventInteraction(onTalk),
        complete = EventInteraction(onComplete),
        title = title ?? JobListing('job $id'),
        startFlag = startFlag ?? _defaultJobFlags[id.value].start,
        endFlag = endFlag ?? _defaultJobFlags[id.value].end,
        rewardedFlag = rewardedFlag ?? _defaultJobFlags[id.value].completed,
        availableWhen =
            availableWhen ?? _defaultJobFlags[id.value].availableWhen;

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
    .map((e) => switch (e) {
          Dialog() => e,
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
