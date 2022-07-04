import 'package:collection/collection.dart';
import 'package:rune/generator/movement.dart';
import 'package:rune/numbers.dart';

import '../asm/asm.dart';
import '../model/model.dart';
import 'generator.dart';

class MapAsm {
  final Asm sprites;
  final Asm objects;
  final Asm dialog;
  final Asm events;
  final Asm cutscenes;
  // might also need dialogTrees ASM
  // if these labels need to be programmatically referred to

  MapAsm({
    required this.sprites,
    required this.objects,
    required this.dialog,
    required this.events,
    required this.cutscenes,
  });

  @override
  String toString() {
    return [
      '; sprites',
      sprites,
      '; objects',
      objects,
      '; dialog',
      dialog,
      '; events',
      events,
      '; cutscenes',
      cutscenes,
    ].join('\n');
  }
}

extension MapToAsm on GameMap {
  MapAsm toAsm(AsmGenerator generator, AsmContext ctx) {
    return mapToAsm(this, generator, ctx);
  }
}

MapAsm mapToAsm(GameMap map, AsmGenerator generator, AsmContext ctx) {
  var spritesAsm = Asm.empty();
  var dialogAsm = Asm.empty();
  var objectsAsm = Asm.empty();
  var eventsAsm = Asm.empty();

  if (map.objects.length > 64) {
    throw Exception('too many objects (limited ram)');
  }

  var vramTileNumbers = _generateSpriteAsm(map, spritesAsm);
  var dialogOffsets =
      _generateDialogAndEventsAsm(map, dialogAsm, eventsAsm, ctx, generator);

  _generateObjectsAsm(map, objectsAsm, vramTileNumbers, dialogOffsets);

  return MapAsm(
      sprites: spritesAsm,
      objects: objectsAsm,
      dialog: dialogAsm,
      events: eventsAsm,
      cutscenes: Asm.empty());
}

void _generateObjectsAsm(GameMap map, Asm objectsAsm,
    Map<Sprite, Word> vramTileNumbers, List<Byte> dialogOffsets) {
  map.objects.forEachIndexed((i, obj) {
    var spec = obj.spec;

    var facingAndDialog = dc.b([spec.startFacing.constant, dialogOffsets[i]]);

    if (spec is Npc) {
      var routine = _npcBehaviorRoutines[spec.behavior.runtimeType];

      if (routine == null) {
        throw Exception(
            'no routine configured for npc behavior ${spec.behavior}');
      }

      objectsAsm.add(dc.w([routine]));
      objectsAsm.add(facingAndDialog);

      // TODO: i think you can use 0 for invisible / no sprite
      // see Map_ZioFort
      var tileNumber = vramTileNumbers[spec.sprite];
      if (tileNumber == null) {
        throw Exception('no tile number for sprite ${spec.sprite}');
      }

      objectsAsm.add(dc.w([tileNumber]));
    } else {
      var routine = _mapObjectSpecRoutines[spec];

      if (routine == null) {
        throw Exception('no routine configured for spec $spec');
      }

      objectsAsm.add(dc.w([routine]));
      objectsAsm.add(facingAndDialog);
      // in this case we assume the vram tile does not matter?
      // TODO: if it does we need to track so do not reuse same
      // todo: is 0 okay?
      objectsAsm.add(
          // dc.w([vramTileNumbers.values.max() + Word(_vramOffsetPerSprite)]));
          dc.w([0.word]));
    }

    objectsAsm.add(
        dc.w([Word(obj.startPosition.x ~/ 8), Word(obj.startPosition.y ~/ 8)]));

    objectsAsm.addNewline();
  });
}

Map<Sprite, Word> _generateSpriteAsm(GameMap map, Asm spritesAsm) {
  var vramOffset = _spriteVramOffsets[map.id];

  if (vramOffset == null) {
    throw Exception('no offset configured for map: ${map.id}');
  }

  var vramTileNumbers = <Sprite, Word>{};

  map.objects
      .map((e) => e.spec)
      .whereType<Npc>()
      .map((e) => e.sprite)
      .toSet()
      .forEachIndexed((i, sprite) {
    var artLbl = _spriteArtLabels[sprite];

    if (artLbl == null) {
      throw Exception('no art label configured for sprite: $sprite');
    }

    var tileNumber = Word(vramOffset + i * _vramOffsetPerSprite);
    vramTileNumbers[sprite] = tileNumber;

    spritesAsm.add(dc.w([tileNumber]));
    spritesAsm.add(dc.l([artLbl]));
  });

  return vramTileNumbers;
}

