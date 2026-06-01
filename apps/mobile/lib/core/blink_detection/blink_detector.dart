import 'dart:async';
import 'package:flutter/foundation.dart';
import 'blink_event.dart';
import 'ear_calculator.dart';

/// Wraps the mediapipe_face_mesh landmark stream and emits [BlinkEvent]s.
///
/// Emits only after [kBlinkFrameDebounce] consecutive frames below
/// [kBlinkEarThreshold], then resets the counter when EAR rises again.
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

  void dispose() {
    _controller.close();
  }
}
