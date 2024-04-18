import 'package:quiver/check.dart';

import 'model.dart';

class IncreaseTone extends Event {
  /// 1 is 100% white.
  final double percent;

  /// Time to wait with increased tone.
  final Duration wait;

  IncreaseTone({required this.percent, this.wait = Duration.zero}) {
    checkArgument(percent >= 0 && percent <= 1,
        message: 'percent must be between 0 and 1');
    checkArgument(wait >= Duration.zero, message: 'wait must be non-negative');
  }

  @override
  void visit(EventVisitor visitor) {
    visitor.increaseTone(this);
  }
}

class FlashScreen extends Event {
  final SoundEffect? sound;

  /// Additional partial flashes in percentages.
  final List<double> partialFlashes;
  final Duration flashed;
  final Duration calm;
  // Could also allow custom colors in future

  FlashScreen(
      {this.sound,
      this.partialFlashes = const [],
      required this.calm,
      this.flashed = Duration.zero}) {
    checkArgument(partialFlashes.every((r) => r >= 0 && r <= 1),
        message: 'restore percentages in sequence must be between 0 and 1');
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
