import 'model.dart';

class OnExitRunBattle extends Event {
  final int battleIndex;
  // defaults map bgm
  final Sound? postBattleSound;
  final bool postBattleFadeInMap;
  final bool postBattleReloadObjects;

  OnExitRunBattle(
      {required this.battleIndex,
      this.postBattleSound,
      this.postBattleFadeInMap = true,
      this.postBattleReloadObjects = false});

  @override
  void visit(EventVisitor visitor) {
    visitor.onExitRunBattle(this);
  }

  @override
  String toString() {
    return 'SetExitToBattle{battleIndex: $battleIndex, '
        'postBattleMusic: $postBattleSound, '
        'fadeInMap: $postBattleFadeInMap, '
        'reloadObjects: $postBattleReloadObjects}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnExitRunBattle &&
          runtimeType == other.runtimeType &&
          battleIndex == other.battleIndex &&
          postBattleSound == other.postBattleSound &&
          postBattleFadeInMap == other.postBattleFadeInMap &&
          postBattleReloadObjects == other.postBattleReloadObjects;

  @override
  int get hashCode =>
      battleIndex.hashCode ^
      postBattleSound.hashCode ^
      postBattleFadeInMap.hashCode ^
      postBattleReloadObjects.hashCode;
}
