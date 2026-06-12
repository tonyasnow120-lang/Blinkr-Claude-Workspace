import 'dart:async';
import 'dart:ui' show Offset;
import 'blink_event.dart';
import 'ear_calculator.dart';

/// Below this ML Kit eye-open probability the eye is treated as closed.
/// Tuned for sparse sampling (~8 Hz via captureFrame polling) — partial
/// closure already drops the probability well under fully-open values.
const double kBlinkOpenProbabilityThreshold = 0.35;

/// Emits [BlinkEvent]s from either of two eye-state sources:
///
/// - [processFrame]: landmark-based (EAR). Emits after
///   [kBlinkFrameDebounce] consecutive frames below [kBlinkEarThreshold].
///   Kept for future high-frame-rate landmark sources.
/// - [processEyeOpenProbability]: ML Kit classification-based, fed at
///   ~8 Hz by FaceTrackingService. No frame debounce — at this rate a
///   normal blink only spans one or two samples.
class BlinkDetector {
  final StreamController<BlinkEvent> _controller =
      StreamController<BlinkEvent>.broadcast();

  int _belowThresholdFrames = 0;
  bool _blinkInProgress = false;

  Stream<BlinkEvent> get blinkStream => _controller.stream;

  /// Call this on every face-mesh frame with the current eye landmarks.
  /// [leftEye] and [rightEye] are each 6 landmark [Offset]s.
  void processFrame({
    required List<Offset> leftEye,
    required List<Offset> rightEye,
    BlinkEventType eventType = BlinkEventType.blink,
  }) {
    final ear = computeMeanEAR(leftEye, rightEye);

    if (ear < kBlinkEarThreshold) {
      _belowThresholdFrames++;

      if (!_blinkInProgress &&
          _belowThresholdFrames >= kBlinkFrameDebounce) {
        _blinkInProgress = true;
        _controller.add(BlinkEvent(
          type: eventType,
          detectedAt: DateTime.now(),
          earValue: ear,
        ));
      }
    } else {
      _belowThresholdFrames = 0;
      _blinkInProgress = false;
    }
  }

  /// Call with the minimum of ML Kit's left/right eye-open probabilities
  /// (so a wink counts as a blink). Emits once per closure; re-arms when
  /// the eyes reopen.
  void processEyeOpenProbability(double openProbability) {
    if (openProbability < kBlinkOpenProbabilityThreshold) {
      if (!_blinkInProgress) {
        _blinkInProgress = true;
        _controller.add(BlinkEvent(
          type: BlinkEventType.blink,
          detectedAt: DateTime.now(),
          earValue: openProbability,
        ));
      }
    } else {
      _blinkInProgress = false;
    }
  }

  void dispose() {
    _controller.close();
  }
}
