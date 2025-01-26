import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('setting character position also sets slot if known', () {
    var state = EventState();
    state.slots[2] = rune;
    state.positions[rune] = Position(0x10, 0x20);
    expect(state.positions[BySlot(2)], Position(0x10, 0x20));
  });
}
