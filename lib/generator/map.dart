import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/collection.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/numbers.dart';
import 'package:rune/src/null.dart';

import '../asm/asm.dart';
import '../model/model.dart';
import 'dialog.dart';
import 'event.dart';
import 'generator.dart';

class MapAsm {
  final Asm sprites;
  final Asm objects;
  final Asm dialog;
  final Asm events;
  // todo: i think cutscenes asm is not needed
  // we just add both kinds of routines to events
  final Asm cutscenes;
  // might also need dialogTrees ASM
  // if these labels need to be programmatically referred to

  MapAsm({
    required this.sprites,
    required this.objects,
    required this.dialog,
    required this.events,
    required this.cutscenes,
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
      '; cutscenes',
      cutscenes,
    ].join('\n');
  }
}

const _defaultVramTilesPerSprite = 0x48;

// These offsets are used to account for assembly specifics, which allows for
// variances in maps to be coded manually (such as objects).
// todo: it might be nice to manage these with the assembly or the compiler
//  itself rather than hard coding here.
//  Program API would be the right place now that we have that.

// todo: this would only be used when we have events which refer to objects by
//   their location in memory. we would have to offset that location.
final _objectIndexOffsets = {MapId.PiataAcademyF1: 1, MapId.Piata: 3};

final _defaultDialogs = {
  MapId.PiataAcademyF1: DialogTree()..add(DialogAsm.emptyDialog()),
  MapId.Piata: DialogTree()..addAll(DialogAsm.fromRaw(_piataDialog).split()),
};
DialogTree _defaultDialogTree(MapId map) =>
    _defaultDialogs[map] ?? DialogTree();

// todo: default to convention & allow override
final _spriteArtLabels = BiMap<Sprite, Label>()
  ..addAll(Sprite.wellKnown.groupFoldBy(
      (sprite) => sprite, (previous, sprite) => Label('Art_${sprite.name}')));

final _mapObjectSpecRoutines = {
  AlysWaiting: FieldRoutine(Word('68'.hex), Label('FieldObj_NPCAlysPiata'),
      SpecFactory((_) => AlysWaiting())),
  AiedoShopperWithBags: FieldRoutine(Word(0x138), Label('loc_490B8'),
      SpecFactory((d) => AiedoShopperWithBags(d))),
  AiedoShopperMom: FieldRoutine(
      Word(0x13C), Label('loc_49128'), SpecFactory((_) => AiedoShopperMom())),
  Elevator: FieldRoutine(
      Word(0x120), Label('FieldObj_Elevator'), SpecFactory((d) => Elevator(d))),
};

final _npcBehaviorRoutines = {
  FaceDown: FieldRoutine(Word('38'.hex), Label('FieldObj_NPCType1'),
      SpecFactory.npc((s, _) => Npc(s, FaceDown()))),
  WanderAround: FieldRoutine(Word('3C'.hex), Label('FieldObj_NPCType2'),
      SpecFactory.npc((s, d) => Npc(s, WanderAround(d)))),
  SlowlyWanderAround: FieldRoutine(Word('40'.hex), Label('FieldObj_NPCType3'),
      SpecFactory.npc((s, d) => Npc(s, SlowlyWanderAround(d)))),
  FaceDownLegsHiddenNonInteractive: FieldRoutine(
      Word(0x140),
      Label('loc_49502'),
      SpecFactory.npc((s, _) => Npc(s, FaceDownLegsHiddenNonInteractive()),
          spriteMappingTiles: 8)),
  FixedFaceDownLegsHidden: FieldRoutine(
      Word(0x108),
      Label('FieldObj_NPCType32'),
      SpecFactory.npc((s, _) => Npc(s, FixedFaceDownLegsHidden()),
          spriteMappingTiles: 8)),
  FixedFaceRight: FieldRoutine(
      Word(0x14C),
      Label('loc_49502'),
      SpecFactory.npc((s, _) => Npc(s, FixedFaceRight()),
          spriteMappingTiles: 8)),
};

abstract class SpecFactory {
  bool get requiresSprite;

  /// How many VRAM tiles are needed by this routine, if [requiresSprite].
  ///
  /// If [requiresSprite] is [false], returns null.
  int? get spriteMappingTiles;
  MapObjectSpec call(Sprite? sprite, Direction facing);

