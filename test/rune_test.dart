import 'dart:io';

import 'package:rune/asm/asm.dart';
import 'package:test/test.dart';

void main() {
  test('parse asm', () async {
    var ps4asm = File(
        '/Users/ahenning/Code/alechenninger.com/macro-server/ps4disasm/ps4.asm');
    var raw = await ps4asm.readAsString();
    // var lines = LineSplitter.split(raw).toList(growable: false);
    //
    // var maps = lines.sublist(183224, 278811);
    // var dialogIncludes = lines.sublist(273295, 273800);
    // maps from / to
    // 183225 (inclusive)
    // 278811

    // dialog trees from / to
    // 273295 (inclusive)
    // 273800 (ish)

    // ignore: unused_local_variable
    var parsed = Asm.fromRaw(raw);

    // var mapsAsm = Asm.fromRaw(maps.join('\n'));
    // var dialogIncludesAsm = Asm.fromRaw(dialogIncludes.join('\n'));
  }, skip: 'just for timing');
}
