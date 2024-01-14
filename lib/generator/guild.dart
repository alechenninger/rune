import 'package:quiver/check.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/model/model.dart';

import 'generator.dart';
import '../model/guild.dart';

class HuntersGuildAsm {
  final Asm guildJobs;
  final Asm moneyTable;
  final Asm guildText;

  HuntersGuildAsm(
      {required this.guildJobs,
      required this.moneyTable,
      required this.guildText});

  HuntersGuildAsm.empty()
      : guildJobs = Asm.empty(),
        moneyTable = Asm.empty(),
        guildText = Asm.empty();
}

HuntersGuildAsm compileHuntersGuild(
    {required HuntersGuild guild,
    required GameMap map,
    required Constants constants,
    required DialogTrees dialogTrees,
    required EventFlags eventFlags,
    required EventRoutines eventRoutines}) {
  for (var (scene, constant)
      in _receptionistSceneConstants.map((getThem) => getThem(guild))) {
    _compileReceptionistScene(
        scene, constant, map, constants, dialogTrees, eventRoutines);
  }

  var guildJobs = Asm.empty();
  var titles = Asm.empty();

  for (var job in guild.jobs) {
    _compileJob(job,
        jobsAsm: guildJobs,
        titlesAsm: titles,
        eventFlags: eventFlags,
        map: map,
        dialogTrees: dialogTrees,
        eventRoutines: eventRoutines);
  }

  titles.add(label(Label('GuildText_ListingPending')));
  titles.add(dc.b(Bytes.ascii(guild.pendingJobText)));
  titles.add(dc.b([Byte(0xfe)]));

  var moneyTable = _compileMoneyTable(guild.jobs);

  return HuntersGuildAsm(
      guildJobs: guildJobs, moneyTable: moneyTable, guildText: titles);
}

typedef _ReceptionistSceneConstant = (Scene, Constant) Function(
    HuntersGuild guild);
final _receptionistSceneConstants = <_ReceptionistSceneConstant>[
  (guild) =>
      (guild.onWelcome, Constant('GrandCross_HuntersGuild_DialogID_Welcome')),
  (guild) =>
      (guild.onJobBoard, Constant('GrandCross_HuntersGuild_DialogID_JobBoard')),
  (guild) =>
      (guild.onNoJobs, Constant('GrandCross_HuntersGuild_DialogID_NoJob')),
  (guild) =>
      (guild.onFarewell, Constant('GrandCross_HuntersGuild_DialogID_Farewell')),
  (guild) => (
        guild.onFirstJobMileDead,
        Constant('GrandCross_HuntersGuild_DialogID_MileDead')
      ),
  (guild) => (
        guild.onNotYetAvailable,
        Constant('GrandCross_HuntersGuild_DialogID_NotYetAvailable')
      ),
  (guild) => (
        guild.onNoLongerAvailable,
        Constant('GrandCross_HuntersGuild_DialogID_NoLongerAvailable')
      ),
  (guild) => (
        guild.onFirstJobNoLongerAvailable,
        Constant('GrandCross_HuntersGuild_DialogID_FirstJobNoLongerAvailable')
      ),
  (guild) => (
        guild.onAlreadyCompleted,
        Constant('GrandCross_HuntersGuild_DialogID_AlreadyCompleted')
      ),
];

void _compileReceptionistScene(Scene scene, Constant constant, GameMap map,
    Constants constants, DialogTrees dialogTrees, EventRoutines eventRoutines) {
  var tree = dialogTrees.forMap(map.id);
  var dialogId = tree.nextDialogId!;
  var eventAsm = EventAsm.empty();

  SceneAsmGenerator.forInteraction(
      map, SceneId(constant.constant), dialogTrees, eventAsm, eventRoutines,
      withObject: false)
    ..scene(scene)
    ..finish();

  if (eventAsm.withoutComments().withoutEmptyLines().isNotEmpty) {
    throw ArgumentError('receptionist scene cannot require event code. '
        'constant=$constant '
        'eventAsm={$eventAsm}');
  }

  constants.add(constant, dialogId);
}

void _compileJob(GuildJob job,
    {required Asm jobsAsm,
    required Asm titlesAsm,
    required EventFlags eventFlags,
    required GameMap map,
    required DialogTrees dialogTrees,
    required EventRoutines eventRoutines}) {
  jobsAsm.add(comment(job.title));

  jobsAsm.add(dc.b([
    eventFlags.toConstant(job.startFlag),
    eventFlags.toConstant(job.endFlag),
    eventFlags.toConstant(job.rewardedFlag),
  ]));

  jobsAsm.add(dc.b([
    for (var stage in [
      JobStage.available,
      JobStage.inProgress,
      JobStage.completed
    ])
      _compileJobScene(job, stage, map, dialogTrees, eventRoutines)
  ]));

  jobsAsm.add(dc.b([
    eventFlags.toConstant(job.availableWhen),
    eventFlags.toConstant(job.unavailableWhen),
  ]));

  jobsAsm.addNewline();

  titlesAsm.add(label(Label(_jobGuildTextLabels[job.id])));
  titlesAsm.add(dc.b(Bytes.ascii(job.title)));
  titlesAsm.add(dc.b([Byte(0xfe)]));
  titlesAsm.addNewline();
  titlesAsm.add(Asm.fromRaw('	even'));
  titlesAsm.addNewline();
}

Byte _compileJobScene(GuildJob job, JobStage stage, GameMap map,
    DialogTrees dialogTrees, EventRoutines eventRoutines) {
  var tree = dialogTrees.forMap(map.id);
  var dialogId = tree.nextDialogId!;
  var eventAsm = EventAsm.empty();

  var generator = SceneAsmGenerator.forInteraction(
      map,
      SceneId('GuildJob_${job.id}_${stage.name}'),
      dialogTrees,
      eventAsm,
      eventRoutines,
      withObject: false);

  var scene = stage.scene(job);

  if (scene.isNotEmpty) {
    generator.scene(scene);
  } else {
    generator.dialog(Dialog(spans: [DialogSpan('(${stage.name} ${job.id})')]));
  }

  generator.finish();

  if (eventAsm.withoutComments().withoutEmptyLines().isNotEmpty) {
    throw ArgumentError('job scene cannot require event code. '
        'jobId=${job.id} '
        'stage=$stage '
        'eventAsm:\n$eventAsm');
  }

  return dialogId;
}

const _jobGuildTextLabels = [
  "GuildText_RanchOwner",
  "GuildText_TinkerbellDog",
  "GuildText_MissingStudent",
  "GuildText_FissureFear",
  "GuildText_StainLife",
  "GuildText_DyingBoy",
  "GuildText_ManTwist",
  "GuildText_SilverSoldier",
];

Asm _compileMoneyTable(List<GuildJob> jobs) {
  checkArgument(jobs.length <= 8,
      message: 'cannot have more than 8 jobs in the guild. '
          'numJobs=${jobs.length}');
  var rewards = jobs.map((j) => j.reward).toList(growable: false);
  return dc.b(Bytes.list(rewards));
}
