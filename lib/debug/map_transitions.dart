import 'package:collection/collection.dart';
import '../model/model.dart';

typedef MapTransition = ({
  MapId from,
  MapId to,
  Position position,
  Direction direction
});

Set<MapTransition> entrypointsToMap(MapId map) {
  return _transitionsByDestination[map] ?? {};
}

List<MapTransition> allEntrypoints() => List.unmodifiable(_mapTransitions);

final _transitionsByDestination = _mapTransitions.groupSetsBy((t) => t.to);

final _mapTransitions = <MapTransition>[
  (
    from: MapId.Motavia,
    to: MapId.Piata,
    position: Position(0x1f0, 0x2e0),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Mile,
    position: Position(0x140, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Zema,
    position: Position(0x1f0, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Krup,
    position: Position(0x260, 0x360),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Molcum,
    position: Position(0x1e0, 0x310),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Tonoe,
    position: Position(0x160, 0x350),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Nalya,
    position: Position(0x1e0, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Aiedo,
    position: Position(0x2f0, 0x520),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Kadary,
    position: Position(0x250, 0x320),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Monsen,
    position: Position(0x120, 0x2c0),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Termi,
    position: Position(0x1e0, 0x360),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Uzo,
    position: Position(0x2f0, 0x130),
    direction: Direction.left
  ),
  (
    from: MapId.Motavia,
    to: MapId.Torinco,
    position: Position(0x130, 0x340),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.ZioFort,
    position: Position(0x2f0, 0x460),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.LadeaTower,
    position: Position(0x2f0, 0x500),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.PassagewayNearKadary,
    position: Position(0x1f0, 0x220),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.PassagewayNearAiedo,
    position: Position(0x1f0, 0x220),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.IslandCave,
    position: Position(0x380, 0x4f0),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.ValleyMazeOutside,
    position: Position(0x1f0, 0x220),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.ValleyMazeOutside2,
    position: Position(0x1f0, 0x220),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.Wreckage,
    position: Position(0x2f0, 0x320),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.MachineCenter,
    position: Position(0x1e0, 0x1a0),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.MotaSpaceport,
    position: Position(0x1e0, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.PlateSystem,
    position: Position(0x240, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.VahalFort,
    position: Position(0x2e0, 0x4e0),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.RappyCave,
    position: Position(0x3f0, 0x710),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.TheEdge,
    position: Position(0x1e0, 0x310),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.TheEdge,
    position: Position(0x1e0, 0x310),
    direction: Direction.up
  ),
  (
    from: MapId.Motavia,
    to: MapId.TheEdge,
    position: Position(0x1e0, 0x310),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.Reshel1,
    position: Position(0x1e0, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.Ryuon,
    position: Position(0x1f0, 0x320),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.Zosa,
    position: Position(0x1f0, 0x340),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.Meese,
    position: Position(0x1d0, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.Tyler,
    position: Position(0x2e0, 0x340),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.Jut,
    position: Position(0x300, 0x4e0),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.MystVale,
    position: Position(0x200, 0x310),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.WeaponPlant,
    position: Position(0x1e0, 0x1c0),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.ClimCenter,
    position: Position(0x2e0, 0x480),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.DezoSpaceport,
    position: Position(0x1e0, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.EspMansionEntrance,
    position: Position(0x200, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.GumbiousEntrance,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.RajaTemple,
    position: Position(0x5f0, 0x240),
    direction: Direction.up
  ),
  (
    from: MapId.Dezolis,
    to: MapId.GaruberkTower,
    position: Position(0x1e0, 0x310),
    direction: Direction.up
  ),
  (
    from: MapId.Rykros,
    to: MapId.SilenceTm,
    position: Position(0x2f0, 0x500),
    direction: Direction.up
  ),
  (
    from: MapId.Rykros,
    to: MapId.StrengthTower,
    position: Position(0x1f0, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.Rykros,
    to: MapId.CourageTower,
    position: Position(0x1f0, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.Rykros,
    to: MapId.AngerTower,
    position: Position(0x1f0, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.Piata,
    to: MapId.Motavia,
    position: Position(0x2e0, 0x8e0),
    direction: Direction.down
  ),
  (
    from: MapId.Piata,
    to: MapId.PiataAcademy,
    position: Position(0x1f0, 0x120),
    direction: Direction.up
  ),
  (
    from: MapId.Piata,
    to: MapId.PiataDorm,
    position: Position(0x2d0, 0x1e0),
    direction: Direction.up
  ),
  (
    from: MapId.Piata,
    to: MapId.PiataInn,
    position: Position(0x290, 0x240),
    direction: Direction.up
  ),
  (
    from: MapId.Piata,
    to: MapId.PiataHouse1,
    position: Position(0x1b0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Piata,
    to: MapId.PiataItemShop,
    position: Position(0x210, 0x240),
    direction: Direction.up
  ),
  (
    from: MapId.Piata,
    to: MapId.PiataHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.PiataAcademy,
    to: MapId.Piata,
    position: Position(0x1f0, 0x60),
    direction: Direction.down
  ),
  (
    from: MapId.PiataAcademy,
    to: MapId.PiataAcademyNearBasement,
    position: Position(0xe0, 0x140),
    direction: Direction.up
  ),
  (
    from: MapId.PiataAcademy,
    to: MapId.PiataAcademyF1,
    position: Position(0x110, 0x120),
    direction: Direction.right
  ),
  (
    from: MapId.PiataAcademy,
    to: MapId.PiataAcademyNearBasement,
    position: Position(0xe0, 0x140),
    direction: Direction.up
  ),
  (
    from: MapId.PiataAcademyNearBasement,
    to: MapId.PiataAcademy,
    position: Position(0x1e0, 0x70),
    direction: Direction.down
  ),
  (
    from: MapId.PiataAcademyNearBasement,
    to: MapId.PiataAcademyBasement,
    position: Position(0x300, 0x80),
    direction: Direction.down
  ),
  (
    from: MapId.PiataAcademyF1,
    to: MapId.PiataAcademyPrincipalOffice,
    position: Position(0xf0, 0x130),
    direction: Direction.up
  ),
  (
    from: MapId.PiataAcademyF1,
    to: MapId.TheEdge,
    position: Position(0x1e0, 0x310),
    direction: Direction.down
  ),
  (
    from: MapId.PiataAcademyF1,
    to: MapId.Dezolis,
    position: Position(0x1e0, 0x310),
    direction: Direction.down
  ),
  (
    from: MapId.PiataAcademyF1,
    to: MapId.Rykros,
    position: Position(0x1e0, 0x310),
    direction: Direction.down
  ),
  (
    from: MapId.PiataAcademyF1,
    to: MapId.PiataAcademy,
    position: Position(0x100, 0x120),
    direction: Direction.left
  ),
  (
    from: MapId.PiataAcademyPrincipalOffice,
    to: MapId.PiataAcademyF1,
    position: Position(0x1f0, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.PiataAcademyBasement,
    to: MapId.PiataAcademyNearBasement,
    position: Position(0x130, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.PiataAcademyBasement,
    to: MapId.PiataAcademyBasementB1,
    position: Position(0x300, 0x80),
    direction: Direction.down
  ),
  (
    from: MapId.PiataAcademyBasementB1,
    to: MapId.PiataAcademyBasement,
    position: Position(0x210, 0x80),
    direction: Direction.down
  ),
  (
    from: MapId.PiataAcademyBasementB1,
    to: MapId.PiataAcademyBasementB2,
    position: Position(0x100, 0x120),
    direction: Direction.left
  ),
  (
    from: MapId.PiataAcademyBasementB2,
    to: MapId.PiataAcademyBasementB1,
    position: Position(0xf0, 0x120),
    direction: Direction.right
  ),
  (
    from: MapId.PiataDorm,
    to: MapId.Piata,
    position: Position(0x160, 0x140),
    direction: Direction.down
  ),
  (
    from: MapId.PiataInn,
    to: MapId.Piata,
    position: Position(0x160, 0x1e0),
    direction: Direction.down
  ),
  (
    from: MapId.PiataHouse1,
    to: MapId.Piata,
    position: Position(0x2a0, 0x1a0),
    direction: Direction.down
  ),
  (
    from: MapId.PiataItemShop,
    to: MapId.Piata,
    position: Position(0x120, 0x260),
    direction: Direction.down
  ),
  (
    from: MapId.PiataHouse2,
    to: MapId.Piata,
    position: Position(0x2e0, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.Mile,
    to: MapId.Motavia,
    position: Position(0x3d0, 0x640),
    direction: Direction.down
  ),
  (
    from: MapId.Mile,
    to: MapId.Motavia,
    position: Position(0x3d0, 0x640),
    direction: Direction.down
  ),
  (
    from: MapId.Mile,
    to: MapId.Motavia,
    position: Position(0x3d0, 0x640),
    direction: Direction.down
  ),
  (
    from: MapId.Mile,
    to: MapId.Motavia,
    position: Position(0x3d0, 0x640),
    direction: Direction.down
  ),
  (
    from: MapId.Mile,
    to: MapId.MileWeaponShop,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Mile,
    to: MapId.MileHouse1,
    position: Position(0x210, 0x240),
    direction: Direction.up
  ),
  (
    from: MapId.Mile,
    to: MapId.MileItemShop,
    position: Position(0x210, 0x240),
    direction: Direction.up
  ),
  (
    from: MapId.Mile,
    to: MapId.MileHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Mile,
    to: MapId.MileInn,
    position: Position(0x150, 0x2c0),
    direction: Direction.up
  ),
  (
    from: MapId.MileDead,
    to: MapId.Motavia,
    position: Position(0x3d0, 0x640),
    direction: Direction.down
  ),
  (
    from: MapId.MileDead,
    to: MapId.Motavia,
    position: Position(0x3d0, 0x640),
    direction: Direction.down
  ),
  (
    from: MapId.MileDead,
    to: MapId.Motavia,
    position: Position(0x3d0, 0x640),
    direction: Direction.down
  ),
  (
    from: MapId.MileDead,
    to: MapId.Motavia,
    position: Position(0x3d0, 0x640),
    direction: Direction.down
  ),
  (
    from: MapId.MileDead,
    to: MapId.MileWeaponShop,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.MileDead,
    to: MapId.MileHouse1,
    position: Position(0x210, 0x240),
    direction: Direction.up
  ),
  (
    from: MapId.MileDead,
    to: MapId.MileItemShop,
    position: Position(0x210, 0x240),
    direction: Direction.up
  ),
  (
    from: MapId.MileDead,
    to: MapId.MileHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.MileDead,
    to: MapId.MileInn,
    position: Position(0x150, 0x2c0),
    direction: Direction.up
  ),
  (
    from: MapId.MileWeaponShop,
    to: MapId.Mile,
    position: Position(0x200, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.MileHouse1,
    to: MapId.Mile,
    position: Position(0x2c0, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.MileItemShop,
    to: MapId.Mile,
    position: Position(0x220, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.MileHouse2,
    to: MapId.Mile,
    position: Position(0x2a0, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.MileInn,
    to: MapId.Mile,
    position: Position(0x260, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.Zema,
    to: MapId.Motavia,
    position: Position(0x630, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.Zema,
    to: MapId.BirthValley,
    position: Position(0x110, 0x330),
    direction: Direction.up
  ),
  (
    from: MapId.Zema,
    to: MapId.ZemaHouse1,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Zema,
    to: MapId.ZemaWeaponShop,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Zema,
    to: MapId.ZemaInn,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Zema,
    to: MapId.ZemaHouse2,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Zema,
    to: MapId.ZemaItemShop,
    position: Position(0x1b0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.ZemaHouse1,
    to: MapId.Zema,
    position: Position(0x2c0, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.ZemaWeaponShop,
    to: MapId.Zema,
    position: Position(0x1a0, 0x1e0),
    direction: Direction.down
  ),
  (
    from: MapId.ZemaInn,
    to: MapId.Zema,
    position: Position(0x240, 0x1e0),
    direction: Direction.down
  ),
  (
    from: MapId.ZemaHouse2,
    to: MapId.Zema,
    position: Position(0x160, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.ZemaHouse2,
    to: MapId.ZemaHouse2_B1,
    position: Position(0x200, 0x1e0),
    direction: Direction.left
  ),
  (
    from: MapId.ZemaHouse2_B1,
    to: MapId.ZemaHouse2,
    position: Position(0x230, 0x160),
    direction: Direction.right
  ),
  (
    from: MapId.ZemaItemShop,
    to: MapId.Zema,
    position: Position(0x2a0, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.BirthValley,
    to: MapId.Zema,
    position: Position(0x1e0, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.BirthValley,
    to: MapId.BirthValley_B1,
    position: Position(0x180, 0x300),
    direction: Direction.left
  ),
  (
    from: MapId.BirthValley_B1,
    to: MapId.BirthValley,
    position: Position(0x210, 0xe0),
    direction: Direction.right
  ),
  (
    from: MapId.BirthValley_B1,
    to: MapId.BioPlant,
    position: Position(0x200, 0x1c0),
    direction: Direction.up
  ),
  (
    from: MapId.ValleyMazeUnused,
    to: MapId.Motavia,
    position: Position(0x800, 0x790),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMazeUnused,
    to: MapId.ValleyMaze_Part2,
    position: Position(0x1c0, 0x250),
    direction: Direction.up
  ),
  (
    from: MapId.ValleyMazeUnused,
    to: MapId.ValleyMaze_Part3,
    position: Position(0x2e0, 0x2f0),
    direction: Direction.up
  ),
  (
    from: MapId.Krup,
    to: MapId.Motavia,
    position: Position(0x6d0, 0x980),
    direction: Direction.down
  ),
  (
    from: MapId.Krup,
    to: MapId.Motavia,
    position: Position(0x6d0, 0x980),
    direction: Direction.down
  ),
  (
    from: MapId.Krup,
    to: MapId.Motavia,
    position: Position(0x6d0, 0x980),
    direction: Direction.down
  ),
  (
    from: MapId.Krup,
    to: MapId.Motavia,
    position: Position(0x6d0, 0x980),
    direction: Direction.down
  ),
  (
    from: MapId.Krup,
    to: MapId.KrupKindergarten,
    position: Position(0x190, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.Krup,
    to: MapId.KrupWeaponShop,
    position: Position(0x190, 0x200),
    direction: Direction.up
  ),
  (
    from: MapId.Krup,
    to: MapId.KrupWeaponShop,
    position: Position(0x270, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Krup,
    to: MapId.KrupItemShop,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Krup,
    to: MapId.KrupHouse,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Krup,
    to: MapId.KrupInn,
    position: Position(0x170, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.KrupKindergarten,
    to: MapId.Krup,
    position: Position(0x240, 0x140),
    direction: Direction.down
  ),
  (
    from: MapId.KrupWeaponShop,
    to: MapId.Krup,
    position: Position(0x140, 0x1c0),
    direction: Direction.down
  ),
  (
    from: MapId.KrupWeaponShop,
    to: MapId.Krup,
    position: Position(0x1a0, 0x1e0),
    direction: Direction.down
  ),
  (
    from: MapId.KrupItemShop,
    to: MapId.Krup,
    position: Position(0x280, 0x1c0),
    direction: Direction.down
  ),
  (
    from: MapId.KrupHouse,
    to: MapId.Krup,
    position: Position(0x160, 0x280),
    direction: Direction.down
  ),
  (
    from: MapId.KrupInn,
    to: MapId.Krup,
    position: Position(0x260, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.KrupInn,
    to: MapId.KrupInn_F1,
    position: Position(0x230, 0x220),
    direction: Direction.right
  ),
  (
    from: MapId.KrupInn_F1,
    to: MapId.KrupInn,
    position: Position(0x2a0, 0x240),
    direction: Direction.left
  ),
  (
    from: MapId.Molcum,
    to: MapId.Motavia,
    position: Position(0x530, 0x9e0),
    direction: Direction.down
  ),
  (
    from: MapId.Molcum,
    to: MapId.Motavia,
    position: Position(0x530, 0x9e0),
    direction: Direction.down
  ),
  (
    from: MapId.Molcum,
    to: MapId.Motavia,
    position: Position(0x530, 0x9e0),
    direction: Direction.down
  ),
  (
    from: MapId.Molcum,
    to: MapId.Motavia,
    position: Position(0x530, 0x9e0),
    direction: Direction.down
  ),
  (
    from: MapId.Tonoe,
    to: MapId.Motavia,
    position: Position(0x970, 0x580),
    direction: Direction.down
  ),
  (
    from: MapId.Tonoe,
    to: MapId.Motavia,
    position: Position(0x970, 0x580),
    direction: Direction.down
  ),
  (
    from: MapId.Tonoe,
    to: MapId.Motavia,
    position: Position(0x970, 0x580),
    direction: Direction.down
  ),
  (
    from: MapId.Tonoe,
    to: MapId.Motavia,
    position: Position(0x970, 0x580),
    direction: Direction.down
  ),
  (
    from: MapId.Tonoe,
    to: MapId.TonoeStorageRoom,
    position: Position(0x1e0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Tonoe,
    to: MapId.TonoeGryzHouse,
    position: Position(0x1e0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Tonoe,
    to: MapId.TonoeHouse1,
    position: Position(0x1e0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Tonoe,
    to: MapId.TonoeHouse2,
    position: Position(0x1e0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Tonoe,
    to: MapId.TonoeInn,
    position: Position(0x160, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.TonoeStorageRoom,
    to: MapId.Tonoe,
    position: Position(0x1f0, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.TonoeStorageRoom,
    to: MapId.TonoeBasement,
    position: Position(0x200, 0x2e0),
    direction: Direction.left
  ),
  (
    from: MapId.TonoeGryzHouse,
    to: MapId.Tonoe,
    position: Position(0x2d0, 0x140),
    direction: Direction.down
  ),
  (
    from: MapId.TonoeHouse1,
    to: MapId.Tonoe,
    position: Position(0x1d0, 0x260),
    direction: Direction.down
  ),
  (
    from: MapId.TonoeHouse2,
    to: MapId.Tonoe,
    position: Position(0x1d0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.TonoeInn,
    to: MapId.Tonoe,
    position: Position(0x130, 0x280),
    direction: Direction.down
  ),
  (
    from: MapId.TonoeBasement,
    to: MapId.TonoeStorageRoom,
    position: Position(0x1f0, 0x1a0),
    direction: Direction.down
  ),
  (
    from: MapId.TonoeBasement,
    to: MapId.TonoeBasement_B1,
    position: Position(0x1e0, 0xc0),
    direction: Direction.left
  ),
  (
    from: MapId.TonoeBasement_B1,
    to: MapId.TonoeBasement,
    position: Position(0x210, 0xe0),
    direction: Direction.down
  ),
  (
    from: MapId.TonoeBasement_B1,
    to: MapId.TonoeBasement_B2,
    position: Position(0x1c0, 0x340),
    direction: Direction.left
  ),
  (
    from: MapId.TonoeBasement_B2,
    to: MapId.TonoeBasement_B1,
    position: Position(0x1f0, 0x300),
    direction: Direction.down
  ),
  (
    from: MapId.TonoeBasement_B2,
    to: MapId.TonoeBasement_B3,
    position: Position(0x320, 0x300),
    direction: Direction.left
  ),
  (
    from: MapId.TonoeBasement_B3,
    to: MapId.TonoeBasement_B2,
    position: Position(0x310, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.Nalya,
    to: MapId.Motavia,
    position: Position(0x510, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.Nalya,
    to: MapId.Motavia,
    position: Position(0x510, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.Nalya,
    to: MapId.Motavia,
    position: Position(0x510, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.Nalya,
    to: MapId.Motavia,
    position: Position(0x510, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.Nalya,
    to: MapId.NalyaHouse1,
    position: Position(0x1e0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Nalya,
    to: MapId.NalyaHouse2,
    position: Position(0x1e0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Nalya,
    to: MapId.NalyaItemShop,
    position: Position(0x1e0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Nalya,
    to: MapId.NalyaHouse3,
    position: Position(0x1b0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Nalya,
    to: MapId.NalyaHouse4,
    position: Position(0x210, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Nalya,
    to: MapId.NalyaHouse5,
    position: Position(0x250, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Nalya,
    to: MapId.NalyaInn,
    position: Position(0x1d0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.NalyaHouse1,
    to: MapId.Nalya,
    position: Position(0x290, 0x1e0),
    direction: Direction.down
  ),
  (
    from: MapId.NalyaHouse2,
    to: MapId.Nalya,
    position: Position(0x210, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.NalyaItemShop,
    to: MapId.Nalya,
    position: Position(0x290, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.NalyaHouse3,
    to: MapId.Nalya,
    position: Position(0x140, 0x220),
    direction: Direction.down
  ),
  (
    from: MapId.NalyaHouse4,
    to: MapId.Nalya,
    position: Position(0x1c0, 0x260),
    direction: Direction.down
  ),
  (
    from: MapId.NalyaHouse5,
    to: MapId.Nalya,
    position: Position(0x160, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.NalyaInn,
    to: MapId.Nalya,
    position: Position(0x280, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.NalyaInn,
    to: MapId.NalyaInn_F1,
    position: Position(0x290, 0x1a0),
    direction: Direction.right
  ),
  (
    from: MapId.NalyaInn_F1,
    to: MapId.NalyaInn,
    position: Position(0x280, 0x1c0),
    direction: Direction.left
  ),
  (
    from: MapId.Aiedo,
    to: MapId.Motavia,
    position: Position(0x240, 0x3c0),
    direction: Direction.down
  ),
  (
    from: MapId.Aiedo,
    to: MapId.Motavia,
    position: Position(0x240, 0x3c0),
    direction: Direction.down
  ),
  (
    from: MapId.Aiedo,
    to: MapId.Motavia,
    position: Position(0x240, 0x3c0),
    direction: Direction.down
  ),
  (
    from: MapId.Aiedo,
    to: MapId.Motavia,
    position: Position(0x240, 0x3c0),
    direction: Direction.down
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoBakery,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.HuntersGuild,
    position: Position(0x110, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoWeaponShop,
    position: Position(0x190, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoWeaponShop,
    position: Position(0x270, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoPrison,
    position: Position(0x170, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoHouse1,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.ShayHouse,
    position: Position(0x1f0, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoHouse3,
    position: Position(0x1d0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoHouse4,
    position: Position(0x230, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoHouse5,
    position: Position(0x230, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoSupermarket,
    position: Position(0x1f0, 0x1e0),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoPub,
    position: Position(0x250, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.RockyHouse,
    position: Position(0x230, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoHouse6,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Aiedo,
    to: MapId.AiedoHouse7,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.AiedoBakery,
    to: MapId.Aiedo,
    position: Position(0x140, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoBakery,
    to: MapId.AiedoBakery_B1,
    position: Position(0x220, 0x1c0),
    direction: Direction.left
  ),
  (
    from: MapId.AiedoBakery_B1,
    to: MapId.AiedoBakery,
    position: Position(0x230, 0x1c0),
    direction: Direction.right
  ),
  (
    from: MapId.HuntersGuild,
    to: MapId.Aiedo,
    position: Position(0x200, 0x180),
    direction: Direction.down
  ),
  (
    from: MapId.HuntersGuild,
    to: MapId.StripClub,
    position: Position(0x220, 0x2c0),
    direction: Direction.up
  ),
  (
    from: MapId.HuntersGuild,
    to: MapId.StripClub,
    position: Position(0x2a0, 0x2c0),
    direction: Direction.up
  ),
  (
    from: MapId.HuntersGuild,
    to: MapId.HuntersGuildStorage,
    position: Position(0x250, 0x1f0),
    direction: Direction.left
  ),
  (
    from: MapId.HuntersGuild,
    to: MapId.StripClubDressingRoom,
    position: Position(0x180, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.HuntersGuildStorage,
    to: MapId.HuntersGuild,
    position: Position(0x1a0, 0x150),
    direction: Direction.right
  ),
  (
    from: MapId.StripClubDressingRoom,
    to: MapId.HuntersGuild,
    position: Position(0x210, 0x120),
    direction: Direction.left
  ),
  (
    from: MapId.StripClubDressingRoom,
    to: MapId.StripClub,
    position: Position(0x180, 0x190),
    direction: Direction.right
  ),
  (
    from: MapId.StripClubDressingRoom,
    to: MapId.StripClub,
    position: Position(0x180, 0x1c0),
    direction: Direction.right
  ),
  (
    from: MapId.StripClub,
    to: MapId.HuntersGuild,
    position: Position(0x2e0, 0x1b0),
    direction: Direction.down
  ),
  (
    from: MapId.StripClub,
    to: MapId.HuntersGuild,
    position: Position(0x320, 0x1b0),
    direction: Direction.down
  ),
  (
    from: MapId.StripClub,
    to: MapId.StripClubDressingRoom,
    position: Position(0x270, 0x1b0),
    direction: Direction.left
  ),
  (
    from: MapId.StripClub,
    to: MapId.StripClubDressingRoom,
    position: Position(0x290, 0x220),
    direction: Direction.left
  ),
  (
    from: MapId.AiedoWeaponShop,
    to: MapId.Aiedo,
    position: Position(0x2a0, 0x220),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoWeaponShop,
    to: MapId.Aiedo,
    position: Position(0x2e0, 0x220),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoPrison,
    to: MapId.Aiedo,
    position: Position(0x380, 0x1a0),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoHouse1,
    to: MapId.Aiedo,
    position: Position(0x4c0, 0x1e0),
    direction: Direction.down
  ),
  (
    from: MapId.ShayHouse,
    to: MapId.Aiedo,
    position: Position(0x160, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoHouse2,
    to: MapId.Aiedo,
    position: Position(0x160, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoHouse3,
    to: MapId.Aiedo,
    position: Position(0x1c0, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoHouse4,
    to: MapId.Aiedo,
    position: Position(0x160, 0x380),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoHouse5,
    to: MapId.Aiedo,
    position: Position(0x1e0, 0x380),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoSupermarket,
    to: MapId.Aiedo,
    position: Position(0x300, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoPub,
    to: MapId.Aiedo,
    position: Position(0x460, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.RockyHouse,
    to: MapId.Aiedo,
    position: Position(0x440, 0x380),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoHouse6,
    to: MapId.Aiedo,
    position: Position(0x4c0, 0x380),
    direction: Direction.down
  ),
  (
    from: MapId.AiedoHouse7,
    to: MapId.Aiedo,
    position: Position(0x260, 0x4a0),
    direction: Direction.down
  ),
  (
    from: MapId.Kadary,
    to: MapId.Motavia,
    position: Position(0x310, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.Kadary,
    to: MapId.Motavia,
    position: Position(0x310, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.Kadary,
    to: MapId.Motavia,
    position: Position(0x310, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.Kadary,
    to: MapId.Motavia,
    position: Position(0x310, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.Kadary,
    to: MapId.KadaryChurch,
    position: Position(0x1f0, 0x320),
    direction: Direction.up
  ),
  (
    from: MapId.Kadary,
    to: MapId.KadaryPub,
    position: Position(0x190, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.Kadary,
    to: MapId.KadaryStorageRoom,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Kadary,
    to: MapId.KadaryHouse1,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Kadary,
    to: MapId.KadaryHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Kadary,
    to: MapId.KadaryHouse3,
    position: Position(0x1b0, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Kadary,
    to: MapId.KadaryItemShop,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Kadary,
    to: MapId.KadaryInn,
    position: Position(0x210, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.KadaryChurch,
    to: MapId.Kadary,
    position: Position(0x140, 0x150),
    direction: Direction.down
  ),
  (
    from: MapId.KadaryPub,
    to: MapId.Kadary,
    position: Position(0x200, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.KadaryPub,
    to: MapId.KadaryPub_F1,
    position: Position(0x270, 0x180),
    direction: Direction.right
  ),
  (
    from: MapId.KadaryPub_F1,
    to: MapId.KadaryPub,
    position: Position(0x260, 0x180),
    direction: Direction.left
  ),
  (
    from: MapId.KadaryStorageRoom,
    to: MapId.Kadary,
    position: Position(0x2c0, 0x120),
    direction: Direction.down
  ),
  (
    from: MapId.KadaryHouse1,
    to: MapId.Kadary,
    position: Position(0x160, 0x260),
    direction: Direction.down
  ),
  (
    from: MapId.KadaryHouse2,
    to: MapId.Kadary,
    position: Position(0x1c0, 0x260),
    direction: Direction.down
  ),
  (
    from: MapId.KadaryHouse3,
    to: MapId.Kadary,
    position: Position(0x260, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.KadaryItemShop,
    to: MapId.Kadary,
    position: Position(0x160, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.KadaryInn,
    to: MapId.Kadary,
    position: Position(0x2c0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.KadaryInn,
    to: MapId.KadaryInn_F1,
    position: Position(0x290, 0x220),
    direction: Direction.right
  ),
  (
    from: MapId.KadaryInn_F1,
    to: MapId.KadaryInn,
    position: Position(0x280, 0x220),
    direction: Direction.left
  ),
  (
    from: MapId.Monsen,
    to: MapId.Motavia,
    position: Position(0xb50, 0x660),
    direction: Direction.down
  ),
  (
    from: MapId.Monsen,
    to: MapId.Motavia,
    position: Position(0xb50, 0x660),
    direction: Direction.down
  ),
  (
    from: MapId.Monsen,
    to: MapId.Motavia,
    position: Position(0xb50, 0x660),
    direction: Direction.down
  ),
  (
    from: MapId.Monsen,
    to: MapId.Motavia,
    position: Position(0xb50, 0x660),
    direction: Direction.down
  ),
  (
    from: MapId.Monsen,
    to: MapId.MonsenCave,
    position: Position(0x340, 0x470),
    direction: Direction.down
  ),
  (
    from: MapId.Monsen,
    to: MapId.MonsenCave,
    position: Position(0x340, 0x470),
    direction: Direction.down
  ),
  (
    from: MapId.Monsen,
    to: MapId.MonsenInn,
    position: Position(0x210, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.Monsen,
    to: MapId.MonsenHouse1,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Monsen,
    to: MapId.MonsenHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Monsen,
    to: MapId.MonsenHouse3,
    position: Position(0x1f0, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Monsen,
    to: MapId.MonsenHouse4,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Monsen,
    to: MapId.MonsenHouse5,
    position: Position(0x210, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.Monsen,
    to: MapId.MonsenItemShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.MonsenInn,
    to: MapId.Monsen,
    position: Position(0x120, 0x1c0),
    direction: Direction.down
  ),
  (
    from: MapId.MonsenHouse1,
    to: MapId.Monsen,
    position: Position(0x1e0, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.MonsenHouse2,
    to: MapId.Monsen,
    position: Position(0x300, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.MonsenHouse3,
    to: MapId.Monsen,
    position: Position(0x220, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.MonsenHouse4,
    to: MapId.Monsen,
    position: Position(0x2c0, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.MonsenHouse5,
    to: MapId.Monsen,
    position: Position(0x1a0, 0x280),
    direction: Direction.down
  ),
  (
    from: MapId.MonsenItemShop,
    to: MapId.Monsen,
    position: Position(0x220, 0x280),
    direction: Direction.down
  ),
  (
    from: MapId.Termi,
    to: MapId.Motavia,
    position: Position(0xe10, 0x760),
    direction: Direction.down
  ),
  (
    from: MapId.Termi,
    to: MapId.Motavia,
    position: Position(0xe10, 0x760),
    direction: Direction.down
  ),
  (
    from: MapId.Termi,
    to: MapId.Motavia,
    position: Position(0xe10, 0x760),
    direction: Direction.down
  ),
  (
    from: MapId.Termi,
    to: MapId.Motavia,
    position: Position(0xe10, 0x760),
    direction: Direction.down
  ),
  (
    from: MapId.Termi,
    to: MapId.TermiItemShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Termi,
    to: MapId.TermiHouse1,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Termi,
    to: MapId.TermiWeaponShop,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Termi,
    to: MapId.TermiInn,
    position: Position(0x230, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Termi,
    to: MapId.TermiHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.TermiItemShop,
    to: MapId.Termi,
    position: Position(0x120, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.TermiHouse1,
    to: MapId.Termi,
    position: Position(0x160, 0x280),
    direction: Direction.down
  ),
  (
    from: MapId.TermiWeaponShop,
    to: MapId.Termi,
    position: Position(0x280, 0x280),
    direction: Direction.down
  ),
  (
    from: MapId.TermiInn,
    to: MapId.Termi,
    position: Position(0x160, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.TermiHouse2,
    to: MapId.Termi,
    position: Position(0x240, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.Passageway,
    to: MapId.PassagewayNearAiedo,
    position: Position(0x1f0, 0x1e0),
    direction: Direction.down
  ),
  (
    from: MapId.Passageway,
    to: MapId.PassagewayNearKadary,
    position: Position(0x1f0, 0x1e0),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort,
    to: MapId.Motavia,
    position: Position(0x380, 0x5e0),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort,
    to: MapId.Motavia,
    position: Position(0x380, 0x5e0),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort,
    to: MapId.Motavia,
    position: Position(0x380, 0x5e0),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort,
    to: MapId.ZioFort_Part2,
    position: Position(0x1f0, 0x220),
    direction: Direction.up
  ),
  (
    from: MapId.ZioFort,
    to: MapId.ZioFort_F1,
    position: Position(0x1d0, 0x500),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort,
    to: MapId.ZioFort_F1,
    position: Position(0x410, 0x500),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort,
    to: MapId.ZioFort_F1,
    position: Position(0x1b0, 0x140),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort,
    to: MapId.ZioFort_F1,
    position: Position(0x450, 0x140),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort,
    to: MapId.Nurvus,
    position: Position(0x200, 0x220),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFort_Part2,
    to: MapId.ZioFort,
    position: Position(0x2f0, 0x180),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort_Part2,
    to: MapId.ZioFort_F1,
    position: Position(0x2d0, 0x160),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort_Part2,
    to: MapId.ZioFort_F1,
    position: Position(0x330, 0x140),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort,
    position: Position(0x130, 0x2f0),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort,
    position: Position(0x130, 0x310),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort,
    position: Position(0x130, 0x330),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort,
    position: Position(0x4c0, 0x2f0),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort,
    position: Position(0x4c0, 0x310),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort,
    position: Position(0x4c0, 0x330),
    direction: Direction.down
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort_F2West,
    position: Position(0x1d0, 0x220),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort_F2East,
    position: Position(0x230, 0x220),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort,
    position: Position(0x1c0, 0x4e0),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort,
    position: Position(0x420, 0x4e0),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort,
    position: Position(0x180, 0x1a0),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort,
    position: Position(0x460, 0x1a0),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort_Part2,
    position: Position(0x1a0, 0x200),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFort_F1,
    to: MapId.ZioFort_Part2,
    position: Position(0x260, 0x1e0),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFort_F2West,
    to: MapId.ZioFortWestTunnel,
    position: Position(0x110, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort_F2West,
    to: MapId.ZioFort_F1,
    position: Position(0x120, 0x2c0),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFortWestTunnel,
    to: MapId.ZioFort_F2West,
    position: Position(0x270, 0x200),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFortWestTunnel,
    to: MapId.ZioFortJuzaRoom,
    position: Position(0x100, 0x240),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFortJuzaRoom,
    to: MapId.ZioFortWestTunnel,
    position: Position(0x2e0, 0x1e0),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFortJuzaRoom,
    to: MapId.ZioFortEastTunnel,
    position: Position(0x110, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFortJuzaRoom,
    to: MapId.ZioFort_F3,
    position: Position(0x1b0, 0x100),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFortEastTunnel,
    to: MapId.ZioFortJuzaRoom,
    position: Position(0x2f0, 0x1e0),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFortEastTunnel,
    to: MapId.ZioFort_F2East,
    position: Position(0x180, 0x200),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort_F2East,
    to: MapId.ZioFortEastTunnel,
    position: Position(0x2e0, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort_F2East,
    to: MapId.ZioFort_F1,
    position: Position(0x4c0, 0x2c0),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFort_F3,
    to: MapId.ZioFort_F4,
    position: Position(0x210, 0x240),
    direction: Direction.right
  ),
  (
    from: MapId.ZioFort_F3,
    to: MapId.ZioFortJuzaRoom,
    position: Position(0x180, 0x120),
    direction: Direction.left
  ),
  (
    from: MapId.ZioFort_F4,
    to: MapId.ZioFort_F3,
    position: Position(0x200, 0x160),
    direction: Direction.left
  ),
  (
    from: MapId.LadeaTower,
    to: MapId.Motavia,
    position: Position(0xce0, 0x8d0),
    direction: Direction.down
  ),
  (
    from: MapId.LadeaTower,
    to: MapId.LadeaTower_F1,
    position: Position(0x310, 0x300),
    direction: Direction.right
  ),
  (
    from: MapId.LadeaTower_F1,
    to: MapId.LadeaTower_F2,
    position: Position(0x270, 0x3c0),
    direction: Direction.right
  ),
  (
    from: MapId.LadeaTower_F1,
    to: MapId.LadeaTower_F2,
    position: Position(0x390, 0x3c0),
    direction: Direction.right
  ),
  (
    from: MapId.LadeaTower_F1,
    to: MapId.LadeaTower,
    position: Position(0x2e0, 0x300),
    direction: Direction.left
  ),
  (
    from: MapId.LadeaTower_F2,
    to: MapId.LadeaTower_F3,
    position: Position(0x2f0, 0x280),
    direction: Direction.right
  ),
  (
    from: MapId.LadeaTower_F2,
    to: MapId.LadeaTower_F1,
    position: Position(0x260, 0x3e0),
    direction: Direction.left
  ),
  (
    from: MapId.LadeaTower_F2,
    to: MapId.LadeaTower_F1,
    position: Position(0x380, 0x3e0),
    direction: Direction.left
  ),
  (
    from: MapId.LadeaTower_F3,
    to: MapId.LadeaTower_F4,
    position: Position(0x310, 0x200),
    direction: Direction.right
  ),
  (
    from: MapId.LadeaTower_F3,
    to: MapId.LadeaTower_F4,
    position: Position(0xf0, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.LadeaTower_F3,
    to: MapId.LadeaTower_F2,
    position: Position(0x2e0, 0x260),
    direction: Direction.left
  ),
  (
    from: MapId.LadeaTower_F4,
    to: MapId.LadeaTower_F5,
    position: Position(0x1f0, 0x300),
    direction: Direction.right
  ),
  (
    from: MapId.LadeaTower_F4,
    to: MapId.LadeaTower_F3,
    position: Position(0x1e0, 0x320),
    direction: Direction.left
  ),
  (
    from: MapId.LadeaTower_F4,
    to: MapId.LadeaTower_F3,
    position: Position(0x400, 0x320),
    direction: Direction.left
  ),
  (
    from: MapId.LadeaTower_F5,
    to: MapId.LadeaTower_F4,
    position: Position(0x1e0, 0x2c0),
    direction: Direction.left
  ),
  (
    from: MapId.IslandCave,
    to: MapId.IslandCave_Part2,
    position: Position(0x1c0, 0x250),
    direction: Direction.up
  ),
  (
    from: MapId.IslandCave,
    to: MapId.Motavia,
    position: Position(0x770, 0x9b0),
    direction: Direction.down
  ),
  (
    from: MapId.IslandCave,
    to: MapId.IslandCave_F1,
    position: Position(0x130, 0x100),
    direction: Direction.right
  ),
  (
    from: MapId.IslandCave,
    to: MapId.IslandCave_F1_Part2,
    position: Position(0x170, 0x280),
    direction: Direction.right
  ),
  (
    from: MapId.IslandCave_F1,
    to: MapId.IslandCave,
    position: Position(0x2c0, 0xe0),
    direction: Direction.left
  ),
  (
    from: MapId.IslandCave_F1,
    to: MapId.IslandCave_F2,
    position: Position(0x2b0, 0x220),
    direction: Direction.right
  ),
  (
    from: MapId.IslandCave_F1,
    to: MapId.IslandCave_F3,
    position: Position(0x110, 0x2a0),
    direction: Direction.right
  ),
  (
    from: MapId.IslandCave_F1_Part2,
    to: MapId.IslandCave,
    position: Position(0x160, 0x1e0),
    direction: Direction.left
  ),
  (
    from: MapId.IslandCave_Part2,
    to: MapId.IslandCave,
    position: Position(0x4a0, 0xd0),
    direction: Direction.down
  ),
  (
    from: MapId.IslandCave_Part2,
    to: MapId.IslandCave_B1,
    position: Position(0x260, 0x180),
    direction: Direction.left
  ),
  (
    from: MapId.IslandCave_B1,
    to: MapId.IslandCave_Part2,
    position: Position(0x250, 0x160),
    direction: Direction.right
  ),
  (
    from: MapId.IslandCave_F2,
    to: MapId.IslandCave_F1,
    position: Position(0x400, 0x2a0),
    direction: Direction.left
  ),
  (
    from: MapId.IslandCave_F3,
    to: MapId.SoldiersTempleOutside,
    position: Position(0x250, 0x1d0),
    direction: Direction.down
  ),
  (
    from: MapId.IslandCave_F3,
    to: MapId.IslandCave_F1,
    position: Position(0x280, 0x420),
    direction: Direction.left
  ),
  (
    from: MapId.SoldiersTempleOutside,
    to: MapId.IslandCave_F3,
    position: Position(0x220, 0x110),
    direction: Direction.down
  ),
  (
    from: MapId.SoldiersTempleOutside,
    to: MapId.SoldiersTemple,
    position: Position(0x1f0, 0x200),
    direction: Direction.up
  ),
  (
    from: MapId.SoldiersTemple,
    to: MapId.SoldiersTempleOutside,
    position: Position(0x190, 0xd0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMaze,
    to: MapId.ValleyMazeOutside,
    position: Position(0x1f0, 0x1e0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMaze,
    to: MapId.ValleyMaze_Part2,
    position: Position(0x1c0, 0x250),
    direction: Direction.up
  ),
  (
    from: MapId.ValleyMaze,
    to: MapId.ValleyMaze_Part3,
    position: Position(0x2e0, 0x2f0),
    direction: Direction.up
  ),
  (
    from: MapId.ValleyMaze_Part2,
    to: MapId.ValleyMaze,
    position: Position(0x2a0, 0xf0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMaze_Part3,
    to: MapId.ValleyMaze,
    position: Position(0x100, 0xb0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMaze_Part3,
    to: MapId.ValleyMaze_Part4,
    position: Position(0x160, 0x210),
    direction: Direction.up
  ),
  (
    from: MapId.ValleyMaze_Part3,
    to: MapId.ValleyMaze_Part5,
    position: Position(0x1e0, 0x2f0),
    direction: Direction.up
  ),
  (
    from: MapId.ValleyMaze_Part4,
    to: MapId.ValleyMaze_Part3,
    position: Position(0x1e0, 0xf0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMaze_Part5,
    to: MapId.ValleyMaze_Part3,
    position: Position(0x100, 0xf0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMaze_Part5,
    to: MapId.ValleyMaze_Part6,
    position: Position(0x1e0, 0x2f0),
    direction: Direction.up
  ),
  (
    from: MapId.ValleyMaze_Part5,
    to: MapId.ValleyMaze_Part7,
    position: Position(0x210, 0x2f0),
    direction: Direction.up
  ),
  (
    from: MapId.ValleyMaze_Part6,
    to: MapId.ValleyMaze_Part5,
    position: Position(0x2c0, 0xf0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMaze_Part7,
    to: MapId.ValleyMaze_Part5,
    position: Position(0x120, 0xf0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMaze_Part7,
    to: MapId.ValleyMazeOutside2,
    position: Position(0x1f0, 0x1e0),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant,
    to: MapId.BirthValley_B1,
    position: Position(0x170, 0xf0),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant,
    to: MapId.BioPlant_Part2,
    position: Position(0x1c0, 0x1e0),
    direction: Direction.up
  ),
  (
    from: MapId.BioPlant_Part2,
    to: MapId.BioPlant,
    position: Position(0x200, 0x140),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_Part2,
    to: MapId.BioPlant_Part3,
    position: Position(0x1d0, 0x1c0),
    direction: Direction.up
  ),
  (
    from: MapId.BioPlant_Part3,
    to: MapId.BioPlant_Part2,
    position: Position(0x200, 0x110),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_Part3,
    to: MapId.BioPlant_B1,
    position: Position(0x200, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B1,
    to: MapId.BioPlant_Part3,
    position: Position(0x200, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B1,
    to: MapId.BioPlant_B2,
    position: Position(0x300, 0x400),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B1,
    to: MapId.BioPlant_B2,
    position: Position(0x440, 0x400),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B2,
    to: MapId.BioPlant_B1,
    position: Position(0x180, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B2,
    to: MapId.BioPlant_B1,
    position: Position(0x280, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B2,
    to: MapId.BioPlant_B3,
    position: Position(0x2e0, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B2,
    to: MapId.BioPlant_B2_Part2,
    position: Position(0x200, 0x1a0),
    direction: Direction.up
  ),
  (
    from: MapId.BioPlant_B2_Part2,
    to: MapId.BioPlant_B2,
    position: Position(0x1a0, 0x250),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B3,
    to: MapId.BioPlant_B3_Part2,
    position: Position(0x220, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B3,
    to: MapId.BioPlant_B2,
    position: Position(0x460, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B3_Part2,
    to: MapId.BioPlant_B4,
    position: Position(0x200, 0x1a0),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B3_Part2,
    to: MapId.BioPlant_B3,
    position: Position(0x200, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.BioPlant_B4,
    to: MapId.BioPlant_B3_Part2,
    position: Position(0x1c0, 0x1a0),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B4,
    to: MapId.BioPlant_B4_Part2,
    position: Position(0x190, 0x220),
    direction: Direction.up
  ),
  (
    from: MapId.BioPlant_B4,
    to: MapId.BioPlant_B4_Part2,
    position: Position(0x280, 0x220),
    direction: Direction.up
  ),
  (
    from: MapId.BioPlant_B4_Part2,
    to: MapId.BioPlant_B4,
    position: Position(0x180, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B4_Part2,
    to: MapId.BioPlant_B4,
    position: Position(0x280, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.BioPlant_B4_Part2,
    to: MapId.BioPlant_B4_Part3,
    position: Position(0x1e0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.BioPlant_B4_Part3,
    to: MapId.BioPlant_B4_Part2,
    position: Position(0x200, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage,
    to: MapId.Motavia,
    position: Position(0x4a0, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage,
    to: MapId.Wreckage_Part2,
    position: Position(0x1e0, 0x180),
    direction: Direction.up
  ),
  (
    from: MapId.Wreckage,
    to: MapId.Wreckage_Part3,
    position: Position(0x2e0, 0x2e0),
    direction: Direction.up
  ),
  (
    from: MapId.Wreckage_Part2,
    to: MapId.Wreckage,
    position: Position(0x260, 0x120),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage_Part3,
    to: MapId.Wreckage,
    position: Position(0x100, 0xe0),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage_Part3,
    to: MapId.Wreckage_F1,
    position: Position(0x300, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage_F1,
    to: MapId.Wreckage_Part3,
    position: Position(0x100, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage_F1,
    to: MapId.Wreckage_F2,
    position: Position(0x260, 0x180),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage_F1,
    to: MapId.Wreckage_F1_Part2,
    position: Position(0x1e0, 0x180),
    direction: Direction.up
  ),
  (
    from: MapId.Wreckage_F1_Part2,
    to: MapId.Wreckage_F1,
    position: Position(0x260, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage_F2,
    to: MapId.Wreckage_F1,
    position: Position(0xe0, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage_F2,
    to: MapId.Wreckage_F2_Part2,
    position: Position(0x2e0, 0x1c0),
    direction: Direction.up
  ),
  (
    from: MapId.Wreckage_F2_Part2,
    to: MapId.Wreckage_F2,
    position: Position(0x1e0, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage_F2_Part2,
    to: MapId.Wreckage_F2_Part3,
    position: Position(0x1e0, 0x1e0),
    direction: Direction.up
  ),
  (
    from: MapId.Wreckage_F2_Part3,
    to: MapId.Wreckage_F2_Part2,
    position: Position(0x120, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.Wreckage_F2_Part3,
    to: MapId.Wreckage_F2_Part4,
    position: Position(0x1e0, 0x2e0),
    direction: Direction.up
  ),
  (
    from: MapId.Wreckage_F2_Part4,
    to: MapId.Wreckage_F2_Part3,
    position: Position(0x1e0, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.MachineCenter,
    to: MapId.Motavia,
    position: Position(0x720, 0xb40),
    direction: Direction.down
  ),
  (
    from: MapId.MachineCenter,
    to: MapId.MachineCenter_B1,
    position: Position(0x1e0, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.MachineCenter_B1,
    to: MapId.MachineCenter,
    position: Position(0x1e0, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.MachineCenter_B1,
    to: MapId.MachineCenter_B1_Part2,
    position: Position(0x1e0, 0x1b0),
    direction: Direction.down
  ),
  (
    from: MapId.MachineCenter_B1_Part2,
    to: MapId.MachineCenter_B1,
    position: Position(0x1e0, 0x1a0),
    direction: Direction.up
  ),
  (
    from: MapId.PlateSystem,
    to: MapId.Motavia,
    position: Position(0xc40, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.PlateSystem,
    to: MapId.PlateSystem_F1,
    position: Position(0x1e0, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.PlateSystem_F1,
    to: MapId.PlateSystem,
    position: Position(0x120, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.PlateSystem_F1,
    to: MapId.PlateSystem_F2,
    position: Position(0x1e0, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.PlateSystem_F2,
    to: MapId.PlateSystem_F1,
    position: Position(0x1e0, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.PlateSystem_F2,
    to: MapId.PlateSystem_F3,
    position: Position(0x140, 0x300),
    direction: Direction.down
  ),
  (
    from: MapId.PlateSystem_F2,
    to: MapId.PlateSystem_F3,
    position: Position(0x280, 0x300),
    direction: Direction.down
  ),
  (
    from: MapId.PlateSystem_F3,
    to: MapId.PlateSystem_F2,
    position: Position(0x140, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.PlateSystem_F3,
    to: MapId.PlateSystem_F2,
    position: Position(0x280, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.PlateSystem_F3,
    to: MapId.PlateSystem_F4,
    position: Position(0x140, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.PlateSystem_F4,
    to: MapId.PlateSystem_F3,
    position: Position(0x140, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.MotaSpaceport,
    to: MapId.Motavia,
    position: Position(0x340, 0x5a0),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter,
    to: MapId.Dezolis,
    position: Position(0x7e0, 0xe0),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter,
    to: MapId.ClimCenter_F1,
    position: Position(0x2e0, 0x300),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter,
    to: MapId.ClimCenter_F1,
    position: Position(0x220, 0x420),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter,
    to: MapId.ClimCenter_F1,
    position: Position(0x3a0, 0x420),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter,
    to: MapId.ClimCenter_F1,
    position: Position(0x440, 0x420),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter_F1,
    to: MapId.ClimCenter_F2,
    position: Position(0x2e0, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter_F1,
    to: MapId.ClimCenter,
    position: Position(0x2e0, 0x300),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter_F1,
    to: MapId.ClimCenter,
    position: Position(0x220, 0x420),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter_F1,
    to: MapId.ClimCenter,
    position: Position(0x3a0, 0x420),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter_F1,
    to: MapId.ClimCenter,
    position: Position(0x440, 0x420),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter_F2,
    to: MapId.ClimCenter_F1,
    position: Position(0x2e0, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter_F2,
    to: MapId.ClimCenter_F3,
    position: Position(0x1e0, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.ClimCenter_F3,
    to: MapId.ClimCenter_F2,
    position: Position(0x2e0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant,
    to: MapId.Dezolis,
    position: Position(0x550, 0x600),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant,
    to: MapId.WeaponPlant_F1,
    position: Position(0x2a0, 0x400),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F1,
    to: MapId.WeaponPlant,
    position: Position(0x1e0, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F1,
    to: MapId.WeaponPlant_F2,
    position: Position(0x320, 0x400),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F1,
    to: MapId.WeaponPlant_F2,
    position: Position(0x140, 0x360),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F1,
    to: MapId.WeaponPlant_F2,
    position: Position(0x480, 0x360),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F1,
    to: MapId.WeaponPlant_F2,
    position: Position(0x2e0, 0xe0),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F2,
    to: MapId.WeaponPlant_F1,
    position: Position(0x320, 0x400),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F2,
    to: MapId.WeaponPlant_F1,
    position: Position(0x140, 0x360),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F2,
    to: MapId.WeaponPlant_F1,
    position: Position(0x480, 0x360),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F2,
    to: MapId.WeaponPlant_F1,
    position: Position(0x2e0, 0xe0),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F2,
    to: MapId.WeaponPlant_F3,
    position: Position(0x340, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F2,
    to: MapId.WeaponPlant_F3,
    position: Position(0x180, 0xe0),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F2,
    to: MapId.WeaponPlant_F3,
    position: Position(0x440, 0xe0),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F3,
    to: MapId.WeaponPlant_F2,
    position: Position(0x340, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F3,
    to: MapId.WeaponPlant_F2,
    position: Position(0x180, 0xe0),
    direction: Direction.down
  ),
  (
    from: MapId.WeaponPlant_F3,
    to: MapId.WeaponPlant_F2,
    position: Position(0x440, 0xe0),
    direction: Direction.down
  ),
  (
    from: MapId.VahalFort,
    to: MapId.Motavia,
    position: Position(0xa20, 0x280),
    direction: Direction.down
  ),
  (
    from: MapId.VahalFort,
    to: MapId.VahalFort_F1,
    position: Position(0x2e0, 0x320),
    direction: Direction.down
  ),
  (
    from: MapId.VahalFort_F1,
    to: MapId.VahalFort,
    position: Position(0x2e0, 0x320),
    direction: Direction.down
  ),
  (
    from: MapId.VahalFort_F1,
    to: MapId.VahalFort_F2,
    position: Position(0x360, 0x380),
    direction: Direction.down
  ),
  (
    from: MapId.VahalFort_F2,
    to: MapId.VahalFort_F1,
    position: Position(0x360, 0x480),
    direction: Direction.down
  ),
  (
    from: MapId.VahalFort_F2,
    to: MapId.VahalFort_F3,
    position: Position(0x100, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.VahalFort_F2,
    to: MapId.VahalFort_F3,
    position: Position(0x4c0, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.VahalFort_F3,
    to: MapId.VahalFort_F2,
    position: Position(0x100, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.VahalFort_F3,
    to: MapId.VahalFort_F2,
    position: Position(0x4c0, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_Part2,
    to: MapId.Nurvus,
    position: Position(0x1f0, 0x1a0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_Part2,
    to: MapId.Nurvus_Part3,
    position: Position(0x110, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.Nurvus_Part2,
    to: MapId.Nurvus_Part3,
    position: Position(0x2c0, 0x300),
    direction: Direction.up
  ),
  (
    from: MapId.Nurvus_Part3,
    to: MapId.Nurvus_Part2,
    position: Position(0x100, 0x120),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_Part3,
    to: MapId.Nurvus_Part2,
    position: Position(0x2c0, 0x120),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_Part3,
    to: MapId.Nurvus_B1,
    position: Position(0x2e0, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B1,
    to: MapId.Nurvus_Part3,
    position: Position(0x1e0, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B1,
    to: MapId.Nurvus_B3,
    position: Position(0x160, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B1,
    to: MapId.Nurvus_B3,
    position: Position(0x460, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B1,
    to: MapId.Nurvus_B3,
    position: Position(0xe0, 0x420),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B1,
    to: MapId.Nurvus_B1Tunnel,
    position: Position(0xe0, 0x1f0),
    direction: Direction.right
  ),
  (
    from: MapId.Nurvus_B1,
    to: MapId.Nurvus_B1Tunnel,
    position: Position(0x2f0, 0x1f0),
    direction: Direction.left
  ),
  (
    from: MapId.Nurvus_B2,
    to: MapId.Nurvus_B3,
    position: Position(0xe0, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B2,
    to: MapId.Nurvus_B3,
    position: Position(0xe0, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B3,
    to: MapId.Nurvus_B1,
    position: Position(0x160, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B3,
    to: MapId.Nurvus_B1,
    position: Position(0x460, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B3,
    to: MapId.Nurvus_B1,
    position: Position(0xe0, 0x420),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B3,
    to: MapId.Nurvus_B2,
    position: Position(0x1e0, 0x1c0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B3,
    to: MapId.Nurvus_B5,
    position: Position(0x1e0, 0x1c0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B3,
    to: MapId.Nurvus_B4,
    position: Position(0x2e0, 0x1a0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B3,
    to: MapId.Nurvus_B2,
    position: Position(0x1e0, 0x220),
    direction: Direction.up
  ),
  (
    from: MapId.Nurvus_B3,
    to: MapId.Nurvus_B5,
    position: Position(0x1e0, 0x220),
    direction: Direction.up
  ),
  (
    from: MapId.Nurvus_B3,
    to: MapId.Nurvus_B3Tunnel,
    position: Position(0xe0, 0x1f0),
    direction: Direction.right
  ),
  (
    from: MapId.Nurvus_B3,
    to: MapId.Nurvus_B3Tunnel,
    position: Position(0x2f0, 0x1f0),
    direction: Direction.left
  ),
  (
    from: MapId.Nurvus_B1Tunnel,
    to: MapId.Nurvus_B1,
    position: Position(0x1c0, 0x480),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B1Tunnel,
    to: MapId.Nurvus_B1,
    position: Position(0x400, 0x480),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B4,
    to: MapId.Nurvus_B3,
    position: Position(0x4c0, 0x4e0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B4,
    to: MapId.Nurvus_B4_Part2,
    position: Position(0x1e0, 0x2e0),
    direction: Direction.up
  ),
  (
    from: MapId.Nurvus_B4_Part2,
    to: MapId.Nurvus_B4,
    position: Position(0x100, 0x1a0),
    direction: Direction.down
  ),
  (
    from: MapId.DezoSpaceport,
    to: MapId.Dezolis,
    position: Position(0xc0, 0x480),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B5,
    to: MapId.Nurvus_B3,
    position: Position(0x4e0, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B5,
    to: MapId.Nurvus_B3,
    position: Position(0x4e0, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B3Tunnel,
    to: MapId.Nurvus_B3,
    position: Position(0x1c0, 0x4a0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus_B3Tunnel,
    to: MapId.Nurvus_B3,
    position: Position(0x400, 0x4a0),
    direction: Direction.down
  ),
  (
    from: MapId.Nurvus,
    to: MapId.Nurvus_Part2,
    position: Position(0x1e0, 0x2e0),
    direction: Direction.up
  ),
  (
    from: MapId.Nurvus,
    to: MapId.ZioFort,
    position: Position(0x300, 0x300),
    direction: Direction.right
  ),
  (
    from: MapId.ValleyMazeOutside,
    to: MapId.Motavia,
    position: Position(0x800, 0x790),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMazeOutside,
    to: MapId.Motavia,
    position: Position(0x800, 0x790),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMazeOutside,
    to: MapId.Motavia,
    position: Position(0x800, 0x790),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMazeOutside,
    to: MapId.ValleyMaze,
    position: Position(0x200, 0x330),
    direction: Direction.up
  ),
  (
    from: MapId.ValleyMazeOutside2,
    to: MapId.Motavia,
    position: Position(0x940, 0x5d0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMazeOutside2,
    to: MapId.Motavia,
    position: Position(0x940, 0x5d0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMazeOutside2,
    to: MapId.Motavia,
    position: Position(0x940, 0x5d0),
    direction: Direction.down
  ),
  (
    from: MapId.ValleyMazeOutside2,
    to: MapId.ValleyMaze_Part7,
    position: Position(0x200, 0xf0),
    direction: Direction.down
  ),
  (
    from: MapId.PassagewayNearAiedo,
    to: MapId.Motavia,
    position: Position(0x240, 0x350),
    direction: Direction.down
  ),
  (
    from: MapId.PassagewayNearAiedo,
    to: MapId.Motavia,
    position: Position(0x240, 0x350),
    direction: Direction.down
  ),
  (
    from: MapId.PassagewayNearAiedo,
    to: MapId.Motavia,
    position: Position(0x240, 0x350),
    direction: Direction.down
  ),
  (
    from: MapId.PassagewayNearAiedo,
    to: MapId.Passageway,
    position: Position(0x520, 0x190),
    direction: Direction.up
  ),
  (
    from: MapId.PassagewayNearKadary,
    to: MapId.Motavia,
    position: Position(0x200, 0x490),
    direction: Direction.down
  ),
  (
    from: MapId.PassagewayNearKadary,
    to: MapId.Motavia,
    position: Position(0x200, 0x490),
    direction: Direction.down
  ),
  (
    from: MapId.PassagewayNearKadary,
    to: MapId.Motavia,
    position: Position(0x200, 0x490),
    direction: Direction.down
  ),
  (
    from: MapId.PassagewayNearKadary,
    to: MapId.Passageway,
    position: Position(0x160, 0x4f0),
    direction: Direction.up
  ),
  (
    from: MapId.Uzo,
    to: MapId.Motavia,
    position: Position(0xe0, 0xb60),
    direction: Direction.down
  ),
  (
    from: MapId.Uzo,
    to: MapId.Motavia,
    position: Position(0xe0, 0xb60),
    direction: Direction.down
  ),
  (
    from: MapId.Uzo,
    to: MapId.Motavia,
    position: Position(0xd0, 0xb60),
    direction: Direction.down
  ),
  (
    from: MapId.Uzo,
    to: MapId.Motavia,
    position: Position(0xe0, 0xb60),
    direction: Direction.down
  ),
  (
    from: MapId.Uzo,
    to: MapId.UzoHouse1,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Uzo,
    to: MapId.UzoHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Uzo,
    to: MapId.UzoInn,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Uzo,
    to: MapId.UzoHouse3,
    position: Position(0x1b0, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Uzo,
    to: MapId.UzoItemShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.UzoHouse1,
    to: MapId.Uzo,
    position: Position(0x180, 0x120),
    direction: Direction.down
  ),
  (
    from: MapId.UzoHouse2,
    to: MapId.Uzo,
    position: Position(0x1e0, 0x120),
    direction: Direction.down
  ),
  (
    from: MapId.UzoInn,
    to: MapId.Uzo,
    position: Position(0x2a0, 0x180),
    direction: Direction.down
  ),
  (
    from: MapId.UzoHouse3,
    to: MapId.Uzo,
    position: Position(0x140, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.UzoItemShop,
    to: MapId.Uzo,
    position: Position(0x240, 0x280),
    direction: Direction.down
  ),
  (
    from: MapId.Torinco,
    to: MapId.Motavia,
    position: Position(0xc00, 0xb20),
    direction: Direction.down
  ),
  (
    from: MapId.Torinco,
    to: MapId.Motavia,
    position: Position(0xc00, 0xb20),
    direction: Direction.down
  ),
  (
    from: MapId.Torinco,
    to: MapId.Motavia,
    position: Position(0xc00, 0xb20),
    direction: Direction.down
  ),
  (
    from: MapId.Torinco,
    to: MapId.Motavia,
    position: Position(0xc00, 0xb20),
    direction: Direction.down
  ),
  (
    from: MapId.Torinco,
    to: MapId.CulversHouse,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Torinco,
    to: MapId.TorincoHouse1,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Torinco,
    to: MapId.TorincoHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Torinco,
    to: MapId.TorincoItemShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Torinco,
    to: MapId.TorincoInn,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.CulversHouse,
    to: MapId.Torinco,
    position: Position(0x180, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.TorincoHouse1,
    to: MapId.Torinco,
    position: Position(0x120, 0x140),
    direction: Direction.down
  ),
  (
    from: MapId.TorincoHouse2,
    to: MapId.Torinco,
    position: Position(0x2a0, 0x1c0),
    direction: Direction.down
  ),
  (
    from: MapId.TorincoItemShop,
    to: MapId.Torinco,
    position: Position(0x260, 0x2a0),
    direction: Direction.down
  ),
  (
    from: MapId.TorincoInn,
    to: MapId.Torinco,
    position: Position(0x140, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.MonsenCave,
    to: MapId.Motavia,
    position: Position(0xb10, 0x690),
    direction: Direction.down
  ),
  (
    from: MapId.RappyCave,
    to: MapId.Motavia,
    position: Position(0xda0, 0xa90),
    direction: Direction.down
  ),
  (
    from: MapId.LeRoofRoom,
    to: MapId.SilenceTm,
    position: Position(0x2f0, 0x440),
    direction: Direction.down
  ),
  (
    from: MapId.SilenceTm,
    to: MapId.Rykros,
    position: Position(0x400, 0x410),
    direction: Direction.down
  ),
  (
    from: MapId.SilenceTm,
    to: MapId.LeRoofRoom,
    position: Position(0x1f0, 0x2e0),
    direction: Direction.up
  ),
  (
    from: MapId.StrengthTower,
    to: MapId.Rykros,
    position: Position(0x200, 0x210),
    direction: Direction.down
  ),
  (
    from: MapId.StrengthTower,
    to: MapId.StrengthTower_F1,
    position: Position(0x1f0, 0x180),
    direction: Direction.right
  ),
  (
    from: MapId.StrengthTower_F1,
    to: MapId.StrengthTower,
    position: Position(0x1e0, 0x180),
    direction: Direction.left
  ),
  (
    from: MapId.StrengthTower_F1,
    to: MapId.StrengthTower_F2,
    position: Position(0x130, 0x160),
    direction: Direction.right
  ),
  (
    from: MapId.StrengthTower_F1,
    to: MapId.StrengthTower_F2,
    position: Position(0x2d0, 0x160),
    direction: Direction.right
  ),
  (
    from: MapId.StrengthTower_F2,
    to: MapId.StrengthTower_F1,
    position: Position(0x120, 0x160),
    direction: Direction.left
  ),
  (
    from: MapId.StrengthTower_F2,
    to: MapId.StrengthTower_F1,
    position: Position(0x2c0, 0x160),
    direction: Direction.left
  ),
  (
    from: MapId.StrengthTower_F2,
    to: MapId.StrengthTower_F3,
    position: Position(0x1b0, 0x1c0),
    direction: Direction.right
  ),
  (
    from: MapId.StrengthTower_F2,
    to: MapId.StrengthTower_F3,
    position: Position(0x190, 0x280),
    direction: Direction.right
  ),
  (
    from: MapId.StrengthTower_F3,
    to: MapId.StrengthTower_F2,
    position: Position(0x1a0, 0x1c0),
    direction: Direction.left
  ),
  (
    from: MapId.StrengthTower_F3,
    to: MapId.StrengthTower_F2,
    position: Position(0x180, 0x280),
    direction: Direction.left
  ),
  (
    from: MapId.StrengthTower_F3,
    to: MapId.StrengthTower_F4,
    position: Position(0x230, 0x260),
    direction: Direction.left
  ),
  (
    from: MapId.StrengthTower_F4,
    to: MapId.StrengthTower_F3,
    position: Position(0x200, 0x220),
    direction: Direction.left
  ),
  (
    from: MapId.CourageTower,
    to: MapId.Rykros,
    position: Position(0x600, 0x610),
    direction: Direction.down
  ),
  (
    from: MapId.CourageTower,
    to: MapId.CourageTower_F1,
    position: Position(0x110, 0x200),
    direction: Direction.right
  ),
  (
    from: MapId.CourageTower,
    to: MapId.CourageTower_F1,
    position: Position(0x2f0, 0x200),
    direction: Direction.right
  ),
  (
    from: MapId.CourageTower_F1,
    to: MapId.CourageTower,
    position: Position(0x100, 0x180),
    direction: Direction.left
  ),
  (
    from: MapId.CourageTower_F1,
    to: MapId.CourageTower,
    position: Position(0x2e0, 0x180),
    direction: Direction.left
  ),
  (
    from: MapId.CourageTower_F1,
    to: MapId.CourageTower_F2,
    position: Position(0x1f0, 0x240),
    direction: Direction.right
  ),
  (
    from: MapId.CourageTower_F1,
    to: MapId.CourageTower_F2,
    position: Position(0x110, 0x280),
    direction: Direction.right
  ),
  (
    from: MapId.CourageTower_F2,
    to: MapId.CourageTower_F1,
    position: Position(0x1e0, 0x240),
    direction: Direction.left
  ),
  (
    from: MapId.CourageTower_F2,
    to: MapId.CourageTower_F1,
    position: Position(0x100, 0x280),
    direction: Direction.left
  ),
  (
    from: MapId.CourageTower_F2,
    to: MapId.CourageTower_F3,
    position: Position(0x170, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.CourageTower_F2,
    to: MapId.CourageTower_F3,
    position: Position(0x2f0, 0x180),
    direction: Direction.right
  ),
  (
    from: MapId.CourageTower_F3,
    to: MapId.CourageTower_F2,
    position: Position(0x160, 0x1e0),
    direction: Direction.left
  ),
  (
    from: MapId.CourageTower_F3,
    to: MapId.CourageTower_F2,
    position: Position(0x2e0, 0x180),
    direction: Direction.left
  ),
  (
    from: MapId.CourageTower_F3,
    to: MapId.CourageTower_F4,
    position: Position(0x1f0, 0x260),
    direction: Direction.right
  ),
  (
    from: MapId.CourageTower_F4,
    to: MapId.CourageTower_F3,
    position: Position(0x1e0, 0x260),
    direction: Direction.left
  ),
  (
    from: MapId.AngerTower,
    to: MapId.Rykros,
    position: Position(0x220, 0x610),
    direction: Direction.down
  ),
  (
    from: MapId.AngerTower,
    to: MapId.AngerTower_F1,
    position: Position(0x190, 0x2c0),
    direction: Direction.right
  ),
  (
    from: MapId.AngerTower,
    to: MapId.AngerTower_F1,
    position: Position(0x270, 0x2c0),
    direction: Direction.right
  ),
  (
    from: MapId.AngerTower_F1,
    to: MapId.AngerTower,
    position: Position(0x180, 0x2c0),
    direction: Direction.left
  ),
  (
    from: MapId.AngerTower_F1,
    to: MapId.AngerTower,
    position: Position(0x260, 0x2c0),
    direction: Direction.left
  ),
  (
    from: MapId.AngerTower_F1,
    to: MapId.AngerTower_F2,
    position: Position(0x1b0, 0x260),
    direction: Direction.right
  ),
  (
    from: MapId.AngerTower_F2,
    to: MapId.AngerTower_F1,
    position: Position(0x1c0, 0x260),
    direction: Direction.left
  ),
  (
    from: MapId.TheEdge,
    to: MapId.Motavia,
    position: Position(0x390, 0x6f0),
    direction: Direction.down
  ),
  (
    from: MapId.TheEdge,
    to: MapId.TheEdge_Part2,
    position: Position(0xd0, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.TheEdge_Part2,
    to: MapId.TheEdge,
    position: Position(0x1e0, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.TheEdge_Part2,
    to: MapId.TheEdge_Part3,
    position: Position(0x220, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.TheEdge_Part2,
    to: MapId.TheEdge_Part3,
    position: Position(0x1b0, 0x140),
    direction: Direction.down
  ),
  (
    from: MapId.TheEdge_Part3,
    to: MapId.TheEdge_Part2,
    position: Position(0x320, 0x170),
    direction: Direction.left
  ),
  (
    from: MapId.TheEdge_Part3,
    to: MapId.TheEdge_Part2,
    position: Position(0x2a0, 0x250),
    direction: Direction.left
  ),
  (
    from: MapId.TheEdge_Part3,
    to: MapId.TheEdge_Part4,
    position: Position(0x320, 0x200),
    direction: Direction.left
  ),
  (
    from: MapId.TheEdge_Part4,
    to: MapId.TheEdge_Part3,
    position: Position(0x1c0, 0x310),
    direction: Direction.up
  ),
  (
    from: MapId.TheEdge_Part4,
    to: MapId.TheEdge_Part5,
    position: Position(0x1e0, 0x310),
    direction: Direction.up
  ),
  (
    from: MapId.TheEdge_Part5,
    to: MapId.TheEdge_Part4,
    position: Position(0xd0, 0x240),
    direction: Direction.right
  ),
  (
    from: MapId.TheEdge_Part5,
    to: MapId.TheEdge_Part7,
    position: Position(0x300, 0x1c0),
    direction: Direction.left
  ),
  (
    from: MapId.TheEdge_Part5,
    to: MapId.TheEdge_Part6,
    position: Position(0xd0, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.TheEdge_Part6,
    to: MapId.TheEdge_Part5,
    position: Position(0x320, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.TheEdge_Part7,
    to: MapId.TheEdge_Part5,
    position: Position(0xe0, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.TheEdge_Part7,
    to: MapId.TheEdge_Part8,
    position: Position(0x1e0, 0x2d0),
    direction: Direction.up
  ),
  (
    from: MapId.TheEdge_Part8,
    to: MapId.TheEdge_Part7,
    position: Position(0xe0, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.TheEdge_Part8,
    to: MapId.TheEdge_Part9,
    position: Position(0x1e0, 0x2d0),
    direction: Direction.up
  ),
  (
    from: MapId.TheEdge_Part9,
    to: MapId.TheEdge_Part8,
    position: Position(0x1e0, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.Tyler,
    to: MapId.Dezolis,
    position: Position(0xe0, 0x440),
    direction: Direction.down
  ),
  (
    from: MapId.Tyler,
    to: MapId.Dezolis,
    position: Position(0xe0, 0x440),
    direction: Direction.down
  ),
  (
    from: MapId.Tyler,
    to: MapId.TylerHouse1,
    position: Position(0x270, 0x1c0),
    direction: Direction.up
  ),
  (
    from: MapId.Tyler,
    to: MapId.TylerWeaponShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Tyler,
    to: MapId.TylerItemShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Tyler,
    to: MapId.TylerHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Tyler,
    to: MapId.TylerInn,
    position: Position(0x1d0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Tyler,
    to: MapId.Hangar,
    position: Position(0x420, 0x140),
    direction: Direction.left
  ),
  (
    from: MapId.TylerHouse1,
    to: MapId.Tyler,
    position: Position(0x2a0, 0x110),
    direction: Direction.down
  ),
  (
    from: MapId.TylerWeaponShop,
    to: MapId.Tyler,
    position: Position(0x320, 0x170),
    direction: Direction.down
  ),
  (
    from: MapId.TylerItemShop,
    to: MapId.Tyler,
    position: Position(0x2c0, 0x210),
    direction: Direction.down
  ),
  (
    from: MapId.TylerHouse2,
    to: MapId.Tyler,
    position: Position(0x260, 0x270),
    direction: Direction.down
  ),
  (
    from: MapId.TylerInn,
    to: MapId.Tyler,
    position: Position(0x300, 0x2b0),
    direction: Direction.down
  ),
  (
    from: MapId.Zosa,
    to: MapId.Dezolis,
    position: Position(0x400, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.Zosa,
    to: MapId.Dezolis,
    position: Position(0x400, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.Zosa,
    to: MapId.Dezolis,
    position: Position(0x400, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.Zosa,
    to: MapId.Dezolis,
    position: Position(0x400, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.Zosa,
    to: MapId.ZosaHouse1,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Zosa,
    to: MapId.ZosaHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Zosa,
    to: MapId.ZosaWeaponShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Zosa,
    to: MapId.ZosaItemShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Zosa,
    to: MapId.ZosaInn,
    position: Position(0x1d0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Zosa,
    to: MapId.ZosaHouse3,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.ZosaHouse1,
    to: MapId.Zosa,
    position: Position(0x100, 0xf0),
    direction: Direction.down
  ),
  (
    from: MapId.ZosaHouse2,
    to: MapId.Zosa,
    position: Position(0x300, 0x290),
    direction: Direction.down
  ),
  (
    from: MapId.ZosaWeaponShop,
    to: MapId.Zosa,
    position: Position(0x180, 0x290),
    direction: Direction.down
  ),
  (
    from: MapId.ZosaItemShop,
    to: MapId.Zosa,
    position: Position(0x1a0, 0x1d0),
    direction: Direction.down
  ),
  (
    from: MapId.ZosaInn,
    to: MapId.Zosa,
    position: Position(0x280, 0x2b0),
    direction: Direction.down
  ),
  (
    from: MapId.ZosaHouse3,
    to: MapId.Zosa,
    position: Position(0x300, 0x310),
    direction: Direction.down
  ),
  (
    from: MapId.Meese,
    to: MapId.Dezolis,
    position: Position(0x920, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.Meese,
    to: MapId.Dezolis,
    position: Position(0x920, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.Meese,
    to: MapId.Dezolis,
    position: Position(0x920, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.Meese,
    to: MapId.Dezolis,
    position: Position(0x920, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.Meese,
    to: MapId.MeeseHouse1,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Meese,
    to: MapId.MeeseItemShop1,
    position: Position(0x230, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Meese,
    to: MapId.MeeseItemShop2,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Meese,
    to: MapId.MeeseWeaponShop,
    position: Position(0x170, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Meese,
    to: MapId.MeeseInn,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Meese,
    to: MapId.MeeseClinic,
    position: Position(0x230, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.MeeseHouse1,
    to: MapId.Meese,
    position: Position(0x240, 0x170),
    direction: Direction.down
  ),
  (
    from: MapId.MeeseItemShop2,
    to: MapId.Meese,
    position: Position(0x2c0, 0x1b0),
    direction: Direction.down
  ),
  (
    from: MapId.MeeseItemShop1,
    to: MapId.Meese,
    position: Position(0x1c0, 0x170),
    direction: Direction.down
  ),
  (
    from: MapId.MeeseWeaponShop,
    to: MapId.Meese,
    position: Position(0x160, 0x1f0),
    direction: Direction.down
  ),
  (
    from: MapId.MeeseInn,
    to: MapId.Meese,
    position: Position(0x1c0, 0x290),
    direction: Direction.down
  ),
  (
    from: MapId.MeeseClinic,
    to: MapId.Meese,
    position: Position(0x2c0, 0x290),
    direction: Direction.down
  ),
  (
    from: MapId.MeeseClinic,
    to: MapId.MeeseClinic_F1,
    position: Position(0x190, 0x240),
    direction: Direction.right
  ),
  (
    from: MapId.MeeseClinic_F1,
    to: MapId.MeeseClinic,
    position: Position(0x120, 0x200),
    direction: Direction.left
  ),
  (
    from: MapId.Jut,
    to: MapId.Dezolis,
    position: Position(0x790, 0x4c0),
    direction: Direction.down
  ),
  (
    from: MapId.Jut,
    to: MapId.Dezolis,
    position: Position(0x790, 0x4c0),
    direction: Direction.down
  ),
  (
    from: MapId.Jut,
    to: MapId.Dezolis,
    position: Position(0x790, 0x4c0),
    direction: Direction.down
  ),
  (
    from: MapId.Jut,
    to: MapId.Dezolis,
    position: Position(0x790, 0x4c0),
    direction: Direction.down
  ),
  (
    from: MapId.Jut,
    to: MapId.JutHouse1,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutHouse3,
    position: Position(0x210, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutHouse4,
    position: Position(0x1a0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutHouse5,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutWeaponShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutItemShop,
    position: Position(0x230, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutHouse6,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutHouse7,
    position: Position(0x250, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutHouse8,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutInn,
    position: Position(0x1f0, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Jut,
    to: MapId.JutChurch,
    position: Position(0x1f0, 0x2c0),
    direction: Direction.up
  ),
  (
    from: MapId.JutHouse1,
    to: MapId.Jut,
    position: Position(0x280, 0x150),
    direction: Direction.down
  ),
  (
    from: MapId.JutHouse2,
    to: MapId.Jut,
    position: Position(0x260, 0x1b0),
    direction: Direction.down
  ),
  (
    from: MapId.JutHouse3,
    to: MapId.Jut,
    position: Position(0x3a0, 0x1b0),
    direction: Direction.down
  ),
  (
    from: MapId.JutHouse4,
    to: MapId.Jut,
    position: Position(0x180, 0x250),
    direction: Direction.down
  ),
  (
    from: MapId.JutHouse5,
    to: MapId.Jut,
    position: Position(0x220, 0x270),
    direction: Direction.down
  ),
  (
    from: MapId.JutWeaponShop,
    to: MapId.Jut,
    position: Position(0x460, 0x230),
    direction: Direction.down
  ),
  (
    from: MapId.JutItemShop,
    to: MapId.Jut,
    position: Position(0x1c0, 0x390),
    direction: Direction.down
  ),
  (
    from: MapId.JutHouse6,
    to: MapId.Jut,
    position: Position(0x400, 0x370),
    direction: Direction.down
  ),
  (
    from: MapId.JutHouse6,
    to: MapId.JutHouse6_F1,
    position: Position(0x230, 0x1a0),
    direction: Direction.right
  ),
  (
    from: MapId.JutHouse6_F1,
    to: MapId.JutHouse6,
    position: Position(0x220, 0x1a0),
    direction: Direction.left
  ),
  (
    from: MapId.JutHouse7,
    to: MapId.Jut,
    position: Position(0x2a0, 0x410),
    direction: Direction.down
  ),
  (
    from: MapId.JutHouse8,
    to: MapId.Jut,
    position: Position(0x260, 0x470),
    direction: Direction.down
  ),
  (
    from: MapId.JutInn,
    to: MapId.Jut,
    position: Position(0x380, 0x450),
    direction: Direction.down
  ),
  (
    from: MapId.JutChurch,
    to: MapId.Jut,
    position: Position(0x300, 0x310),
    direction: Direction.down
  ),
  (
    from: MapId.Ryuon,
    to: MapId.Dezolis,
    position: Position(0x240, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.Ryuon,
    to: MapId.Dezolis,
    position: Position(0x240, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.Ryuon,
    to: MapId.Dezolis,
    position: Position(0x240, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.Ryuon,
    to: MapId.Dezolis,
    position: Position(0x240, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.Ryuon,
    to: MapId.RyuonItemShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Ryuon,
    to: MapId.RyuonWeaponShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Ryuon,
    to: MapId.RyuonHouse1,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Ryuon,
    to: MapId.RyuonHouse2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Ryuon,
    to: MapId.RyuonHouse3,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Ryuon,
    to: MapId.RyuonPub,
    position: Position(0x220, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Ryuon,
    to: MapId.RyuonInn,
    position: Position(0x190, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.RyuonItemShop,
    to: MapId.Ryuon,
    position: Position(0x120, 0x170),
    direction: Direction.down
  ),
  (
    from: MapId.RyuonWeaponShop,
    to: MapId.Ryuon,
    position: Position(0x180, 0x170),
    direction: Direction.down
  ),
  (
    from: MapId.RyuonHouse1,
    to: MapId.Ryuon,
    position: Position(0x200, 0x170),
    direction: Direction.down
  ),
  (
    from: MapId.RyuonHouse2,
    to: MapId.Ryuon,
    position: Position(0x1a0, 0x210),
    direction: Direction.down
  ),
  (
    from: MapId.RyuonHouse3,
    to: MapId.Ryuon,
    position: Position(0x1a0, 0x2d0),
    direction: Direction.down
  ),
  (
    from: MapId.RyuonPub,
    to: MapId.Ryuon,
    position: Position(0x280, 0x230),
    direction: Direction.down
  ),
  (
    from: MapId.RyuonInn,
    to: MapId.Ryuon,
    position: Position(0x240, 0x2d0),
    direction: Direction.down
  ),
  (
    from: MapId.RajaTemple,
    to: MapId.Dezolis,
    position: Position(0x240, 0x5e0),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel1,
    to: MapId.Dezolis,
    position: Position(0x7e0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel2,
    to: MapId.Dezolis,
    position: Position(0x7e0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel2,
    to: MapId.Dezolis,
    position: Position(0x7e0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel2,
    to: MapId.Reshel2House,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Reshel2,
    to: MapId.Reshel2WeaponShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Reshel3,
    to: MapId.Dezolis,
    position: Position(0x7e0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel3,
    to: MapId.Dezolis,
    position: Position(0x7e0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel3,
    to: MapId.Dezolis,
    position: Position(0x7e0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel3,
    to: MapId.Dezolis,
    position: Position(0x7e0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel3,
    to: MapId.Reshel3House1,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Reshel3,
    to: MapId.Reshel3ItemShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Reshel3,
    to: MapId.Reshel3House2,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Reshel3,
    to: MapId.Reshel3WeaponShop,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Reshel3,
    to: MapId.Reshel3Inn,
    position: Position(0x210, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.Reshel3,
    to: MapId.Reshel3House3,
    position: Position(0x210, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Reshel2House,
    to: MapId.Reshel2,
    position: Position(0x180, 0x150),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel2WeaponShop,
    to: MapId.Reshel2,
    position: Position(0x1a0, 0x230),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel3House1,
    to: MapId.Reshel3,
    position: Position(0x180, 0x150),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel3ItemShop,
    to: MapId.Reshel3,
    position: Position(0x280, 0x170),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel3House2,
    to: MapId.Reshel3,
    position: Position(0x260, 0x1d0),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel3WeaponShop,
    to: MapId.Reshel3,
    position: Position(0x1a0, 0x230),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel3Inn,
    to: MapId.Reshel3,
    position: Position(0x240, 0x270),
    direction: Direction.down
  ),
  (
    from: MapId.Reshel3House3,
    to: MapId.Reshel3,
    position: Position(0x2c0, 0x2b0),
    direction: Direction.down
  ),
  (
    from: MapId.MystVale,
    to: MapId.Dezolis,
    position: Position(0x230, 0x30),
    direction: Direction.down
  ),
  (
    from: MapId.MystVale,
    to: MapId.MystVale_Part2,
    position: Position(0x150, 0x2f0),
    direction: Direction.up
  ),
  (
    from: MapId.MystVale_Part2,
    to: MapId.MystVale,
    position: Position(0x220, 0x110),
    direction: Direction.down
  ),
  (
    from: MapId.MystVale_Part2,
    to: MapId.MystVale_Part3,
    position: Position(0x230, 0x2d0),
    direction: Direction.up
  ),
  (
    from: MapId.MystVale_Part2,
    to: MapId.MystVale_Part3,
    position: Position(0x180, 0x2d0),
    direction: Direction.up
  ),
  (
    from: MapId.MystVale_Part2,
    to: MapId.MystVale_Part4,
    position: Position(0x2a0, 0x1d0),
    direction: Direction.down
  ),
  (
    from: MapId.MystVale_Part3,
    to: MapId.MystVale_Part2,
    position: Position(0x2a0, 0x170),
    direction: Direction.down
  ),
  (
    from: MapId.MystVale_Part3,
    to: MapId.MystVale_Part2,
    position: Position(0x240, 0x150),
    direction: Direction.down
  ),
  (
    from: MapId.MystVale_Part4,
    to: MapId.MystVale_Part2,
    position: Position(0x120, 0x150),
    direction: Direction.down
  ),
  (
    from: MapId.MystVale_Part4,
    to: MapId.MystVale_Part5,
    position: Position(0x1e0, 0x310),
    direction: Direction.up
  ),
  (
    from: MapId.MystVale_Part5,
    to: MapId.MystVale_Part4,
    position: Position(0x160, 0x1d0),
    direction: Direction.down
  ),
  (
    from: MapId.ElsydeonCave,
    to: MapId.InnerSanctuary_B1,
    position: Position(0x1e0, 0x190),
    direction: Direction.down
  ),
  (
    from: MapId.ElsydeonCave,
    to: MapId.ElsydeonCave_B1,
    position: Position(0x200, 0x2c0),
    direction: Direction.left
  ),
  (
    from: MapId.ElsydeonCave_B1,
    to: MapId.ElsydeonCave,
    position: Position(0x210, 0x2a0),
    direction: Direction.right
  ),
  (
    from: MapId.Hangar,
    to: MapId.Dezolis,
    position: Position(0x90, 0x480),
    direction: Direction.down
  ),
  (
    from: MapId.Hangar,
    to: MapId.Tyler,
    position: Position(0x140, 0x190),
    direction: Direction.down
  ),
  (
    from: MapId.GumbiousEntrance,
    to: MapId.Dezolis,
    position: Position(0x7d0, 0x460),
    direction: Direction.down
  ),
  (
    from: MapId.GumbiousEntrance,
    to: MapId.Dezolis,
    position: Position(0x7d0, 0x460),
    direction: Direction.down
  ),
  (
    from: MapId.GumbiousEntrance,
    to: MapId.Dezolis,
    position: Position(0x7d0, 0x460),
    direction: Direction.down
  ),
  (
    from: MapId.GumbiousEntrance,
    to: MapId.Gumbious,
    position: Position(0x2f0, 0x400),
    direction: Direction.up
  ),
  (
    from: MapId.Gumbious,
    to: MapId.GumbiousEntrance,
    position: Position(0x1f0, 0x1f0),
    direction: Direction.down
  ),
  (
    from: MapId.Gumbious,
    to: MapId.Gumbious_B1,
    position: Position(0x220, 0x2c0),
    direction: Direction.left
  ),
  (
    from: MapId.Gumbious,
    to: MapId.Gumbious_F1,
    position: Position(0x130, 0x2e0),
    direction: Direction.right
  ),
  (
    from: MapId.Gumbious_F1,
    to: MapId.Gumbious,
    position: Position(0x240, 0x3a0),
    direction: Direction.left
  ),
  (
    from: MapId.Gumbious_B1,
    to: MapId.Gumbious,
    position: Position(0x3b0, 0x3a0),
    direction: Direction.right
  ),
  (
    from: MapId.Gumbious_B1,
    to: MapId.Gumbious_B2,
    position: Position(0x1e0, 0x220),
    direction: Direction.left
  ),
  (
    from: MapId.Gumbious_B2,
    to: MapId.Gumbious_B2_Part2,
    position: Position(0x1e0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.Gumbious_B2,
    to: MapId.Gumbious_B1,
    position: Position(0x2f0, 0x100),
    direction: Direction.right
  ),
  (
    from: MapId.Gumbious_B2_Part2,
    to: MapId.Gumbious_B2,
    position: Position(0x1e0, 0x170),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionEntrance,
    to: MapId.Dezolis,
    position: Position(0xe70, 0x380),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionEntrance,
    to: MapId.Dezolis,
    position: Position(0xe70, 0x380),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionEntrance,
    to: MapId.Dezolis,
    position: Position(0xe70, 0x380),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionEntrance,
    to: MapId.EspMansion,
    position: Position(0x2f0, 0x400),
    direction: Direction.up
  ),
  (
    from: MapId.EspMansion,
    to: MapId.EspMansionEntrance,
    position: Position(0x200, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansion,
    to: MapId.EspMansionWestRoom,
    position: Position(0x210, 0x240),
    direction: Direction.up
  ),
  (
    from: MapId.EspMansion,
    to: MapId.EspMansionEastRoom,
    position: Position(0x1e0, 0x240),
    direction: Direction.up
  ),
  (
    from: MapId.EspMansion,
    to: MapId.EspMansionNorthEastRoom,
    position: Position(0x1c0, 0x200),
    direction: Direction.up
  ),
  (
    from: MapId.EspMansion,
    to: MapId.EspMansionNorthWestRoom,
    position: Position(0x250, 0x200),
    direction: Direction.up
  ),
  (
    from: MapId.EspMansion,
    to: MapId.EspMansionNorth,
    position: Position(0x1d0, 0x360),
    direction: Direction.up
  ),
  (
    from: MapId.EspMansion,
    to: MapId.EspMansionNorth,
    position: Position(0x420, 0x360),
    direction: Direction.up
  ),
  (
    from: MapId.EspMansionWestRoom,
    to: MapId.EspMansion,
    position: Position(0x110, 0x330),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionEastRoom,
    to: MapId.EspMansion,
    position: Position(0x4e0, 0x330),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionNorth,
    to: MapId.EspMansion,
    position: Position(0x1b0, 0x190),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionNorth,
    to: MapId.EspMansion,
    position: Position(0x440, 0x190),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionNorth,
    to: MapId.EspMansionCourtyard,
    position: Position(0x1f0, 0xf0),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionNorthEastRoom,
    to: MapId.EspMansion,
    position: Position(0x4c0, 0x190),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionNorthWestRoom,
    to: MapId.EspMansion,
    position: Position(0x130, 0x190),
    direction: Direction.down
  ),
  (
    from: MapId.EspMansionCourtyard,
    to: MapId.EspMansionNorth,
    position: Position(0x2f0, 0x120),
    direction: Direction.up
  ),
  (
    from: MapId.EspMansionCourtyard,
    to: MapId.InnerSanctuary,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.InnerSanctuary,
    to: MapId.EspMansionCourtyard,
    position: Position(0x1f0, 0x2b0),
    direction: Direction.down
  ),
  (
    from: MapId.InnerSanctuary,
    to: MapId.InnerSanctuary_B1,
    position: Position(0x1e0, 0x260),
    direction: Direction.left
  ),
  (
    from: MapId.InnerSanctuary_B1,
    to: MapId.ElsydeonCave,
    position: Position(0x140, 0x2f0),
    direction: Direction.up
  ),
  (
    from: MapId.InnerSanctuary_B1,
    to: MapId.InnerSanctuary,
    position: Position(0x200, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F1_Part9,
    position: Position(0x1f0, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_Part5,
    position: Position(0x1f0, 0xb0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_Part4,
    position: Position(0x1f0, 0xb0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F1_Part5,
    position: Position(0x160, 0x120),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F1_Part2,
    position: Position(0x290, 0x120),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_Part3,
    position: Position(0x2f0, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F1_Part11,
    position: Position(0x1c0, 0x180),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F1_Part11,
    position: Position(0x430, 0x180),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_Part8,
    position: Position(0x220, 0x340),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F1_Part10,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_Part7,
    position: Position(0x1f0, 0x340),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F1_Part3,
    position: Position(0x1d0, 0x240),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F1_Part4,
    position: Position(0x1d0, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F1,
    position: Position(0x210, 0x2a0),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F1_Part12,
    position: Position(0x1c0, 0x300),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastle_F2,
    position: Position(0x1f0, 0x260),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part6,
    to: MapId.AirCastleXeAThoulRoom,
    position: Position(0x1f0, 0x320),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle,
    to: MapId.AirCastle_Part2,
    position: Position(0x1f0, 0x280),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle,
    to: MapId.AirCastle_F1_Part5,
    position: Position(0x1e0, 0x320),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle,
    to: MapId.AirCastle_Part3,
    position: Position(0x200, 0x410),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle,
    to: MapId.AirCastle_Part3,
    position: Position(0x3f0, 0x410),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle,
    to: MapId.AirCastle_F1_Part2,
    position: Position(0x210, 0x320),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part2,
    to: MapId.AirCastle,
    position: Position(0x3f0, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part2,
    to: MapId.AirCastle_Part3,
    position: Position(0x2f0, 0x410),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part3,
    to: MapId.AirCastle_Part2,
    position: Position(0x1f0, 0x1c0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part3,
    to: MapId.AirCastle_Part6,
    position: Position(0x3f0, 0x610),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part3,
    to: MapId.AirCastle,
    position: Position(0x2e0, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part3,
    to: MapId.AirCastle,
    position: Position(0x510, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part3,
    to: MapId.AirCastle_Part4,
    position: Position(0x300, 0x170),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part3,
    to: MapId.AirCastle_F1_Part9,
    position: Position(0x1f0, 0x210),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part3,
    to: MapId.AirCastle_Part5,
    position: Position(0xf0, 0x150),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part4,
    to: MapId.AirCastle_Part3,
    position: Position(0x220, 0x2b0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part4,
    to: MapId.AirCastle_Part6,
    position: Position(0x1b0, 0x590),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part4,
    to: MapId.AirCastle_F1_Part5,
    position: Position(0x130, 0x180),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastle_Part5,
    to: MapId.AirCastle_Part3,
    position: Position(0x3d0, 0x2b0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part5,
    to: MapId.AirCastle_Part6,
    position: Position(0x630, 0x590),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_Part5,
    to: MapId.AirCastle_F1_Part2,
    position: Position(0x2f0, 0x1a0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastle_F1_Part9,
    to: MapId.AirCastle_Part3,
    position: Position(0x2f0, 0x270),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_F1_Part9,
    to: MapId.AirCastle_Part6,
    position: Position(0x3f0, 0x5b0),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_F1_Part5,
    to: MapId.AirCastle_Part6,
    position: Position(0x100, 0x5f0),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_F1_Part5,
    to: MapId.AirCastle,
    position: Position(0x160, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_F1_Part5,
    to: MapId.AirCastle_Part4,
    position: Position(0x100, 0xe0),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastle_F1_Part2,
    to: MapId.AirCastle_Part6,
    position: Position(0x6f0, 0x5f0),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_F1_Part2,
    to: MapId.AirCastle,
    position: Position(0x690, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_F1_Part2,
    to: MapId.AirCastle_Part5,
    position: Position(0x300, 0xe0),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastle_F1_Part10,
    to: MapId.AirCastle_Part6,
    position: Position(0x3f0, 0x4c0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_F1_Part10,
    to: MapId.AirCastle_F1_Part11,
    position: Position(0x240, 0x3d0),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_F1_Part10,
    to: MapId.AirCastleInner,
    position: Position(0x1f0, 0x230),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_F1_Part10,
    to: MapId.AirCastle_F1_Part11,
    position: Position(0x3b0, 0x3d0),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastleInner,
    to: MapId.AirCastle_F1_Part10,
    position: Position(0x1f0, 0x1a0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastleInner,
    to: MapId.AirCastleInner_B1,
    position: Position(0x260, 0xc0),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastle_F1_Part11,
    to: MapId.AirCastle_Part6,
    position: Position(0x2c0, 0x1f0),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_F1_Part11,
    to: MapId.AirCastle_Part6,
    position: Position(0x530, 0x1f0),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastle_F1_Part11,
    to: MapId.AirCastle_F1_Part10,
    position: Position(0x140, 0x140),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_F1_Part11,
    to: MapId.AirCastle_F1_Part10,
    position: Position(0x2b0, 0x140),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_F1_Part11,
    to: MapId.AirCastle_F1_Part12,
    position: Position(0x240, 0x1c0),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastle_F1_Part11,
    to: MapId.AirCastle_F1_Part13,
    position: Position(0x1e0, 0x1c0),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastle_F1_Part11,
    to: MapId.AirCastle_F2,
    position: Position(0x1f0, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastle_F1_Part12,
    to: MapId.AirCastle_F1_Part11,
    position: Position(0x1f0, 0x2e0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastle_F1_Part12,
    to: MapId.AirCastle_Part6,
    position: Position(0x290, 0x4a0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastle_F1_Part13,
    to: MapId.AirCastle_F1_Part11,
    position: Position(0x410, 0x2e0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastle_Part8,
    to: MapId.AirCastle_Part6,
    position: Position(0x1a0, 0x480),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part8,
    to: MapId.AirCastle_F1_Part4,
    position: Position(0x130, 0x2a0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastle_Part7,
    to: MapId.AirCastle_Part6,
    position: Position(0x630, 0x480),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_Part7,
    to: MapId.AirCastle_F1,
    position: Position(0x2d0, 0x2c0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastle_F1_Part4,
    to: MapId.AirCastle_Part6,
    position: Position(0x190, 0x2f0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_F1_Part4,
    to: MapId.AirCastle_Part8,
    position: Position(0x140, 0x160),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastle_F1,
    to: MapId.AirCastle_Part6,
    position: Position(0x650, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_F1,
    to: MapId.AirCastle_Part7,
    position: Position(0x2c0, 0x160),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastle_F1_Part3,
    to: MapId.AirCastle_Part6,
    position: Position(0x1b0, 0x400),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_F2,
    to: MapId.AirCastle_Part6,
    position: Position(0x5b0, 0x3a0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastle_F2,
    to: MapId.AirCastle_F1_Part11,
    position: Position(0x4c0, 0x360),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastleXeAThoulRoom,
    to: MapId.AirCastle_Part6,
    position: Position(0x3f0, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastleInner_B1,
    to: MapId.AirCastleInner,
    position: Position(0x1f0, 0x1e0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastleInner_B1,
    to: MapId.AirCastleInner_B2,
    position: Position(0x140, 0x260),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastleInner_B1,
    to: MapId.AirCastleInner_B2,
    position: Position(0x2a0, 0x260),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastleInner_B1,
    to: MapId.AirCastleInner_B1_Part2,
    position: Position(0x130, 0x250),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastleInner_B1_Part2,
    to: MapId.AirCastleInner_B1,
    position: Position(0x110, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastleInner_B1_Part2,
    to: MapId.AirCastleInner_B1_Part3,
    position: Position(0x1e0, 0x310),
    direction: Direction.up
  ),
  (
    from: MapId.AirCastleInner_B1_Part3,
    to: MapId.AirCastleInner_B1_Part2,
    position: Position(0x200, 0x180),
    direction: Direction.down
  ),
  (
    from: MapId.AirCastleInner_B2,
    to: MapId.AirCastleInner_B1,
    position: Position(0x150, 0x240),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastleInner_B2,
    to: MapId.AirCastleInner_B1,
    position: Position(0x2a0, 0x240),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastleInner_B2,
    to: MapId.AirCastleInner_B3,
    position: Position(0x140, 0x1c0),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastleInner_B2,
    to: MapId.AirCastleInner_B3,
    position: Position(0x2a0, 0x1c0),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastleInner_B3,
    to: MapId.AirCastleInner_B2,
    position: Position(0x150, 0x1a0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastleInner_B3,
    to: MapId.AirCastleInner_B2,
    position: Position(0x2b0, 0x1a0),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastleInner_B3,
    to: MapId.AirCastleInner_B4,
    position: Position(0x140, 0x100),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastleInner_B3,
    to: MapId.AirCastleInner_B4,
    position: Position(0x2a0, 0x100),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastleInner_B4,
    to: MapId.AirCastleInner_B3,
    position: Position(0x170, 0x100),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastleInner_B4,
    to: MapId.AirCastleInner_B3,
    position: Position(0x2d0, 0x100),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastleInner_B4,
    to: MapId.AirCastleInner_B5,
    position: Position(0x140, 0x220),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastleInner_B4,
    to: MapId.AirCastleInner_B5,
    position: Position(0x2a0, 0x260),
    direction: Direction.left
  ),
  (
    from: MapId.AirCastleInner_B5,
    to: MapId.AirCastleInner_B4,
    position: Position(0x150, 0x240),
    direction: Direction.right
  ),
  (
    from: MapId.AirCastleInner_B5,
    to: MapId.AirCastleInner_B4,
    position: Position(0x2b0, 0x240),
    direction: Direction.right
  ),
  (
    from: MapId.Zelan,
    to: MapId.Zelan_F1,
    position: Position(0x1e0, 0x300),
    direction: Direction.down
  ),
  (
    from: MapId.Zelan_F1,
    to: MapId.Zelan,
    position: Position(0x1e0, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran,
    to: MapId.Kuran_F1,
    position: Position(0x2e0, 0x320),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1,
    to: MapId.Kuran_F2,
    position: Position(0x2e0, 0xa0),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1,
    to: MapId.Kuran_F2,
    position: Position(0x2e0, 0x1a0),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1,
    to: MapId.Kuran,
    position: Position(0x1e0, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1,
    to: MapId.Kuran_F1_Part4,
    position: Position(0x1e0, 0x160),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1,
    to: MapId.Kuran_F1_Part2,
    position: Position(0x320, 0x200),
    direction: Direction.up
  ),
  (
    from: MapId.Kuran_F1,
    to: MapId.Kuran_F1_Part3,
    position: Position(0x2c0, 0x200),
    direction: Direction.up
  ),
  (
    from: MapId.Kuran_F1,
    to: MapId.Kuran_F1_Part5,
    position: Position(0xc0, 0x200),
    direction: Direction.up
  ),
  (
    from: MapId.Kuran_F1,
    to: MapId.Kuran_F2_Part2,
    position: Position(0x120, 0x200),
    direction: Direction.up
  ),
  (
    from: MapId.Kuran_F2,
    to: MapId.Kuran_F1,
    position: Position(0x2e0, 0x100),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F2,
    to: MapId.Kuran_F1,
    position: Position(0x2e0, 0x220),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F2,
    to: MapId.Kuran_F3,
    position: Position(0x1e0, 0x300),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F2,
    to: MapId.Kuran_F1_Part4,
    position: Position(0x1e0, 0x200),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1_Part2,
    to: MapId.Kuran_F1_Part3,
    position: Position(0xc0, 0x220),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1_Part2,
    to: MapId.Kuran_F1,
    position: Position(0x160, 0x320),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1_Part3,
    to: MapId.Kuran_F1_Part2,
    position: Position(0xc0, 0x220),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1_Part3,
    to: MapId.Kuran_F1,
    position: Position(0x100, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1_Part5,
    to: MapId.Kuran_F2_Part2,
    position: Position(0x120, 0x1c0),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1_Part5,
    to: MapId.Kuran_F1,
    position: Position(0x460, 0x320),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F2_Part2,
    to: MapId.Kuran_F1_Part5,
    position: Position(0x120, 0x1c0),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F2_Part2,
    to: MapId.Kuran_F1,
    position: Position(0x4c0, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1_Part4,
    to: MapId.Kuran_F2,
    position: Position(0x2e0, 0x520),
    direction: Direction.down
  ),
  (
    from: MapId.Kuran_F1_Part4,
    to: MapId.Kuran_F1,
    position: Position(0x2e0, 0x4c0),
    direction: Direction.up
  ),
  (
    from: MapId.Kuran_F3,
    to: MapId.Kuran_F2,
    position: Position(0x2e0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower,
    to: MapId.GaruberkTower_Part2,
    position: Position(0x240, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower,
    to: MapId.Dezolis,
    position: Position(0xba0, 0x60),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part2,
    to: MapId.GaruberkTower,
    position: Position(0x220, 0x120),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part2,
    to: MapId.GaruberkTower_Part3,
    position: Position(0x160, 0xc0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part3,
    to: MapId.GaruberkTower_Part2,
    position: Position(0x3e0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part3,
    to: MapId.GaruberkTower_Part4,
    position: Position(0x2c0, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part3,
    to: MapId.GaruberkTower_Part4,
    position: Position(0x3c0, 0x3c0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part4,
    to: MapId.GaruberkTower_Part3,
    position: Position(0x2e0, 0x260),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part4,
    to: MapId.GaruberkTower_Part3,
    position: Position(0x3e0, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part4,
    to: MapId.GaruberkTower_Part5,
    position: Position(0x180, 0x4a0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part5,
    to: MapId.GaruberkTower_Part4,
    position: Position(0x160, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part5,
    to: MapId.GaruberkTower_Part6,
    position: Position(0x3e0, 0x140),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part5,
    to: MapId.GaruberkTower_Part6,
    position: Position(0x460, 0x220),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part5,
    to: MapId.GaruberkTower_Part6,
    position: Position(0x460, 0x2e0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part5,
    to: MapId.GaruberkTower_Part6,
    position: Position(0x260, 0x340),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part6,
    to: MapId.GaruberkTower_Part5,
    position: Position(0x1a0, 0x2c0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part6,
    to: MapId.GaruberkTower_Part5,
    position: Position(0x340, 0xe0),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part6,
    to: MapId.GaruberkTower_Part5,
    position: Position(0x3e0, 0x180),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part6,
    to: MapId.GaruberkTower_Part5,
    position: Position(0x3e0, 0x240),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part6,
    to: MapId.GaruberkTower_Part7,
    position: Position(0x260, 0x220),
    direction: Direction.down
  ),
  (
    from: MapId.GaruberkTower_Part7,
    to: MapId.GaruberkTower_Part6,
    position: Position(0x320, 0x160),
    direction: Direction.down
  ),
];
