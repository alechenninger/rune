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

  const HideTopPanels([this.panelsToHide = 1]);

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
  const HideAllPanels();

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

class FadeOut extends Event {
  const FadeOut();

  @override
  void visit(EventVisitor visitor) {
    visitor.fadeOut(this);
  }

  @override
  String toString() {
    return 'FadeOutField{}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FadeOut && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

class FadeInField extends Event {
  const FadeInField();

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
      other is FadeInField && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
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
