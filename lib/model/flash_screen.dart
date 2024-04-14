import 'package:quiver/check.dart';

import 'model.dart';

class FlashScreen extends Event {
  final SoundEffect? sound;
  final Duration flashed;
  final Duration calm;
  // Could also allow custom colors in future

  FlashScreen({this.sound, required this.calm, this.flashed = Duration.zero}) {
    checkArgument(calm >= Duration.zero, message: 'calm must non-negative');
    checkArgument(flashed >= Duration.zero,
        message: 'flashed must be non-negative');
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.flashScreen(this);
  }

  @override
  String toString() {
    return 'FlashScreen{sound: $sound, flashed: $flashed, calm: $calm}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlashScreen &&
          runtimeType == other.runtimeType &&
          sound == other.sound &&
          flashed == other.flashed &&
          calm == other.calm;

  @override
  int get hashCode => sound.hashCode ^ flashed.hashCode ^ calm.hashCode;
}
