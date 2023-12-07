import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/collection.dart';
import 'package:quiver/iterables.dart' as iterables;
import 'package:rune/generator/movement.dart';
import 'package:rune/numbers.dart';
import 'package:rune/src/null.dart';

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

// todo: default to convention & allow override
final _spriteArtLabels = BiMap<Sprite, Label>()
  ..addAll(Sprite.wellKnown.groupFoldBy(
      (sprite) => sprite, (previous, sprite) => Label('Art_${sprite.name}')));

extension SpriteLabel on Sprite {
  Label get label => _spriteArtLabels[this] ?? Label(name);
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

  spriteVramOffset = _addBuiltInSpriteData(map, spriteVramOffset, spritesAsm);
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

// TODO(map compiler): this should be externalized to Program API for testing
final _builtInSprites = {
  MapId.BirthValley_B1: [(Label('loc_1379A8'), 0x39)]
};

/// Some maps utilize sprites outside of objects, in event routines.
///
/// TODO: This assumes that this sprite data will always be first in VRAM.
/// This may not always be the case.
Word? _addBuiltInSpriteData(
    GameMap map, Word? spriteVramOffset, Asm spritesAsm) {
  if (_builtInSprites[map.id] case var s when s != null && s.isNotEmpty) {
    if (spriteVramOffset == null) {
      throw Exception('no vram offsets defined but map has sprites. '
          'builtIn=$s');
    }

    for (var (lbl, tiles) in s) {
      spritesAsm.add(dc.w([spriteVramOffset!]));
      spritesAsm.add(dc.l([lbl]));

      spriteVramOffset = (spriteVramOffset + tiles.toValue) as Word;
    }
  }
  return spriteVramOffset;
}

/// Writes all sprite pointer and VRAM tile pairs for objects in the map.
///
/// Returns a map of object IDs to their VRAM tile number.
/// This is useful for compiling object data,
/// which refers back to each objects' intended VRAM tile number
/// (in order to use the correct sprite for that object).
Map<MapObjectId, Word> _compileMapSpriteData(
    List<MapObject> objects, Asm asm, int? spriteVramOffset) {
  // 1. Aggregate all art pointers and their vram tile layouts
  // 2. Aggregate all objects and their art pointers
  // 3. Assign vram tile numbers to objects,
  //    considering what art is reused,
  //    and the vram tile layout of each art pointer.

  // This is a multimap because art can be reused by multiple objects.
  // However those objects can use the same art with different mappings.
  var artPointers =
      Multimap<ArtPointer?, (SpriteVramMapping, List<MapObjectId>)>();

  for (var obj in objects) {
    var spec = obj.spec;
    var routine = _fieldRoutines.bySpec(spec);

    if (routine == null) {
      throw Exception('unknown field routine for spec $spec');
    }

    switch (routine.spriteLayoutForSpec(spec)) {
      case var vram when vram != null:
        var art = vram.art;
        var current = artPointers[art];

        if (current.isEmpty) {
          artPointers.add(art, (vram, [obj.id]));
        } else {
          // If any of the current vram mappings can be merged, merge
          // and replace that mapping with the merged one.
          // Else, add a new mapping.
          var merged = false;
          var updated = <(SpriteVramMapping, List<MapObjectId>)>[];

          for (var (mapping, objects) in current) {
            if (!merged) {
              // Try merging.
              var mergedMapping = mapping.merge(vram);
              if (mergedMapping != null) {
                updated.add((mergedMapping, [...objects, obj.id]));
                merged = true;
              } else {
                // Couldn't merge. Keep this set and continue.
                updated.add((mapping, objects));
              }
            } else {
              // Already merged. Keep this set and continue.
              updated.add((mapping, objects));
            }
          }

          if (!merged) {
            // Never merged. Add additional.
            updated.add((vram, [obj.id]));
          }

          // Replace current mappings with updated mappings.
          artPointers.removeAll(art);
          artPointers.addValues(art, updated);
        }

        break;
      // else, no sprite. just use vram tile 0.
    }
  }

  var vramTileByObject = <MapObjectId, Word>{};
  // If need to support required mappings...
  // This happens when hard coded in routine, but where the sprite
  // is still variable.
  // Maybe if the sprite isn't really variable, we just define it
  // in the map data? (past normal vram mappings)
  // var requiredMappings = PriorityQueue<_SpriteVramMapping>(
  //     (a, b) => a.requiredVramTile!.compareTo(b.requiredVramTile!));

  for (var MapEntry(key: pointer, value: mappings)
      in artPointers.asMap().entries) {
    for (var (mapping, objects) in mappings) {
      if (mapping.tiles == 0) continue;

      if (spriteVramOffset == null) {
        throw Exception('no vram offsets defined but map has sprites. '
            'objects=${vramTileByObject.keys}');
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

      if (spriteVramOffset >= 0x534) {
        throw Exception('sprite data extends into character sprites. '
            'tile number: $tile '
            'width: ${mapping.tiles} '
            'art: $pointer '
            'asm: $asm');
      }

      for (var obj in objects) {
        vramTileByObject[obj] = tile;
      }

      if (pointer case RomArt(label: var lbl)) {
        asm.add(dc.w([tile]));
        asm.add(dc.l([lbl]));

        for (var offset in mapping.duplicateOffsets) {
          asm.add(dc.w([Word(tile.value + offset)]));
          asm.add(dc.l([lbl]));
        }
      }
    }
  }

  return vramTileByObject;
}

class SpriteVramMapping {
  /// The art used for this mapping, if known.
  final ArtPointer? art;

  /// The total tiles required by the sprite
  final int tiles;

  /// Additional offsets in vram which duplicate the sprite.
  ///
  /// This is used for sprites where the sprite data
  /// does not alone account for all facing directions needed.
  final Iterable<int> duplicateOffsets;

  final bool animated;

  // See notes in _compileMapSpriteData
  // final Word? requiredVramTile;

  const SpriteVramMapping._(
      {required this.tiles,
      this.art,
      this.duplicateOffsets = const [],
      this.animated = false});

  bool get mergable => art != null && !animated;

  SpriteVramMapping? merge(SpriteVramMapping other) {
    if (!const IterableEquality<int>()
        .equals(duplicateOffsets, other.duplicateOffsets)) return null;
    if (animated || other.animated) return null;
    if (art != other.art) return null;
    if (art == null || other.art == null) return null;
    return SpriteVramMapping._(
        tiles: max(tiles, other.tiles),
        art: art,
        duplicateOffsets: duplicateOffsets);
  }

  @override
  String toString() {
    return '_SpriteVramMapping{tiles: $tiles, offsets: $duplicateOffsets}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpriteVramMapping &&
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
  var routine = _fieldRoutines.bySpec(spec);

  if (routine == null) {
    throw Exception('no routine known for spec $spec');
  }

  asm.add(comment(obj.id.toString()));
  asm.add(dc.w([routine.index]));
  asm.add(dc.b([spec.startFacing.constant, dialogId]));
  asm.add(dc.w([tileNumber]));
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

  switch (spec) {
    case AsmArea():
      asm.add(dc.b([
        spec.eventType,
        spec.eventFlag,
        spec.interactionRoutine,
        spec.interactionParameter
      ]));

      break;
    case InteractiveAreaSpec():
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

      break;
  }

  asm.addNewline();
}

extension ObjectRoutine on MapObject {
  FieldRoutine get routine {
    var spec = this.spec;

    var routine = _fieldRoutines.bySpec(spec);
    if (routine == null) {
      throw Exception('no routine configured for spec $spec');
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

    // field object secondary address + object size * index
    var address = 0xFFFFC300 + 0x40 * index;
    return Longword(address);
  }
}

FutureOr<Word?> firstSpriteVramTileOfMap(Asm asm) {
  var reader = ConstantReader.asm(asm);
  // skip general var, music, something else
  _skipToSprites(reader);
  var sprites = _readSprites(reader);
  return sprites.keys
      .whereType<_VramSprite>()
      .map((v) => v.tile)
      .sorted((a, b) => a.compareTo(b))
      .firstOrNull;
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

  addComment('General variable, music, tilesets');
  defineConstants(_skipToSprites(reader));

  // ignore & replace real sprite data
  var spritesData = _readSprites(reader);
  addComment('ROM sprites');
  processed.add(sprites);
  addComment('RAM sprites');
  defineConstants([
    for (var MapEntry(key: loc, value: label) in spritesData.entries)
      if (loc case _RamSprite(address: var address)) ...[
        Word(0xfffe),
        address,
        label
      ]
  ]);
  defineConstants([Word(0xffff)]);

  addComment('RAM sprites (alt compression), map updates, transition data');
  defineConstants(_skipAfterSpritesToObjects(reader));

  // ignore & replace real object data
  _readObjects(reader);
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

  var asmObjects = _readObjects(reader);

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

Iterable<Sized> _skipToSprites(ConstantReader reader) {
  // skip general var, music, tilesets
  return reader.skipThrough(times: 1, value: Size.w.maxValueSized);
}

Map<_SpriteLoc, Label> _readSprites(ConstantReader reader) {
  var sprites = <_SpriteLoc, Label>{};

  while (true) {
    var control = reader.readWord();
    if (control == Word(0xfffe)) {
      var address = reader.readWord();
      var sprite = reader.readLabel();
      sprites[_RamSprite(address)] = sprite;
    } else if (control.isNegative) {
      return sprites;
    } else {
      var sprite = reader.readLabel();
      sprites[_VramSprite(control)] = sprite;
    }
  }
}

sealed class _SpriteLoc {}

class _VramSprite implements _SpriteLoc {
  final Word tile;
  _VramSprite(this.tile);
  @override
  String toString() {
    return '_VramSprite{tile: $tile}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _VramSprite &&
          runtimeType == other.runtimeType &&
          tile == other.tile;
  @override
  int get hashCode => tile.hashCode;
}

class _RamSprite implements _SpriteLoc {
  final Word address;
  _RamSprite(this.address);
  @override
  String toString() {
    return '_RamSprite{address: $address}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RamSprite &&
          runtimeType == other.runtimeType &&
          address == other.address;
  @override
  int get hashCode => address.hashCode;
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

List<_AsmObject> _readObjects(ConstantReader reader) {
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

    var spec = _fieldRoutines.byIndex(routineOrTerminate)?.factory;
    if (spec == null) {
      throw Exception('unknown field routine: $routineOrTerminate '
          'objectIndex=${objects.length}');
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

Iterable<Sized> _skipAfterObjectsToLabels(ConstantReader reader) {
  // skip treasure and tile animations
  return reader.skipThrough(value: Size.w.maxValueSized, times: 2);
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

List<MapObject> _buildObjects(MapId mapId, Map<_SpriteLoc, Label> sprites,
    List<_AsmObject> asmObjects, DialogTree dialogTree) {
  // The same scene must reuse same object in memory
  var scenesById = <Byte, Scene>{};

  return asmObjects.mapIndexed((i, asm) {
    var artLbl = sprites[_VramSprite(asm.vramTile)];

    if (asm.spec.requiresSprite && artLbl == null) {
      throw StateError('field object routine ${asm.routine} requires sprite '
          'but art label was null for tile number ${asm.vramTile}');
    }

    var sprite = _spriteArtLabels.inverse[artLbl] ??
        switch (artLbl) { Label l => Sprite(l.name), null => null };
    var spec = asm.spec(sprite, asm.facing);
    var object = MapObject(
        id: '${mapId.name}_$i', startPosition: asm.position, spec: spec);

    if (spec case Interactive s) {
      var scene = scenesById.putIfAbsent(
          asm.dialogId,
          // todo: if shared scene, default speaker may be misleading
          // but maybe better than nothing
          () => toScene(asm.dialogId.value, dialogTree,
              defaultSpeaker: object, isObjectInteraction: true));
      s.onInteract = scene;
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

// TODO: make injectable in Program API for testing
final _fieldRoutines = _FieldRoutineRepository([
  FieldRoutine(
      Word(0x68),
      Label('FieldObj_NPCAlysPiata'),
      spriteMappingTiles: 8,
      SpecFactory((_) => AlysWaiting(), forSpec: AlysWaiting)),
  FieldRoutine(
      Word(0x138),
      Label('loc_490B8'),
      spriteMappingTiles: 8,
      ramArt: RamArt(address: Word(0)),
      vramAnimated: true,
      SpecFactory((d) => AiedoShopperWithBags(d),
          forSpec: AiedoShopperWithBags)),
  FieldRoutine(
      Word(0x13C),
      Label('loc_49128'),
      spriteMappingTiles: 8,
      ramArt: RamArt(address: Word(0x0900)),
      vramAnimated: true,
      SpecFactory((_) => AiedoShopperMom(), forSpec: AiedoShopperMom)),
  FieldRoutine(
      Word(0x120),
      Label('FieldObj_Elevator'),
      spriteMappingTiles: 0,
      SpecFactory((d) => Elevator(d), forSpec: Elevator)),
  FieldRoutine(
      Word(0x74),
      Label('FieldObj_InvisibleBlock'),
      spriteMappingTiles: 0,
      SpecFactory((_) => InvisibleBlock(), forSpec: InvisibleBlock)),
  FieldRoutine(Word(0x38), Label('FieldObj_NPCType1'),
      SpecFactory.npc((s, _) => Npc(s, FaceDown()), forBehavior: FaceDown)),
  FieldRoutine(
      Word(0x134),
      Label('FieldObj_Pana'),
      spriteMappingTiles: 18,
      SpecFactory.npc((s, _) => Npc(s, FaceDownSimpleSprite()),
          forBehavior: FaceDownSimpleSprite)),
  FieldRoutine(
      Word(0x3C),
      Label('FieldObj_NPCType2'),
      SpecFactory.npc((s, d) => Npc(s, WanderAround(d)),
          forBehavior: WanderAround)),
  FieldRoutine(
      Word(0x40),
      Label('FieldObj_NPCType3'),
      SpecFactory.npc((s, d) => Npc(s, SlowlyWanderAround(d)),
          forBehavior: SlowlyWanderAround)),
  FieldRoutine(
      Word(0x140),
      Label('loc_49502'),
      spriteMappingTiles: 8,
      SpecFactory.npc((s, _) => Npc(s, FaceDownLegsHiddenNonInteractive()),
          forBehavior: FaceDownLegsHiddenNonInteractive)),
  FieldRoutine(
      Word(0x108),
      Label('FieldObj_NPCType32'),
      spriteMappingTiles: 0x38,
      SpecFactory.npc((s, _) => Npc(s, FaceDownOrUpLegsHidden()),
          forBehavior: FaceDownOrUpLegsHidden)),
  FieldRoutine(
      Word(0x14C),
      Label('loc_49502'),
      spriteMappingTiles: 8,
      SpecFactory.npc((s, _) => Npc(s, FixedFaceRight()),
          forBehavior: FixedFaceRight)),
  FieldRoutine(
      Word(0xF8),
      Label('FieldObj_NPCType28'),
      spriteMappingTiles: 6,
      ramArt: RamArt(address: Word(0)),
      vramAnimated: true,
      SpecFactory.asm(Word(0xF8))),
]);

class _FieldRoutineRepository {
  final Map<Word, FieldRoutine> _byIndex;
  final Map<Label, FieldRoutine> _byLabel;
  final Map<SpecModel, FieldRoutine> _byModel;

  _FieldRoutineRepository(Iterable<FieldRoutine> routines)
      : _byIndex = {for (var r in routines) r.index: r},
        _byLabel = {for (var r in routines) r.label: r},
        _byModel = {for (var r in routines) r.factory.routineModel: r};

  FieldRoutine? byIndex(Word index) {
    var byIndex = _byIndex[index];
    if (byIndex != null) return byIndex;
    var label = labelOfFieldObjectRoutine(index);
    if (label == null) return null;
    return FieldRoutine(index, label, SpecFactory.asm(index));
  }

  FieldRoutine? byLabel(Label label) {
    var byLabel = _byLabel[label];
    if (byLabel != null) return byLabel;
    var index = indexOfFieldObjectRoutine(label);
    if (index == null) return null;
    return FieldRoutine(index, label, SpecFactory.asm(index));
  }

  FieldRoutine? bySpec(MapObjectSpec spec) {
    switch (spec) {
      // TODO: this may not be symmetrical
      // it's possible the found routine constructs specs of a different type
      case AsmSpec():
        return byIndex(spec.routine);
      case Npc():
        return _byModel[NpcRoutineModel(spec.behavior.runtimeType)];
      default:
        return _byModel[SpecRoutineModel(spec.runtimeType)];
    }
  }
}

sealed class SpecModel {}

class NpcRoutineModel extends SpecModel {
  final Type behaviorType;

  NpcRoutineModel(this.behaviorType);

  @override
  String toString() {
    return 'NpcRoutineModel{$behaviorType}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NpcRoutineModel &&
          runtimeType == other.runtimeType &&
          behaviorType == other.behaviorType;

  @override
  int get hashCode => behaviorType.hashCode;
}

class SpecRoutineModel extends SpecModel {
  final Type specType;

  SpecRoutineModel(this.specType);

  @override
  String toString() {
    return 'SpecRoutineModel{$specType}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpecRoutineModel &&
          runtimeType == other.runtimeType &&
          specType == other.specType;

  @override
  int get hashCode => specType.hashCode;
}

class AsmRoutineModel extends SpecModel {
  AsmRoutineModel();

  @override
  String toString() {
    return 'AsmRoutineModel{}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsmRoutineModel && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Used to parse the ASM into the model
/// as well as store necessary information for generation.
abstract class SpecFactory {
  bool get requiresSprite;

  SpecModel get routineModel;

  MapObjectSpec call(Sprite? sprite, Direction facing);

  static SpecFactory npc<T extends NpcBehavior>(
      Npc<T> Function(Sprite sprite, Direction facing) factory,
      {required Type forBehavior}) {
    return _NpcFactory(factory, forBehavior);
  }

  factory SpecFactory(MapObjectSpec Function(Direction facing) factory,
      {required Type forSpec}) {
    return _SpecFactory(factory, forSpec);
  }

  factory SpecFactory.asm(Word routine) {
    return _AsmSpecFactory(routine);
  }
}

class _NpcFactory<T extends NpcBehavior> implements SpecFactory {
  @override
  final requiresSprite = true;
  @override
  final SpecModel routineModel;
  final Npc<T> Function(Sprite sprite, Direction facing) _factory;
  _NpcFactory(this._factory, Type behaviorType)
      : routineModel = NpcRoutineModel(behaviorType);
  @override
  Npc<T> call(Sprite? sprite, Direction facing) => _factory(sprite!, facing);
}

class _SpecFactory<T extends MapObjectSpec> implements SpecFactory {
  @override
  final requiresSprite = false;
  @override
  final SpecModel routineModel;
  final T Function(Direction facing) _factory;
  _SpecFactory(this._factory, Type specType)
      : routineModel = SpecRoutineModel(specType);
  @override
  T call(Sprite? sprite, Direction facing) => _factory(facing);
}

class _AsmSpecFactory implements SpecFactory {
  @override
  final requiresSprite = false;
  @override
  final SpecModel routineModel = AsmRoutineModel();
  final Word routine;
  _AsmSpecFactory(this.routine);
  @override
  AsmSpec call(Sprite? sprite, Direction facing) {
    var label = switch (sprite) {
      Sprite() => _spriteArtLabels[sprite] ?? Label(sprite.name),
      null => null,
    };
    return AsmSpec(artLabel: label, routine: routine, startFacing: facing);
  }
}

class FieldRoutine<T extends MapObjectSpec> {
  final Word index;
  final Label label;

  /// How many VRAM tiles are needed by this routine's sprite mappings.
  ///
  /// 0 if no sprite is used.
  final int spriteMappingTiles;

  /// Address field routine expects art to be loaded into.
  ///
  /// If null, art may be configurable via map data
  /// (if not otherwise hard coded into the routine).
  final RamArt? ramArt;

  /// If mappings rely on animating the sprite in place in VRAM.
  ///
  /// In this case, VRAM cannot be shared between objects.
  // TODO: this might go hand in hand with ram art?
  // look into render flag $6 usage?
  final bool vramAnimated;

  final SpecFactory factory;

  SpriteVramMapping? spriteLayoutForSpec(MapObjectSpec spec) {
    // What do we need to know?
    // - how the sprite is defined: routine->rom, map->rom, map->ram
    // - this varies based on the spec. we don't know why each option is used.
    // So we do this:
    // - assume there is a sprite, unless tiles are set to 0.
    // - if a sprite is configured, assume the routine allows it to be
    //   configured via rom pointers. (map->rom)
    // - if a sprite is not configured, fall back to routine's ramart.
    //   if present, this uses map->ram.
    //   if not, we assume routine->rom (indicated via null art pointer, but
    //   non-zero tiles).
    // This can be wrong in the future (e.g. if we add configurable sprites
    // for routines which use ram) but for now it should work.

    if (spriteMappingTiles == 0) return null;

    var maybeLbl =
        switch (spec) { MayConfigureSprite s => s.sprite?.label, _ => null };
    var artPointer = maybeLbl == null ? ramArt : RomArt(label: maybeLbl);

    // Bit of a hack for this one sprite;
    // can clean it up if it turns out other sprites need similar treatment
    var duplicateOffsets = (maybeLbl == Label('Art_GuildReceptionist') &&
            spriteMappingTiles >=
                0x38 /* 0x28 offset + 16 tile width in sprite */)
        ? const [0x28]
        : const <int>[];

    return SpriteVramMapping._(
        tiles: spriteMappingTiles,
        art: artPointer,
        duplicateOffsets: duplicateOffsets,
        animated: vramAnimated);
  }

  const FieldRoutine(this.index, this.label, this.factory,
      {this.spriteMappingTiles = _defaultVramTilesPerSprite,
      this.ramArt,
      this.vramAnimated = false});

  @override
  String toString() {
    return 'FieldRoutine{index: $index, label: $label, '
        'spriteMappingTiles: $spriteMappingTiles, factory: $factory}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldRoutine &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          label == other.label &&
          spriteMappingTiles == other.spriteMappingTiles &&
          ramArt == other.ramArt &&
          factory == other.factory;

  @override
  int get hashCode =>
      index.hashCode ^
      label.hashCode ^
      spriteMappingTiles.hashCode ^
      ramArt.hashCode ^
      factory.hashCode;
}

sealed class ArtPointer {}

class RomArt extends ArtPointer {
  final Label label;

  RomArt({required this.label});

  @override
  String toString() {
    return 'RomArt{label: $label}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RomArt &&
          runtimeType == other.runtimeType &&
          label == other.label;

  @override
  int get hashCode => label.hashCode;
}

class RamArt extends ArtPointer {
  final Word address;

  RamArt({required this.address});

  @override
  String toString() {
    return 'RamArt{address: $address}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RamArt &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}
