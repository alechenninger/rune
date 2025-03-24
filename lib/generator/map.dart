import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/collection.dart';
import 'package:quiver/iterables.dart' as iterables;

import '../src/null.dart';
import '../model/model.dart';
import 'movement.dart';
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
  final Asm runEventRoutines;
  final Asm runEventIndices;
  // might also need dialogTrees ASM
  // if these labels need to be programmatically referred to

  MapAsm(
      {required this.sprites,
      required this.objects,
      required this.areas,
      required this.dialog,
      required this.events,
      this.runEventRoutines = const Asm.none(),
      this.runEventIndices = const Asm.none()});

  MapAsm.empty()
      : sprites = Asm.empty(),
        objects = Asm.empty(),
        areas = Asm.empty(),
        dialog = Asm.empty(),
        events = Asm.empty(),
        runEventRoutines = Asm.empty(),
        runEventIndices = Asm.empty();

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

MapAsm compileMap(GameMap map, ProgramConfiguration config) {
  var spriteVramOffset = config.spriteVramOffsetForMap(map.id);
  var builtInSprites = config.builtInSpritesForMap(map.id);
  var dialogTrees = config.dialogTrees;
  var eventFlags = config.eventFlags;
  var fieldRoutines = config.fieldRoutines;

  var spritesAsm = Asm.empty();
  var objectsAsm = Asm.empty();
  var areasAsm = Asm.empty();
  var eventsAsm = EventAsm.empty();
  var runEventsAsm = Asm.empty();
  var runEventIndices = <Byte>[];

  var objects = map.orderedObjects;

  if (objects.length > 64) {
    throw 'too many objects';
  }

  var objectsTileNumbers = _compileMapSpriteData(
      objects, spritesAsm, spriteVramOffset?.value,
      builtIns: builtInSprites, fieldRoutines: fieldRoutines);

  var sceneIds = Map<MapElement, Byte>.identity();
  var elementsByScene = Map<Scene, List<MapObjectOrArea>>.identity();

  Byte compileInteraction(Scene scene, SceneId id, {FieldObject? withObject}) {
    return _compileInteractionScene(
        map, scene, id, dialogTrees, eventsAsm, config, eventFlags,
        withObject: withObject, fieldRoutines: fieldRoutines);
  }

  for (var element in <MapObjectOrArea>[...objects, ...map.areas]) {
    if (element case InteractiveMapElement e) {
      elementsByScene.putIfAbsent(e.onInteract, () => []).add(element);
    }
  }

  for (var MapEntry(key: scene, value: elements) in elementsByScene.entries) {
    var first = elements.first;
    var (id, withObject) = switch (first) {
      MapObject o => (
          SceneId('${map.id.name}_${o.id}'),
          elements.cast<MapObject>().singleOrNull ?? const InteractionObject()
        ),
      MapArea a => (SceneId('${map.id.name}_${a.id}'), null),
    };
    var dialogId = compileInteraction(scene, id, withObject: withObject);
    for (var obj in elements) {
      sceneIds[obj] = dialogId;
    }
  }

  for (var obj in objects) {
    var tileNumber = objectsTileNumbers[obj.id] ?? Word(0);
    // If no ID, it must not be interactive.
    var dialogId = sceneIds[obj];
    if (dialogId == null) {
      if (obj is InteractiveMapObject) {
        throw Exception('no dialog id for interactive object ${obj.id}');
      }
      // Doesn't matter – never used
      dialogId = Byte(0);
    }
    _compileMapObjectData(objectsAsm, obj, tileNumber, dialogId,
        fieldRoutines: fieldRoutines);
  }

  for (var area in map.areas) {
    _compileMapAreaData(areasAsm, area, eventFlags, (s) {
      var dialogId = sceneIds[area];
      if (dialogId == null) {
        throw Exception('no dialog id for area ${area.id}');
      }
      return dialogId;
    });
  }

  for (var (id, scene) in map.events) {
    var name = Label('RunEvent_GrandCross_$id');
    runEventIndices.add(config.addRunEvent(name));
    runEventsAsm.add(label(name));

    var generator = SceneAsmGenerator.forRunEvent(id,
        inMap: map,
        eventAsm: eventsAsm,
        runEventAsm: runEventsAsm,
        config: config);

    for (var event in scene.events) {
      event.visit(generator);
    }

    generator.finish();
  }

  for (var id in map.asmEvents) {
    runEventIndices.add(id);
  }

  if (runEventIndices.length.isEven) {
    // Must be word aligned – terminating byte counts as one.
    // This requires 0 is a noop event,
    // which would probaly be good to externalize, but...
    runEventIndices.add(Byte(0));
  }

  return MapAsm(
      sprites: spritesAsm,
      objects: objectsAsm,
      areas: areasAsm,
      dialog: dialogTrees.forMap(map.id).toAsm(),
      events: eventsAsm,
      runEventRoutines: runEventsAsm,
      runEventIndices: dc.b(runEventIndices));
}

