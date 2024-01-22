import 'package:rune/generator/generator.dart';
import 'package:rune/model/guild.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  group('guild compiler generates', () {
    late Program program;
    late GameMap guildMap;

    setUp(() {
      program = Program();
      guildMap = GameMap(MapId.HuntersGuild);
    });

    test('job data for progress flags', () {
      var asm = program.configureHuntersGuild(HuntersGuildInteractions(),
          inMap: guildMap);
      var jobData = asm.guildJobs.withoutComments().withoutEmptyLines();
      expect(
          jobData[0],
          dc.b([
            Constant('EventFlag_TheRanchOwner'),
            Constant('EventFlag_MileSandWorm'),
            Constant('EventFlag_RanchOwnerFee')
          ]));
    });

    test('job data for availability flags', () {
      var asm = program.configureHuntersGuild(HuntersGuildInteractions(),
          inMap: guildMap);
      var jobData = asm.guildJobs.withoutComments().withoutEmptyLines();
      expect(
          jobData[2],
          dc.b([
            Constant('EventFlag_AlysFound'),
            Constant('EventFlag_Elsydeon')
          ]));
    });

    test('money table for job rewards', () {}, skip: 'TODO');

    test('guild text for job titles', () {}, skip: 'TODO');

    test('guild text for pending listing', () {}, skip: 'TODO');

    test('dialog for receptionist', () {}, skip: 'TODO');

    test('constants refer to the right receptionist dialog ids', () {},
        skip: 'TODO');
  });
}
