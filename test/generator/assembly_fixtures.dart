import 'package:rune/asm/asm.dart';
import 'package:rune/generator/movement.dart';
import 'package:test/test.dart';

typedef GeneratedAssembly = ({Asm event, Asm dialog});

Asm expectedAssembly(Iterable<Asm> fragments) =>
    Asm(fragments.toList()).withoutComments().withoutEmptyLines();

void expectGenerated(GeneratedAssembly generated, List<Asm> event,
    {List<Asm> dialog = const []}) {
  expect(generated.event.withoutComments().withoutEmptyLines(),
      expectedAssembly(event),
      reason: 'event assembly');
  expect(generated.dialog.withoutComments().withoutEmptyLines(),
      expectedAssembly(dialog),
      reason: 'dialog assembly');
}

// The interaction index selects a 0x40-byte secondary object slot.
Asm loadInteractionObject(DirectAddressRegister destination) => Asm([
      moveq(0.i, d0),
      move.b(Constant('Interaction_Object_Index').w, d0),
      lsl.w(6.i, d0),
      addi.l(Constant('Field_Obj_Secondary').i, d0),
      movea.l(d0, destination),
    ]);

// Expected direction calculation after loading the X/Y deltas into d2/d3.
// Callers spell out coordinate reads, zero-vector fallback, and facing update.
Asm vectorDirection(String suffix) => Asm([
      move.w(d2, d4),
      bpl.s(Label('.positive_dx$suffix')),
      neg.w(d4),
      label(Label('.positive_dx$suffix')),
      move.w(d3, d5),
      bpl.s(Label('.positive_dy$suffix')),
      neg.w(d5),
      label(Label('.positive_dy$suffix')),
      cmp.w(d4, d5),
      bgt.s(Label('.checky$suffix')),
      tst.w(d4),
      beq.s(Label('.zerovector$suffix')),
      tst.w(d2),
      bpl.s(Label('.right$suffix')),
      move.w(FacingDir_Left.i, d0),
      bra.s(Label('.keep$suffix')),
      label(Label('.right$suffix')),
      move.w(FacingDir_Right.i, d0),
      bra.s(Label('.keep$suffix')),
      label(Label('.checky$suffix')),
      tst.w(d3),
      bpl.s(Label('.down$suffix')),
      move.w(FacingDir_Up.i, d0),
      bra.s(Label('.keep$suffix')),
      label(Label('.down$suffix')),
      move.w(FacingDir_Down.i, d0),
      bra.s(Label('.keep$suffix')),
      label(Label('.zerovector$suffix')),
    ]);
