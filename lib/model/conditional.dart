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

class IfEvent extends Event {
  final EventFlag flag;
  final List<Event> ifSet;
  final List<Event> ifUnset;

  IfEvent(this.flag, {this.ifSet = const [], this.ifUnset = const []});

  @override
  void visit(EventVisitor visitor) {
    visitor.ifEvent(this);
  }

  @override
  String toString() {
    return 'IfEvent{$flag}';
  }
}
