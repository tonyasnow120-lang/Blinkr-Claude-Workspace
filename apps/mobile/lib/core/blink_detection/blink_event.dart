enum BlinkEventType { blink, gazeBreak }

class BlinkEvent {
  final BlinkEventType type;
  final DateTime detectedAt;
  final double earValue;

  const BlinkEvent({
    required this.type,
    required this.detectedAt,
    required this.earValue,
  });
}
