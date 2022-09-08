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
    return 'IfEvent{$flag}';
  }
}