/// Writes all sprite pointer and VRAM tile pairs for objects in the map.
///
/// Returns a map of object IDs to their VRAM tile number.
/// This is useful for compiling object data,
/// which refers back to each objects' intended VRAM tile number
/// (in order to use the correct sprite for that object).
Map<MapObjectId, Word> _compileMapSpriteData(
    List<MapObject> objects, Asm asm, int? spriteVramOffset,
    {Iterable<SpriteVramMapping> builtIns = const [],
    required FieldRoutineRepository fieldRoutines}) {
  // First we need to figure out what sprites can
  // share what VRAM mappings, and which must be unique.
  var sprites = _ObjectSprites(fieldRoutines)
    ..mergeBuiltInMappings(builtIns)
    ..mergeSpriteMappings(objects);

  // Now we figure out where we can place the deduplicated mappings
  // in VRAM.
  _VramTiles? vram;

  for (var (mapping, objects) in sprites.mappings()) {
    if (mapping.tiles == 0) continue;

    if (spriteVramOffset == null) {
      throw Exception('no vram offsets defined but map has sprites. '
          'mapping=$mapping '
          'objects=$objects');
    } else {
      vram ??= _VramTiles(start: spriteVramOffset, fixed: sprites.fixed());
    }

    if (vram.place(mapping) case var d when d.isNotEmpty) {
      throw Exception('cannot fit sprite in vram: too much sprite data. '
          'width: ${mapping.tiles} '
          'art: ${mapping.art} '
          'not_placed: $d '
          'vram: $vram');
    }
  }

  var vramTileByObject = <MapObjectId, Word>{};

  for (var (mapping, objects) in sprites.mappings()) {
    var pointer = mapping.art;
    var tile = vram!.tileFor(mapping);

    if (tile == null) {
      throw 'no tile for mapping: $mapping';
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

  return vramTileByObject;
}

class _ObjectSprites {
  // This is a multimap because art can be reused by multiple objects.
  // However those objects can use the same art with different mappings.
  final _pointers =
      Multimap<ArtPointer?, (SpriteVramMapping, List<MapObjectId>)>();

  final FieldRoutineRepository _fieldRoutines;

  _ObjectSprites(this._fieldRoutines);

  Iterable<(SpriteVramMapping, List<MapObjectId>)> mappings() =>
      _pointers.values;

  Iterable<SpriteVramMapping> fixed() sync* {
    for (var (mapping, _) in _pointers.values) {
      if (mapping.requiredVramTile != null) {
        yield mapping;
      }
    }
  }

  void mergeBuiltInMappings(Iterable<SpriteVramMapping> mappings) {
    for (var mapping in mappings) {
      _mergeMapping(mapping, null);
    }
  }

  void mergeSpriteMappings(Iterable<MapObject> objects) {
    for (var obj in objects) {
      var spec = obj.spec;
      var routine = _fieldRoutines.bySpec(spec);

      if (routine == null) {
        throw Exception('unknown field routine for spec $spec');
      }

      if (routine.spriteVramMapping(spec) case SpriteVramMapping m) {
        _mergeMapping(m, obj.id);
      }
    }
  }

  void _mergeMapping(SpriteVramMapping vram, MapObjectId? obj) {
    var art = vram.art;
    var current = _pointers[art];

    if (current.isEmpty) {
      _pointers.add(art, (vram, [if (obj != null) obj]));
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
            updated.add((mergedMapping, [...objects, if (obj != null) obj]));
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
        updated.add((vram, [if (obj != null) obj]));
      }

      // Replace current mappings with updated mappings.
      _pointers.removeAll(art);
      _pointers.addValues(art, updated);
    }
  }
}

class _VramTiles {
  // Priority ordered
  final _regions = <_VramRegion>[];
  late final List<_VramRegion> _regionsInOrder;

  _VramTiles(
      {required int start, Iterable<SpriteVramMapping> fixed = const []}) {
    _regions.addAll([
      _VramRegion(minStart: start, maxEnd: 0x4dc),
      _VramRegion(minStart: 0x4ed, maxEnd: 0x534),
      _VramRegion(
          minStart: start,
          maxStart: 0x4dc,
          maxEnd: 0x534,
          allowed: (m) => m.lazilyLoaded)
    ]);

    var numNormalRegions = _regions.length;

    for (var mapping in fixed) {
      var start = mapping.requiredVramTile?.value;

      if (start == null) continue;

      var end = start + mapping.tiles;

      for (var i = 0; i < numNormalRegions; i++) {
        var r = _regions[i];

        if (r.minStart < start && r.maxEnd > end) {
          // We need to split this region into two.
          var copy = r.copy()..resize(newMaxEnd: start);

          r.resize(newMinStart: end);

          if (copy.free > 0) {
            _regions.insert(i, copy);
            numNormalRegions++;
            i++;
          }
        } else {
          if (r.minStart >= start && r.minStart < end) {
            // clamps maxstart to max(minStart, maxStart);
            r.resize(newMinStart: end);
          }

          if (r.minStart < start && r.maxEnd > start) {
            r.resize(newMaxEnd: start);
          }
        }

        if (r.free == 0) {
          _regions.removeAt(i--);
          numNormalRegions--;
        }
      }

      _regions.add(_VramRegion(
          minStart: start,
          maxStart: start,
          minEnd: end,
          maxEnd: end,
          allowed: (m) => m == mapping)
        ..place(mapping));
    }

    _regionsInOrder = _regions.sorted((a, b) => a.start.compareTo(b.start));
  }

  Word? tileFor(SpriteVramMapping mapping) {
    for (var region in _regions) {
      var tile = region.tileFor(mapping);
      if (tile != null) return tile;
    }
    return null;
  }

  /// Places the [mapping] in VRAM.
  ///
  /// Returns any mappings that could not be placed.
  Iterable<SpriteVramMapping> place(SpriteVramMapping mapping,
      {bool rearrange = true}) {
    if (contains(mapping)) return const [];

    for (var i = 0; i < _regions.length; i++) {
      var region = _regions[i];

      // Claim, allowing extension up to the next regions' max allowed start
      switch (_placeInRegion(mapping, region)) {
        case []:
          return const [];
        case [var d] when d == mapping:
          // Couldn't place this mapping, but nothing else was displaced.
          // Just try the next region.
          continue;
        case var d:
          // Placed, but displaced other mappings.
          // Try to replace those.
          return _placeAll(d, rearrange: rearrange);
      }
    }

    if (!rearrange) return [mapping];

    var state = _regions.map((r) => r.copy()).toList(growable: false);

    for (var i = 0; i < _regions.length; i++) {
      var region = _regions[i];

      if (!region.allowed(mapping)) continue;

      var freed = region.freeUp(mapping.tiles);

      if (freed == null) continue;

      // We were able to free up space.
      // So now try to replace this mapping.
      // Then, try to replace the freed ones.
      var dropped = _placeInRegion(mapping, region);

      if (_placeAll([...dropped, ...freed], rearrange: false) case []) {
        return const [];
      } else {
        for (var i = 0; i < _regions.length; i++) {
          // TODO: this is brittle
          _regions[i].restore(state[i]);
        }
      }
    }

    return [mapping];
  }

  Iterable<SpriteVramMapping> _placeInRegion(
      SpriteVramMapping mapping, _VramRegion r) {
    // Claim, allowing extension up to the next regions' max allowed start
    if (r.place(mapping)) {
      var orderedIndex = _regionsInOrder.indexOf(r);

      // Have to push all subsequent regions out.
      var prior = r;
      var dropped = <SpriteVramMapping>[];

      for (var j = orderedIndex + 1; j < _regionsInOrder.length; j++) {
        var r = _regionsInOrder[j];
        dropped.addAll(r.startAt(prior.occupiedEnd));
        prior = r;
      }

      return dropped;
    } else {
      return [mapping];
    }
  }

  Iterable<SpriteVramMapping> _placeAll(Iterable<SpriteVramMapping> mappings,
      {required bool rearrange}) {
    var remaining = <SpriteVramMapping>[];

    // Always go through all of them and collect what was misplaced.
    for (var m in mappings) {
      var r = place(m, rearrange: rearrange);
      remaining.addAll(r);
    }

    return remaining;
  }

  bool contains(SpriteVramMapping mapping) {
    for (var region in _regions) {
      if (region._mappings.contains(mapping)) return true;
    }
    return false;
  }

  @override
  String toString() {
    return '_VramTiles{_regions: $_regions}';
  }
}

bool _anyMapping(SpriteVramMapping mapping) => true;

class _VramRegion {
  /// The current, mutable start of the region
  /// (the [_start], with configurable offset)
  int _offsetStart;

  /// The current start of the region (default + offset).
  int get start => _offsetStart;

  int _minStart;
  int _maxStart;
  int get minStart => _minStart;
  int get maxStart => _maxStart;

  /// The minimum the [end] may be pushed back to, regardless of unused space.
  ///
  /// Must be >= [maxStart]. (If ==, region is length 0 and can fit no mappings)
  int _minEnd;
  int _maxEnd;
  int get minEnd => _minEnd;
  int get maxEnd => _maxEnd;

  int get free => maxEnd - occupiedEnd;

  /// The end of where sprites currently occupy the region.
  int get occupiedEnd => _offsetStart + width;

  int _next = 0;

  /// How many tiles occupy the region.
  int get width => _next;
  int get nextTile => _offsetStart + _next;
  final bool Function(SpriteVramMapping) allowed;

  final _mappings = <SpriteVramMapping>[];

  _VramRegion(
      {required int minStart,
      required int maxEnd,
      this.allowed = _anyMapping,
      // todo
      int? maxStart,
      int? minEnd})
      : _offsetStart = minStart,
        _minStart = minStart,
        _maxEnd = maxEnd,
        _minEnd = minEnd ?? minStart,
        _maxStart = maxStart ?? minEnd ?? maxEnd;

  _VramRegion copy() {
    var copy = _VramRegion(
        minStart: minStart,
        maxEnd: maxEnd,
        allowed: allowed,
        maxStart: maxStart,
        minEnd: minEnd);
    copy._offsetStart = _offsetStart;
    copy._next = _next;
    copy._mappings.addAll(_mappings);
    return copy;
  }

  void restore(_VramRegion region) {
    _offsetStart = region._offsetStart;
    _next = region._next;
    _mappings.clear();
    _mappings.addAll(region._mappings);
  }

  Word? tileFor(SpriteVramMapping mapping) {
    for (var (t, m) in _tiles()) {
      if (identical(mapping, m)) return t;
    }
    return null;
  }

  Iterable<(Word, SpriteVramMapping)> _tiles() sync* {
    var tile = _offsetStart;
    for (var m in _mappings) {
      yield (Word(tile), m);
      tile += m.tiles;
    }
  }

  /// Drops the mapping from the region.
  /// Returns true if the mapping was found and dropped.
  bool drop(SpriteVramMapping mapping) {
    var removed = _mappings.remove(mapping);
    if (removed) _next -= mapping.tiles;
    return removed;
  }

  Iterable<SpriteVramMapping> resize({int? newMinStart, int? newMaxEnd}) {
    if (newMinStart != null && newMaxEnd != null) {
      if (newMinStart > newMaxEnd) {
        throw ArgumentError('Invalid bounds: minStart > maxEnd');
      }
    }

    // Calculate the amount of space needed to accommodate the new bounds
    // TODO: this might be wrong; consider offsetstart / free
    var amountNeeded = 0;
    if (newMinStart != null && newMinStart > minStart) {
      amountNeeded += newMinStart - minStart;
    }

    if (newMaxEnd != null && newMaxEnd < maxEnd) {
      amountNeeded += maxEnd - newMaxEnd;
    }

    // Free up the necessary space
    var freedMappings = freeUp(amountNeeded);
    if (freedMappings == null) {
      throw StateError('Not enough space to accommodate the new bounds');
    }

    // Update the bounds
    if (newMinStart != null) {
      _minStart = newMinStart;
      _maxStart = max(minStart, maxStart);
      _minEnd = max(minStart, minEnd);
      _offsetStart = max(minStart, _offsetStart);
    }

    if (newMaxEnd != null) {
      _maxEnd = newMaxEnd;
      _minEnd = min(maxEnd, minEnd);
      _maxStart = min(maxStart, maxEnd);
    }

    return freedMappings;
  }

  /// Drop mappings, if needed, to accommodate [amount] space
  /// within region limits.
  ///
  /// Returns `null` if the amount cannot be freed.`
  Iterable<SpriteVramMapping>? freeUp(int amount) {
    var toFree = amount - free;

    // Do we already have enough free?
    if (toFree <= 0) return const [];

    var goalSize = width - toFree;

    // Would the goal size violate region constraints?
    if (start + goalSize < minEnd || goalSize < 0) {
      return null;
    }

    var bestSize = 0;
    var bestSubset = <SpriteVramMapping>[];

    // Find the set of mappings which is closest to goal without going over
    var sorted = _mappings.sorted((a, b) => b.tiles.compareTo(a.tiles));
    var n = _mappings.length;

    // Branch and bound
    void backtrack(int start, int currentSize, List<SpriteVramMapping> subset) {
      if (currentSize > goalSize || start == n) return;

      if (currentSize > bestSize) {
        bestSize = currentSize;
        bestSubset = subset.toList();
      }

      var nextMapping = sorted[start];
      subset.add(nextMapping);

      backtrack(start + 1, currentSize + nextMapping.tiles, subset);

      // Try the other branch, without the next mapping
      subset.removeLast();
      backtrack(start + 1, currentSize, subset);
    }

    backtrack(0, 0, []);

    // Modify mappings and return the ones we dropped.
    var dropped = <SpriteVramMapping>[];

    for (var i = 0; i < _mappings.length; i++) {
      var mapping = _mappings[i];
      if (!bestSubset.contains(mapping)) {
        _mappings.removeAt(i);
        dropped.add(mapping);
        _next -= mapping.tiles;
        i--;
      }
    }

    return dropped;
  }

  /// Move the start address.
  ///
  /// If the start address is less than the current start, the end position
  /// stays.
  ///
  /// If the start is greater than the current start,
  /// the end may move up to [maxEnd] to accommodate fitting existing mappings.
  ///
  /// If any cannot be fit, they are dropped and returned.
  Iterable<SpriteVramMapping> startAt(int address) {
    address = max(minStart, address);

    if (address < _offsetStart) {
      _offsetStart = address;
      return const [];
    } else {
      var toFree = address - _offsetStart;
      var dropped = freeUp(toFree);
      if (dropped == null) {
        throw StateError('cannot move start to ${Longword(address)}; '
            'not enough space to free ${Longword(toFree)}. '
            'fixed regions may be too small. '
            'this can happen if an object corresponding to sprite in a '
            'fixed region does not have the correct spriteMappingTiles.');
      }
      _offsetStart = address;
      return dropped;
    }
  }

  /// Attempts to place the mapping in this region,
  /// possibly extending the regions end up to [maxEnd].
  ///
  /// Return false if cannot be claimed in this region.
  bool place(SpriteVramMapping mapping) {
    if (!allowed(mapping)) return false;

    if (nextTile + mapping.tiles > maxEnd) return false;

    _mappings.add(mapping);
    _next += mapping.tiles;

    return true;
  }

  @override
  String toString() {
    return '_VramRegion{_offset: $_offsetStart, end: $occupiedEnd, '
        '_next: $_next, _mappings: $_mappings}';
  }
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

  bool get lazilyLoaded => art == null || art is RamArt;

  final Word? requiredVramTile;

  SpriteVramMapping(
      {required this.tiles,
      this.art,
      this.duplicateOffsets = const [],
      this.animated = false,
      this.requiredVramTile});

  bool get mergable => art != null && !animated;

  SpriteVramMapping? merge(SpriteVramMapping other) {
    if (!const IterableEquality<int>()
        .equals(duplicateOffsets, other.duplicateOffsets)) return null;
    if (animated || other.animated) return null;
    if (art != other.art) return null;
    if (art == null || other.art == null) return null;
    final requiredTiles = <Word>{
      if (requiredVramTile case var t?) t,
      if (other.requiredVramTile case var t?) t,
    };
    // Two different required tiles; cannot merge
    if (requiredTiles.length == 2) return null;
    return SpriteVramMapping(
        tiles: max(tiles, other.tiles),
        art: art,
        duplicateOffsets: duplicateOffsets,
        requiredVramTile: requiredTiles.firstOrNull);
  }

  @override
  String toString() {
    return 'SpriteVramMapping{art: $art, tiles: $tiles, '
        'duplicateOffsets: $duplicateOffsets, animated: $animated}';
  }
}

Byte _compileInteractionScene(
    GameMap map,
    Scene scene,
    SceneId id,
    DialogTrees trees,
    EventAsm asm,
    EventRoutines eventRoutines,
    EventFlags eventFlags,
    {required FieldObject? withObject,
    required FieldRoutineRepository fieldRoutines}) {
  var events = scene.events;

  // todo: handle max
  var tree = trees.forMap(map.id);
  var dialogId = tree.nextDialogId!;

  SceneAsmGenerator generator = SceneAsmGenerator.forInteraction(
      map, id, trees, asm, eventRoutines,
      eventFlags: eventFlags,
      withObject: withObject,
      fieldRoutines: fieldRoutines);

  generator.runEventIfNeeded(events);

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
    Asm asm, MapObject obj, Word tileNumber, Byte dialogId,
    {required FieldRoutineRepository fieldRoutines}) {
  var spec = obj.spec;
  var routine = fieldRoutines.bySpec(spec);

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
      var doNotInteractIf = spec.oneTimeFlag;
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
  FieldRoutine routine(FieldRoutineRepository fieldRoutines) {
    var spec = this.spec;

    var routine = fieldRoutines.bySpec(spec);
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
    required Label dialog,
    String? events,
    FieldRoutineRepository? fieldRoutines}) {
  fieldRoutines ??= defaultFieldRoutines;
  final reader = ConstantReader.asm(original);
  final processed = <String>[];

  final trimmed = original.trim();
  final map = trimmed.first.label?.map((l) => Label(l));
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
  _readObjects(reader, fieldRoutines: fieldRoutines).forEach((_) {});
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
    _readAreas(reader).forEach((_) {});
    addComment('Areas');
    processed.add(areas);
    defineConstants([Word(0xffff)]);
  }

  if (events != null) {
    _readEvents(reader).forEach((_) {});
    addComment('Events');
    processed.add(events);
    defineConstants([Byte(0xff)]);
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

Future<GameMap> asmToMap(Label mapLabel, Asm asm, DialogTreeLookup dialogLookup,
    {FieldRoutineRepository? fieldRoutines}) async {
  fieldRoutines ??= defaultFieldRoutines;

  final mapId = labelToMapId(mapLabel);
  final map = GameMap(mapId);

  final reader = ConstantReader.asm(asm);

  _skipToSprites(reader);

  var sprites = _readSprites(reader);

  _skipAfterSpritesToObjects(reader);

  final asmObjects = _readObjects(reader, fieldRoutines: fieldRoutines)
      .toList(growable: false);

  _skipAfterObjectsToLabels(reader);

  // on maps there are 2 labels before dialog,
  // except on motavia and dezolis
  // (this is simply hard coded based on map IDs)
  Label dialogLabel;
  if ([MapId.Motavia, MapId.Dezolis].contains(mapId)) {
    dialogLabel = reader.readLabel();
  } else {
    reader.readLabel();
    reader.readLabel();
    dialogLabel = reader.readLabel();
  }

  var lookup = dialogLookup.byLabel(dialogLabel);
  var scenes = <_DialogAndLabel, Scene>{};

  // todo: pass map instead of returning lists to add to map?
  for (var asm in _readAreas(reader)) {
    var model = await _buildArea(mapId, asm,
        dialogLookup: dialogLookup,
        isWorldMotavia: mapId.world == World.Motavia,
        scenes: scenes);
    map.addArea(model);
  }

  for (var asm in _readEvents(reader)) {
    map.addAsmEvent(asm);
  }

  for (var obj in _buildObjects(mapId, sprites, asmObjects, await lookup)) {
    map.addObject(obj);
  }

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
            oneTimeFlag: flag != Byte.zero ? toEventFlag(flag) : null,
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

Iterable<_AsmObject> _readObjects(ConstantReader reader,
    {required FieldRoutineRepository fieldRoutines}) sync* {
  var i = 0;

  while (true) {
    var routineOrTerminate = reader.readWord();

    if (routineOrTerminate == Word(0xffff)) {
      return;
    }

    var facing = reader.readByte();
    var dialogId = reader.readByte();
    var vramTile = reader.readWord();
    var x = reader.readWord();
    var y = reader.readWord();

    var spec = fieldRoutines.byIndex(routineOrTerminate)?.factory;
    if (spec == null) {
      throw Exception('unknown field routine: $routineOrTerminate '
          'objectIndex=$i');
    }

    var position = Position(x.value * 8, y.value * 8);

    yield _AsmObject(
        routine: routineOrTerminate,
        spec: spec,
        facing: _byteToFacingDirection(facing),
        dialogId: dialogId,
        vramTile: vramTile,
        position: position);

    i++;
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

Iterable<MapObject> _buildObjects(MapId mapId, Map<_SpriteLoc, Label> sprites,
    Iterable<_AsmObject> asmObjects, DialogTree dialogTree) {
  // The same scene must reuse same object in memory
  var scenesById = <Byte, Scene>{};

  return asmObjects.mapIndexed((i, asm) {
    var artLbl = sprites[_VramSprite(asm.vramTile)];

    if (asm.spec.requiresSprite && artLbl == null) {
      throw StateError('field object routine ${asm.routine} requires sprite '
          'but art label was null for tile number ${asm.vramTile}');
    }

    var sprite = artLbl == null ? null : spriteForLabel(artLbl);
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
  });
}

Iterable<_AsmArea> _readAreas(ConstantReader reader) sync* {
  var i = 0;

  while (true) {
    var xOrTerminate = reader.readWord();
    if (xOrTerminate == Word(0xffff)) {
      return;
    }

    var x = xOrTerminate;
    var y = reader.readWord();
    var range = _parseRangeType(reader.readWord());
    var flagType = reader.readByte();
    var flag = reader.readByte();
    var routine = reader.readByte();
    var param = reader.readByteExpression();
    var position = Position(x.value << 3, y.value << 3);

    yield _AsmArea(i++, range, position,
        flagType: flagType, flag: flag, routine: routine, param: param);
  }
}

Iterable<Byte> _readEvents(ConstantReader reader) {
  var events = <Byte>[];

  while (true) {
    var control = reader.readByte();
    if (control == Byte(0xff)) {
      return events;
    }
    events.add(control);
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
