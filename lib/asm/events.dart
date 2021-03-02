import 'asm.dart';

Asm stepObject(
    {required Address x, required Address y, required Address frames}) {
  return Asm([
    move.l(x, Address.d(0)),
    move.l(y, Address.d(1)),
    move.l(frames, Address.d(2)),
    jsr(Label('Event_StepObject').l)
  ]);
}
