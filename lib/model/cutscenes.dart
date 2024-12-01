import 'package:quiver/check.dart';

import 'model.dart';

class ShowPanel extends Event implements RunnableInDialog {
  final Panel panel;
  final Portrait? portrait;
  final bool showDialogBox;
  final bool runMapUpdates;
  final PanelPlane plane;

  ShowPanel(this.panel,
      {bool showDialogBox = false,
      this.portrait,
      this.runMapUpdates = false,
      this.plane = PanelPlane.foreground})
      : showDialogBox = showDialogBox || portrait != null {
    checkArgument(!(showDialogBox && plane == PanelPlane.background),
        message: 'Cannot show dialog box in background');
  }

  ShowPanel inDialog() {
    return ShowPanel(panel,
        showDialogBox: true, portrait: null, runMapUpdates: runMapUpdates);
  }

  @override
  bool canRunInDialog([EventState? state]) =>
      showDialogBox &&
      (portrait == null || state == null || portrait == state.dialogPortrait);

  @override
  void visit(EventVisitor visitor) {
    visitor.showPanel(this);
  }

  @override
  String toString() {
    return 'ShowPanel{panel: $panel, '
        'portrait: $portrait, '
        'showDialogBox: $showDialogBox, '
        'runMapUpdates: $runMapUpdates, '
        'plane: $plane}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShowPanel &&
          runtimeType == other.runtimeType &&
          panel == other.panel &&
          portrait == other.portrait &&
          showDialogBox == other.showDialogBox &&
          runMapUpdates == other.runMapUpdates &&
          plane == other.plane;

  @override
  int get hashCode =>
      panel.hashCode ^
      portrait.hashCode ^
      showDialogBox.hashCode ^
      runMapUpdates.hashCode ^
      plane.hashCode;
}

enum PanelPlane {
  background,
  foreground,
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

sealed class FadeSpeed {
  const FadeSpeed();
}

class VariableSpeed extends FadeSpeed {
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

class Instantly extends FadeSpeed {
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

class Normal extends FadeSpeed {
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
  final FadeSpeed speed;

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
  final FadeSpeed speed;

  const FadeInField({bool instantly = false})
      : speed = instantly ? const Instantly() : const Normal();

  const FadeInField.instantly() : speed = const Instantly();

  FadeInField.withSpeed(int speed) : speed = VariableSpeed(speed);

  @override
  void visit(EventVisitor visitor) {
    visitor.fadeInField(this);
  }

  @override
  String toString() {
    return 'FadeInField{$speed}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FadeInField &&
          runtimeType == other.runtimeType &&
          speed == other.speed;

  @override
  int get hashCode => speed.hashCode ^ runtimeType.hashCode;
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
