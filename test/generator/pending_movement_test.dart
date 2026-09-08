import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/labels.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

AbsoluteMoves moving([FieldObject object = shay]) => AbsoluteMoves()
  ..destinations[object] = Position(0x100, 0x100)
  ..waitForMovements = false;

IndividualMoves facing([FieldObject object = shay]) =>
    IndividualMoves()..moves[object] = Face(up);

StepPath walking() => StepPath()
  ..distance = 1.step
  ..direction = right;

int waits(Asm asm) => asm.lines
    .where((line) =>
        line.cmd == 'jsr' &&
        line.toString().contains('Event_DoWaitForCharacter'))
    .length;

void main() {
  late EventAsm asm;
  late SceneAsmGenerator generator;
  late EventState state;
  late GameMap map;
  late DialogTrees dialogs;

  void captureState() {
    generator.setContext(SetContext((value) => state = value));
  }

  setUp(() {
    map = GameMap(MapId.Test);
    dialogs = DialogTrees();
    asm = EventAsm.empty();
    generator = SceneAsmGenerator.forEvent(SceneId('pending'), dialogs, asm,
        startingMap: map);
    captureState();
    state.setSlot(1, alys);
    state.setSlot(2, shay);
    state.cameraLock = true;
  });

  final operations = <String, Event Function()>{
    'step': () => StepObject.constantStep(BySlot.two,
        stepPerFrame: Point(1, 0), frames: 2),
    'steps': () => StepObjects.constantStep([BySlot.two, BySlot.one],
        stepPerFrame: Point(1, 0), frames: 2),
    'individual move': () => IndividualMoves()..moves[BySlot.two] = walking(),
    'absolute move': () =>
        AbsoluteMoves()..destinations[BySlot.two] = Position(0x120, 0x100),
    'overlap': () => OverlapCharacters(),
    'party move': () => RelativePartyMove(walking()),
    'facing': () => facing(BySlot.two),
    'face player': () => FacePlayer(BySlot.two),
  };

  for (var operation in operations.entries) {
    test('waits before ${operation.key} through a different object reference',
        () {
      generator.absoluteMoves(moving());
      expect(state.pendingMovements, {shay});
      var before = asm.length;
      operation.value().visit(generator);
      expect(state.pendingMovements, isEmpty);
      expect(waits(asm), 1);
      var generated =
          asm.lines.skip(before).map((line) => line.toString()).join('\n');
      expect(generated, contains('Event_DoWaitForCharacter'));
      // The wait starts the callback, before the operation's own instructions.
      var instructions =
          asm.lines.skip(before).where((line) => line.cmd != null).toList();
      expect(instructions.take(3).join('\n'),
          contains('Event_DoWaitForCharacter'));
      generator.finish();
      expect(waits(asm), 1);
    });
  }

  test('unrelated targeted operations do not wait', () {
    generator.absoluteMoves(moving());
    generator.individualMoves(facing(alys));
    expect(waits(asm), 0);
    expect(state.pendingMovements, {shay});
    generator.finish();
    expect(waits(asm), 1);
    expect(state.pendingMovements, isEmpty);
  });

  test('explicit wait removes only its resolved objects', () {
    generator
        .absoluteMoves(moving()..destinations[alys] = Position(0x80, 0x80));
    generator.waitForMovements(WaitForMovements([BySlot.two]));
    expect(state.pendingMovements, {alys});
    generator.individualMoves(facing(shay));
    expect(waits(asm), 1);
    generator.finish();
    expect(waits(asm), 2);
    expect(state.pendingMovements, isEmpty);
  });

  test('explicit waits are emitted without tracked movement', () {
    generator.waitForMovements(WaitForMovements([BySlot.two]));
    expect(waits(asm), 1);
  });

  test('consecutive asynchronous moves wait before restarting movement', () {
    generator.absoluteMoves(moving());
    var before = asm.length;
    generator.absoluteMoves(moving(BySlot.two));
    var next = asm.lines.skip(before).join('\n');
    expect(next.indexOf('Event_DoWaitForCharacter'),
        lessThan(next.indexOf('dest_x_pos')));
    expect(state.pendingMovements, {shay});
    generator.finish();
    expect(waits(asm), 2);
  });

  test('synchronous and empty absolute moves create no pending movement', () {
    generator.absoluteMoves(moving()..waitForMovements = true);
    generator.absoluteMoves(AbsoluteMoves()..waitForMovements = false);
    expect(state.pendingMovements, isEmpty);
    generator.finish();
    expect(waits(asm), 0);
  });

  test('leader movement tracks and waits for followers', () {
    generator.absoluteMoves(moving(BySlot.one)..followLeader = true);
    expect(state.pendingMovements,
        {alys, shay, BySlot.three, BySlot.four, BySlot.five});
    generator.individualMoves(facing(BySlot.two));
    expect(waits(asm), 1);
    expect(state.hasPendingMovement(shay), isFalse);
    generator.finish();
    expect(waits(asm), 5);
  });

  test('party-wide operations wait for pending moves in unknown slots', () {
    generator.absoluteMoves(moving(BySlot.three));
    generator.overlapCharacters(OverlapCharacters());
    expect(state.pendingMovements, isEmpty);
    expect(waits(asm), 1);
  });

  for (var next in ['move', 'facing', 'explicit wait', 'finish']) {
    test('queued move is not flushed early before $next', () {
      generator.dialog(Dialog(spans: [DialogSpan('Hello')]));
      var before = asm.toString();
      generator.absoluteMoves(moving());
      expect(state.pendingMovements, isEmpty);
      expect(asm.toString(), before);
      switch (next) {
        case 'move':
          generator.absoluteMoves(moving(BySlot.two));
        case 'facing':
          generator.individualMoves(facing(BySlot.two));
        case 'explicit wait':
          generator.waitForMovements(WaitForMovements([BySlot.two]));
        case 'finish':
          break;
      }
      if (next != 'explicit wait') {
        expect(state.pendingMovements, isEmpty);
        expect(asm.toString(), before);
      }
      generator.finish();
      expect(state.pendingMovements, isEmpty);
      expect(waits(asm), next == 'move' ? 2 : 1);
    });
  }

  test('dialog-only interaction waits after queued moves before termination',
      () {
    generator = SceneAsmGenerator.forInteraction(
        map, SceneId('interaction'), dialogs, asm, TestEventRoutines(),
        withObject: null);
    captureState();
    state.setSlot(1, alys);
    state.setSlot(2, shay);
    generator.dialog(Dialog(spans: [DialogSpan('Hello')]));
    generator.absoluteMoves(moving());
    generator.absoluteMoves(moving(BySlot.two));
    expect(state.pendingMovements, isEmpty);
    expect(asm, isEmpty);
    generator.finish();
    expect(state.pendingMovements, isEmpty);
    expect(waits(asm), 2);
    var labels =
        asm.lines.map((line) => line.label).whereType<Label>().toList();
    expect(labels.toSet().length, labels.length);
    var dialog = dialogs.forMap(map.id).toString();
    expect(dialog, contains('AbsoluteMoves'));
    expect(dialog, contains('AutomaticMovementWait'));
  });

  test('queued facing waits in dialog without entering event mode', () {
    generator.dialog(Dialog(spans: [DialogSpan('Hello')]));
    generator.absoluteMoves(moving());
    generator.individualMoves(facing(BySlot.two));
    expect(state.pendingMovements, isEmpty);
    generator.dialog(Dialog(spans: [DialogSpan('Still talking')]));
    expect(generator.inDialogLoop, isTrue);
    expect(state.pendingMovements, isEmpty);
    expect(waits(asm), 0); // Wait routine remains in post-ASM until finish.
    generator.finish();
    expect(waits(asm), 1);
    expect(
        dialogs.forMap(map.id).toString(), contains('AutomaticMovementWait'));
  });

  test('map object references wait and clear through resolved identity', () {
    var object = MapObject(
        id: 'npc', startPosition: Position(0, 0), spec: AlysWaiting());
    map.addObject(object);
    generator.absoluteMoves(moving(MapObjectById.of('npc')));
    expect(state.pendingMovements, {object});
    generator.individualMoves(facing(object));
    expect(state.pendingMovements, isEmpty);
    expect(asm.toString(), contains('Event_MoveCharacter'));
    var before = 'Event_MoveCharacter'.allMatches(asm.toString()).length;
    generator.finish();
    expect('Event_MoveCharacter'.allMatches(asm.toString()).length, before);
  });

  test('moving only an NPC does not track party followers', () {
    var object = MapObject(
        id: 'npc', startPosition: Position(0, 0), spec: AlysWaiting());
    map.addObject(object);
    generator.absoluteMoves(moving(object)..followLeader = true);
    expect(state.pendingMovements, {object});
    generator.finish();
    expect(state.pendingMovements, isEmpty);
    expect(waits(asm), 0);
  });

  test('instant moves do not insert an automatic wait', () {
    generator.absoluteMoves(moving());
    generator.instantMoves(InstantMoves()..put(shay, Position(0x120, 0x100)));
    expect(waits(asm), 0);
    expect(state.pendingMovements, {shay});
  });

  test('position references do not wait for the reference object', () {
    generator.absoluteMoves(moving());
    generator.absoluteMoves(
        AbsoluteMoves()..destinations[alys] = BySlot.two.position());
    expect(waits(asm), 0);
    expect(state.pendingMovements, {shay});
    generator.finish();
    expect(waits(asm), 1);
  });

  test('inline asynchronous movement is waited for on scene finish', () {
    generator.dialog(Dialog(spans: [
      DialogSpan('Hello', events: [moving()])
    ]));
    expect(state.pendingMovements, {shay});
    generator.finish();
    expect(state.pendingMovements, isEmpty);
    expect(waits(asm), 1);
  });

  test('value branch joins preserve possible pending movement', () {
    generator.ifValue(IfValue(BySlot.one.position().component(Axis.y),
        comparedTo: PositionComponent(0x200, Axis.y), equal: [moving()]));
    captureState();
    expect(state.hasPendingMovement(shay), isTrue);
    generator.finish();
    expect(waits(asm), 1);
  });

  test('ReturnControl waits before returning', () {
    generator.absoluteMoves(moving());
    generator.returnControl(ReturnControl());
    expect(state.pendingMovements, isEmpty);
    expect(waits(asm), 1);
    expect(asm.lines.last.cmd, 'rts');
  });

  test('conditional start survives a branch join', () {
    generator.ifFlag(IfFlag(EventFlag('moving'), isSet: [moving()]));
    captureState();
    expect(state.hasPendingMovement(shay), isTrue);
    generator.individualMoves(facing(BySlot.two));
    expect(state.pendingMovements, isEmpty);
    expect(waits(asm), 1);
  });

  test('conditional explicit wait does not clear movement on the other path',
      () {
    generator.absoluteMoves(moving());
    generator.ifFlag(IfFlag(EventFlag('waiting'), isSet: [
      WaitForMovements([BySlot.two])
    ]));
    captureState();
    expect(state.hasPendingMovement(shay), isTrue);
    generator.finish();
    expect(waits(asm), 2);
  });

  test(
      'inline dialog events track, wait for conflicts, and clear explicit waits',
      () {
    var memory = Memory()
      ..setSlot(1, alys)
      ..setSlot(2, shay)
      ..cameraLock = true;
    var dialog = Dialog(spans: [
      DialogSpan('Hello', events: [
        moving(),
        facing(BySlot.two),
        moving(BySlot.two),
        WaitForMovements([shay]),
      ])
    ]);
    var (_, routines) = dialog.toGeneratedAsm(memory,
        labeller: Labeller.localTo('inline'),
        fieldRoutines: defaultFieldRoutines);
    expect(memory.pendingMovements, isEmpty);
    expect(waits(Asm(routines)), 2);
    expect(routines.length, 4);
  });
  test('dialog movement types track and complete movement without a wrapper',
      () {
    var memory = Memory()..setSlot(2, shay);
    var labels = Labeller.localTo('direct');
    AbsoluteMovesInDialog(moving())
        .toAsm(memory, labeller: labels.withContext('first'));
    expect(memory.pendingMovements, {shay});

    var (_, routines) = AbsoluteMovesInDialog(moving(BySlot.two))
        .toAsm(memory, labeller: labels.withContext('second'));
    expect(waits(Asm(routines)), 1);
    expect(memory.pendingMovements, {shay});

    var (_, waitRoutines) =
        WaitForMovementsInDialog(WaitForMovements([BySlot.two]))
            .toAsm(memory, labeller: labels.withContext('explicit'));
    expect(waits(Asm(waitRoutines)), 1);
    expect(memory.pendingMovements, isEmpty);
  });

  for (var routine in [false, true]) {
    test('dialog facing type waits directly, routine=$routine', () {
      var memory = Memory()
        ..setSlot(2, shay)
        ..startMovement(shay);
      var moves = facing(BySlot.two);
      DialogEvent event = routine
          ? FaceInDialogRoutine(moves)
          : FaceInDialogByteCode(moves.justFacing!);
      var (_, routines) = event.toAsm(memory,
          labeller: Labeller.localTo('directFace'),
          fieldRoutines: defaultFieldRoutines);
      expect(waits(Asm(routines)), 1);
      expect(memory.pendingMovements, isEmpty);
    });
  }
}
