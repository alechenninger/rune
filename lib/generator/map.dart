import 'package:collection/collection.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/numbers.dart';

import '../asm/asm.dart';
import '../model/model.dart';
import 'generator.dart';

class MapAsm {
  final Asm sprites;
  final Asm objects;
  final Asm dialog;
  final Asm events;
  final Asm eventPointers;
  final Asm cutscenes;
  final Asm cutscenePointers;
  // might also need dialogTrees ASM
  // if these labels need to be programmatically referred to

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

extension MapToAsm on GameMap {
  MapAsm toAsm(AsmGenerator generator, AsmContext ctx) {
    return mapToAsm(this, generator, ctx);
  }
}

MapAsm mapToAsm(GameMap map, AsmGenerator generator, AsmContext ctx) {
  var spritesAsm = Asm.empty();
  var dialogAsm = Asm.empty();
  var objectsAsm = Asm.empty();
  var eventsAsm = Asm.empty();
  var eventPointersAsm = Asm.empty();

  if (map.objects.length > 64) {
    throw Exception('too many objects (limited ram)');
  }

  var vramTileNumbers = _generateSpriteAsm(map, spritesAsm);
  var dialogOffsets = _generateDialogAndEventsAsm(
      map, dialogAsm, eventsAsm, eventPointersAsm, ctx, generator);

  _generateObjectsAsm(map, objectsAsm, vramTileNumbers, dialogOffsets);

  return MapAsm(
      sprites: spritesAsm,
      objects: objectsAsm,
      dialog: dialogAsm,
      events: eventsAsm,
      eventPointers: eventPointersAsm,
      cutscenes: Asm.empty(),
      cutscenePointers: Asm.empty());
}

void _generateObjectsAsm(GameMap map, Asm objectsAsm,
    Map<Sprite, Word> vramTileNumbers, List<Byte> dialogOffsets) {
  map.objects.forEachIndexed((i, obj) {
    var spec = obj.spec;

    var facingAndDialog = dc.b([spec.startFacing.constant, dialogOffsets[i]]);

    if (spec is Npc) {
      var routine = _npcBehaviorRoutines[spec.behavior];

      if (routine == null) {
        throw Exception(
            'no routine configured for npc behavior ${spec.behavior}');
      }

      objectsAsm.add(dc.w([routine]));
      objectsAsm.add(facingAndDialog);

      // TODO: i think you can use 0 for invisible / no sprite
      // see Map_ZioFort
      var tileNumber = vramTileNumbers[spec.sprite];
      if (tileNumber == null) {
        throw Exception('no tile number for sprite ${spec.sprite}');
      }

      objectsAsm.add(dc.w([tileNumber]));
    } else {
      var routine = _mapObjectSpecRoutines[spec];

      if (routine == null) {
        throw Exception('no routine configured for spec $spec');
      }

      objectsAsm.add(dc.w([routine]));
      objectsAsm.add(facingAndDialog);
      // in this case we assume the vram tile does not matter?
      // TODO: if it does we need to track so do not reuse same
      // todo: is 0 okay?
      objectsAsm.add(
          // dc.w([vramTileNumbers.values.max() + Word(_vramOffsetPerSprite)]));
          dc.w([0.word]));
    }

    objectsAsm.add(
        dc.w([Word(obj.startPosition.x ~/ 8), Word(obj.startPosition.y ~/ 8)]));

    objectsAsm.addNewline();
  });
}

Map<Sprite, Word> _generateSpriteAsm(GameMap map, Asm spritesAsm) {
  var vramOffset = _spriteVramOffsets[map.id];

  if (vramOffset == null) {
    throw Exception('no offset configured for map: ${map.id}');
  }

  var vramTileNumbers = <Sprite, Word>{};

  map.objects
      .map((e) => e.spec)
      .whereType<Npc>()
      .map((e) => e.sprite)
      .toSet()
      .forEachIndexed((i, sprite) {
    var artLbl = _spriteArtLabels[sprite];

    if (artLbl == null) {
      throw Exception('no art label configured for sprite: $sprite');
    }

    var tileNumber = Word(vramOffset + i * _vramOffsetPerSprite);
    vramTileNumbers[sprite] = tileNumber;

    spritesAsm.add(dc.w([tileNumber]));
    spritesAsm.add(dc.l([artLbl]));
  });

  return vramTileNumbers;
}

List<Byte> _generateDialogAndEventsAsm(
    GameMap map,
    Asm dialogAsm,
    Asm eventsAsm,
    Asm eventPointersAsm,
    AsmContext ctx,
    AsmGenerator generator) {
  var dialogIdx = _dialogIdOffsets[map.id] ?? 0;
  var dialogOffsets = <Byte>[];
  var tree = DialogTree();

  ctx.state.currentMap = map;

  for (var obj in map.objects) {
    dialogOffsets.add(Byte(dialogIdx));

    // Interaction always starts with triggering dialog
    ctx.startDialogInteraction();

    var sceneAsm = generator.sceneToAsm(obj.onInteract, ctx, tree);

    dialogAsm.add(sceneAsm.allDialog);
    eventsAsm.add(sceneAsm.event);
    eventsAsm.addNewline();
    eventPointersAsm.add(sceneAsm.eventPointers);

    dialogIdx += sceneAsm.dialog.length;
  }

  return dialogOffsets;
}

final _vramOffsetPerSprite = '48'.hex;

// These offsets are used to account for assembly specifics, which allows for
// variances in maps to be coded manually (such as objects).
// todo: it might be nice to manage these with the assembly or the compiler
//  itself rather than hard coding here.

final _spriteVramOffsets = {
  MapId.aiedo: '29A'.hex,
  MapId.piata: '2D0'.hex,
  MapId.piataAcademyF1: '27F'.hex, // Map_PiataAcademy_F1
  MapId.piataAcademyPrincipalOffice: '27F'.hex, // Map_AcademyPrincipalOffice
};

// todo: this would only be used when we have events which refer to objects by
//   their location in memory. we would have to offset that location.
final _objectIndexOffsets = {
  MapId.piataAcademyF1: 1,
};

final _dialogIdOffsets = {
  MapId.piataAcademyF1: 1,
};

final _spriteArtLabels = {
  Sprite.palmanMan1: Label('Art_PalmanMan1'),
  Sprite.palmanMan2: Label('Art_PalmanMan2'),
  Sprite.palmanWoman1: Label('Art_PalmanWoman1'),
  Sprite.palmanWoman2: Label('Art_PalmanWoman2'),
};

final _mapObjectSpecRoutines = {AlysWaiting(): Word('68'.hex)};

final _npcBehaviorRoutines = {FacingDown(): Word('38'.hex)};

extension ReduceMax<E extends Comparable> on Iterable<E> {
  E max() {
    return reduce(
        (value, element) => value.compareTo(element) > 0 ? value : element);
  }
}
