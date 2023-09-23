import 'package:collection/collection.dart';

import '../model/model.dart';
import 'generator.dart';

abstract class StateChange<T> {
  T apply(Memory memory);
  mayApply(Memory memory);
}

class AddressOf {
  final Object obj;

  AddressOf(this.obj);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressOf &&
          runtimeType == other.runtimeType &&
          obj == other.obj;

  @override
  int get hashCode => obj.hashCode;

  @override
  String toString() {
    return 'AddressOf{$obj}';
  }
}

class SystemState {
  final _inAddress = <DirectAddressRegister, AddressOf>{};
  bool _hasSavedDialogPosition = false;
  DialogTree? _loadedDialogTree;
  bool? _isMapInVram = true;
  bool? _isMapInCram = true;
  bool? _isDialogInCram = true;
  bool? _displayEnabled = true;

  void _refreshMap(MapId map, DialogTrees trees) {
    _loadedDialogTree = trees.forMap(map);
    //_loadedMapPalette = map;
  }

  void _putInAddress(DirectAddressRegister a, Object? obj) {
    if (obj == null) {
      _inAddress.remove(a);
    } else {
      _inAddress[a] = AddressOf(obj);
    }
  }

  SystemState branch() => SystemState()
    .._inAddress.addAll(_inAddress)
    .._hasSavedDialogPosition = _hasSavedDialogPosition
    .._loadedDialogTree = _loadedDialogTree
    .._isDialogInCram = _isDialogInCram
    .._isMapInCram = _isMapInCram
    .._isMapInVram = _isMapInVram
    .._displayEnabled = _displayEnabled;
}

class Memory implements EventState {
  final List<StateChange> _changes = [];
  final SystemState _sysState;
  final EventState _eventState;

  Memory()
      : _sysState = SystemState(),
        _eventState = EventState();
  Memory.from(this._sysState, this._eventState);

  @override
  Memory branch() => Memory.from(_sysState.branch(), _eventState.branch());

  List<StateChange> get changes => UnmodifiableListView(_changes);

  void clearChanges() {
    _changes.clear();
  }

  set hasSavedDialogPosition(bool saved) {
    _apply(SetSavedDialogPosition(saved));
  }

  bool get hasSavedDialogPosition => _sysState._hasSavedDialogPosition;

  AddressOf? inAddress(DirectAddressRegister a) => _sysState._inAddress[a];

  /// Return the address register the object is referenced in, if any.
  DirectAddressRegister? addressRegisterFor(Object obj) {
    return _sysState._inAddress.entries
        .firstWhereOrNull((e) => e.value.obj == obj)
        ?.key;
  }

  /// [obj] should not be wrapped in [AddressOf].
  void putInAddress(DirectAddressRegister a, Object? obj) {
    _apply(PutInAddress(a, obj));
  }

  // todo: maybe not actually needed?
  DialogTree? get loadedDialogTree => _sysState._loadedDialogTree;
  set loadedDialogTree(DialogTree? tree) {
    _apply(SetValue<DialogTree>(tree, (mem) => mem._sysState._loadedDialogTree,
        (val, mem) => mem._sysState._loadedDialogTree = val));
  }

  bool? get isMapInCram => _sysState._isMapInCram;
  set isMapInCram(bool? flag) {
    _apply(SetValue<bool>(flag, (mem) => mem._sysState._isMapInCram,
        (val, mem) => mem._sysState._isMapInCram = val));
  }

  bool? get isDialogInCram => _sysState._isDialogInCram;
  set isDialogInCram(bool? flag) {
    _apply(SetValue<bool>(flag, (mem) => mem._sysState._isDialogInCram,
        (val, mem) => mem._sysState._isDialogInCram = val));
  }

  bool? get isMapInVram => _sysState._isMapInVram;
  set isMapInVram(bool? flag) {
    _apply(SetValue<bool>(flag, (mem) => mem._sysState._isMapInVram,
        (val, mem) => mem._sysState._isMapInVram = val));
  }

  bool? get isDisplayEnabled => _sysState._displayEnabled;
  set isDisplayEnabled(bool? flag) {
    _apply(SetValue<bool>(flag, (mem) => mem._sysState._displayEnabled,
        (val, mem) => mem._sysState._displayEnabled = val));
  }

  @override
  Positions get positions => _Positions(this);

  @override
  Slots get slots => _Slots(this);

