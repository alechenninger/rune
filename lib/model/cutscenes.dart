import 'package:quiver/check.dart';

import 'model.dart';

class ShowPanel extends Event {
  final Panel panel;
  final Portrait? portrait;
  final bool showDialogBox;

  const ShowPanel(this.panel, {bool showDialogBox = false, this.portrait})
      : showDialogBox = showDialogBox || portrait != null;

  @override
  void visit(EventVisitor visitor) {
    visitor.showPanel(this);
  }

  @override
  String toString() {
    return 'ShowPanel{panel: $panel, speaker: $portrait}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShowPanel &&
          runtimeType == other.runtimeType &&
          panel == other.panel &&
          portrait == other.portrait;

  @override
  int get hashCode => panel.hashCode ^ portrait.hashCode;
}

class HideTopPanels extends Event {
  final int panelsToHide;
  final bool instantly;

  const HideTopPanels([this.panelsToHide = 1]) : instantly = false;

  const HideTopPanels.instantly([this.panelsToHide = 1]) : instantly = true;

  @override
  void visit(EventVisitor visitor) {
    visitor.hideTopPanels(this);
  }

  @override
  String toString() {
    return 'HideTopPanels{panelsToRemove: $panelsToHide}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HideTopPanels &&
          runtimeType == other.runtimeType &&
          panelsToHide == other.panelsToHide;

  @override
  int get hashCode => panelsToHide.hashCode;
}

class HideAllPanels extends Event {
  final bool instantly;

  const HideAllPanels({this.instantly = false});

  @override
  void visit(EventVisitor visitor) {
    visitor.hideAllPanels(this);
  }

  @override
  String toString() {
    return 'HideAllPanels{}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HideAllPanels && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

sealed class FadeOutSpeed {
  const FadeOutSpeed();
}

class VariableSpeed extends FadeOutSpeed {
  final int value;

  VariableSpeed(this.value) {
    checkArgument(value >= 0, message: 'speed must be >= 0');
  }

  @override
  String toString() => 'VariableSpeed{$value}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariableSpeed &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class Instantly extends FadeOutSpeed {
  const Instantly();
  @override
  String toString() => 'Instantly';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Instantly && runtimeType == other.runtimeType;
  @override
  int get hashCode => toString().hashCode;
}

class Normal extends FadeOutSpeed {
  const Normal();
  @override
  String toString() => 'Normal';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Normal && runtimeType == other.runtimeType;
  @override
  int get hashCode => toString().hashCode;
}

class FadeOut extends Event {
  final FadeOutSpeed speed;

  const FadeOut() : speed = const Normal();

  FadeOut.withSpeed(int speed) : speed = VariableSpeed(speed);

  const FadeOut.instantly() : speed = const Instantly();

  @override
  void visit(EventVisitor visitor) {
    visitor.fadeOut(this);
  }

  @override
  String toString() {
    return 'FadeOutField{$speed}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FadeOut &&
          runtimeType == other.runtimeType &&
          speed == other.speed;

  @override
  int get hashCode => speed.hashCode;
}

class FadeInField extends Event {
  final bool instantly;

  const FadeInField({this.instantly = false});

  @override
  void visit(EventVisitor visitor) {
    visitor.fadeInField(this);
  }

  @override
  String toString() {
    return 'FadeInField{}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FadeInField &&
          runtimeType == other.runtimeType &&
          instantly == other.instantly;

  @override
  int get hashCode => instantly.hashCode ^ runtimeType.hashCode;
}

sealed class Panel {}

// See _panelData for generation
final allPanels = <Panel>[
  ...PrincipalPanel.values,
  ...MeetingHahnPanel.values,
  ...BirthValleyPanel.values,
  ...MolcumPanel.values,
];

enum PrincipalPanel implements Panel {
  principal,
  shayAndAlys,
  xanafalgue,
  principalScared,
  alysGrabsPrincipal,
  zio,
  manTurnedToStone,
  alysWhispersToHahn,
}

enum MeetingHahnPanel implements Panel {
  hahn,
  hahnSweatsBeforeAlys,
}

enum BirthValleyPanel implements Panel {
  holtPetrifiedBeforeHahn,
  holtPetrifiedPortrait,
  hahnDarkEyes,
  alysEyesAndShay,
  alysFingerUp,
  hahnEmotional,
}

enum MolcumPanel implements Panel {
  rune,
  runeCloseUp,
  shayAndRune,
  alysSurprised,
  alysSlightlyEmbarrassed,
}

class PanelByIndex implements Panel {
  final int index;

  PanelByIndex(this.index);
}
