import 'dart:core';

import 'package:quiver/check.dart';
import 'package:rune/generator/generator.dart';

import 'model.dart';

class AsmEvent implements Event {
  final Asm asm;

  /// If assembly must run in an event. Otherwise it may be triggered before
  /// first field updates (transitions, object updates, tiles, map updates, and
  /// vint).
  final bool requireEvent;

  AsmEvent(this.asm, {this.requireEvent = false});

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    // raw asm a bit fragile! ctx not updated
    return asm;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsmEvent && runtimeType == other.runtimeType && asm == other.asm;

  @override
  int get hashCode => asm.hashCode;

  @override
  void visit(EventVisitor visitor) {
    visitor.asm(this);
  }
}

class DialogCodes extends Event implements RunnableInDialog {
  final Bytes codes;

  DialogCodes(this.codes);

  @override
  bool canRunInDialog([EventState? state]) => true;

  @override
  void visit(EventVisitor visitor) {
    visitor.dialogCodes(this);
  }

  @override
  String toString() {
    return 'DialogCodes{codes: $codes}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DialogCodes &&
          runtimeType == other.runtimeType &&
          codes == other.codes;

  @override
  int get hashCode => codes.hashCode;
}

// todo: this event is not like the others, and routinely causes some issues
class SetContext extends Event {
  final void Function(EventState ctx) _setCtx;

  SetContext(this._setCtx);

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    _setCtx(ctx.state);
    return Asm.empty();
  }

  void call(EventState state) {
    _setCtx(state);
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.setContext(this);
  }

  @override
  String toString() {
    // todo: detect if mirrors avail and output source?
    return 'SetContext{$_setCtx}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetContext &&
          runtimeType == other.runtimeType &&
          _setCtx == other._setCtx;

  @override
  int get hashCode => _setCtx.hashCode;
}

class Pause extends Event implements RunnableInDialog {
  final Duration duration;

  /// Whether or not to pause with the dialog window up, or not.
  ///
  /// If `null`, will use either depending on surrounding events.
  final bool? duringDialog;
  final bool runObjects;

  Pause(this.duration, {this.duringDialog = false, this.runObjects = false}) {
    checkArgument(!(runObjects && duringDialog == true),
        message: "Cannot run objects while pausing during dialog.");
  }

  Dialog asDialogEvent() {
    if (runObjects) {
      throw StateError("Cannot convert to dialog event if running objects.");
    }
    return Dialog(spans: [DialogSpan("", pause: duration)]);
  }

  @override
  bool canRunInDialog([EventState? state]) =>
      duringDialog != false && !runObjects;

  Pause inDialog() =>
      Pause(duration, duringDialog: true, runObjects: runObjects);

  @override
  Asm generateAsm(AsmGenerator generator, AsmContext ctx) {
    return generator.pauseToAsm(this);
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.pause(this);
  }

  @override
  String toString() {
    return 'Pause{$duration, '
        'duringDialog: $duringDialog, '
        'runObjects: $runObjects}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pause &&
          runtimeType == other.runtimeType &&
          duration == other.duration &&
          duringDialog == other.duringDialog &&
          runObjects == other.runObjects;

  @override
  int get hashCode => duration.hashCode ^ duringDialog.hashCode;
}

/// Resets palettes and other state for showing the map.
class PrepareMap extends Event {
  final bool refreshObjects;

  PrepareMap({this.refreshObjects = false});

  @override
  void visit(EventVisitor visitor) {
    visitor.prepareMap(this);
  }

  @override
  String toString() {
    return 'PrepareMap{resetObjects: $refreshObjects}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrepareMap &&
          runtimeType == other.runtimeType &&
          refreshObjects == other.refreshObjects;

  @override
  int get hashCode => refreshObjects.hashCode;
}

class LoadMap extends Event {
  // todo: should not be map, should be map id
  //   map might not actually even be in the same game model
  final GameMap map;
  final Position startingPosition;
  final Direction facing;
  final PartyArrangement arrangement;
  final PartyEvent? updateParty;

  /// This controls whether the field stays faded (`false`),
  /// allowing a fade in event,
  /// or if this event should immediately render the updated field (`true`).
  final bool showField;

  final bool refreshObjects;

  LoadMap(
      {required this.map,
      required this.startingPosition,
      required this.facing,
      PartyArrangement? arrangement,
      this.updateParty,
      this.showField = false,
      this.refreshObjects = true})
      : arrangement = arrangement ?? PartyArrangement.overlapping;

  @override
  void visit(EventVisitor visitor) {
    visitor.loadMap(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadMap &&
          runtimeType == other.runtimeType &&
          map == other.map &&
          showField == other.showField &&
          startingPosition == other.startingPosition &&
          facing == other.facing &&
          arrangement == other.arrangement &&
          updateParty == other.updateParty &&
          refreshObjects == other.refreshObjects;

  @override
  int get hashCode =>
      map.hashCode ^
      showField.hashCode ^
      startingPosition.hashCode ^
      facing.hashCode ^
      arrangement.hashCode ^
      updateParty.hashCode ^
      refreshObjects.hashCode;

  @override
  String toString() {
    return 'LoadMap{map: $map, '
        'startingPosition: $startingPosition, '
        'facing: $facing, '
        'arrangement: $arrangement, '
        'updateParty: $updateParty, '
        'showField: $showField, '
        'refreshObjects: $refreshObjects}';
  }
}

class AddMoney extends Event {
  /// May be negative.
  final int meseta;

  AddMoney(this.meseta);

  @override
  void visit(EventVisitor visitor) {
    visitor.addMoney(this);
  }

  @override
  String toString() {
    return 'AddMoney{meseta: $meseta}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddMoney &&
          runtimeType == other.runtimeType &&
          meseta == other.meseta;

  @override
  int get hashCode => meseta.hashCode;
}

/// Returns control to the player early, exiting the current scene.
///
/// This performs all necessary cleanup (hiding panels, fading in field,
/// unlocking camera, resetting step speed) based on the current game mode.
///
/// When used inside a conditional branch (IfFlag, IfValue), only that branch
/// is terminated; other branches and subsequent events outside the conditional
/// are unaffected.
class ReturnControl extends Event {
  const ReturnControl();

  @override
  void visit(EventVisitor visitor) {
    visitor.returnControl(this);
  }

  @override
  String toString() => 'ReturnControl{}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ReturnControl;

  @override
  int get hashCode => runtimeType.hashCode;
}
