import 'package:rune/generator/generator.dart';
import 'package:rune/model/model.dart';
import 'package:rune/parser/movement.dart';
import 'package:test/test.dart';

void main() {
  test('parses individual moves', () {
    /*
 	lea	(Character_1).w, a4
	move.w	#$250, d0
	move.w	#$250, d1
	bset	#0, (Char_Move_Flags).w	; don't follow lead character
	jsr	(Event_MoveCharacter).l

	; keep alys ahead, move shay down and behind
	lea	(Character_1).w, a4
	move.w	#$2A0, dest_x_pos(a4)
	move.w	#$250, dest_y_pos(a4)
	lea	(Character_2).w, a4
	move.w	#$280, d0
	move.w	#$250, d1
	bset	#1, (Char_Move_Flags).w
	jsr	(Event_MoveCharacter).l

	; keep alys ahead, move up
	bclr	#1, (Char_Move_Flags).w
	lea	(Character_1).w, a4
	move.w	#$2A0, dest_x_pos(a4)
	move.w	#$1A0, dest_y_pos(a4)
	lea	(Character_2).w, a4
	move.w	#$2A0, d0
	move.w	#$230, d1
	jsr	(Event_MoveCharacter).l

	; alys move to dresser, shay stops
	lea	(Character_1).w, a4
	move.w	#$2A0, d0
	move.w	#$1D0, d1
	jsr	(Event_MoveCharacter).l
	bset	#2, (Char_Move_Flags).w	; lock camera
	move.w	#$2A0, d0
	move.w	#$190, d1
	jsr	(Event_MoveCharacter).l
	moveq	#4, d0
	jsr	(Event_UpdateObjFacing).l
     */

    var events = parseEvent(r'''Alys starts at #230, #250
Shay starts at #230, #240
Alys is in slot 1
Shay is in slot 2
Alys walks 17 steps left, 11 steps up, 4 steps right, 1 step up
After 2 steps, Shay walks 2 steps down, 14 steps left, and faces up
After 1 step, Shay walks 6 steps up''');

    var scene = Scene([events]);
    var generator = AsmGenerator();

    print(generator.sceneToAsm(scene));
  });

  test('parses party move', () {
    var events = parseEvent(r'''Alys starts at #230, #250
Shay starts at #230, #240
Alys is in slot 1
Shay is in slot 2
The party moves 3 steps right.''');

    var scene = Scene([events]);
    var generator = AsmGenerator();

    print(generator.sceneToAsm(scene));
  });
}
