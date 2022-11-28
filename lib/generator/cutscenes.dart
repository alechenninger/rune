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
