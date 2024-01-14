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
  Scene onNoJobs =
      Scene([Dialog.parse('(no jobs)', speaker: Speaker.HuntersGuildClerk)]);
  Scene onFarewell =
      Scene([Dialog.parse('(farewell)', speaker: Speaker.HuntersGuildClerk)]);

  Scene onNotYetAvailable = Scene([
    Dialog.parse('(not available yet)', speaker: Speaker.HuntersGuildClerk)
  ]);
  Scene onFirstJobNoLongerAvailable = Scene([
    Dialog.parse('(first job no longer available)',
        speaker: Speaker.HuntersGuildClerk)
  ]);
  Scene onFirstJobMileDead = Scene([
    Dialog.parse('(first job mile dead)', speaker: Speaker.HuntersGuildClerk)
  ]);
  Scene onNoLongerAvailable = Scene([
    Dialog.parse('(no longer available)', speaker: Speaker.HuntersGuildClerk)
  ]);

  String pendingJobText = 'Listing pending';

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

class GuildJob {
  final JobId id;

  final String title;

  final EventFlag startFlag;
  final EventFlag endFlag;
  final EventFlag rewardedFlag;
  final EventFlag availableWhen;
  final EventFlag unavailableWhen;

  /// Scene for when the job is selected.
  final Scene prompt;

  /// Scene upon talking to receptionist when the job is started,
  /// but not completed.
  // Remember, this can use IfFlag to have different dialog
  // throughout the quest
  final Scene onTalk;

  /// Scene upon talking to to receptionist once the job is completed.
  final Scene onComplete;

  final ThousandMeseta reward;

  GuildJob(
      {required this.id,
      required this.title,
      required this.startFlag,
      required this.endFlag,
      required this.rewardedFlag,
      required this.availableWhen,
      this.unavailableWhen = const EventFlag('GuildPlaceholder'),
      required List<Event> prompt,
      required List<Dialog> onAccept,
      required List<Dialog> onDecline,
      required this.onTalk,
      required this.onComplete,
      required this.reward})
      : prompt = Scene(
            [...prompt, YesOrNoChoice(ifYes: onAccept, ifNo: onDecline)]) {
    checkArgument(title.length <= 16,
        message: 'title must be no more than 16 characters but got "$title"');
  }

  // TODO: possibly use table of existing quest data
  // maybe parse out the dialog? but in that case
  // we'd configure the jobs in the doc and keep something like this.
  GuildJob.placeholder(JobId id)
      : this(
            id: id,
            title: 'job $id',
            startFlag: _defaultJobFlags[id].start,
            endFlag: _defaultJobFlags[id].end,
            rewardedFlag: _defaultJobFlags[id].completed,
            availableWhen: _defaultJobFlags[id].availableWhen,
            unavailableWhen: _defaultJobFlags[id].unavailableWhen,
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
