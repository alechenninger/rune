import '../model/cutscenes.dart';

final _panelData = [
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
    var i = _panelData.indexOf(this);
    if (i < 0) {
      throw UnimplementedError('no panel data for $this');
    }
    return i;
  }
}
