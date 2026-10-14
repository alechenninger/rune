import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  for (var runObjects in [false, true]) {
    test('RunEvent pause dispatches before waiting with runObjects=$runObjects',
        () {
      var eventAsm = EventAsm.empty();
      var runEventAsm = Asm.empty();
      SceneAsmGenerator.forRunEvent(SceneId('Wait'),
          inMap: GameMap(MapId.Test),
          eventAsm: eventAsm,
          runEventAsm: runEventAsm,
          config: ProgramConfiguration.empty())
        ..pause(Pause(Duration(milliseconds: 500), runObjects: runObjects))
        ..finish();

      var routine = runObjects ? 'DoMainUpdatesLoop' : 'DoMapUpdateLoop';
      expect(runEventAsm.toString(), contains('Event_Index'));
      expect(runEventAsm.toString(), isNot(contains(routine)));
      expect(eventAsm.toString(), contains(routine));
    });
  }

  test('dialog transitions retain update permissions without a prior mode', () {
    var event =
        EventMode(type: EventType.event, execution: const TalkEventExecution());
    var dialog = event.enterDialogLoop();
    var afterDialog = dialog.exitDialogLoop();

    for (var mode in [event, dialog, afterDialog]) {
      expect(mode.priorMode, isNull);
      expect(mode.canRunMapUpdates, isFalse);
      expect(mode.canRunObjects, isFalse);
    }
  });
}
