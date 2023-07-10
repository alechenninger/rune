import 'model.dart';

class HuntersGuild {
  final Scene onWelcome;
  final Scene onJobBoard;
  final Scene onAlreadyCompleted;
  final Scene onNoJobs;
  final Scene onFarewell;

  HuntersGuild(
      {required this.onWelcome,
      required this.onJobBoard,
      required this.onAlreadyCompleted,
      required this.onNoJobs,
      required this.onFarewell});

  final List<GuildJob> _jobs = [];
  List<GuildJob> get jobs => List.unmodifiable(_jobs);

  void addJob(GuildJob job) {
    _jobs.add(job);
  }
}

class GuildJob {
  // max chars? not much
  final String title;

  final EventFlag startFlag;
  final EventFlag endFlag;
  final EventFlag completeFlag;
  final EventFlag availableWhen;
  final EventFlag unavailableWhen;

  final Scene prompt;
  // I think we compute the "real" prompt scene
  // which includes the yes/no prompt and the corresponding
  // accept/decline branches see dialogue 26 $14 as an example
  final Scene onAccept;
  final Scene onDecline;
  // Remember, this can use IfFlag to have different dialog
  // throughout the quest
  final Scene onTalk;
  final Scene onComplete;

  GuildJob(
      {required this.title,
      required this.startFlag,
      required this.endFlag,
      required this.completeFlag,
      required this.availableWhen,
      this.unavailableWhen = const EventFlag('GuildPlaceholder'),
      required this.prompt,
      required this.onAccept,
      required this.onDecline,
      required this.onTalk,
      required this.onComplete});
}