  factory SpecFactory.npc(
      MapObjectSpec Function(Sprite sprite, Direction facing) factory,
      {int spriteMappingTiles = _defaultVramTilesPerSprite}) {
    return _NpcFactory(factory, spriteMappingTiles);
  }

  factory SpecFactory(MapObjectSpec Function(Direction facing) factory) {
    return _SpecFactory(factory);
  }
}

class _NpcFactory implements SpecFactory {
  @override
  final requiresSprite = true;
  @override
  final int spriteMappingTiles;
  final MapObjectSpec Function(Sprite sprite, Direction facing) _factory;
  _NpcFactory(this._factory, this.spriteMappingTiles);
  @override
  MapObjectSpec call(Sprite? sprite, Direction facing) =>
      _factory(sprite!, facing);
}

class _SpecFactory implements SpecFactory {
  @override
  final requiresSprite = false;
  @override
  final spriteMappingTiles = null;
  final MapObjectSpec Function(Direction facing) _factory;
  _SpecFactory(this._factory);
  @override
  MapObjectSpec call(Sprite? sprite, Direction facing) => _factory(facing);
}

final _specFactories = _buildSpecFactories();

Map<Word, SpecFactory> _buildSpecFactories() {
  var factories = <Word, SpecFactory>{};
  for (var routine in [
    ..._mapObjectSpecRoutines.values,
    ..._npcBehaviorRoutines.values
  ]) {
    factories[routine.index] = routine.factory;
  }
  return factories;
}

class FieldRoutine {
  final Word index;
  final Label label;
  final SpecFactory factory;

  const FieldRoutine(this.index, this.label, this.factory);

