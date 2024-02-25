import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';

Asm generateEventAsm(List<Event> events,
    {EventState? context, GameMap? inMap}) {
  var asm = EventAsm.empty();
  var gen = SceneAsmGenerator.forEvent(SceneId('test'), DialogTrees(), asm,
      startingMap: inMap)
    ..setContext(setContext(context));
  for (var e in events) {
    e.visit(gen);
  }
  gen.finish();
  return asm.withoutComments();
}

class TestEventRoutines extends EventRoutines {
  final eventRoutines = <Label>[];
  final cutsceneRoutines = <Label>[];

  @override
  Word addEvent(Label name) {
    eventRoutines.add(name);
    return Word(eventRoutines.length - 1);
  }

  @override
  Word addCutscene(Label name) {
    cutsceneRoutines.add(name);
    return Word(cutsceneRoutines.length - 1);
  }
}

SetContext setContext(EventState? ctx) {
  return SetContext((c) {
    c.followLead = ctx?.followLead ?? c.followLead;
    ctx?.positions.forEach((obj, pos) => c.positions[obj] = pos);
  });
}

MapObject testObjectForScene(Scene scene, {String id = '0'}) {
  return MapObject(
      id: id,
      startPosition: Position(0x200, 0x200),
      spec: Npc(Sprite.PalmanWoman1,
          WanderAround(Direction.down, onInteract: scene)));
}

extension EasyIntDuration on int {
  Duration get second => Duration(seconds: this);
  Duration get seconds => Duration(seconds: this);
}

extension EasyDoubleDuration on double {
  Duration get second => Duration(milliseconds: (this * 1000).truncate());
  Duration get seconds => Duration(milliseconds: (this * 1000).truncate());
}
