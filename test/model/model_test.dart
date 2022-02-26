import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  group('==', () {
    test('IndividualMoves', () {
      var moves = IndividualMoves();
      moves.moves[alys] = StepDirection()
        ..direction = Direction.down
        ..distance = 2
        ..delay = 3;

      expect(
          moves,
          equals(IndividualMoves()
            ..moves[alys] = (StepDirection()
              ..direction = Direction.down
              ..distance = 2
              ..delay = 3)));
    });

    test('alys', () {
      expect(alys, equals(alys));
    });

    test('StepDirection', () {
      expect(
          StepDirection()
            ..direction = Direction.down
            ..distance = 2
            ..delay = 3,
          equals(StepDirection()
            ..direction = Direction.down
            ..distance = 2
            ..delay = 3));
    });

    test('StepDirections', () {
      expect(
          StepDirections()
            ..step(StepDirection()
              ..direction = Direction.down
              ..distance = 2
              ..delay = 3),
          equals(StepDirections()
            ..step(StepDirection()
              ..direction = Direction.down
              ..distance = 2
              ..delay = 3)));
    });
  });
}