  @override
  Axis? get startingAxis => _eventState.startingAxis;

  @override
  set startingAxis(Axis? a) {
    _apply(SetStartingAxis(a));
  }

  @override
  bool? get followLead => _eventState.followLead;

  @override
  set followLead(bool? follow) => _apply(SetValue<bool>(follow,
      (m) => m._eventState.followLead, (f, m) => m._eventState.followLead = f));

  @override
  bool? get cameraLock => _eventState.cameraLock;

  @override
  set cameraLock(bool? lock) => _apply(SetValue<bool>(lock,
      (m) => m._eventState.cameraLock, (l, m) => m._eventState.cameraLock = l));

  @override
  GameMap? get currentMap => _eventState.currentMap;

  @override
  set currentMap(GameMap? map) => _apply(SetValue<GameMap>(
      map,
      (m) => m._eventState.currentMap,
      (map, m) => m._eventState.currentMap = map));

  @override
  Portrait? get dialogPortrait => _eventState.dialogPortrait;

  @override
  set dialogPortrait(Portrait? speaker) => _apply(SetValue<Portrait>(
      speaker,
      (m) => m._eventState.dialogPortrait,
      (s, m) => m._eventState.dialogPortrait = s));

  @override
  DirectionExpression? getFacing(FieldObject obj) => _eventState.getFacing(obj);

  @override
  void setFacing(FieldObject obj, Direction dir) {
    _apply(SetFacing(obj, dir));
  }

  @override
  void clearFacing(FieldObject obj) {
    _apply(ClearFacing(obj));
  }

  @override
  int? slotFor(Character c) => _eventState.slotFor(c);

  @override
  int get numCharacters => _eventState.numCharacters;

  @override
  void setSlot(int slot, Character c) {
    _apply(SetSlot(slot, c));
  }

  @override
  void clearSlot(int slot) {
    _apply(SetSlot(slot, null));
  }

  @override
  void addCharacter(Character c,
      {int? slot, Position? position, Direction? facing}) {
    if (slot != null) slots[slot] = c;
    if (position != null) positions[c] = position;
    if (facing != null) setFacing(c, facing);
  }

  @override
  bool? get isFieldShown => _eventState.isFieldShown;

  @override
  set isFieldShown(bool? isShown) {
    _apply(SetValue<bool>(isShown, (mem) => mem._eventState.isFieldShown,
        (val, mem) => mem._eventState.isFieldShown = val));
  }

  @override
  int? get panelsShown => _eventState.panelsShown;

  @override
  set panelsShown(int? panels) {
    _apply(SetValue<int>(panels, (mem) => mem._eventState.panelsShown,
        (val, mem) => mem._eventState.panelsShown = val));
  }

  @override
  void addPanel() {
    _apply(AddPanel());
  }

  @override
  void removePanels([int n = 1]) {
    _apply(RemovePanels(n));
  }

  @override
  RoutineRef? getRoutine(FieldObject obj) => _eventState.getRoutine(obj);

  void unknownAddressRegisters() {
    _apply(UnknownAddressRegisters());
  }

  @override
  void setRoutine(FieldObject obj, RoutineRef? r) {
    _apply(UpdateRoutine(obj, r));
  }

  T _apply<T>(StateChange<T> change) {
    _changes.add(change);
    return change.apply(this);
  }
}

class _Positions implements Positions {
  final Memory _memory;

  _Positions(this._memory);

  @override
  Position? operator [](FieldObject obj) => _memory._eventState.positions[obj];

  @override
  void operator []=(FieldObject obj, Position? p) {
    _memory._apply(SetPosition(obj, p));
  }

  @override
  void addAll(Positions p) {
    _memory._apply(AddAllPositions(p));
  }

  @override
  void forEach(Function(FieldObject obj, Position pos) func) {
    _memory._eventState.positions.forEach(func);
  }
}

class _Slots implements Slots {
  final Memory _memory;

  _Slots(this._memory);

  @override
  Character? operator [](int slot) => _memory._eventState.slots[slot];

  @override
  void operator []=(int slot, Character? c) =>
      _memory._eventState.slots[slot] = c;

  @override
  int? slotFor(Character c) => _memory._eventState.slots.slotFor(c);

  @override
  int get numCharacters => _memory._eventState.numCharacters;

  @override
  void addAll(Slots slots) {
    _memory._apply(AddAllSlots(slots));
  }

