import 'package:rune/generator/generator.dart';
import 'package:rune/generator/labels.dart';
import 'package:rune/generator/text.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('generates asm for group 2 events which span multiple group 1 events',
      () {
    var g1 = TextGroup();
    var g2 = TextGroup();
    var fadeIn1 = g1.addBlock()
      // g0, b0, e0, t0
      ..addEvent(PaletteEvent(FadeState.fadeIn, Duration(seconds: 1)))
      // g0, b0, e1, t1
      ..addEvent(PaletteEvent(FadeState.wait, Duration(seconds: 1)))
      // g0, b0, e2, t2
      ..addEvent(PaletteEvent(FadeState.fadeOut, Duration(seconds: 1)));
    var fadeIn3 = g1.addBlock()
      // g0, b1, e0, t3
      ..addEvent(PaletteEvent(FadeState.fadeIn, Duration(seconds: 1)))
      // g0, b1, e1, t4
      ..addEvent(PaletteEvent(FadeState.fadeOut, Duration(seconds: 1)));
    var fade4 = g1.addBlock()
      // g0, b2, e0, t5
      ..addEvent(PaletteEvent(FadeState.fadeIn, Duration(milliseconds: 500)))
      // g0, b2, e1, t5.5
      ..addEvent(PaletteEvent(FadeState.wait, Duration(milliseconds: 500)))
      // g0, b2, e2, t6
      ..addEvent(PaletteEvent(FadeState.fadeOut, Duration(milliseconds: 500)))
      // g0, b2, e3, t6.5
      ..addEvent(PaletteEvent(FadeState.fadeIn, Duration(seconds: 1)))
      // g0, b2, e4, t7.5
      ..addEvent(PaletteEvent(FadeState.fadeOut, Duration(seconds: 1)));
    var fadeIn2 = g2.addBlock()
      // g1, b0, e0, t0
      ..addEvent(PaletteEvent(FadeState.fadeIn, Duration(seconds: 3)))
      // g1, b0, e1, t3
      ..addEvent(PaletteEvent(FadeState.fadeOut, Duration(seconds: 3)));
    var fadeIn5 = g2.addBlock()
      // g1, b1, e0, t6
      ..addEvent(PaletteEvent(FadeState.fadeIn, Duration(seconds: 2)))
      // g1, b1, e1, t8
      ..addEvent(PaletteEvent(FadeState.fadeOut, Duration(seconds: 2)));
    var dialog = DialogTree();
    var asm = displayTextToAsm(
        DisplayText(
            column: TextColumn(vAlign: VerticalAlignment.center, texts: [
          Text(spans: Span.parse('Hello world! '), groupSet: fadeIn1),
          Text(spans: Span.parse('Bye! '), groupSet: fadeIn2),
          Text(spans: Span.parse('Hi again! '), groupSet: fadeIn3),
          Text(
              spans: Span.parse('This fading _business_ is really something. '),
              groupSet: fade4),
          Text(spans: Span.parse("I'll say!"), groupSet: fadeIn5),
          Text(spans: Span.parse('This is even wackier'), groupSet: fadeIn1),
        ])),
        dialog,
        labeller: Labeller.localTo('test').withContext('0'));

    print(asm);
    print(dialog);

    expect(
        asm.event, Asm.fromRaw(r'''        clr.w   (Palette_Table_Buffer+$5E).w

        move.b  #$00, d0
        jsr     (GetDialogueByID).l
        lea     ($FFFF8480).l, a1
        move.w  #$4200, d3
        moveq   #1, d4
        jsr     (RunText2).l
        jsr     (VInt_Prepare).l

        move.b  #$06, d0
        jsr     (GetDialogueByID).l
        lea     ($FFFF8780).l, a1
        move.w  #$4240, d3
        moveq   #1, d4
        jsr     (RunText2).l
        jsr     (VInt_Prepare).l

        clr.w   (Palette_Table_Buffer+$7E).w

        move.b  #$01, d0
        jsr     (GetDialogueByID).l
        lea     ($FFFF849A).l, a1
        move.w  #$6280, d3
        moveq   #1, d4
        jsr     (RunText2).l
        jsr     (DMAPlane_A_VInt).l

        moveq   #$3D, d0
.0_fadeloop_t0:
        bsr     .0_group0_block0_event0
        bsr     .0_group1_block0_event0
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t0

        moveq   #$3D, d0
.0_fadeloop_t1000:
        bsr     .0_group1_block0_event0
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t1000

        moveq   #$3D, d0
.0_fadeloop_t2000:
        bsr     .0_group0_block0_event2
        bsr     .0_group1_block0_event0
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t2000

        ; clear previous text in plane A buffer
        lea     ($FFFF8480).w, a0
        move.w  #$000C, d7
        trap    #0
        lea     ($FFFF8500).w, a0
        move.w  #$000C, d7
        trap    #0
        lea     ($FFFF8780).w, a0
        move.w  #$001F, d7
        trap    #0
        lea     ($FFFF8800).w, a0
        move.w  #$001F, d7
        trap    #0

        move.b  #$02, d0
        jsr     (GetDialogueByID).l
        lea     ($FFFF84A4).l, a1
        move.w  #$4200, d3
        moveq   #1, d4
        jsr     (RunText2).l
        jsr     (DMAPlane_A_VInt).l

        moveq   #$3D, d0
.0_fadeloop_t3000:
        bsr     .0_group0_block1_event0
        bsr     .0_group1_block0_event1
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t3000

        moveq   #$3D, d0
.0_fadeloop_t4000:
        bsr     .0_group0_block1_event1
        bsr     .0_group1_block0_event1
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t4000

        ; clear previous text in plane A buffer
        lea     ($FFFF84A4).w, a0
        move.w  #$001F, d7
        trap    #0
        lea     ($FFFF8524).w, a0
        move.w  #$001F, d7
        trap    #0

        move.b  #$03, d0
        jsr     (GetDialogueByID).l
        lea     ($FFFF84B8).l, a1
        move.w  #$4200, d3
        moveq   #1, d4
        jsr     (RunText2).l
        jsr     (VInt_Prepare).l

        move.b  #$04, d0
        jsr     (GetDialogueByID).l
        lea     ($FFFF8600).l, a1
        move.w  #$4240, d3
        moveq   #1, d4
        jsr     (RunText2).l
        jsr     (DMAPlane_A_VInt).l

        moveq   #$1F, d0
.0_fadeloop_t5000:
        bsr     .0_group0_block2_event0
        bsr     .0_group1_block0_event1
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t5000

        moveq   #$1F, d0
.0_fadeloop_t5500:
        bsr     .0_group1_block0_event1
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t5500

        ; clear previous text in plane A buffer
        lea     ($FFFF849A).w, a0
        move.w  #$0004, d7
        trap    #0
        lea     ($FFFF851A).w, a0
        move.w  #$0004, d7
        trap    #0

        move.b  #$05, d0
        jsr     (GetDialogueByID).l
        lea     ($FFFF863C).l, a1
        move.w  #$6280, d3
        moveq   #1, d4
        jsr     (RunText2).l
        jsr     (DMAPlane_A_VInt).l

        moveq   #$1F, d0
.0_fadeloop_t6000:
        bsr     .0_group0_block2_event2
        bsr     .0_group1_block1_event0
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t6000

        moveq   #$3D, d0
.0_fadeloop_t6500:
        bsr     .0_group0_block2_event3
        bsr     .0_group1_block1_event0
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t6500

        moveq   #$1F, d0
.0_fadeloop_t7500:
        bsr     .0_group0_block2_event4
        bsr     .0_group1_block1_event0
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t7500

        moveq   #$1F, d0
.0_fadeloop_t8000:
        bsr     .0_group0_block2_event4
        bsr     .0_group1_block1_event1
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t8000

        ; clear previous text in plane A buffer
        lea     ($FFFF84B8).w, a0
        move.w  #$001F, d7
        trap    #0
        lea     ($FFFF8538).w, a0
        move.w  #$001F, d7
        trap    #0
        lea     ($FFFF8600).w, a0
        move.w  #$001D, d7
        trap    #0
        lea     ($FFFF8680).w, a0
        move.w  #$001D, d7
        trap    #0

        jsr     (DMA_PlaneA).l

        moveq   #$5B, d0
.0_fadeloop_t8500:
        bsr     .0_group1_block1_event1
        jsr     (VInt_Prepare).l
        dbf     d0, .0_fadeloop_t8500

        ; clear previous text in plane A buffer
        lea     ($FFFF863C).w, a0
        move.w  #$001F, d7
        trap    #0
        lea     ($FFFF86BC).w, a0
        move.w  #$001F, d7
        trap    #0

        jsr     (DMA_PlaneA).l

        bra     .0_done

.0_group0_block0_event0:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$0007, d1
        bne.s   .0_group0_block0_event0_ret
        lea     (Palette_Table_Buffer+$5E).w, a0
        move.w  (A0), d1
        addi.w  #$0222, d1
        btst    #12, d1
        bne.s   .0_group0_block0_event0_ret
        move.w  d1, (A0)
.0_group0_block0_event0_ret
        rts

.0_group1_block0_event0:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$001F, d1
        bne.s   .0_group1_block0_event0_ret
        lea     (Palette_Table_Buffer+$7E).w, a0
        move.w  (A0), d1
        addi.w  #$0222, d1
        btst    #12, d1
        bne.s   .0_group1_block0_event0_ret
        move.w  d1, (A0)
.0_group1_block0_event0_ret
        rts

.0_group0_block0_event2:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$0007, d1
        bne.s   .0_group0_block0_event2_ret
        lea     (Palette_Table_Buffer+$5E).w, a0
        move.w  (A0), d1
        tst.w   d1
        beq.s   .0_group0_block0_event2_ret
        subi.w  #$0222, d1
        move.w  d1, (A0)
.0_group0_block0_event2_ret
        rts

.0_group0_block1_event0:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$0007, d1
        bne.s   .0_group0_block1_event0_ret
        lea     (Palette_Table_Buffer+$5E).w, a0
        move.w  (A0), d1
        addi.w  #$0222, d1
        btst    #12, d1
        bne.s   .0_group0_block1_event0_ret
        move.w  d1, (A0)
.0_group0_block1_event0_ret
        rts

.0_group1_block0_event1:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$001F, d1
        bne.s   .0_group1_block0_event1_ret
        lea     (Palette_Table_Buffer+$7E).w, a0
        move.w  (A0), d1
        tst.w   d1
        beq.s   .0_group1_block0_event1_ret
        subi.w  #$0222, d1
        move.w  d1, (A0)
.0_group1_block0_event1_ret
        rts

.0_group0_block1_event1:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$0007, d1
        bne.s   .0_group0_block1_event1_ret
        lea     (Palette_Table_Buffer+$5E).w, a0
        move.w  (A0), d1
        tst.w   d1
        beq.s   .0_group0_block1_event1_ret
        subi.w  #$0222, d1
        move.w  d1, (A0)
.0_group0_block1_event1_ret
        rts

.0_group0_block2_event0:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$0003, d1
        bne.s   .0_group0_block2_event0_ret
        lea     (Palette_Table_Buffer+$5E).w, a0
        move.w  (A0), d1
        addi.w  #$0222, d1
        btst    #12, d1
        bne.s   .0_group0_block2_event0_ret
        move.w  d1, (A0)
.0_group0_block2_event0_ret
        rts

.0_group0_block2_event2:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$0003, d1
        bne.s   .0_group0_block2_event2_ret
        lea     (Palette_Table_Buffer+$5E).w, a0
        move.w  (A0), d1
        tst.w   d1
        beq.s   .0_group0_block2_event2_ret
        subi.w  #$0222, d1
        move.w  d1, (A0)
.0_group0_block2_event2_ret
        rts

.0_group1_block1_event0:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$000F, d1
        bne.s   .0_group1_block1_event0_ret
        lea     (Palette_Table_Buffer+$7E).w, a0
        move.w  (A0), d1
        addi.w  #$0222, d1
        btst    #12, d1
        bne.s   .0_group1_block1_event0_ret
        move.w  d1, (A0)
.0_group1_block1_event0_ret
        rts

.0_group0_block2_event3:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$0007, d1
        bne.s   .0_group0_block2_event3_ret
        lea     (Palette_Table_Buffer+$5E).w, a0
        move.w  (A0), d1
        addi.w  #$0222, d1
        btst    #12, d1
        bne.s   .0_group0_block2_event3_ret
        move.w  d1, (A0)
.0_group0_block2_event3_ret
        rts

.0_group0_block2_event4:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$0007, d1
        bne.s   .0_group0_block2_event4_ret
        lea     (Palette_Table_Buffer+$5E).w, a0
        move.w  (A0), d1
        tst.w   d1
        beq.s   .0_group0_block2_event4_ret
        subi.w  #$0222, d1
        move.w  d1, (A0)
.0_group0_block2_event4_ret
        rts

.0_group1_block1_event1:
        move.b  (Main_Frame_Count+1).w, d1
        andi.w  #$000F, d1
        bne.s   .0_group1_block1_event1_ret
        lea     (Palette_Table_Buffer+$7E).w, a0
        move.w  (A0), d1
        tst.w   d1
        beq.s   .0_group1_block1_event1_ret
        subi.w  #$0222, d1
        move.w  d1, (A0)
.0_group1_block1_event1_ret
        rts

.0_done:'''));
  });

  test(
      'drawing to vram and mapping plane at new location does not show phantom text',
      () {
    // need to get 2 texts to load simultaneously
    // and then after, one loads which goes past
    var g1 = TextGroup();
    var g2 = TextGroup();
    var g1s1 = g1.addBlock()
      ..addEvent(fadeIn(Duration(seconds: 1)))
      ..addEvent(fadeOut(Duration(seconds: 1)));
    var g1s2 = g1.addBlock()
      ..addEvent(fadeIn(Duration(seconds: 1)))
      ..addEvent(fadeOut(Duration(seconds: 1)));
    var g2s1 = g2.addBlock()
      ..addEvent(fadeIn(Duration(seconds: 1)))
      ..addEvent(fadeOut(Duration(seconds: 1)));

    var display = DisplayText(
        column: TextColumn(texts: [
      Text(spans: [Span('hello ')], groupSet: g1s1),
      Text(
          spans: [Span('1234567890abcdefghijklmnopqrstuvwxyz!-– ')],
          groupSet: g2s1),
      Text(spans: Span.parse('world '), groupSet: g1s1),
      Text(
          spans: [Span('1234567890abcdefghijklmnopqrstuvwxyz!-– ')],
          groupSet: g1s2),
    ]));

    var dialog = DialogTree();
    print(displayTextToAsm(display, dialog));
    print(dialog);
  });

  test('demo text', () {
    var g1 = TextGroup(defaultBlack: Word(0x666));
    var g2 = TextGroup(defaultBlack: Word(0x666));

    var riseAndFall = g1.addBlock()
      ..addEvent(fadeIn(Duration(milliseconds: 500)))
      ..addEvent(wait(Duration(seconds: 2)))
      ..addEvent(fadeOut(Duration(milliseconds: 500)));

    var duskAndDawn = g2.addBlock()
      ..addEvent(wait(Duration(seconds: 2, milliseconds: 500)))
      ..addEvent(fadeIn(Duration(milliseconds: 500)))
      ..addEvent(wait(Duration(seconds: 2)))
      ..addEvent(fadeOut(Duration(milliseconds: 500)));

    var begAndEnd = g1.addBlock()
      ..addEvent(wait(Duration(seconds: 2)))
      ..addEvent(fadeIn(Duration(milliseconds: 500)))
      ..addEvent(wait(Duration(seconds: 4, milliseconds: 500)))
      ..addEvent(fadeOut(Duration(milliseconds: 500)));

    var ofMillen = g2.addBlock()
      ..addEvent(wait(Duration(seconds: 2)))
      ..addEvent(fadeIn(Duration(milliseconds: 500)))
      ..addEvent(wait(Duration(seconds: 2)))
      ..addEvent(fadeOut(Duration(milliseconds: 500)))
      ..addEvent(wait(Duration(seconds: 2)));

    var display = DisplayText(
        // lineOffset: 7,
        lineOffset: 0,
        column: TextColumn(
            vAlign: VerticalAlignment.center,
            hAlign: HorizontalAlignment.center,
            texts: [
              Text(
                  spans: [Span('The rise and fall.')],
                  groupSet: riseAndFall,
                  lineBreak: true),
              Text(
                  spans: [Span('The dusk and dawn.')],
                  groupSet: duskAndDawn,
                  lineBreak: true),
              Text(
                  spans: [Span('The beginning and the end...')],
                  groupSet: begAndEnd,
                  lineBreak: true),
              Text(spans: [Span('of the millennium.')], groupSet: ofMillen),
            ]));

    var tree = DialogTree();
    print(displayTextToAsm(display, tree));
    print(tree);
  });
}
