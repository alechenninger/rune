import 'model.dart';

class ShowPanel extends Event {
  final Panel panel;

  const ShowPanel(this.panel);

  @override
  void visit(EventVisitor visitor) {
    visitor.showPanel(this);
  }

  @override
  String toString() {
    return 'ShowPanel{$panel}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShowPanel &&
          runtimeType == other.runtimeType &&
          panel == other.panel;

  @override
  int get hashCode => panel.hashCode;
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

class FadeOutField extends Event {
  const FadeOutField();

  @override
  void visit(EventVisitor visitor) {
    visitor.fadeOutField(this);
  }

  @override
  String toString() {
    return 'FadeOutField{}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FadeOutField && runtimeType == other.runtimeType;

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

class Panel {}

final allPanels = <Panel>[
  ...PrincipalPanel.values,
  ...MeetingHahnPanel.values,
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
