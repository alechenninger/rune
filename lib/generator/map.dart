import 'package:rune/asm/dialog.dart';
import 'package:rune/asm/events.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/numbers.dart';

import '../asm/asm.dart';
import '../model/model.dart';

class MapAsm {
  final Asm sprites;
  final Asm objects;
  final Asm dialog;
  final Asm events;
  final Asm eventPointers;
  final Asm cutscenes;
  final Asm cutscenePointers;
  // might also need dialogTree ASM
  // if these labels need to be programmatically referred ot

  MapAsm({
    required this.sprites,
    required this.objects,
    required this.dialog,
    required this.events,
    required this.eventPointers,
    required this.cutscenes,
    required this.cutscenePointers,
  });

  @override
  String toString() {
    return [
      '; sprites',
      sprites,
      '; objects',
      objects,
      '; dialog',
      dialog,
      '; events',
      events,
      '; eventPointers',
      eventPointers,
      '; cutscenes',
      cutscenes,
      '; cutscenePointers',
      cutscenePointers
    ].join('\n');
  }
}

MapAsm mapToAsm(GameMap map, int eventPointersOffset) {
  var spritesAsm = Asm.empty();
  var dialogAsm = Asm.empty();
  var objectsAsm = Asm.empty();
  var eventsAsm = Asm.empty();
  var eventPointersAsm = Asm.empty();

  var vramTileNumbers = _generateSpriteAsm(map, spritesAsm);
  var dialogOffsets = _generateDialogAndEventsAsm(
      map, dialogAsm, eventsAsm, eventPointersAsm, eventPointersOffset);

  for (var obj in map.objects) {
    var spec = obj.spec;

    if (spec is Npc) {
      var routine = _npcBehaviorRoutines[spec.behavior];

      if (routine == null) {
        throw Exception(
            'no routine configured for npc behavior ${spec.behavior}');
      }

      objectsAsm.add(dc.w([routine]));
    } else {
      var routine = _mapObjectSpecRoutines[spec];

      if (routine == null) {
        throw Exception('no routine configured for spec $spec');
      }

      objectsAsm.add(dc.w([routine]));
    }
  }

  return MapAsm(
      sprites: spritesAsm,
      objects: objectsAsm,
      dialog: dialogAsm,
      events: eventsAsm,
      eventPointers: eventPointersAsm,
      cutscenes: Asm.empty(),
      cutscenePointers: Asm.empty());
}

Map<Sprite, Word> _generateSpriteAsm(GameMap map, Asm spritesAsm) {
  var vramOffset = _spriteVramOffsets[map.runtimeType];

  if (vramOffset == null) {
    throw Exception('no offset configured for map: ${map.runtimeType}');
  }

  var vramTileNumbers = <Sprite, Word>{};

  for (var i = 0,
          sprites = map.objects
              .map((e) => e.spec)
              .whereType<Npc>()
              .map((e) => e.sprite)
              .toSet()
              .toList(growable: false);
      i < sprites.length;
      i++) {
    var sprite = sprites[i];
    var artLbl = _spriteArtLabels[sprite];

    if (artLbl == null) {
      throw Exception('no art label configured for sprite: $sprite');
    }

    var tileNumber = Word(vramOffset + i * '48'.hex);
    vramTileNumbers[sprite] = tileNumber;

    spritesAsm.add(dc.w([tileNumber]));
    spritesAsm.add(dc.l([artLbl]));
  }

  return vramTileNumbers;
}

List<Byte> _generateDialogAndEventsAsm(GameMap map, Asm dialogAsm,
    Asm eventsAsm, Asm eventPointersAsm, int eventPointersOffset) {
  var dialogIdx = 0;
  var dialogOffsets = <Byte>[];

  for (var obj in map.objects) {
    // write dialog for each obj, may require disjoint dialogs based on
    // branching conditions, perhaps depending on other events
    // write event code
    // write event pointer for each event,
    // write the dialog offset which the obj should start with to array
  }

  return dialogOffsets;
}

Word _routineFor(MapObjectSpec spec) {
  if (spec is Npc) {
    var routine = _npcBehaviorRoutines[spec.behavior];

    if (routine == null) {
      throw Exception(
          'no routine configured for npc behavior ${spec.behavior}');
    }

    return routine;
  } else {
    var routine = _mapObjectSpecRoutines[spec];

    if (routine == null) {
      throw Exception('no routine configured for spec $spec');
    }

    return routine;
  }
}

final _spriteVramOffsets = {Aiedo: '29A'.hex, Piata: '2D0'.hex};

final _spriteArtLabels = {
  Sprite.palmanMan1: Label('Art_PalmanMan1'),
  Sprite.palmanMan2: Label('Art_PalmanMan2')
};

final _mapObjectSpecRoutines = {AlysWaiting(): Word('68'.hex)};

final _npcBehaviorRoutines = {FacingDown(): Word('38'.hex)};