List<Byte> _generateDialogAndEventsAsm(GameMap map, Asm dialogAsm,
    Asm eventsAsm, AsmContext ctx, AsmGenerator generator) {
  var dialogOffsets = <Byte>[];
  var tree = DialogTree(offset: Byte(_dialogIdOffsets[map.id] ?? 0));

  ctx.state.currentMap = map;

  // hard coded dialog
  switch (map.id) {
    case MapId.Piata:
      dialogAsm.add(Asm.fromRaw(_piataDialog));
      break;
    default:
    // noop
  }

  for (var obj in map.objects) {
    // todo: handle max
    dialogOffsets.add(tree.nextDialogId!);

    // Interaction always starts with triggering dialog
    ctx.startDialogInteraction();

    var sceneAsm = generator.sceneToAsm(obj.onInteract, ctx,
        dialogTree: tree, id: SceneId("${map.id.name}_${obj.id}"));

    dialogAsm.add(sceneAsm.allDialog);
    eventsAsm.add(sceneAsm.event);
    eventsAsm.addNewline();
  }

  return dialogOffsets;
}

final _vramOffsetPerSprite = '48'.hex;

// These offsets are used to account for assembly specifics, which allows for
// variances in maps to be coded manually (such as objects).
// todo: it might be nice to manage these with the assembly or the compiler
//  itself rather than hard coding here.

final _spriteVramOffsets = {
  MapId.Aiedo: '29A'.hex,
  MapId.Piata: '480'.hex, // Map_Pata, normally 2D0
  MapId.PiataAcademyF1: '27F'.hex, // Map_PiataAcademy_F1
  MapId.PiataAcademyPrincipalOffice: '27F'.hex, // Map_AcademyPrincipalOffice
};

// todo: this would only be used when we have events which refer to objects by
//   their location in memory. we would have to offset that location.
final _objectIndexOffsets = {MapId.PiataAcademyF1: 1, MapId.Piata: 7};

final _dialogIdOffsets = {
  MapId.PiataAcademyF1: 1,
  MapId.Piata: 45,
};

final _spriteArtLabels = {
  Sprite.PalmanMan1: Label('Art_PalmanMan1'),
  Sprite.PalmanMan2: Label('Art_PalmanMan2'),
  Sprite.PalmanWoman1: Label('Art_PalmanWoman1'),
  Sprite.PalmanWoman2: Label('Art_PalmanWoman2'),
};

final _mapObjectSpecRoutines = {AlysWaiting(): Word('68'.hex)};

final _npcBehaviorRoutines = {
  FaceDown: Word('38'.hex), // FieldObj_NPCType1
  WanderAround: Word('3C'.hex) // FieldObj_NPCType2
};

extension ReduceMax<E extends Comparable> on Iterable<E> {
  E max() {
    return reduce(
        (value, element) => value.compareTo(element) > 0 ? value : element);
  }
}

