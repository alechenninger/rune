import 'package:collection/collection.dart';

import 'model.dart';

class EventFlag {
  final String name;

  EventFlag(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventFlag &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return 'EventFlag{$name}';
  }
}

class IfFlag extends Event {
  final EventFlag flag;
  final List<Event> isSet;
  final List<Event> isUnset;

  IfFlag(this.flag, {this.isSet = const [], this.isUnset = const []});

  @override
  void visit(EventVisitor visitor) {
    visitor.ifFlag(this);
  }

  @override
  String toString() {
    return 'IfFlag{flag: $flag, isSet: $isSet, isUnset: $isUnset}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IfFlag &&
          runtimeType == other.runtimeType &&
          flag == other.flag &&
          const ListEquality<Event>().equals(isSet, other.isSet) &&
          const ListEquality<Event>().equals(isUnset, other.isUnset);

  @override
  int get hashCode =>
      flag.hashCode ^
      const ListEquality<Event>().hash(isSet) ^
      const ListEquality<Event>().hash(isUnset);
}

class SetFlag extends Event {
  final EventFlag flag;

  SetFlag(this.flag);

  @override
  void visit(EventVisitor visitor) {
    visitor.setFlag(this);
  }

  @override
  String toString() {
    return 'SetFlag{$flag}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetFlag &&
          runtimeType == other.runtimeType &&
          flag == other.flag;

  @override
  int get hashCode => flag.hashCode;
}
