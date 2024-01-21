import 'package:quiver/check.dart';

import 'model.dart';

class HuntersGuild {
  HuntersGuild();

  // These scenes cannot run events.

  Scene onWelcome =
      Scene([Dialog.parse('(welcome)', speaker: Speaker.HuntersGuildClerk)]);
  Scene onJobBoard =
      Scene([Dialog.parse('(job board)', speaker: Speaker.HuntersGuildClerk)]);
  Scene onAlreadyCompleted = Scene([
    Dialog.parse('(already completed)', speaker: Speaker.HuntersGuildClerk)
  ]);
  Scene onNoJobsAvailable =
      Scene([Dialog.parse('(no jobs)', speaker: Speaker.HuntersGuildClerk)]);
  Scene onFarewell =
      Scene([Dialog.parse('(farewell)', speaker: Speaker.HuntersGuildClerk)]);

  Scene onJobNotYetAvailable = Scene([
    Dialog.parse('(not available yet)', speaker: Speaker.HuntersGuildClerk)
  ]);
  Scene onFirstJobNoLongerAvailable = Scene([
    Dialog.parse('(first job no longer available)',
        speaker: Speaker.HuntersGuildClerk)
  ]);
  Scene onFirstJobMileDead = Scene([
    Dialog.parse('(first job mile dead)', speaker: Speaker.HuntersGuildClerk)
  ]);
  Scene onJobNoLongerAvailable = Scene([
    Dialog.parse('(no longer available)', speaker: Speaker.HuntersGuildClerk)
  ]);

  JobListing pendingJob = JobListing('Listing pending');

  final List<GuildJob> _jobs =
      List.generate(8, (i) => GuildJob.placeholder(i), growable: false);
  List<GuildJob> get jobs => List.unmodifiable(_jobs);

  void configureJob(GuildJob job) {
    checkArgument(job.id >= 0 && job.id < 8,
        message: 'job id must be between 0 and 7 but got ${job.id}');
    _jobs[job.id] = job;
  }
}

/// 0 through 7.
typedef JobId = int;
typedef ThousandMeseta = int;

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

  /// Scene for when the job is selected.
  Scene prompt;

  /// Scene upon talking to receptionist when the job is started,
  /// but not completed.
  // Remember, this can use IfFlag to have different dialog
  // throughout the quest
  Scene onTalk;

  /// Scene upon talking to to receptionist once the job is completed.
  Scene onComplete;

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
      this.onTalk = const Scene.none(),
      this.onComplete = const Scene.none(),
      this.reward = 0})
      : prompt =
            Scene([...prompt, YesOrNoChoice(ifYes: onAccept, ifNo: onDecline)]),
        title = title ?? JobListing('job $id'),
        startFlag = startFlag ?? _defaultJobFlags[id].start,
        endFlag = endFlag ?? _defaultJobFlags[id].end,
        rewardedFlag = rewardedFlag ?? _defaultJobFlags[id].completed,
        availableWhen = availableWhen ?? _defaultJobFlags[id].availableWhen;

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
      'prompt: $prompt, '
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
          prompt == other.prompt &&
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
      prompt.hashCode ^
      onTalk.hashCode ^
      onComplete.hashCode ^
      reward.hashCode;
}

enum JobStage {
  available,
  inProgress,
  completed;

  Scene scene(GuildJob job) => switch (this) {
        JobStage.available => job.prompt,
        JobStage.inProgress => job.onTalk,
        JobStage.completed => job.onComplete
      };
}

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
