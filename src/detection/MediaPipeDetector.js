/**
 * MediaPipe Face Landmarker blink detector for Android (and iOS fallback).
 *
 * Wire-up: This class calculates EAR from MediaPipe landmarks. You call
 * processFrame(landmarks) from a VisionCamera frame processor plugin.
 *
 * Integration steps:
 *   1. Use the useFaceLandmarker hook from react-native-mediapipe in the
 *      component that owns the camera.
 *   2. Pass each frame result's landmarks array to detector.processFrame().
 *   3. Alternatively, call detector.start() with a camera ref if the
 *      react-native-mediapipe version supports it directly.
 *
 * EAR landmarks (MediaPipe 478-point model):
 *   Right eye: [33, 160, 158, 133, 153, 144]
 *   Left eye:  [362, 385, 387, 263, 373, 380]
 *
 * EAR = (||p2-p6|| + ||p3-p5||) / (2 * ||p1-p4||)
 * Score is normalized to match ARKit convention: 0.0 = open, 1.0 = closed.
 */

// Indices into the full 478-landmark array for each eye (p1..p6 order)
const RIGHT_EYE_EAR = [33, 160, 158, 133, 153, 144];
const LEFT_EYE_EAR = [362, 385, 387, 263, 373, 380];

// Average EAR when eye is fully open — used for 0→1 normalization
const EAR_OPEN_BASELINE = 0.3;

class MediaPipeDetector {
  constructor() {
    this._callback = null;
    this._isRunning = false;
  }

  /**
   * @param {(data: {eyeBlinkLeft: number, eyeBlinkRight: number, timestamp: number}) => void} onData
   */
  async start(onData) {
    this._callback = onData;
    this._isRunning = true;
    // TODO: if react-native-mediapipe supports a standalone session (not
    // frame-processor), initialize it here and call processFrame internally.
  }

  async stop() {
    this._isRunning = false;
    this._callback = null;
  }

  /**
   * Call this from a VisionCamera frame processor or MediaPipe result handler.
   * @param {Array<{x: number, y: number, z: number}>} landmarks - 478 points
   */
  processFrame(landmarks) {
    if (!this._isRunning || !this._callback || !landmarks?.length) return;

    const rightEAR = this._ear(landmarks, RIGHT_EYE_EAR);
    const leftEAR = this._ear(landmarks, LEFT_EYE_EAR);

    this._callback({
      eyeBlinkLeft: this._earToBlinkScore(leftEAR),
      eyeBlinkRight: this._earToBlinkScore(rightEAR),
      timestamp: Date.now(),
    });
  }

  getName() {
    return 'MediaPipe';
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  _ear(landmarks, indices) {
    const [p1, p2, p3, p4, p5, p6] = indices.map(i => landmarks[i]);
    const vertical1 = this._dist(p2, p6);
    const vertical2 = this._dist(p3, p5);
    const horizontal = this._dist(p1, p4);
    return horizontal > 0 ? (vertical1 + vertical2) / (2 * horizontal) : 0;
  }

  _dist(a, b) {
    return Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2 + (a.z - b.z) ** 2);
  }

  // Converts EAR (high = open) to blink score (high = closed), clamped 0–1
  _earToBlinkScore(ear) {
    return Math.max(0, Math.min(1, 1 - ear / EAR_OPEN_BASELINE));
  }
}

export default MediaPipeDetector;
