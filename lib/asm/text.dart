// ignore_for_file: non_constant_identifier_names

import 'asm.dart';

final GetDialogueByID = 'GetDialogueByID'.toLabel;
final RunText2 = 'RunText2'.toLabel;
final VInt_Prepare = 'VInt_Prepare'.toLabel;
final DMAPlane_A_VInt = 'DMAPlane_A_VInt'.toLabel;
final Main_Frame_Count = 'Main_Frame_Count'.toConstant;

final Palette_Table_Buffer = 'Palette_Table_Buffer'.toConstant;

Asm getDialogueByID(Byte id) {
  return Asm([
    move.b(id.i, d0), //
    jsr(GetDialogueByID.l)
  ]);
}

Asm vIntPrepare() {
  return jsr(VInt_Prepare.l);
}

Asm dmaPlaneAVInt() {
  return jsr(DMAPlane_A_VInt.l);
}

Asm runText2(
  Address planeABufferPosition,
  Address vramTileNumber,
) {
  return Asm([
    lea(planeABufferPosition, a1),
    move.w(vramTileNumber, d3),
    moveq(1.toValue.i, d4),
    jsr(RunText2.l),
  ]);
}
