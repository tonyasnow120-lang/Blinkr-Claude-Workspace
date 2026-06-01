import 'dart:math';
import 'dart:ui' show Offset;

// SECURITY / PRIVACY AUDIT — Biometric Data Handling (M8)
//
// This module computes the Eye Aspect Ratio (EAR) from MediaPipe Face Mesh landmarks.
//
// What is processed ON DEVICE ONLY:
//   • 468 facial landmark coordinates (x, y, z) per frame — computed locally
//   • EAR value derived from 6 per-eye landmark points
//   • Binary blink signal (true/false + timestamp) — the only output that leaves this module
//
// What is NOT stored or transmitted:
//   • Raw camera frames — NOT stored, NOT transmitted
//   • Facial landmark coordinates — NOT stored, NOT transmitted
//   • EAR values — NOT stored (only the boolean blink outcome is sent to the server)
//   • Biometric templates or identifiers — NOT generated
//
// The blink event object { detectedAt, earValue, eventType } that is POSTed to the backend
// contains the EAR value as supporting evidence for adjudication. This is match metadata,
// not a biometric identifier. See PRIVACY_COMPLIANCE.md for the full regulatory analysis.

const double kBlinkEarThreshold = 0.20;
const int kBlinkFrameDebounce = 2;

/// Computes Eye Aspect Ratio from 6 landmark points.
/// p1, p4 = horizontal endpoints; p2,p3,p5,p6 = vertical pairs
/// EAR = (||p2−p6|| + ||p3−p5||) / (2 × ||p1−p4||)
double computeEAR(List<Offset> landmarks) {
  assert(landmarks.length == 6, 'computeEAR requires exactly 6 landmark points');

  final p1 = landmarks[0];
  final p2 = landmarks[1];
  final p3 = landmarks[2];
  final p4 = landmarks[3];
  final p5 = landmarks[4];
  final p6 = landmarks[5];

  final horizontal = _dist(p1, p4);
  if (horizontal == 0.0) return 0.0;

  final vertical1 = _dist(p2, p6);
  final vertical2 = _dist(p3, p5);

  return (vertical1 + vertical2) / (2.0 * horizontal);
}

/// Returns the average EAR of both eyes.
double computeMeanEAR(List<Offset> leftEye, List<Offset> rightEye) {
  return (computeEAR(leftEye) + computeEAR(rightEye)) / 2.0;
}

double _dist(Offset a, Offset b) {
  final dx = a.dx - b.dx;
  final dy = a.dy - b.dy;
  return sqrt(dx * dx + dy * dy);
}
