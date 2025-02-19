import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  test('generates asm from dialog', () {
    var dialog = Dialog(
        speaker: alys,
        spans: DialogSpan.parse("Hi I'm Alys! _What are you doing here?_"));

    print(dialog);

    var asm = dialog.toAsm();

    expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Hi I'm Alys! ", $64, $6F, $68, $7B, " ", $68, $79, $6C, " ", $80, $76, $7C, " ", $6B, $76, $70, $75, $6E
	dc.b	$FC
	dc.b	$6F, $6C, $79, $6C, $83''');
  });

  test('skips repeated spaces', () {
    var dialog = Dialog(speaker: alys, spans: DialogSpan.parse('Test  1 2 3'));

    print(dialog);

    var asm = dialog.toAsm();

    expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Test 1 2 3"''');
  });

  test('newlines are converted to spaces', () {
    var dialog = Dialog(speaker: alys, spans: DialogSpan.parse('Test\n1 2 3'));

    print(dialog);

    var asm = dialog.toAsm();

    expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Test 1 2 3"''');
  });

  test('repeat newlines are converted to a single space', () {
    var dialog =
        Dialog(speaker: alys, spans: DialogSpan.parse('Test\n\n1 2 3'));

    print(dialog);

    var asm = dialog.toAsm();

    expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Test 1 2 3"''');
  });

  test('all italics uses ascii for non-italics characters', () {
    var dialog = Dialog(spans: [
      DialogSpan("Alys peered out over the Motavian wilds, as the rising",
          italic: true)
    ]);

    var asm = dialog.toAsm();

    print(asm);

    expect(asm.toString(),
        r'''	dc.b	$4E, $73, $80, $7A, " ", $77, $6C, $6C, $79, $6C, $6B, " ", $76, $7C, $7B, " ", $76, $7D, $6C, $79, " ", $7B, $6F, $6C
	dc.b	$FC
	dc.b	$5A, $76, $7B, $68, $7D, $70, $68, $75, " ", $7E, $70, $73, $6B, $7A, ", ", $68, $7A, " ", $7B, $6F, $6C, " ", $79, $70, $7A, $70, $75, $6E''');
  });

  group('sets portrait control codes', () {
    late DialogTrees dialogTrees;
    late DialogTree dialogTree;
    late EventAsm eventAsm;
    late GameMap map;

    setUp(() {
      dialogTrees = DialogTrees();
      eventAsm = EventAsm.empty();
      map = GameMap(MapId.Test);
      dialogTree = dialogTrees.forMap(MapId.Test);
    });

    test('only when not already displayed', () {
      SceneAsmGenerator.forEvent(SceneId('test'), dialogTrees, eventAsm,
          startingMap: map)
        ..dialog(Dialog(speaker: alys, spans: DialogSpan.parse('Hello')))
        ..dialog(Dialog(speaker: alys, spans: DialogSpan.parse('Hello')))
        ..finish();

      var dialog = dialogTree[0];

      expect(
          dialog.withoutComments().trim(),
          DialogAsm([
            dc.b([Byte(0xf4), Byte(2)]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xfd)]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xff)]),
          ]));
    });

    test('for new speakers', () {
      SceneAsmGenerator.forEvent(SceneId('test'), dialogTrees, eventAsm,
          startingMap: map)
        ..dialog(Dialog(speaker: alys, spans: DialogSpan.parse('Hello')))
        ..dialog(Dialog(speaker: shay, spans: DialogSpan.parse('Hello')))
        ..finish();

      var dialog = dialogTree[0];

      expect(
          dialog.withoutComments().trim(),
          DialogAsm([
            dc.b([Byte(0xf4), Byte(2)]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xfd)]),
            dc.b([Byte(0xf4), Byte(1)]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xff)]),
          ]));
    });

    test('for unnamed speakers', () {
      SceneAsmGenerator.forEvent(SceneId('test'), dialogTrees, eventAsm,
          startingMap: map)
        ..dialog(Dialog(spans: DialogSpan.parse('Hello')))
        ..dialog(Dialog(spans: DialogSpan.parse('Hello')))
        ..finish();

      var dialog = dialogTree[0];

      expect(
          dialog.withoutComments().trim(),
          DialogAsm([
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xfd)]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xff)]),
          ]));
    });

    test('for npc speakers', () {
      SceneAsmGenerator.forEvent(SceneId('test'), dialogTrees, eventAsm,
          startingMap: map)
        ..dialog(Dialog(
            speaker: NpcSpeaker(Portrait.AlysWounded, 'Alys'),
            spans: DialogSpan.parse('Hello')))
        ..dialog(Dialog(
            speaker: NpcSpeaker(Portrait.AlysWounded, 'Alys'),
            spans: DialogSpan.parse('Hello')))
        ..finish();

      var dialog = dialogTree[0];

      expect(
          dialog.withoutComments().trim(),
          DialogAsm([
            dc.b([Byte(0xf4), Byte(0x22)]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xfd)]),
            dc.b(Bytes.ascii('Hello')),
            dc.b([Byte(0xff)]),
          ]));
    });
  });

  group('a cursor separates', () {
    test('every other line from the same dialog', () {
      var dialog = Dialog(
          speaker: alys,
          spans: DialogSpan.parse(
              "Hi I'm Alys! Lots of words take up lots of lines. You can "
              "only have 32 characters per line! How fascinating it is to "
              "deal with assembly."));

      print(dialog);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Hi I'm Alys! Lots of words take"
	dc.b	$FC
	dc.b	"up lots of lines. You can only"
	dc.b	$FD
	dc.b	"have 32 characters per line! How"
	dc.b	$FC
	dc.b	"fascinating it is to deal with"
	dc.b	$FD
	dc.b	"assembly."''');
    });
  });

  group('spans with pauses', () {
    test('just pause and speaker', () {
      var dialog = Dialog(
          speaker: alys, spans: [DialogSpan("", pause: Duration(seconds: 1))]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	$F9, $3B''');
    });

    test('just pause, no speaker', () {
      var dialog = Dialog(spans: [DialogSpan("", pause: Duration(seconds: 1))]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F9, $3B''');
    });

    test('pauses come at the end of spans', () {
      var dialog = Dialog(
          speaker: alys,
          spans: [DialogSpan("Hi I'm Alys!", pause: Duration(seconds: 1))]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"Hi I'm Alys!"
	dc.b	$F9, $3B''');
    });

    test('bug1', () {
      var dialog = Dialog(speaker: shay, spans: [
        DialogSpan('It takes and it takes. And I owe it nothing...',
            pause: Duration(seconds: 1)),
        DialogSpan('nothing but a fight.  ', pause: Duration(seconds: 1)),
        DialogSpan('')
      ]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $01
	dc.b	"It takes and it takes. And I owe"
	dc.b	$FC
	dc.b	"it nothing..."
	dc.b	$F9, $3B
	dc.b	"nothing but a"
	dc.b	$FD
	dc.b	"fight."
	dc.b	$F9, $3B''');
    });

    test('bug2', () {
      /*
      Dialog{speaker: Alys, _spans: [
      Span{text: Now take heed…, italic: false, pause: 0:00:01.000000},
      Span{text: else I walk alone once more., italic: false, pause: 0:00:01.000000}]},
      cause: RangeError (end): Invalid value: Not in inclusive range 0..11: 12}
       */
      var dialog = Dialog(speaker: alys, spans: [
        DialogSpan('Now take heed…', pause: Duration(seconds: 1)),
        DialogSpan('else I walk alone once more.', pause: Duration(seconds: 1)),
      ]);

      var asm = dialog.toAsm();

      print(asm);
    });

    test('pause at 32 characters mid dialog', () {
      var dialog = Dialog(speaker: shay, spans: [
        DialogSpan("That you’ve always done this...",
            pause: Duration(seconds: 1)),
        DialogSpan('alone.', pause: Duration(seconds: 1))
      ]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $01
	dc.b	"That you've always done this..."
	dc.b	$FC
	dc.b	$F9, $3B
	dc.b	"alone."
	dc.b	$F9, $3B''');
    });

    test('pause at 32 characters end of dialog', () {
      var dialog = Dialog(speaker: shay, spans: [
        DialogSpan("That you’ve always done this...",
            pause: Duration(seconds: 1)),
      ]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $01
	dc.b	"That you've always done this..."
	dc.b	$F9, $3B''');
    });

    test('dialog with event before skipped whitespace plays event', () {
      var dialog = Dialog(speaker: alys, spans: [
        DialogSpan("...and they will very likely",
            events: [IndividualMoves()..moves[alys] = Face(left)]),
        DialogSpan(" come up with something.",
            events: [IndividualMoves()..moves[alys] = Face(up)]),
      ]);

      var asm = dialog.toAsm();

      expect(asm.toString(), r'''	dc.b	$F4, $02
	dc.b	"...and they will very likely"
	dc.b	$F2, $0E, $01
	dc.w	FacingDir_Left
	dc.b	$FC
	dc.b	"come up with something."
	dc.b	$F2, $0E, $01
	dc.w	FacingDir_Up''');
    });
  });

  group('dialog count', () {
    test('==0 if empty', () {
      expect(DialogAsm.empty().dialogs, 0);
      expect(DialogAsm([]).dialogs, 0);
      expect(DialogAsm([comment('foo')]).dialogs, 0);
    });

    test('==0 if no terminator', () {
      expect(DialogAsm([dc.b(Bytes.ascii("Hello"))]).dialogs, 0);
    });

    test('==1 with just 0xff', () {
      expect(DialogAsm([dc.b(Bytes.of(0xff))]).dialogs, 1);
    });

    test('==1 with one dialog', () {
      expect(
          DialogAsm([
            dc.b(Bytes.ascii("Hello")),
            dc.b([Byte(0xff)])
          ]).dialogs,
          1);
    });

    test('==1 with one dialog terminator on same line', () {
      expect(
          DialogAsm([
            dc.b(BytesAndAscii([
              Bytes.ascii("Hello"),
              Bytes.list([0xff])
            ])),
          ]).dialogs,
          1);
    });

    test('==2 with one dialog and extra terminator', () {
      expect(
          DialogAsm([
            dc.b(Bytes.ascii("Hello")),
            dc.b([Byte(0xff)]),
            dc.b([Byte(0xff)])
          ]).dialogs,
          2);
    });

    test('==2 with two dialogs on same line', () {
      expect(
          DialogAsm([
            dc.b(BytesAndAscii([
              Bytes.ascii("Hello"),
              Bytes.list([0xff]),
              Bytes.ascii("World"),
              Bytes.list([0xff]),
            ])),
          ]).dialogs,
          2);
    });
  });

  group('parses scene from dialog', () {
    test('simple scene with just text', () {
      var asm = DialogAsm.fromRaw(r'''	dc.b	"Thank you very much!"
	dc.b	$FC
	dc.b	"I feel much safer now."
	dc.b	$FF''');

      var scene = toScene(0, DialogTree()..add(asm));

      expect(
          scene,
          Scene([
            Dialog(
                spans: DialogSpan.parse('Thank you very much! '
                    'I feel much safer now.'))
          ]));
    });

    test('lines comments are ignored during parsing', () {
      var asm = DialogAsm.fromRaw(r'''	dc.b	"Thank you very much!"
	dc.b	$FC
	; some comment
	dc.b	"I feel much safer now."
	dc.b	$FF''');

      var scene = toScene(0, DialogTree()..add(asm));

      expect(
          scene,
          Scene([
            Dialog(
                spans: DialogSpan.parse('Thank you very much! '
                    'I feel much safer now.'))
          ]));
    });

    test('parses speaker from portrait', () {
      var asm = DialogAsm.fromRaw(r'''	dc.b	$F4, $02	
	dc.b	"Hello world!"
	dc.b	$FF''');

      var scene = toScene(0, DialogTree()..add(asm));

      expect(
          scene,
          Scene([
            Dialog(speaker: alys, spans: DialogSpan.parse('Hello world!'))
          ]));
    });

    test('empty scene', () {
      var asm = DialogAsm.fromRaw(r'''	dc.b	$FF''');

      var scene = toScene(0, DialogTree()..add(asm));

      expect(scene, Scene([]));
    });

    test('continue control code parses to separate dialogs', () {
      var asm = DialogAsm.fromRaw(r'''	dc.b	"Thank you very much!"
	dc.b	$FD
	dc.b	"I feel much safer now."
	dc.b	$FF''');

      var scene = toScene(0, DialogTree()..add(asm));

      expect(
          scene,
          Scene([
            Dialog(spans: DialogSpan.parse('Thank you very much!')),
            Dialog(spans: DialogSpan.parse('I feel much safer now.'))
          ]));
    });

    test('F9 parses pauses in span', () {
      var asm = DialogAsm.fromRaw(r'''	dc.b	"Thank you very much!"
	dc.b	$F9, $3C
	dc.b  $FC
	dc.b	"I feel much safer now."
	dc.b	$FF''');

      var scene = toScene(0, DialogTree()..add(asm));

      expect(
          scene,
          Scene([
            Dialog(spans: [
              DialogSpan('Thank you very much!', pause: 1.second),
              DialogSpan(' I feel much safer now.')
            ]),
          ]));
    });

    test('F9 parses pauses in beginning of span', () {
      var asm = DialogAsm.fromRaw(r'''	dc.b	$F9, $3C
	dc.b	"Thank you very much!"
	dc.b  $FC
	dc.b	"I feel much safer now."
	dc.b	$FF''');

      var scene = toScene(0, DialogTree()..add(asm));

      expect(
          scene,
          Scene([
            Dialog(spans: [
              DialogSpan('', pause: 1.second),
              DialogSpan('Thank you very much! I feel much safer now.')
            ]),
          ]));
    });

    group('with event flag checks', () {
      test('single branch scene', () {
        var asm = DialogAsm.fromRaw(r'''	dc.b	$FA
	dc.b	$0B, $01
	dc.b	"Are you a hunter?"
	dc.b	$FF

	dc.b	"Thank you very much!"
	dc.b	$FC
	dc.b	"I feel much safer now."
	dc.b	$FF''');

        var scene = toScene(0, DialogTree()..addAll(asm.split()));

        expect(
            scene,
            Scene([
              IfFlag(EventFlag('Igglanova'), isSet: [
                Dialog(
                    spans: DialogSpan.parse(
                        'Thank you very much! I feel much safer now.'))
              ], isUnset: [
                Dialog(spans: DialogSpan.parse('Are you a hunter?'))
              ])
            ]));
      });

      test('multi branch scene', () {
        var asm = DialogAsm.fromRaw(r'''; 0
	dc.b	$FA
	dc.b	$DA, $03
	dc.b	$FA
	dc.b	$34, $02
	dc.b	$FA
	dc.b	$0B, $01
	dc.b	"Are you a hunter?"
	dc.b	$FF

; $1
	dc.b	"Thank you very much!"
	dc.b	$FF

; $2
	dc.b	"Thank you again"
	dc.b	$FF

; $3
	dc.b	"What's going to happen now?"
	dc.b	$FF''');

        var scene = toScene(0, DialogTree()..addAll(asm.split()));

        expect(
            scene,
            Scene([
              IfFlag(EventFlag('Reunion'), isSet: [
                Dialog(spans: DialogSpan.parse("What's going to happen now?"))
              ], isUnset: [
                IfFlag(EventFlag('BioPlantEscape'), isSet: [
                  Dialog(spans: DialogSpan.parse('Thank you again'))
                ], isUnset: [
                  IfFlag(EventFlag('Igglanova'), isSet: [
                    Dialog(spans: DialogSpan.parse('Thank you very much!'))
                  ], isUnset: [
                    Dialog(spans: DialogSpan.parse('Are you a hunter?'))
                  ])
                ])
              ]),
            ]));
      });
    });

    group('interactions', () {
      test('starting with f3 do not start with face player', () {
        var asm = DialogAsm.fromRaw(r'''	dc.b	$F3
	dc.b	"Thank you very much!"
	dc.b	$FC
	dc.b	"I feel much safer now."
	dc.b	$FF''');

        var scene =
            toScene(0, DialogTree()..add(asm), isObjectInteraction: true);

        expect(
            scene,
            Scene([
              Dialog(
                  spans: DialogSpan.parse('Thank you very much! '
                      'I feel much safer now.'))
            ]));
      });

      test('starting without f3 start with face player', () {
        var asm = DialogAsm.fromRaw(r'''	dc.b	"Thank you very much!"
	dc.b	$FC
	dc.b	"I feel much safer now."
	dc.b	$FF''');

        var scene =
            toScene(0, DialogTree()..add(asm), isObjectInteraction: true);

        expect(
            scene,
            Scene([
              InteractionObject.facePlayer(),
              Dialog(
                  spans: DialogSpan.parse('Thank you very much! '
                      'I feel much safer now.'))
            ]));
      });

      test('after event checks without f3 start branches with face player', () {
        var asm = DialogAsm.fromRaw(r'''	dc.b	$FA
	dc.b	$08, $01
	dc.b	"Thank you very much!"
	dc.b	$FF
	
	dc.b	"I feel much safer now."
	dc.b	$FF''');

        var scene = toScene(0, asm.splitToTree(), isObjectInteraction: true);

        expect(
            scene,
            Scene([
              IfFlag(EventFlag('AlysFound'), isSet: [
                InteractionObject.facePlayer(),
                Dialog(spans: DialogSpan.parse('I feel much safer now.'))
              ], isUnset: [
                InteractionObject.facePlayer(),
                Dialog(spans: DialogSpan.parse('Thank you very much!'))
              ])
            ]));
      });

      test('after event checks with f3 start branches without face player', () {
        var asm = DialogAsm.fromRaw(r'''	dc.b	$FA
	dc.b	$08, $01
	dc.b	$F3
	dc.b	"Thank you very much!"
	dc.b	$FF

	dc.b	$F3
	dc.b	"I feel much safer now."
	dc.b	$FF''');

        var scene = toScene(0, asm.splitToTree(), isObjectInteraction: true);

        expect(
            scene,
            Scene([
              IfFlag(EventFlag('AlysFound'), isSet: [
                Dialog(spans: DialogSpan.parse('I feel much safer now.'))
              ], isUnset: [
                Dialog(spans: DialogSpan.parse('Thank you very much!'))
              ])
            ]));
      });

      test('after event checks some with and without f3', () {
        var asm = DialogAsm.fromRaw(r'''	dc.b	$FA
	dc.b	$08, $01
	dc.b	$F3
	dc.b	"Thank you very much!"
	dc.b	$FF

	dc.b	"I feel much safer now."
	dc.b	$FF''');

        var scene = toScene(0, asm.splitToTree(), isObjectInteraction: true);

        expect(
            scene,
            Scene([
              IfFlag(EventFlag('AlysFound'), isSet: [
                InteractionObject.facePlayer(),
                Dialog(spans: DialogSpan.parse('I feel much safer now.'))
              ], isUnset: [
                Dialog(spans: DialogSpan.parse('Thank you very much!'))
              ])
            ]));
      });
    });
  });
}
