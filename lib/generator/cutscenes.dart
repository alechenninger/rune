import '../model/cutscenes.dart';

final _panelData = <Panel>[
  PrincipalPanel.principal,
  PrincipalPanel.shayAndAlys,
  PrincipalPanel.xanafalgue,
  PrincipalPanel.principalScared,
  MeetingHahnPanel.hahn,
  MeetingHahnPanel.hahnSweatsBeforeAlys,
  PrincipalPanel.alysGrabsPrincipal,
  PrincipalPanel.zio,
  PrincipalPanel.manTurnedToStone,
  PrincipalPanel.alysWhispersToHahn,
  BirthValleyPanel.holtPetrifiedBeforeHahn,
  BirthValleyPanel.holtPetrifiedPortrait,
  BirthValleyPanel.hahnDarkEyes,
  BirthValleyPanel.alysEyesAndShay,
  BirthValleyPanel.alysFingerUp,
  BirthValleyPanel.hahnEmotional,
  MolcumPanel.rune,
  MolcumPanel.runeCloseUp,
  MolcumPanel.shayAndRune,
  MolcumPanel.alysSurprised,
  MolcumPanel.alysSlightlyEmbarrassed,
];

extension PanelIndex on Panel {
  int get panelIndex {
    var self = this;

    if (self is PanelByIndex) {
      return self.index;
    }

    var i = _panelData.indexOf(self);
    if (i < 0) {
      throw UnimplementedError('no panel data for $self');
    }
    return i;
  }
}
