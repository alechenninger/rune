import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/collection.dart';
import 'package:quiver/iterables.dart' as iterables;
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
  final Asm areas;
  @Deprecated('use DialogTrees API instead')
  final Asm? dialog;
  final Asm events;
  // might also need dialogTrees ASM
  // if these labels need to be programmatically referred to

  MapAsm(
      {required this.sprites,
      required this.objects,
      required this.areas,
      required this.dialog,
      required this.events});

  MapAsm.empty()
      : sprites = Asm.empty(),
        objects = Asm.empty(),
        areas = Asm.empty(),
        dialog = Asm.empty(),
        events = Asm.empty();

  @override
  String toString() {
    return [
      '; sprites',
      sprites,
      '; objects',
      objects,
      '; areas',
      areas,
      '; events',
      events,
    ].join('\n');
  }
}

Constant mapIdToAsm(MapId map) {
  switch (map) {
    case MapId.ShayHouse:
      return Constant('MapID_ChazHouse');
    case MapId.PiataAcademyF1:
      return Constant('MapID_PiataAcademy_F1');
    case MapId.PiataAcademyPrincipalOffice:
      return Constant('MapID_AcademyPrincipalOffice');
    case MapId.PiataAcademyBasement:
      return Constant('MapID_AcademyBasement');
    case MapId.PiataAcademyBasementB1:
      return Constant('MapID_AcademyBasement_B1');
    case MapId.PiataAcademyBasementB2:
      return Constant('MapID_AcademyBasement_B2');
    default:
      return Constant('MapID_${map.name}');
  }
}

MapId? asmToMapId(Constant c) {
  var id = c.constant.substring(6);
  switch (id) {
    case 'ChazHouse':
      return MapId.ShayHouse;
    case 'PiataAcademy_F1':
      return MapId.PiataAcademyF1;
    case 'AcademyPrincipalOffice':
      return MapId.PiataAcademyPrincipalOffice;
    case 'AcademyBasement':
      return MapId.PiataAcademyBasement;
    case 'AcademyBasement_B1':
      return MapId.PiataAcademyBasementB1;
    case 'AcademyBasement_B2':
      return MapId.PiataAcademyBasementB2;
    default:
      return MapId.values.firstWhereOrNull((v) => v.name == id);
  }
}

extension MapIdAsm on MapId {
  Constant get toAsm => mapIdToAsm(this);
}

const _defaultVramTilesPerSprite = 0x48;

// These offsets are used to account for assembly specifics, which allows for
// variances in maps to be coded manually (such as objects).
// todo: it might be nice to manage these with the assembly or the compiler
//  itself rather than hard coding here.
//  Program API would be the right place now that we have that.

// todo: now that we automatically boostrap maps, maybe remove this
final _objectIndexOffsets = <MapId, int>{};

// todo: default to convention & allow override
final _spriteArtLabels = BiMap<Sprite, Label>()
  ..addAll(Sprite.wellKnown.groupFoldBy(
      (sprite) => sprite, (previous, sprite) => Label('Art_${sprite.name}')));

// todo: can use field objects jmp tbl in objects.dart now
final _mapObjectSpecRoutines = {
  AlysWaiting: FieldRoutine(Word('68'.hex), Label('FieldObj_NPCAlysPiata'),
      SpecFactory((_) => AlysWaiting())),
  AiedoShopperWithBags: FieldRoutine(Word(0x138), Label('loc_490B8'),
      SpecFactory((d) => AiedoShopperWithBags(d))),
  AiedoShopperMom: FieldRoutine(
      Word(0x13C), Label('loc_49128'), SpecFactory((_) => AiedoShopperMom())),
  Elevator: FieldRoutine(
      Word(0x120), Label('FieldObj_Elevator'), SpecFactory((d) => Elevator(d))),
  InvisibleBlock: FieldRoutine(Word(0x74), Label('FieldObj_InvisibleBlock'),
      SpecFactory((_) => InvisibleBlock())),
};

