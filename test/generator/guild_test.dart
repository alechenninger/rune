import 'package:rune/generator/generator.dart';
import 'package:rune/model/guild.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  group('guild compiler generates', () {
    late Program program;
    late GameMap guildMap;
    late HuntersGuildInteractions guild;

    setUp(() {
      program = Program();
      guildMap = GameMap(MapId.HuntersGuild);
      guild = HuntersGuildInteractions();
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

    group('receptionist', () {
      test('dialog', () {}, skip: "TODO");

      test('event flag constants if there are conditional checks', () {
        guild.clerkInteraction(ClerkInteraction.welcome).onInteract = Scene([
          IfFlag(EventFlag('some_new_flag'),
              isSet: [Dialog.parse('flag set')],
              isUnset: [Dialog.parse('flag not set')])
        ]);
        program.configureHuntersGuild(guild, inMap: guildMap);

        expect(program.extraConstants().map((l) => l.toString()),
            containsOnce(matches(r'EventFlag_some_new_flag\s=\s\S*')));
      });
    });

    test('constants refer to the right receptionist dialog ids', () {},
        skip: 'TODO');
  });
}