  @override
  String toString() {
    return 'FieldRoutine{index: $index, label: $label}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldRoutine &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          label == other.label;

  @override
  int get hashCode => index.hashCode ^ label.hashCode;
}

MapAsm compileMap(
    GameMap map, EventRoutines eventRoutines, int spriteVramOffset,
    {DialogTree? dialogTree}) {
  // TODO: move this out?
  var tree = dialogTree ?? _defaultDialogTree(map.id);
  var spritesAsm = Asm.empty();
  var objectsAsm = Asm.empty();
  var eventsAsm = EventAsm.empty();

  var objects = map.orderedObjects;

  if (objects.length > 64) {
    throw 'too many objects';
  }

  var objectsTileNumbers =
      _compileMapSpriteData(objects, spritesAsm, spriteVramOffset);

  var scenes = Map<Scene, Byte>.identity();

  for (var obj in objects) {
    var scene = obj.onInteract;
    var dialogId = scenes.putIfAbsent(
        scene,
        () => _compileInteractionScene(
            map,
            scene,
            // todo: scene id arbitrarily refers to first object referenced.
            // maybe scene id should be a part of scene after all
            SceneId('${map.id.name}_${obj.id}'),
            tree,
            eventsAsm,
            eventRoutines));
    var tileNumber = objectsTileNumbers[obj.id] ?? Word(0);
    _compileMapObjectData(objectsAsm, obj, tileNumber, dialogId);
  }

  return MapAsm(
      sprites: spritesAsm,
      objects: objectsAsm,
      dialog: tree.toAsm(),
      events: eventsAsm,
      cutscenes: Asm.empty());
}

Map<MapObjectId, Word> _compileMapSpriteData(
    List<MapObject> objects, Asm asm, int spriteVramOffset) {
  // aggregate all sprites and their vram tiles needed
  // aggregate all objects and their sprites
  // then assign vram tile numbers to objects.
  var mappingTiles = <Label, int>{};
  // The use of 'multimap' here is exactly why we need an aggregation:
  // a sprite maybe used by multiple objects,
  // and objects may have differing vram tiles needed.
  var objectSprites = Multimap<Label, MapObjectId>();

  for (var obj in objects) {
    var spec = obj.spec;
    Label? maybeLbl;

    if (spec is Npc) {
      // todo: factor this into function
      var routine = _npcBehaviorRoutines[spec.behavior.runtimeType];
      if (routine == null) {
        throw Exception(
            'no routine configured for npc behavior ${spec.behavior}');
      }

      maybeLbl = _spriteArtLabels[spec.sprite];

      if (maybeLbl == null) {
        throw Exception('no art label configured for sprite: ${spec.sprite}');
      }

      var tiles = routine.factory.spriteMappingTiles!;
      mappingTiles.update(maybeLbl, (current) => max(current, tiles),
          ifAbsent: () => tiles);
    } else if (spec is AsmSpec) {
      maybeLbl = spec.artLabel;
      if (maybeLbl != null) {
        mappingTiles.update(
            maybeLbl, (current) => max(current, _defaultVramTilesPerSprite),
            ifAbsent: () => _defaultVramTilesPerSprite);
      }
    }

    if (maybeLbl != null) {
      objectSprites.add(maybeLbl, obj.id);
    }
  }

  var objectTiles = <MapObjectId, Word>{};

  for (var entry in mappingTiles.entries) {
    var artLbl = entry.key;
    var mappingTiles = entry.value;

    // TODO: looks like max vram tile should be 28, 21 (x, y) = ~0x55c
    // >= 0x522~ seems to be weird
    // there are none defined past 4e2 which is one of the weird ones
    // loaded from ram
    // greatest one loaded normally is 4b8
    // is 0x500 right?
    if (spriteVramOffset > 0x500) {
      throw Exception('possibly too many sprites? '
          'only remove this exception after testing. '
          'tile number: $spriteVramOffset '
          'art label: ${artLbl.name} '
          'asm: $asm');
    }

    var tile = Word(spriteVramOffset);
    spriteVramOffset += mappingTiles;

    for (var obj in objectSprites[artLbl]) {
      objectTiles[obj] = tile;
    }

    asm.add(dc.w([tile]));
    asm.add(dc.l([artLbl]));
  }

  return objectTiles;
}

Byte _compileInteractionScene(GameMap map, Scene scene, SceneId id,
    DialogTree tree, EventAsm asm, EventRoutines eventRoutines) {
  var events = scene.events;

  // todo: handle max
  var dialogId = tree.nextDialogId!;

  SceneAsmGenerator generator =
      SceneAsmGenerator.forInteraction(map, id, tree, asm, eventRoutines);

  generator.runEventFromInteractionIfNeeded(events);

  for (var event in events) {
    event.visit(generator);
  }

  generator.finish(appendNewline: true);

  assert(tree.length > dialogId.value, "no interaction dialog in tree");

  return dialogId;
}

void _compileMapObjectData(
    Asm asm, MapObject obj, Word tileNumber, Byte dialogId) {
  var spec = obj.spec;
  var facingAndDialog = dc.b([spec.startFacing.constant, dialogId]);

  asm.add(comment(obj.id.toString()));

  // hacky?
  if (spec is Npc || spec is AsmSpec) {
    Word routineIndex;
    if (spec is Npc) {
      var routine = _npcBehaviorRoutines[spec.behavior.runtimeType];

      if (routine == null) {
        throw Exception(
            'no routine configured for npc behavior ${spec.behavior}');
      }
      routineIndex = routine.index;
    } else {
      // analyzer should be smart enough to know spec is AsmSpec?
      // but its not :(
      spec = spec as AsmSpec;
      routineIndex = spec.routine;
    }

    asm.add(dc.w([routineIndex]));
    asm.add(facingAndDialog);
    asm.add(dc.w([tileNumber]));
  } else {
    var routine = _mapObjectSpecRoutines[spec.runtimeType];

    if (routine == null) {
      throw Exception('no routine configured for spec $spec');
    }

    asm.add(dc.w([routine.index]));
    asm.add(facingAndDialog);
    // in this case we assume the vram tile does not matter?
    // TODO: if it does we need to track so do not reuse same
    // todo: is 0 okay?
    asm.add(
        // dc.w([vramTileNumbers.values.max() + Word(_vramOffsetPerSprite)]));
        dc.w([0.toWord]));
  }

  asm.add(
      dc.w([Word(obj.startPosition.x ~/ 8), Word(obj.startPosition.y ~/ 8)]));

  asm.addNewline();
}

extension ObjectRoutine on MapObject {
  FieldRoutine get routine {
    var spec = this.spec;
    var routine = spec is Npc
        ? _npcBehaviorRoutines[spec.behavior.runtimeType]
        : _mapObjectSpecRoutines[spec.runtimeType];
    if (routine == null) {
      if (routine == null) {
        throw Exception('no routine configured for spec $spec');
      }
    }
    return routine;
  }
}

extension ObjectAddress on GameMap {
  Longword addressOf(MapObject obj) {
    // ramaddr(Field_Obj_Secondary + 0x40 * object_index)
    // For example, Alys_Piata is at ramaddr(FFFFC4C0) and at object_index 7
    // ramaddr(FFFFC300 + 0x40 * 7) = ramaddr(FFFFC4C0)
    // Then load this via lea into a4
    // e.g. lea	(Alys_Piata).w, a4

    var index = this.indexOf(obj.id);

    if (index == null) {
      throw StateError('map object not found in map. obj=$obj map=$this');
    }

    var offset = _objectIndexOffsets[id] ?? 0;
    // field object secondary address + object size * index
    var address = 0xFFFFC300 + 0x40 * (index + offset);
    return Longword(address);
  }
}

Future<GameMap> asmToMap(
    Label mapLabel, Asm asm, DialogTreeLookup dialogLookup) async {
  var reader = ConstantReader.asm(asm);

  // skip general var, music, something else
  reader.skipThrough(times: 1, value: Size.w.maxValueSized);

  var sprites = _readSprites(reader);

  // skip secondary sprite data
  // such as those loaded into ram instead of vram
  reader.skipThrough(value: Size.w.maxValueSized, times: 2);

  // skip map updates
  reader.skipThrough(value: Size.b.maxValueSized, times: 1);

  // skip transition data 1 & 2
  reader.skipThrough(value: Size.w.maxValueSized, times: 2);

  var asmObjects = _readObjects(reader, sprites);

  // skip treasure and tile animations
  reader.skipThrough(value: Size.w.maxValueSized, times: 2);

  // on maps there are 2 labels before dialog,
  // except on motavia and dezolis
  // (this is simply hard coded based on map IDs)
  var mapId = _labelToMapId(mapLabel);
  Label dialogLabel;
  if ([MapId.Motavia, MapId.Dezolis].contains(mapId)) {
    dialogLabel = reader.readLabel();
  } else {
    reader.readLabel();
    reader.readLabel();
    dialogLabel = reader.readLabel();
  }

  var dialogTree = await dialogLookup.byLabel(dialogLabel);
  var mapObjects = _buildObjects(mapId, sprites, asmObjects, dialogTree);

  var map = GameMap(mapId);
  mapObjects.forEach(map.addObject);

  return map;
}

Map<Word, Label> _readSprites(ConstantReader reader) {
  var sprites = <Word, Label>{};

  while (true) {
    var vramTile = reader.readWord();
    //loc_519D2:
    // 	tst.w	(a0)
    // 	bmi.w	loc_51A14
    if (vramTile.isNegative) {
      return sprites;
    }
    var sprite = reader.readLabel();
    sprites[vramTile] = sprite;
  }
}

List<_AsmObject> _readObjects(ConstantReader reader, Map<Word, Label> sprites) {
  var objects = <_AsmObject>[];

  while (true) {
    var routineOrTerminate = reader.readWord();

    if (routineOrTerminate == Word(0xffff)) {
      return objects;
    }

    var facing = reader.readByte();
    var dialogId = reader.readByte();
    var vramTile = reader.readWord();
    var x = reader.readWord();
    var y = reader.readWord();

    var spec = _specFactories[routineOrTerminate];

    if (spec == null) {
      // In this case, we don't have this routine incorporated in the model
      // So populate the model with an escape hatch: raw ASM
      // We can decide to model in later if needed

      var spriteLbl = sprites[vramTile];
      spec = SpecFactory((d) => AsmSpec(
          artLabel: spriteLbl, routine: routineOrTerminate, startFacing: d));
    }

    var position = Position(x.value * 8, y.value * 8);

    objects.add(_AsmObject(
        routine: routineOrTerminate,
        spec: spec,
        facing: _byteToFacingDirection(facing),
        dialogId: dialogId,
        vramTile: vramTile,
        position: position));
  }
}

Direction _byteToFacingDirection(Byte w) {
  if (w == Byte(0)) return Direction.down;
  if (w == Byte(4)) return Direction.up;
  if (w == Byte(8)) return Direction.right;
  if (w == Byte(0xC)) return Direction.left;
  throw ArgumentError.value(w, 'w', 'is not a direction');
}

class _AsmObject {
  final Word routine;
  final SpecFactory spec;
  final Direction facing;
  final Byte dialogId;
  final Word vramTile;
  final Position position;