// TODO(generation): it would be nice if we could describe mapping needs
//  for routines without having to create model objects
// After creating the parser, the high level model is less useful.
// Kinda just boilerplate.
final _npcBehaviorRoutines = {
  FaceDown: FieldRoutine(Word('38'.hex), Label('FieldObj_NPCType1'),
      SpecFactory.npc((s, _) => Npc(s, FaceDown()))),
  FaceDownSimpleSprite: FieldRoutine(
      Word(0x134),
      Label('FieldObj_Pana'),
      SpecFactory.npc((s, _) => Npc(s, FaceDownSimpleSprite()),
          spriteMappingTiles: 18)),
  WanderAround: FieldRoutine(Word('3C'.hex), Label('FieldObj_NPCType2'),
      SpecFactory.npc((s, d) => Npc(s, WanderAround(d)))),
  SlowlyWanderAround: FieldRoutine(Word('40'.hex), Label('FieldObj_NPCType3'),
      SpecFactory.npc((s, d) => Npc(s, SlowlyWanderAround(d)))),
  FaceDownLegsHiddenNonInteractive: FieldRoutine(
      Word(0x140),
      Label('loc_49502'),
      SpecFactory.npc((s, _) => Npc(s, FaceDownLegsHiddenNonInteractive()),
          spriteMappingTiles: 8)),
  FaceDownOrUpLegsHidden: FieldRoutine(
      Word(0x108),
      Label('FieldObj_NPCType32'),
      SpecFactory.npc((s, _) => Npc(s, FaceDownOrUpLegsHidden()),
          spriteMappingTiles: 0x38)),
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
    GameMap map, EventRoutines eventRoutines, Word? spriteVramOffset,
    {required DialogTrees dialogTrees, required EventFlags eventFlags}) {
  var trees = dialogTrees;
  var spritesAsm = Asm.empty();
  var objectsAsm = Asm.empty();
  var areasAsm = Asm.empty();
  var eventsAsm = EventAsm.empty();

  var objects = map.orderedObjects;

  if (objects.length > 64) {
    throw 'too many objects';
  }

  var objectsTileNumbers =
      _compileMapSpriteData(objects, spritesAsm, spriteVramOffset?.value);

  var scenes = Map<Scene, Byte>.identity();

  Byte compileInteraction(Scene scene, SceneId id, {required bool withObject}) {
    return scenes.putIfAbsent(
        scene,
        () => _compileInteractionScene(
            map, scene, id, trees, eventsAsm, eventRoutines, eventFlags,
            withObject: withObject));
  }

  for (var obj in objects) {
    var dialogId = compileInteraction(
        obj.onInteract, SceneId('${map.id.name}_${obj.id}'),
        withObject: true);
    var tileNumber = objectsTileNumbers[obj.id] ?? Word(0);
    _compileMapObjectData(objectsAsm, obj, tileNumber, dialogId);
  }

  for (var area in map.areas) {
    _compileMapAreaData(
        areasAsm,
        area,
        eventFlags,
        (s) => compileInteraction(s, SceneId('${map.id.name}_${area.id}'),
            withObject: false));
  }

  return MapAsm(
      sprites: spritesAsm,
      objects: objectsAsm,
      areas: areasAsm,
      dialog: trees.forMap(map.id).toAsm(),
      events: eventsAsm);
}

Map<MapObjectId, Word> _compileMapSpriteData(
    List<MapObject> objects, Asm asm, int? spriteVramOffset) {
  // aggregate all sprites and their vram tiles needed
  // aggregate all objects and their sprites
  // then assign vram tile numbers to objects.
  var vramMapping = <Label, _SpriteVramMapping>{};
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

      // try the sprite name as a label itself if not preconfigured
      maybeLbl = _spriteArtLabels[spec.sprite] ?? Label(spec.sprite.name);

      var tiles = routine.factory.spriteMappingTiles!;

      // Bit of a hack for this one sprite;
      // can clean it up if it turns out other sprites need similar treatment
      var mapping = (maybeLbl == Label('Art_GuildReceptionist') &&
              tiles >= 0x38 /* 0x28 offset + 16 tile width in sprite */)
          ? _SpriteVramMapping(tiles, [0x28])
          : _SpriteVramMapping(tiles);

      vramMapping.update(maybeLbl, (current) => current.merge(mapping),
          ifAbsent: () => mapping);
    } else if (spec is AsmSpec) {
      maybeLbl = spec.artLabel;
      if (maybeLbl != null) {
        // Get custom vram tile width if known for this routine,
        // even though it's not specified in the model.
        var factory = _specFactories[spec.routine];
        var tiles = factory?.spriteMappingTiles;
        var spriteMapping = tiles == null
            ? _SpriteVramMapping.defaults()
            : _SpriteVramMapping(tiles);

        vramMapping.update(maybeLbl, (current) => current.merge(spriteMapping),
            ifAbsent: () => spriteMapping);
      }
    }

    if (maybeLbl != null) {
      objectSprites.add(maybeLbl, obj.id);
    }
  }

  var objectTiles = <MapObjectId, Word>{};
  // If need to support required mappings...
  // This happens when hard coded in routine, but where the sprite
  // is still variable.
  // Maybe if the sprite isn't really variable, we just define it
  // in the map data? (past normal vram mappings)
  // var requiredMappings = PriorityQueue<_SpriteVramMapping>(
  //     (a, b) => a.requiredVramTile!.compareTo(b.requiredVramTile!));

  for (var entry in vramMapping.entries) {
    if (spriteVramOffset == null) {
      throw Exception('no vram offsets defined but map has sprites. '
          'objects=${objectTiles.keys}');
    }

    var artLbl = entry.key;
    var mapping = entry.value;

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

    // if (requiredMappings.isNotEmpty) {
    //   var required = requiredMappings.first;
    //   if (required.requiredVramTile! <= tile) {
    //     tile = required.requiredVramTile!;
    //     mapping = required;
    //     requiredMappings.removeFirst();
    //   }
    // }

    spriteVramOffset += mapping.tiles;

    for (var obj in objectSprites[artLbl]) {
      objectTiles[obj] = tile;
    }

    asm.add(dc.w([tile]));
    asm.add(dc.l([artLbl]));

    for (var offset in mapping.duplicateOffsets) {
      asm.add(dc.w([Word(tile.value + offset)]));
      asm.add(dc.l([artLbl]));
    }
  }

  return objectTiles;
}

