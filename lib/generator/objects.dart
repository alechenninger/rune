import 'package:collection/collection.dart';
import 'package:quiver/collection.dart';

import '../model/model.dart';
import 'generator.dart';

const _defaultVramTilesPerSprite = 0x48;

// todo: default to convention & allow override
final _spriteArtLabels = BiMap<Sprite, Label>()
  ..addAll(Sprite.wellKnown.groupFoldBy(
      (sprite) => sprite, (previous, sprite) => Label('Art_${sprite.name}')));

extension SpriteLabel on Sprite {
  Label get label => _spriteArtLabels[this] ?? Label(name);
}

Sprite spriteForLabel(Label label) {
  return _spriteArtLabels.inverse[label] ?? Sprite(label.name);
}

final defaultFieldRoutines = FieldRoutineRepository([
  FieldRoutine(
      Word(0x68),
      Label('FieldObj_NPCAlysPiata'),
      spriteMappingTiles: 8,
      vramAnimated: true,
      SpecFactory((_) => AlysWaiting(), forSpec: AlysWaiting)),
  FieldRoutine.asm(Word(0xF0), Label('FieldObj_NPCGryz'),
      spriteMappingTiles: 8, vramAnimated: true),
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
      SpecFactory.npc((s, _) => Npc(s, FaceDown()))),
  FieldRoutine(
      Word(0x134),
      Label('FieldObj_Pana'),
      spriteMappingTiles: 18,
      SpecFactory.npc((s, _) => Npc(s, FaceDownSimpleSprite()))),
  FieldRoutine(Word(0x3C), Label('FieldObj_NPCType2'),
      SpecFactory.npc((s, d) => Npc(s, WanderAround(d)))),
  FieldRoutine(Word(0x40), Label('FieldObj_NPCType3'),
      SpecFactory.npc((s, d) => Npc(s, SlowlyWanderAround(d)))),
  FieldRoutine(Word(0x58), Label('FieldObj_NPCType9'),
      SpecFactory.npc((s, d) => Npc(s, FaceUp()))),
  FieldRoutine(
      Word(0x140),
      Label('loc_49502'),
      spriteMappingTiles: 8,
      SpecFactory.npc((s, _) => Npc(s, FaceDownLegsHiddenNonInteractive()))),
  FieldRoutine(
      Word(0x108),
      Label('FieldObj_NPCType32'),
      spriteMappingTiles: 0x38,
      SpecFactory.npc((s, _) => Npc(s, FaceDownOrUpLegsHidden()))),
  FieldRoutine(
      Word(0x14C),
      Label('loc_49502'),
      spriteMappingTiles: 8,
      SpecFactory.npc((s, _) => Npc(s, FixedFaceRight()))),
  FieldRoutine.asm(Word(0xF8), Label('FieldObj_NPCType28'),
      spriteMappingTiles: 6,
      ramArt: RamArt(address: Word(0)),
      vramAnimated: true),
  FieldRoutine.asm(Word(0x174), Label('FieldObj_BigDuck'),
      spriteMappingTiles: 0x20),
  FieldRoutine.asm(Word(0x178), Label('FieldObj_SmallWhiteDuck'),
      spriteMappingTiles: 0x20),
  FieldRoutine.asm(Word(0x17c), Label('FieldObj_SmallBrownDuck'),
      spriteMappingTiles: 0x20),
  FieldRoutine.asm(Word(0x144), Label('loc_49192'), spriteMappingTiles: 0x36),
  FieldRoutine.asm(Word(0x170), Label('FieldObj_Butterfly'),
      spriteMappingTiles: 2),
  FieldRoutine.asm(Word(0x2F4), Label('FieldObj_StrayRocky'),
      // TODO(field routines): this can probably be less
      spriteMappingTiles: 0x40),
  FieldRoutine.asm(Word(0x1B0), Label('FieldObj_DorinChair'),
      spriteMappingTiles: 0x15),
  FieldRoutine.asm(Word(0x12C), Label('loc_48F96'), spriteMappingTiles: 24),
  FieldRoutine.asm(Word(0x298), Label('FieldObj_NPCAlysInBed'),
      spriteMappingTiles: 7),
  FieldRoutine.asm(Word(0xEC), Label('FieldObj_NPCHahn'),
      spriteMappingTiles: 8),
]);

class FieldRoutineRepository {
  final Map<Word, FieldRoutine> _byIndex;
  final Map<Label, FieldRoutine> _byLabel;
  final Map<SpecModel, FieldRoutine> _byModel;

  FieldRoutineRepository(Iterable<FieldRoutine> routines)
      : _byIndex = {for (var r in routines) r.index: r},
        _byLabel = {for (var r in routines) r.label: r},
        _byModel = {for (var r in routines) r.factory.routineModel: r};

  Iterable<FieldRoutine> all() =>
      fieldObjectsJmpTbl.values.map((i) => byIndex(i)).whereNotNull();

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
    return switch (spec) {
      // TODO: this may not be symmetrical
      // it's possible the found routine constructs specs of a different type
      AsmSpec() => byIndex(spec.routine),
      Npc() => _byModel[NpcRoutineModel(spec.behavior.runtimeType)],
      _ => _byModel[SpecRoutineModel(spec.runtimeType)]
    };
  }

  FieldRoutine? bySpecModel(SpecModel spec) {
    return switch (spec) {
      AsmRoutineModel() => byIndex(spec.index),
      NpcRoutineModel() => _byModel[spec],
      SpecRoutineModel() => _byModel[spec],
    };
  }
}

/// Used to parse the ASM into the model
/// as well as store necessary information for generation.
abstract class SpecFactory {
  bool get requiresSprite;

  SpecModel get routineModel;

  MapObjectSpec call(Sprite? sprite, Direction facing);

  static SpecFactory npc<T extends NpcBehavior>(
      Npc<T> Function(Sprite sprite, Direction facing) factory) {
    return _NpcFactory(factory, T);
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
  final AsmRoutineModel routineModel;
  _AsmSpecFactory(Word routine) : routineModel = AsmRoutineModel(routine);
  @override
  AsmSpec call(Sprite? sprite, Direction facing) {
    var label = switch (sprite) {
      Sprite() => _spriteArtLabels[sprite] ?? Label(sprite.name),
      null => null,
    };
    return AsmSpec(
        artLabel: label, routine: routineModel.index, startFacing: facing);
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

  const FieldRoutine(this.index, this.label, this.factory,
      {this.spriteMappingTiles = _defaultVramTilesPerSprite,
      this.ramArt,
      this.vramAnimated = false});

  FieldRoutine.asm(this.index, this.label,
      {this.spriteMappingTiles = _defaultVramTilesPerSprite,
      this.ramArt,
      this.vramAnimated = false})
      : factory = SpecFactory.asm(index);

  SpriteVramMapping? spriteVramMapping(MapObjectSpec spec) {
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

    // TODO: need way to set required vram tile here
    // probably parameterize this per map object somehow
    return SpriteVramMapping(
        tiles: spriteMappingTiles,
        art: artPointer,
        duplicateOffsets: duplicateOffsets,
        animated: vramAnimated);
  }

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