  _AsmObject(
      {required this.routine,
      required this.spec,
      required this.facing,
      required this.dialogId,
      required this.vramTile,
      required this.position});
}

List<MapObject> _buildObjects(MapId mapId, Map<Word, Label> sprites,
    List<_AsmObject> asmObjects, DialogTree dialogTree) {
  // The same scene must reuse same object in memory
  var scenesById = <Byte, Scene>{};

  return asmObjects.mapIndexed((i, asm) {
    var artLbl = sprites[asm.vramTile];

    if (asm.spec.requiresSprite && artLbl == null) {
      throw StateError('field object routine ${asm.routine} requires sprite '
          'but art label was null for tile number ${asm.vramTile}');
    }

    var sprite =
        _spriteArtLabels.inverse[artLbl] ?? artLbl?.map((l) => Sprite(l.name));
    var spec = asm.spec(sprite, asm.facing);
    var object = MapObject(
        id: '${mapId.name}_$i', startPosition: asm.position, spec: spec);

    if (spec is Interactive) {
      var scene = scenesById.putIfAbsent(
          asm.dialogId,
          // todo: if shared scene, default speaker may be misleading
          // but maybe better than nothing
          () => toScene(asm.dialogId.value, dialogTree,
              defaultSpeaker: object, isInteraction: true));
      (spec as Interactive).onInteract = scene;
    }

    return object;
  }).toList(growable: false);
}

MapId _labelToMapId(Label lbl) {
  var m = MapId.values.firstWhereOrNull((id) => Label('Map_${id.name}') == lbl);
  if (m != null) return m;
  m = _fallbackMapIdsByLabel[lbl];
  if (m == null) {
    throw UnimplementedError('no MapId defined for $lbl');
  }
  return m;
}

final _fallbackMapIdsByLabel = {
  Label('Map_PiataAcademy_F1'): MapId.PiataAcademyF1,
  Label('Map_AcademyPrincipalOffice'): MapId.PiataAcademyPrincipalOffice,
  Label('Map_ChazHouse'): MapId.ShayHouse,
  Label('Map_AcademyBasement'): MapId.PiataAcademyBasement,
  Label('Map_AcademyBasement_B1'): MapId.PiataAcademyBasementB1,
  Label('Map_AcademyBasement_B2'): MapId.PiataAcademyBasementB2,
};

const _piataDialog = r'''
; $40
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"My parents live in Mile, a"
	dc.b	$FC
	dc.b	"village northeast of here."
	dc.b	$FD
	dc.b	"Recently, I haven't been getting"
	dc.b	$FC
	dc.b	"my allowance. I wonder if"
	dc.b	$FD
	dc.b	"they've forgotten me?"
	dc.b	$FD
	dc.b	"Oh well, I better find a job."
	dc.b	$FD
	dc.b	"Becoming a hunter..."
	dc.b	$FC
	dc.b	"now that sounds exciting."
	dc.b	$FF

; $41
	dc.b	"Is it true that the village of"
	dc.b	$FC
	dc.b	"Mile has become a village of"
	dc.b	$FD
	dc.b	"death?"
	dc.b	$FD
	dc.b	"Dad! Mom!"
	dc.b	$FF

; $42
	dc.b	$FA
	dc.b	$DA, $02
	dc.b	$FA
	dc.b	$0C, $01
	dc.b	"Just when it seemed that the"
	dc.b	$FC
	dc.b	"number of monsters was"
	dc.b	$FD
	dc.b	"decreasing, they're now roaming"
	dc.b	$FC
	dc.b	"in the town!"
	dc.b	$FD
	dc.b	"Do you think this is some"
	dc.b	$FC
	dc.b	"kind of omen?"
	dc.b	$FF

; $43
	dc.b	"Apparently, the monsters aren't"
	dc.b	$FC
	dc.b	"appearing in town anymore."
	dc.b	$FD
	dc.b	"Thank goodness for that."
	dc.b	$FF

; $44
	dc.b	"Th...this universe is coming to "
	dc.b	$FC
	dc.b	"an end."
	dc.b	$FF

; $45
	dc.b	$FA
	dc.b	$DA, $02
	dc.b	$FA
	dc.b	$0C, $01
	dc.b	"No monster can get into this"
	dc.b	$FC
	dc.b	"town. The wall surrounding the"
	dc.b	$FD
	dc.b	"town will protect us."
	dc.b	$FD
	dc.b	"That's why I think those strange"
	dc.b	$FC
	dc.b	"monsters must be appearing from"
	dc.b	$FD
	dc.b	"within the town."
	dc.b	$FD
	dc.b	"I think there's something mighty"
	dc.b	$FC
	dc.b	"suspicious about the research"
	dc.b	$FD
	dc.b	"going on at the academy."
	dc.b	$FF

; $46
	dc.b	"I heard those monsters were"
	dc.b	$FC
	dc.b	"conquered by some hunter whose"
	dc.b	$FD
	dc.b	"name I've forgotten."
	dc.b	$FF

; $47
	dc.b	"You say poison is coming out of"
	dc.b	$FC
	dc.b	"the hole?"
	dc.b	$FD
	dc.b	"Hey! Is that true?"
	dc.b	$FF

; $48
	dc.b	$FA
	dc.b	$DA, $02
	dc.b	$FA
	dc.b	$0C, $01
	dc.b	"I saw it! In the middle of the"
	dc.b	$FC
	dc.b	"night, some suspicious-looking"
	dc.b	$FD
	dc.b	"men carried a big parcel into "
	dc.b	$FC
	dc.b	"the academy!"
	dc.b	$FD
	dc.b	"This happened some time ago,"
	dc.b	$FC
	dc.b	"but I wonder what it could've"
	dc.b	$FD
	dc.b	"been!"
	dc.b	$FF

; $49
	dc.b	"Now that I look back,"
	dc.b	$FC
	dc.b	"I wonder if there was some"
	dc.b	$FD
	dc.b	"connection between that parcel"
	dc.b	$FC
	dc.b	"and the monsters?"
	dc.b	$FF

; $4A
	dc.b	"I can't tell what's going on."
	dc.b	$FD
	dc.b	"Only the fact"
	dc.b	$FC
	dc.b	"that there's a hole..."
	dc.b	$FF

; $4B
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"What's with you guys?"
	dc.b	$FD
	dc.b	"You're being way too"
	dc.b	$FC
	dc.b	"friendly!"
	dc.b	$FF

; $4C
	dc.b	"H...heeelp!"
	dc.b	$FF

; $4D
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"I'm studying geology."
	dc.b	$FD
	dc.b	"Recently, the soil quality has"
	dc.b	$FC
	dc.b	"been deteriorating."
	dc.b	$FD
	dc.b	"Crops barely grow on this farm."
	dc.b	$FD
	dc.b	"My boyfriend,in the agricultural"
	dc.b	$FC
	dc.b	"department, is rather upset."
	dc.b	$FF

; $4E
	dc.b	"This can't all be explained"
	dc.b	$FC
	dc.b	"away by saying that the ground"
	dc.b	$FD
	dc.b	"surface suddenly began to sink!"
	dc.b	$FF

; $4F
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"We're still all right here,"
	dc.b	$FC
	dc.b	"but apparently the wells are all"
	dc.b	$FD
	dc.b	"dried up in the village of Mile!"
	dc.b	$FF

; $50
	dc.b	"If Mile is in trouble,"
	dc.b	$FC
	dc.b	"we're going to be in trouble"
	dc.b	$FD
	dc.b	"soon!"
	dc.b	$FF

; $51
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"I heard some students jumped"
	dc.b	$FC
	dc.b	"into this fountain the other"
	dc.b	$FD
	dc.b	"day."
	dc.b	$FD
	dc.b	"I can't believe I missed all"
	dc.b	$FC
	dc.b	"the fun."
	dc.b	$FD
	dc.b	"You should take a dip, it'll"
	dc.b	$FC
	dc.b	"do you good."
	dc.b	$FF

; $52
	dc.b	"Ahhhhhhh!"
	dc.b	$FF

; $53
	dc.b	$FA
	dc.b	$DA, $02
	dc.b	$FA
	dc.b	$0C, $01
	dc.b	"Orders from the principal."
	dc.b	$FC
	dc.b	"I can't allow anyone to pass"
	dc.b	$FD
	dc.b	"beyond this point!"
	dc.b	$FF

; $54
	dc.b	"This is the university town of"
	dc.b	$FC
	dc.b	"Piata."
	dc.b	$FD
	dc.b	"It's a town for students"
	dc.b	$FC
	dc.b	"and academics."
	dc.b	$FF

; $55
	dc.b	"This is the town Piata, but"
	dc.b	$FC
	dc.b	"there's no time for chatter!"
	dc.b	$FD
	dc.b	"To the north, near Mile,"
	dc.b	$FC
	dc.b	"there's a big hole!"
	dc.b	$FF

; $56
	dc.b	$FF

; $57
	dc.b	$FA
	dc.b	$2A, $05
	dc.b	$FA
	dc.b	$27, $03
	dc.b	$FA
	dc.b	$26, $02
	dc.b	$FA
	dc.b	$44, $01
	dc.b	"These are the student dorms"
	dc.b	$FC
	dc.b	"of Motavia Academy."
	dc.b	$FD
	dc.b	"Me? I'm the caretaker."
	dc.b	$FF

; $58
	dc.b	"I thought if I let things"
	dc.b	$FC
	dc.b	"alone, they would eventually"
	dc.b	$FD
	dc.b	"come back, but they still..."
	dc.b	$FD
	dc.b	"Oh, it's nothing,"
	dc.b	$FC
	dc.b	"nothing to do with you!"
	dc.b	$FF

; $59
	dc.b	$F6
	dc.w	$0076	; => Event_PiataDormOwner
	dc.b	$FF

; $5A
	dc.b	"Thank you"
	dc.b	$FC
	dc.b	"for your help in this matter."
	dc.b	$FF

; $5B
	dc.b	"Thank you so much!"
	dc.b	$FD
	dc.b	"Now we can keep up appearances"
	dc.b	$FC
	dc.b	"at this dorm."
	dc.b	$FD
	dc.b	"We shall remit the agreed upon"
	dc.b	$FC
	dc.b	"fee to the guild!"
	dc.b	$FD
	dc.b	"Oh, and also...I would"
	dc.b	$FC
	dc.b	"appreciate it if you could"
	dc.b	$FD
	dc.b	"keep this matter to yourselves."
	dc.b	$FF

; $5C
	dc.b	"Thank you for your assistance."
	dc.b	$FF

; $5D
	dc.b	$FA
	dc.b	$65, $01
	dc.b	"I've got a report due tomorrow,"
	dc.b	$FC
	dc.b	"but I haven't written a word"
	dc.b	$FD
	dc.b	"of it!"
	dc.b	$FF

; $5E
	dc.b	"'Fail'..."
	dc.b	$FD
	dc.b	"I guess it's no wonder"
	dc.b	$FC
	dc.b	"considering that I didn't"
	dc.b	$FD
	dc.b	"get the report in on time..."
	dc.b	$FC
	dc.b	"Boo hoo."
	dc.b	$FF

; $5F
	dc.b	$FA
	dc.b	$DA, $03
	dc.b	$FA
	dc.b	$2A, $02
	dc.b	$FA
	dc.b	$26, $01
	dc.b	"It's so much fun lazing around"
	dc.b	$FC
	dc.b	"than going to class."
	dc.b	$FF

; $60
	dc.b	"The girl in the room next door?"
	dc.b	$FC
	dc.b	"Come to think of it,"
	dc.b	$FD
	dc.b	"I haven't seen her recently."
	dc.b	$FF

; $61
	dc.b	"The girl in the room next door"
	dc.b	$FC
	dc.b	"is back?"
	dc.b	$FD
	dc.b	"I didn't know that."
	dc.b	$FF

; $62
	dc.b	"When it's this crazy,"
	dc.b	$FC
	dc.b	"I want to go to the academy"
	dc.b	$FD
	dc.b	"even less."
	dc.b	$FF

; $63
	dc.b	$FA
	dc.b	$DA, $03
	dc.b	$FA
	dc.b	$2A, $02
	dc.b	$FA
	dc.b	$26, $01
	dc.b	"The girl next door has been"
	dc.b	$FC
	dc.b	"influenced by some strange"
	dc.b	$FD
	dc.b	"religion."
	dc.b	$FD
	dc.b	"She's been missing for a while."
	dc.b	$FC
	dc.b	"Where did she go?"
	dc.b	$FF

; $64
	dc.b	"The girl next door"
	dc.b	$FC
	dc.b	"hasn't come back yet."
	dc.b	$FD
	dc.b	"I wonder where she is"
	dc.b	$FC
	dc.b	"and what she's doing..."
	dc.b	$FF

; $65
	dc.b	"The girl next door"
	dc.b	$FC
	dc.b	"has returned!"
	dc.b	$FD
	dc.b	"It appears she has no memory of"
	dc.b	$FC
	dc.b	"what happened to her while"
	dc.b	$FD
	dc.b	"she was gone..."
	dc.b	$FC
	dc.b	"I'm very concerned."
	dc.b	$FF

; $66
	dc.b	"What did you say happened?"
	dc.b	$FF

; $67
	dc.b	$FA
	dc.b	$DA, $02
	dc.b	$FA
	dc.b	$65, $01
	dc.b	"Hey! I'm undressing!"
	dc.b	$FC
	dc.b	"Get out! Get out!!!"
	dc.b	$FF

; $68
	dc.b	"I'm still getting undressed!"
	dc.b	$FC
	dc.b	"Get out! get out!!!"
	dc.b	$FF

; $69
	dc.b	"I'm getting undressed, you know!"
	dc.b	$FC
	dc.b	"So leave!"
	dc.b	$FF

; $6A
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"What...have I been"
	dc.b	$FC
	dc.b	"doing all this time...?"
	dc.b	$FD
	dc.b	"When I try to remember what"
	dc.b	$FC
	dc.b	"happened, I get a headache..."
	dc.b	$FF

; $6B
	dc.b	"I have...a terrible headache..."
	dc.b	$FC
	dc.b	"What...is this!?"
	dc.b	$FF

; $6C
	dc.b	"Oh, you're the hunter from the"
	dc.b	$FC
	dc.b	"guild? Pl...please help!"
	dc.b	$FD
	dc.b	"The fact of the matter is that"
	dc.b	$FC
	dc.b	"one of the female students"
	dc.b	$FD
	dc.b	"living here is missing!"
	dc.b	$FD
	dc.b	"Apparently, she has become an"
	dc.b	$FC
	dc.b	"enthusiastic devotee of some"
	dc.b	$FD
	dc.b	"kind of religion and just up"
	dc.b	$FC
	dc.b	"and left."
	dc.b	$FD
	dc.b	"I thought the infatuation would"
	dc.b	$FC
	dc.b	"pass and eventually she'd come"
	dc.b	$FD
	dc.b	"back, but she still hasn't..."
	dc.b	$FD
	dc.b	"I have the terrible"
	dc.b	$FC
	dc.b	"responsibility of being"
	dc.b	$FD
	dc.b	"entrusted with the care of"
	dc.b	$FC
	dc.b	"another's child!"
	dc.b	$FD
	dc.b	"With a blunder like this, even"
	dc.b	$FC
	dc.b	"the academy's reputation could"
	dc.b	$FD
	dc.b	"be tarnished!"
	dc.b	$FD
	dc.b	"Please, could you bring her back"
	dc.b	$FC
	dc.b	"here before things become known"
	dc.b	$FD
	dc.b	"to the public?"
	dc.b	$FD
	dc.b	"I appreciate the trouble"
	dc.b	$FC
	dc.b	"I'm putting you through."
	dc.b	$FF
''';
