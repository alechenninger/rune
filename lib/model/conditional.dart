import 'model.dart';

class EventFlag {
  final String value;

  EventFlag(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventFlag &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'EventFlag{$value}';
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