const _piataDialog = r'''
; $40
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"My parents live in Mile, a"
	dc.b	$FC
	dc.b	"village northeast of here."
	dc.b	$FD
	dc.b	"Recently, I haven't been getting"
	dc.b	$FC
	dc.b	"my allowance. I wonder if"
	dc.b	$FD
	dc.b	"they've forgotten me?"
	dc.b	$FD
	dc.b	"Oh well, I better find a job."
	dc.b	$FD
	dc.b	"Becoming a hunter..."
	dc.b	$FC
	dc.b	"now that sounds exciting."
	dc.b	$FF

; $41
	dc.b	"Is it true that the village of"
	dc.b	$FC
	dc.b	"Mile has become a village of"
	dc.b	$FD
	dc.b	"death?"
	dc.b	$FD
	dc.b	"Dad! Mom!"
	dc.b	$FF

; $42
	dc.b	$FA
	dc.b	$DA, $02
	dc.b	$FA
	dc.b	$0C, $01
	dc.b	"Just when it seemed that the"
	dc.b	$FC
	dc.b	"number of monsters was"
	dc.b	$FD
	dc.b	"decreasing, they're now roaming"
	dc.b	$FC
	dc.b	"in the town!"
	dc.b	$FD
	dc.b	"Do you think this is some"
	dc.b	$FC
	dc.b	"kind of omen?"
	dc.b	$FF

; $43
	dc.b	"Apparently, the monsters aren't"
	dc.b	$FC
	dc.b	"appearing in town anymore."
	dc.b	$FD
	dc.b	"Thank goodness for that."
	dc.b	$FF

; $44
	dc.b	"Th...this universe is coming to "
	dc.b	$FC
	dc.b	"an end."
	dc.b	$FF

; $45
	dc.b	$FA
	dc.b	$DA, $02
	dc.b	$FA
	dc.b	$0C, $01
	dc.b	"No monster can get into this"
	dc.b	$FC
	dc.b	"town. The wall surrounding the"
	dc.b	$FD
	dc.b	"town will protect us."
	dc.b	$FD
	dc.b	"That's why I think those strange"
	dc.b	$FC
	dc.b	"monsters must be appearing from"
	dc.b	$FD
	dc.b	"within the town."
	dc.b	$FD
	dc.b	"I think there's something mighty"
	dc.b	$FC
	dc.b	"suspicious about the research"
	dc.b	$FD
	dc.b	"going on at the academy."
	dc.b	$FF

; $46
	dc.b	"I heard those monsters were"
	dc.b	$FC
	dc.b	"conquered by some hunter whose"
	dc.b	$FD
	dc.b	"name I've forgotten."
	dc.b	$FF

; $47
	dc.b	"You say poison is coming out of"
	dc.b	$FC
	dc.b	"the hole?"
	dc.b	$FD
	dc.b	"Hey! Is that true?"
	dc.b	$FF

; $48
	dc.b	$FA
	dc.b	$DA, $02
	dc.b	$FA
	dc.b	$0C, $01
	dc.b	"I saw it! In the middle of the"
	dc.b	$FC
	dc.b	"night, some suspicious-looking"
	dc.b	$FD
	dc.b	"men carried a big parcel into "
	dc.b	$FC
	dc.b	"the academy!"
	dc.b	$FD
	dc.b	"This happened some time ago,"
	dc.b	$FC
	dc.b	"but I wonder what it could've"
	dc.b	$FD
	dc.b	"been!"
	dc.b	$FF

; $49
	dc.b	"Now that I look back,"
	dc.b	$FC
	dc.b	"I wonder if there was some"
	dc.b	$FD
	dc.b	"connection between that parcel"
	dc.b	$FC
	dc.b	"and the monsters?"
	dc.b	$FF

; $4A
	dc.b	"I can't tell what's going on."
	dc.b	$FD
	dc.b	"Only the fact"
	dc.b	$FC
	dc.b	"that there's a hole..."
	dc.b	$FF

; $4B
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"What's with you guys?"
	dc.b	$FD
	dc.b	"You're being way too"
	dc.b	$FC
	dc.b	"friendly!"
	dc.b	$FF

; $4C
	dc.b	"H...heeelp!"
	dc.b	$FF

; $4D
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"I'm studying geology."
	dc.b	$FD
	dc.b	"Recently, the soil quality has"
	dc.b	$FC
	dc.b	"been deteriorating."
	dc.b	$FD
	dc.b	"Crops barely grow on this farm."
	dc.b	$FD
	dc.b	"My boyfriend,in the agricultural"
	dc.b	$FC
	dc.b	"department, is rather upset."
	dc.b	$FF

; $4E
	dc.b	"This can't all be explained"
	dc.b	$FC
	dc.b	"away by saying that the ground"
	dc.b	$FD
	dc.b	"surface suddenly began to sink!"
	dc.b	$FF

; $4F
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"We're still all right here,"
	dc.b	$FC
	dc.b	"but apparently the wells are all"
	dc.b	$FD
	dc.b	"dried up in the village of Mile!"
	dc.b	$FF

; $50
	dc.b	"If Mile is in trouble,"
	dc.b	$FC
	dc.b	"we're going to be in trouble"
	dc.b	$FD
	dc.b	"soon!"
	dc.b	$FF

; $51
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"I heard some students jumped"
	dc.b	$FC
	dc.b	"into this fountain the other"
	dc.b	$FD
	dc.b	"day."
	dc.b	$FD
	dc.b	"I can't believe I missed all"
	dc.b	$FC
	dc.b	"the fun."
	dc.b	$FD
	dc.b	"You should take a dip, it'll"
	dc.b	$FC
	dc.b	"do you good."
	dc.b	$FF

; $52
	dc.b	"Ahhhhhhh!"
	dc.b	$FF

; $53
	dc.b	$FA
	dc.b	$DA, $02
	dc.b	$FA
	dc.b	$0C, $01
	dc.b	"Orders from the principal."
	dc.b	$FC
	dc.b	"I can't allow anyone to pass"
	dc.b	$FD
	dc.b	"beyond this point!"
	dc.b	$FF

; $54
	dc.b	"This is the university town of"
	dc.b	$FC
	dc.b	"Piata."
	dc.b	$FD
	dc.b	"It's a town for students"
	dc.b	$FC
	dc.b	"and academics."
	dc.b	$FF

; $55
	dc.b	"This is the town Piata, but"
	dc.b	$FC
	dc.b	"there's no time for chatter!"
	dc.b	$FD
	dc.b	"To the north, near Mile,"
	dc.b	$FC
	dc.b	"there's a big hole!"
	dc.b	$FF

; $56
	dc.b	$FF

; $57
	dc.b	$FA
	dc.b	$2A, $05
	dc.b	$FA
	dc.b	$27, $03
	dc.b	$FA
	dc.b	$26, $02
	dc.b	$FA
	dc.b	$44, $01
	dc.b	"These are the student dorms"
	dc.b	$FC
	dc.b	"of Motavia Academy."
	dc.b	$FD
	dc.b	"Me? I'm the caretaker."
	dc.b	$FF

; $58
	dc.b	"I thought if I let things"
	dc.b	$FC
	dc.b	"alone, they would eventually"
	dc.b	$FD
	dc.b	"come back, but they still..."
	dc.b	$FD
	dc.b	"Oh, it's nothing,"
	dc.b	$FC
	dc.b	"nothing to do with you!"
	dc.b	$FF

; $59
	dc.b	$F6
	dc.w	$0076	; => Event_PiataDormOwner
	dc.b	$FF

; $5A
	dc.b	"Thank you"
	dc.b	$FC
	dc.b	"for your help in this matter."
	dc.b	$FF

; $5B
	dc.b	"Thank you so much!"
	dc.b	$FD
	dc.b	"Now we can keep up appearances"
	dc.b	$FC
	dc.b	"at this dorm."
	dc.b	$FD
	dc.b	"We shall remit the agreed upon"
	dc.b	$FC
	dc.b	"fee to the guild!"
	dc.b	$FD
	dc.b	"Oh, and also...I would"
	dc.b	$FC
	dc.b	"appreciate it if you could"
	dc.b	$FD
	dc.b	"keep this matter to yourselves."
	dc.b	$FF

; $5C
	dc.b	"Thank you for your assistance."
	dc.b	$FF

; $5D
	dc.b	$FA
	dc.b	$65, $01
	dc.b	"I've got a report due tomorrow,"
	dc.b	$FC
	dc.b	"but I haven't written a word"
	dc.b	$FD
	dc.b	"of it!"
	dc.b	$FF

; $5E
	dc.b	"'Fail'..."
	dc.b	$FD
	dc.b	"I guess it's no wonder"
	dc.b	$FC
	dc.b	"considering that I didn't"
	dc.b	$FD
	dc.b	"get the report in on time..."
	dc.b	$FC
	dc.b	"Boo hoo."
	dc.b	$FF

; $5F
	dc.b	$FA
	dc.b	$DA, $03
	dc.b	$FA
	dc.b	$2A, $02
	dc.b	$FA
	dc.b	$26, $01
	dc.b	"It's so much fun lazing around"
	dc.b	$FC
	dc.b	"than going to class."
	dc.b	$FF

; $60
	dc.b	"The girl in the room next door?"
	dc.b	$FC
	dc.b	"Come to think of it,"
	dc.b	$FD
	dc.b	"I haven't seen her recently."
	dc.b	$FF

; $61
	dc.b	"The girl in the room next door"
	dc.b	$FC
	dc.b	"is back?"
	dc.b	$FD
	dc.b	"I didn't know that."
	dc.b	$FF

; $62
	dc.b	"When it's this crazy,"
	dc.b	$FC
	dc.b	"I want to go to the academy"
	dc.b	$FD
	dc.b	"even less."
	dc.b	$FF

; $63
	dc.b	$FA
	dc.b	$DA, $03
	dc.b	$FA
	dc.b	$2A, $02
	dc.b	$FA
	dc.b	$26, $01
	dc.b	"The girl next door has been"
	dc.b	$FC
	dc.b	"influenced by some strange"
	dc.b	$FD
	dc.b	"religion."
	dc.b	$FD
	dc.b	"She's been missing for a while."
	dc.b	$FC
	dc.b	"Where did she go?"
	dc.b	$FF

; $64
	dc.b	"The girl next door"
	dc.b	$FC
	dc.b	"hasn't come back yet."
	dc.b	$FD
	dc.b	"I wonder where she is"
	dc.b	$FC
	dc.b	"and what she's doing..."
	dc.b	$FF

; $65
	dc.b	"The girl next door"
	dc.b	$FC
	dc.b	"has returned!"
	dc.b	$FD
	dc.b	"It appears she has no memory of"
	dc.b	$FC
	dc.b	"what happened to her while"
	dc.b	$FD
	dc.b	"she was gone..."
	dc.b	$FC
	dc.b	"I'm very concerned."
	dc.b	$FF

; $66
	dc.b	"What did you say happened?"
	dc.b	$FF

; $67
	dc.b	$FA
	dc.b	$DA, $02
	dc.b	$FA
	dc.b	$65, $01
	dc.b	"Hey! I'm undressing!"
	dc.b	$FC
	dc.b	"Get out! Get out!!!"
	dc.b	$FF

; $68
	dc.b	"I'm still getting undressed!"
	dc.b	$FC
	dc.b	"Get out! get out!!!"
	dc.b	$FF

; $69
	dc.b	"I'm getting undressed, you know!"
	dc.b	$FC
	dc.b	"So leave!"
	dc.b	$FF

; $6A
	dc.b	$FA
	dc.b	$DA, $01
	dc.b	"What...have I been"
	dc.b	$FC
	dc.b	"doing all this time...?"
	dc.b	$FD
	dc.b	"When I try to remember what"
	dc.b	$FC
	dc.b	"happened, I get a headache..."
	dc.b	$FF

; $6B
	dc.b	"I have...a terrible headache..."
	dc.b	$FC
	dc.b	"What...is this!?"
	dc.b	$FF

; $6C
	dc.b	"Oh, you're the hunter from the"
	dc.b	$FC
	dc.b	"guild? Pl...please help!"
	dc.b	$FD
	dc.b	"The fact of the matter is that"
	dc.b	$FC
	dc.b	"one of the female students"
	dc.b	$FD
	dc.b	"living here is missing!"
	dc.b	$FD
	dc.b	"Apparently, she has become an"
	dc.b	$FC
	dc.b	"enthusiastic devotee of some"
	dc.b	$FD
	dc.b	"kind of religion and just up"
	dc.b	$FC
	dc.b	"and left."
	dc.b	$FD
	dc.b	"I thought the infatuation would"
	dc.b	$FC
	dc.b	"pass and eventually she'd come"
	dc.b	$FD
	dc.b	"back, but she still hasn't..."
	dc.b	$FD
	dc.b	"I have the terrible"
	dc.b	$FC
	dc.b	"responsibility of being"
	dc.b	$FD
	dc.b	"entrusted with the care of"
	dc.b	$FC
	dc.b	"another's child!"
	dc.b	$FD
	dc.b	"With a blunder like this, even"
	dc.b	$FC
	dc.b	"the academy's reputation could"
	dc.b	$FD
	dc.b	"be tarnished!"
	dc.b	$FD
	dc.b	"Please, could you bring her back"
	dc.b	$FC
	dc.b	"here before things become known"
	dc.b	$FD
	dc.b	"to the public?"
	dc.b	$FD
	dc.b	"I appreciate the trouble"
	dc.b	$FC
	dc.b	"I'm putting you through."
	dc.b	$FF
''';