class _SpriteVramMapping {
  /// The total tiles required by the sprite
  final int tiles;

  /// Additional offsets in vram which duplicate the sprite.
  ///
  /// This is used for sprites where the sprite data
  /// does not alone account for all facing directions needed.
  final List<int> duplicateOffsets;

  // See notes in _compileMapSpriteData
  // final Word? requiredVramTile;

  const _SpriteVramMapping(this.tiles, [this.duplicateOffsets = const []]);

  const _SpriteVramMapping.defaults() : this(_defaultVramTilesPerSprite);

  _SpriteVramMapping merge(_SpriteVramMapping other) {
    if (other.duplicateOffsets != duplicateOffsets) {
      throw ArgumentError.value(other, 'other',
          'cannot merge different duplicate offsets. this=$this');
    }
    return _SpriteVramMapping(max(tiles, other.tiles), duplicateOffsets);
  }

  @override
  String toString() {
    return '_SpriteVramMapping{tiles: $tiles, offsets: $duplicateOffsets}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SpriteVramMapping &&
          runtimeType == other.runtimeType &&
          tiles == other.tiles &&
          duplicateOffsets == other.duplicateOffsets;

  @override
  int get hashCode => tiles.hashCode ^ duplicateOffsets.hashCode;
}

Byte _compileInteractionScene(
    GameMap map,
    Scene scene,
    SceneId id,
    DialogTrees trees,
    EventAsm asm,
    EventRoutines eventRoutines,
    EventFlags eventFlags,
    {required bool withObject}) {
  var events = scene.events;

  // todo: handle max
  var tree = trees.forMap(map.id);
  var dialogId = tree.nextDialogId!;

  SceneAsmGenerator generator = SceneAsmGenerator.forInteraction(
      map, id, trees, asm, eventRoutines,
      eventFlags: eventFlags, withObject: withObject);

  generator.runEventFromInteractionIfNeeded(events);

  for (var event in events) {
    event.visit(generator);
  }

  generator.finish(appendNewline: true);

  if (tree.length <= dialogId.value) {
    throw ArgumentError("no interaction dialog for ${map.id} in scene");
  }

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

void _compileMapAreaData(Asm asm, MapArea area, EventFlags eventFlags,
    Byte Function(Scene s) compileScene) {
  var spec = area.spec;

  asm.add(comment(area.id.toString()));
  asm.add(dc.w([for (var i in area.position.asList) Word(i ~/ 8)],
      comment: area.position.toString()));
  asm.add(dc.w([_rangeTypeId(area.range)], comment: area.range.name));

  if (spec is AsmArea) {
    asm.add(dc.b([
      spec.eventType,
      spec.eventFlag,
      spec.interactionRoutine,
      spec.interactionParameter
    ]));
  } else if (spec is InteractiveAreaSpec) {
    var dialogId = compileScene(spec.onInteract);

    Expression flag;
    var doNotInteractIf = spec.doNotInteractIf;
    if (doNotInteractIf != null) {
      var value = eventFlags.toConstantValue(doNotInteractIf);
      if (value.value >= Byte.max) {
        throw Exception('extended event flags not supported for interaction '
            'area check. eventFlag=$value');
      }
      flag = value.constant;
    } else {
      flag = Byte.zero;
    }

    asm.add(dc.b([
      Byte.zero, // always a story event
      flag,
      Byte(7), // Interaction_DisplayDialogueGrandCross
      dialogId,
    ]));
  } else {
    throw UnsupportedError('unsupported area spec: $spec');
  }

  asm.addNewline();
}

extension ObjectRoutine on MapObject {
  FieldRoutine get routine {
    var spec = this.spec;

    if (spec is AsmSpec) {
      var index = spec.routine;
      var label = labelOfFieldObjectRoutine(index);
      if (label == null) {
        throw Exception('invalid field object routine index: $index');
      }
      var factory = SpecFactory((d) =>
          AsmSpec(artLabel: spec.artLabel, routine: index, startFacing: d));
      return FieldRoutine(index, label, factory);
    } else {
      var routine = spec is Npc
          ? _npcBehaviorRoutines[spec.behavior.runtimeType]
          : _mapObjectSpecRoutines[spec.runtimeType];
      if (routine == null) {
        throw Exception('no routine configured for spec $spec');
      }
      return routine;
    }
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

FutureOr<Word?> firstSpriteVramTileOfMap(Asm asm) {
  var reader = ConstantReader.asm(asm);
  // skip general var, music, something else
  _skipToSprites(reader);
  var sprites = _readSprites(reader);
  return sprites.keys.sorted((a, b) => a.compareTo(b)).firstOrNull;
}

List<(MapId, Position, Direction, PartyArrangement)> mapTransitions(Asm asm) {
  var reader = ConstantReader.asm(asm);

  _skipToSprites(reader);
  _readSprites(reader);

  // skip secondary sprite data
  // such as those loaded into ram instead of vram
  reader.skipThrough(value: Size.w.maxValueSized, times: 2);

  // skip map updates
  reader.skipThrough(value: Size.b.maxValueSized, times: 1);

  var transitions = <(MapId, Position, Direction, PartyArrangement)>[];
  var numTransitions = 0;

  while (numTransitions < 2) {
    var termOrRange = reader.readWord();
    if (termOrRange == Size.w.maxValueSized) {
      numTransitions++;
      continue;
    }

    reader.readWord(); // range type; ignored

    var to = reader.readWordExpression();
    var x = reader.readByte();
    var y = reader.readByte();
    var facing = reader.readByte();
    var arrangeB = reader.readByte();

    var mapId = asmToMapId(Constant(to.toString()));
    if (mapId == null) throw ArgumentError('unknown map id: $to');
    var arrange = asmToArrangement(arrangeB);
    if (arrange == null) {
      throw ArgumentError('could not parse arrange: $arrangeB');
    }
    transitions.add((
      mapId,
      Position(x.value, y.value),
      _byteToFacingDirection(facing),
      arrange
    ));
  }
  return transitions;
}

List<String> preprocessMapToRaw(Asm original,
    {required String sprites,
    required String objects,
    String? areas,
    required Label dialog}) {
  var reader = ConstantReader.asm(original);
  var processed = <String>[];

  var trimmed = original.trim();
  var map = trimmed.first.label?.map((l) => Label(l));
  if (map == null) {
    throw ArgumentError(
        'original asm does not start with label: ${trimmed.first}');
  }

  processed.add(label(map).toString());

  defineConstants(Iterable<Sized> constants) {
    processed
        .addAll(_defineConstants(constants).lines.map((l) => l.toString()));
  }

  addComment(String c) {
    processed.add(comment(c).toString());
  }

  addComment('General variable / Music');
  defineConstants(_skipToSprites(reader));

  // ignore & replace real sprite data
  _readSprites(reader);
  addComment('Sprites');
  processed.add(sprites);
  defineConstants([Word(0xffff)]);

  addComment('Secondary sprites, map updates, transition data');
  defineConstants(_skipAfterSpritesToObjects(reader));

  // ignore & replace real object data
  _readObjects(reader, {});
  addComment('Objects');
  processed.add(objects);
  defineConstants([Word(0xffff)]);

  addComment('Treasure, tile animations');
  defineConstants(_skipAfterObjectsToLabels(reader));

  addComment('?');
  // on maps there are 2 labels before dialog,
  // except on motavia and dezolis
  // (this is simply hard coded based on map IDs)
  if (!const ['Map_Motavia', 'Map_Dezolis'].contains(map.name)) {
    defineConstants([reader.readLabel(), reader.readLabel()]);
  }

  // skip actual label
  reader.readLabel();

  addComment('Dialog address');
  // replace dialog label
  // defineConstants([Label('Map_${mapId.name}_Dialog')]);
  defineConstants([dialog]);

  // ignore & replace real area data, if there is any area data
  if (areas != null) {
    _readAreas(reader);
    addComment('Areas');
    processed.add(areas);
    defineConstants([Word(0xffff)]);
  }

  processed.addAll(reader.remaining.lines.map((l) => l.toString()));

  return processed;
}

Asm _defineConstants(Iterable<Sized> constants) {
  var asm = Asm.empty();
  Size? size;
  var buffer = <Sized>[];
  for (var expression in constants) {
    if (size != expression.size) {
      if (size != null) {
        asm.add(dc.size(size, buffer));
        buffer.clear();
      }
      size = expression.size;
    }
    buffer.add(expression);
  }
  if (buffer.isNotEmpty) {
    asm.add(dc.size(size!, buffer));
  }
  return asm;
}

Future<GameMap> asmToMap(
    Label mapLabel, Asm asm, DialogTreeLookup dialogLookup) async {
  var reader = ConstantReader.asm(asm);

  _skipToSprites(reader);

  var sprites = _readSprites(reader);

  _skipAfterSpritesToObjects(reader);

  var asmObjects = _readObjects(reader, sprites);

  _skipAfterObjectsToLabels(reader);

  // on maps there are 2 labels before dialog,
  // except on motavia and dezolis
  // (this is simply hard coded based on map IDs)
  var mapId = labelToMapId(mapLabel);
  Label dialogLabel;
  if ([MapId.Motavia, MapId.Dezolis].contains(mapId)) {
    dialogLabel = reader.readLabel();
  } else {
    reader.readLabel();
    reader.readLabel();
    dialogLabel = reader.readLabel();
  }

  var lookup = dialogLookup.byLabel(dialogLabel);

  // todo: pass map instead of returning lists to add to map?
  var scenes = <_DialogAndLabel, Scene>{};
  var areas = [
    for (var a in _readAreas(reader))
      await _buildArea(mapId, a,
          dialogLookup: dialogLookup,
          isWorldMotavia: mapId.world == World.Motavia,
          scenes: scenes)
  ];

  var dialogTree = await lookup;
  var mapObjects = _buildObjects(mapId, sprites, asmObjects, dialogTree);

  var map = GameMap(mapId);
  mapObjects.forEach(map.addObject);
  areas.forEach(map.addArea);

  return map;
}

Future<MapArea> _buildArea(MapId map, _AsmArea area,
    {required DialogTreeLookup dialogLookup,
    required bool isWorldMotavia,
    required Map<_DialogAndLabel, Scene> scenes}) async {
  var id = MapAreaId('${map.name}_area_${area.index}');
  var position = area.at;
  var routine = area.routine;
  var flagType = area.flagType;
  var flag = area.flag;
  var range = area.range;
  var param = area.param;

  if (routine == Byte.zero) {
    if (flagType != Byte.zero) {
      // routine is dialog, but flag type is not event flag
      // means we need to model other flag type
      throw UnsupportedError(
          'unexpected flag type with interactive area: ${flagType.value}');
    }

    if (param is! Byte) {
      throw UnsupportedError('cannot evaluate constant expression for '
          'dialog ID. param=$param');
    }

    var dialog = _dialogLabelForAreaDialogue(isWorldMotavia, param);
    var ref = _DialogAndLabel(param.value, dialog);
    var scene = scenes[ref];
    if (scene == null) {
      scene = toScene(param.value, await dialogLookup.byLabel(dialog),
          isObjectInteraction: false);
      scenes[ref] = scene;
    }

    return MapArea(
        id: id,
        at: position,
        range: range,
        spec: InteractiveAreaSpec(
            doNotInteractIf: flag != Byte.zero ? toEventFlag(flag) : null,
            onInteract: scene));
  } else {
    return MapArea(
        id: id,
        at: position,
        range: range,
        spec: AsmArea(
            eventType: flagType,
            eventFlag: flag,
            interactionRoutine: routine,
            interactionParameter: param));
  }
}

/// See Interaction_DisplayDialogue
Label _dialogLabelForAreaDialogue(bool isWorldMotavia, Byte param) {
  if (isWorldMotavia) {
    if (param.value < 0x7f) {
      return Label('DialogueTree28');
    } else {
      return Label('DialogueTree29');
    }
  } else {
    return Label('DialogueTree30');
  }
}

Iterable<Sized> _skipAfterObjectsToLabels(ConstantReader reader) {
  // skip treasure and tile animations
  return reader.skipThrough(value: Size.w.maxValueSized, times: 2);
}

Iterable<Sized> _skipAfterSpritesToObjects(ConstantReader reader) {
  // skip secondary sprite data
  // such as those loaded into ram instead of vram
  var sprite = reader.skipThrough(value: Size.w.maxValueSized, times: 2);

  // skip map updates
  var updates = reader.skipThrough(value: Size.b.maxValueSized, times: 1);

  // skip transition data 1 & 2
  var transition = reader.skipThrough(value: Size.w.maxValueSized, times: 2);

  return iterables.concat([sprite, updates, transition]);
}

Iterable<Sized> _skipToSprites(ConstantReader reader) {
  // skip general var, music, something else
  return reader.skipThrough(times: 1, value: Size.w.maxValueSized);
}

Map<Word, Label> _readSprites(ConstantReader reader) {
  var sprites = <Word, Label>{};

  while (true) {
    var vramTile = reader.readWord();
    //loc_519D2:
    // 	tst.w	(a0)
    // 	bmi.w	loc_51A14
    if (vramTile.isNegative) {
      // skip over secondary sprites for now
      if (vramTile == Word(0xfffe)) {
        reader.skipThrough(value: Size.w.maxValueSized, times: 1);
      }

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
              defaultSpeaker: object, isObjectInteraction: true));
      (spec as Interactive).onInteract = scene;
    }

    return object;
  }).toList(growable: false);
}

List<_AsmArea> _readAreas(ConstantReader reader) {
  var areas = <_AsmArea>[];

  while (true) {
    var xOrTerminate = reader.readWord();
    if (xOrTerminate == Word(0xffff)) {
      return areas;
    }

    var x = xOrTerminate;
    var y = reader.readWord();
    var range = _parseRangeType(reader.readWord());
    var flagType = reader.readByte();
    var flag = reader.readByte();
    var routine = reader.readByte();
    var param = reader.readByteExpression();
    var position = Position(x.value << 3, y.value << 3);

    areas.add(_AsmArea(areas.length, range, position,
        flagType: flagType, flag: flag, routine: routine, param: param));
  }
}

class _AsmArea {
  int index;
  AreaRange range;
  Position at;
  Byte flagType;
  Byte flag;
  Byte routine;
  Sized param;

