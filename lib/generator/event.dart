import '../asm/asm.dart';

class EventAsm extends Asm {
  EventAsm(List<Asm> asm) : super(asm);

  EventAsm.of(Asm asm) : this([asm]);

  EventAsm.empty() : super.empty();

  EventAsm.fromInstruction(Instruction line) : super.fromInstruction(line);

  EventAsm.fromInstructions(List<Instruction> lines)
      : super.fromInstructions(lines);

  EventAsm.fromRaw(String raw) : super.empty() {
    add(Instruction.parse(raw));
  }
}
