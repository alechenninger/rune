import 'dart:core';

import 'package:rune/generator/generator.dart';

import 'model.dart';

class AsmEvent implements Event {
  final Asm asm;

  AsmEvent(this.asm);

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

class Pause extends Event {
  final Duration duration;

  /// Whether or not to pause with the dialog window up, or not.
  ///
  /// If `null`, will use either depending on surrounding events.
  final bool? duringDialog;

  Pause(this.duration, {this.duringDialog = false});

  Dialog asDialogEvent() {
    return Dialog(spans: [DialogSpan("", pause: duration)]);
  }

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
    return 'Pause{$duration, duringDialog: $duringDialog}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pause &&
          runtimeType == other.runtimeType &&
          duration == other.duration && 
          duringDialog == other.duringDialog;

  @override
  int get hashCode => duration.hashCode ^ duringDialog.hashCode;
}

/// Resets palettes and other state for showing the map.
class PrepareMap extends Event {
  final bool resetObjects;

  PrepareMap({this.resetObjects = false});

  @override
  void visit(EventVisitor visitor) {
    visitor.prepareMap(this);
  }

  @override
  String toString() {
    return 'PrepareMap{resetObjects: $resetObjects}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrepareMap &&
          runtimeType == other.runtimeType &&
          resetObjects == other.resetObjects;

  @override
  int get hashCode => resetObjects.hashCode;
}

class LoadMap extends Event {
  // todo: should not be map, should be map id
  //   map might not actually even be in the same game model
  final GameMap map;
  final Position startingPosition;
  final Direction facing;
  final PartyArrangement arrangement;

  /// This controls whether the field stays faded (`false`),
  /// allowing a fade in event,
  /// or if this event should immediately render the updated field (`true`).
  final bool showField;

  LoadMap(
      {required this.map,
      required this.startingPosition,
      required this.facing,
      PartyArrangement? arrangement,
      this.showField = false})
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
          showField == other.showField;

  @override
  int get hashCode => map.hashCode ^ showField.hashCode;

  @override
  String toString() {
    return 'LoadMap{map: $map, showField: $showField}';
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