  @override
  void forEach(Function(int slot, Character c) func) {
    _memory._eventState.slots.forEach(func);
  }
}

// TODO: if prior value is same, then "may apply" can keep same value
// e.g. if

class SetSavedDialogPosition implements StateChange {
  final bool saved;

  SetSavedDialogPosition(this.saved);

  @override
  apply(Memory memory) {
    memory._sysState._hasSavedDialogPosition = saved;
  }

  @override
  mayApply(Memory memory) {
    memory._sysState._hasSavedDialogPosition = false;
  }
}

class PutInAddress implements StateChange {
  final DirectAddressRegister register;
  final Object? obj;

  PutInAddress(this.register, this.obj);

  @override
  apply(Memory memory) {
    memory._sysState._putInAddress(register, obj);
  }

  @override
  mayApply(Memory memory) {
    memory._sysState._putInAddress(register, null);
  }
}

class UnknownAddressRegisters implements StateChange {
  @override
  apply(Memory memory) {
    memory._sysState._inAddress.clear();
  }

  @override
  mayApply(Memory memory) {
    memory._sysState._inAddress.clear();
  }
}

class SetFacing implements StateChange {
  final FieldObject obj;
  final Direction dir;

  SetFacing(this.obj, this.dir);

  @override
  apply(Memory memory) {
    memory._eventState.setFacing(obj, dir);
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.clearFacing(obj);
  }
}

class ClearFacing implements StateChange {
  final FieldObject obj;

  ClearFacing(this.obj);

  @override
  apply(Memory memory) {
    memory._eventState.clearFacing(obj);
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.clearFacing(obj);
  }
}

class SetSlot implements StateChange {
  final int slot;
  final Character? char;

  SetSlot(this.slot, this.char);

  @override
  apply(Memory memory) {
    var c = char;
    if (c == null) {
      memory._eventState.clearSlot(slot);
    } else {
      memory._eventState.setSlot(slot, c);
    }
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.clearSlot(slot);
  }
}

class AddAllSlots implements StateChange {
  final Slots slots;

  AddAllSlots(this.slots);

  @override
  apply(Memory memory) {
    memory._eventState.slots.addAll(slots);
  }

  @override
  mayApply(Memory memory) {
    slots.forEach((slot, c) => memory._eventState.slots[slot] = null);
  }
}

class SetPosition implements StateChange {
  final FieldObject obj;
  final Position? pos;

  SetPosition(this.obj, this.pos);

  @override
  apply(Memory memory) {
    memory._eventState.positions[obj] = pos;
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.positions[obj] = null;
  }
}

class AddAllPositions implements StateChange {
  final Positions positions;

  AddAllPositions(this.positions);

  @override
  apply(Memory memory) {
    memory._eventState.positions.addAll(positions);
  }

  @override
  mayApply(Memory memory) {
    positions.forEach((obj, pos) => memory._eventState.positions[obj] = null);
  }
}

class SetStartingAxis implements StateChange {
  final Axis? axis;

  SetStartingAxis(this.axis);

  @override
  apply(Memory memory) {
    memory._eventState.startingAxis = axis;
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.startingAxis = null;
  }
}

class SetValue<T> implements StateChange {
  final T? _val;
  final T? Function(Memory mem) _get;
  final void Function(T? val, Memory mem) _set;

  SetValue(this._val, this._get, this._set);

  @override
  apply(Memory memory) {
    _set(_val, memory);
  }

  @override
  mayApply(Memory memory) {
    // todo: not sure about this?
    if (_get(memory) != _val) {
      _set(null, memory);
    }
  }
}

class AddPanel implements StateChange {
  @override
  apply(Memory memory) {
    memory._eventState.addPanel();
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.panelsShown = null;
  }
}

class RemovePanels implements StateChange {
  final int n;

  RemovePanels(this.n);

  @override
  apply(Memory memory) {
    memory._eventState.removePanels(n);
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.panelsShown = null;
  }
}

class UpdateRoutine implements StateChange {
  final FieldObject obj;
  final RoutineRef? routine;

  UpdateRoutine(this.obj, this.routine);

  @override
  apply(Memory memory) {
    memory._eventState.setRoutine(obj, routine);
  }

  @override
  mayApply(Memory memory) {
    memory._eventState.setRoutine(obj, null);
  }
}
