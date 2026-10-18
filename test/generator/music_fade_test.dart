import 'package:rune/asm/asm.dart';
import 'package:rune/generator/dialog.dart';
import 'package:rune/generator/event.dart';
import 'package:rune/generator/generator.dart';
import 'package:rune/generator/memory.dart';
import 'package:rune/model/model.dart';
import 'package:test/test.dart';

void main() {
  Asm generate(List<Event> events) {
    var program = Program();
    return program
        .addScene(SceneId('MusicFade'), Scene(events),
            startingMap: GameMap(MapId.Test))
        .event
        .withoutComments();
  }

  test('fade speeds validate and affect event identity/dialogue support', () {
    expect(StopMusic(), StopMusic());
    expect(StopMusic(fadeSpeed: 2), StopMusic(fadeSpeed: 2));
    expect(StopMusic(fadeSpeed: 2), isNot(StopMusic()));
    expect(StopMusic(fadeSpeed: 2), isNot(StopMusic(fadeSpeed: 3)));
    expect(StopMusic().canRunInDialog(), isTrue);
    expect(StopMusic(fadeSpeed: 2).canRunInDialog(), isFalse);
    expect(DialogEvent.fromEvent(StopMusic(fadeSpeed: 2), Memory()), isNull);
    for (var speed in [0, -1, 128]) {
      expect(() => StopMusic(fadeSpeed: speed), throwsArgumentError);
    }
    for (var speed in [1, 127]) {
      expect(StopMusic(fadeSpeed: speed).fadeSpeed, speed);
    }
  });

  test('normal stop preserves the sound command and saved music', () {
    expect(
        generate([StopMusic()]),
        Asm([
          move.b(Constant('Sound_StopMusic').i, Constant('Sound_Index').l),
          move.b(
              Constant('Sound_StopMusic').i, Constant('Saved_Sound_Index').w),
        ]));
  });

  test('slow stop posts its request without queuing the short stop', () {
    expect(
        generate([StopMusic(fadeSpeed: 2)]),
        Asm([
          move.b(2.i, Constant('Sound_SlowFade').l),
          move.b(
              Constant('Sound_StopMusic').i, Constant('Saved_Sound_Index').w),
        ]));
  });

  test('wait checks queued stops and fade state before advancing a frame', () {
    var asm = generate([
      SetContext((state) => state.isFieldShown = false),
      StopMusic(),
      const WaitForMusicFade(),
      PlayMusic(Music.krupNight),
    ]);
    var loop = Label('.wait_music_fade2');
    var check = Label('.check_music_fade2');
    expect(
        asm,
        Asm([
          move.b(Constant('Sound_StopMusic').i, Constant('Sound_Index').l),
          move.b(
              Constant('Sound_StopMusic').i, Constant('Saved_Sound_Index').w),
          bra.s(check),
          label(loop),
          jsr(Label('VInt_Prepare').l),
          label(check),
          cmpi.b(Constant('Sound_StopMusic').i, Constant('Sound_Index').l),
          beq.s(loop),
          tst.b(Constant('Sound_SlowFade').l),
          bne.s(loop),
          tst.b(Longword(0xFF5004).l),
          bne.s(loop),
          move.b(Constant('MusicID_KrupNight').i, Constant('Sound_Index').l),
          move.b(
              Constant('MusicID_KrupNight').i, Constant('Saved_Sound_Index').w),
          jsr(Label('Pal_FadeIn').l),
        ]));
  });

  test('standalone waits can return without advancing a frame', () {
    var asm = generate([const WaitForMusicFade()]);
    expect(asm.first, bra.s(Label('.check_music_fade1')).first);
    expect(
        asm.toString(), contains('cmpi.b\t#Sound_StopMusic, (Sound_Index).l'));
  });

  test('intervening non-waiting events retain the queued-stop check', () {
    var asm = generate([
      StopMusic(),
      SetFlag(EventFlag('MusicFadeRequested')),
      const WaitForMusicFade(),
    ]).toString();
    var queuedStopCheck =
        asm.indexOf('cmpi.b\t#Sound_StopMusic, (Sound_Index).l');
    expect(queuedStopCheck, greaterThan(asm.indexOf('EventFlags_Set')));
    expect(queuedStopCheck, lessThan(asm.indexOf('tst.b\t(Sound_SlowFade).l')));
  });

  test('a queued song is consumed before posting a slow fade', () {
    var asm = generate([
      SetContext((state) => state.isFieldShown = false),
      PlayMusic(Music.herLastBreath),
      StopMusic(fadeSpeed: 3),
    ]).toString();
    expect(asm.indexOf('(VInt_Prepare).l'),
        lessThan(asm.indexOf('(Sound_SlowFade).l')));
    expect(asm, contains('#MusicID_HerLastBreath'));
  });

  test('slow fades and waits promote run-event generation into an event', () {
    for (var event in [StopMusic(fadeSpeed: 2), const WaitForMusicFade()]) {
      var eventAsm = EventAsm.empty();
      var runEventAsm = Asm.empty();
      var generator = SceneAsmGenerator.forRunEvent(SceneId('MusicFade'),
          inMap: GameMap(MapId.Test),
          eventAsm: eventAsm,
          runEventAsm: runEventAsm,
          config: ProgramConfiguration.empty());
      event.visit(generator);
      generator.finish();
      expect(runEventAsm.toString(), contains('Event_Index'));
      expect(runEventAsm.toString(), isNot(contains('Sound_SlowFade')));
      expect(eventAsm.toString(), contains('Sound_SlowFade'));
    }
  });
}
