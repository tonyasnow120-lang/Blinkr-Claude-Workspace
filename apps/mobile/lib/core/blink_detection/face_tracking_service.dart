import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'blink_detector.dart';

/// Drives blink detection from the LiveKit camera track.
///
/// The LiveKit Flutter SDK has no per-frame callback API (see
/// docs/FACE_TRACKING_SCOPE.md), so this polls `captureFrame()` on the
/// track's underlying MediaStreamTrack at ~8 Hz, runs ML Kit face detection
/// in classification mode, and feeds the eye-open probability into
/// [BlinkDetector]. Everything is best-effort: a failed capture or
/// detection just skips to the next tick.
class FaceTrackingService {
  static const _interval = Duration(milliseconds: 125); // ~8 Hz

  final BlinkDetector blinkDetector;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  Timer? _timer;
  bool _busy = false;
  File? _frameFile;

  FaceTrackingService(this.blinkDetector);

  bool get isRunning => _timer != null;

  void start(livekit.LocalVideoTrack track) {
    stop();
    _timer = Timer.periodic(_interval, (_) => _processFrame(track));
  }

  Future<void> _processFrame(livekit.LocalVideoTrack track) async {
    // Skip ticks while a previous capture+detection is still in flight so
    // slow devices degrade to a lower rate instead of queueing work.
    if (_busy) return;
    _busy = true;
    try {
      final buffer = await track.mediaStreamTrack.captureFrame();

      // captureFrame returns encoded image bytes; ML Kit's fromBytes wants
      // raw planes, so round-trip through a (reused) temp file and let the
      // platform decode it.
      final file = _frameFile ??=
          File('${Directory.systemTemp.path}/blinkr_frame.jpg');
      await file.writeAsBytes(buffer.asUint8List(), flush: false);

      final faces =
          await _detector.processImage(InputImage.fromFilePath(file.path));
      if (faces.isEmpty) return;

      final face = faces.first;
      final left = face.leftEyeOpenProbability;
      final right = face.rightEyeOpenProbability;
      if (left == null || right == null) return;

      // min: closing either eye (including a wink) counts as a blink.
      blinkDetector.processEyeOpenProbability(math.min(left, right));
    } catch (_) {
      // Best-effort — skip this frame and try again next tick.
    } finally {
      _busy = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _detector.close();
    _frameFile?.delete().ignore();
  }
}