  _AsmArea(this.index, this.range, this.at,
      {required this.flagType,
      required this.flag,
      required this.routine,
      required this.param});
}

class _DialogAndLabel {
  final int dialog;
  final Label label;

  _DialogAndLabel(this.dialog, this.label);

  @override
  String toString() {
    return '_DialogAndLabel{dialog: $dialog, label: $label}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DialogAndLabel &&
          runtimeType == other.runtimeType &&
          dialog == other.dialog &&
          label == other.label;

  @override
  int get hashCode => dialog.hashCode ^ label.hashCode;
}

final _rangeIds = BiMap<Word, AreaRange>()
  ..addAll({
    Word(1): AreaRange.x40y40,
    Word(2): AreaRange.x20y20,
    Word(3): AreaRange.xyExact,
    Word(4): AreaRange.xLower,
    Word(5): AreaRange.xHigher,
    Word(6): AreaRange.yLower,
    Word(7): AreaRange.yHigher,
    Word(8): AreaRange.xyLowerAndYLessOrEqualTo_Y_0x2A0,
    Word(9): AreaRange.x20y10,
    Word(0xA): AreaRange.x10y60,
    Word(0xB): AreaRange.x40y20,
    Word(0xC): AreaRange.x10y20,
    Word(0xD): AreaRange.x60y10,
    Word(0xE): AreaRange.x40y10,
  });

AreaRange _parseRangeType(Word range) {
  var r = _rangeIds[range];
  if (r == null) {
    throw UnsupportedError('unsupported range type ${range.hex}');
  }
  return r;
}

Word _rangeTypeId(AreaRange range) {
  var r = _rangeIds.inverse[range];
  if (r == null) {
    throw UnsupportedError('unsupported range type $range');
  }
  return r;
}

MapId labelToMapId(Label lbl) {
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
