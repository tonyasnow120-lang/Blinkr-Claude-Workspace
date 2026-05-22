import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blinkr/core/blink_detection/ear_calculator.dart';

void main() {
  group('computeEAR', () {
    // Eye open: vertical distances are large relative to horizontal.
    // Using a unit square eye: p1=(0,0), p4=(1,0), p2=(0.25,0.25), p3=(0.75,0.25),
    // p5=(0.75,-0.25), p6=(0.25,-0.25)
    // EAR = (0.5 + 0.5) / (2 * 1.0) = 0.5
    test('returns EAR >= kBlinkEarThreshold for open eye', () {
      final landmarks = [
        const Offset(0.0, 0.0),   // p1
        const Offset(0.25, 0.25), // p2
        const Offset(0.75, 0.25), // p3
        const Offset(1.0, 0.0),   // p4
        const Offset(0.75, -0.25),// p5
        const Offset(0.25, -0.25),// p6
      ];
      final ear = computeEAR(landmarks);
      expect(ear, greaterThanOrEqualTo(kBlinkEarThreshold));
      expect(ear, closeTo(0.5, 0.001));
    });

    // Blink: vertical distances collapse to nearly zero.
    // p1=(0,0), p4=(1,0), p2=(0.25,0.01), p3=(0.75,0.01), p5=(0.75,-0.01), p6=(0.25,-0.01)
    // EAR = (0.02 + 0.02) / 2.0 = 0.02
    test('returns EAR < kBlinkEarThreshold for blink', () {
      final landmarks = [
        const Offset(0.0, 0.0),
        const Offset(0.25, 0.01),
        const Offset(0.75, 0.01),
        const Offset(1.0, 0.0),
        const Offset(0.75, -0.01),
        const Offset(0.25, -0.01),
      ];
      final ear = computeEAR(landmarks);
      expect(ear, lessThan(kBlinkEarThreshold));
    });

    // Edge case: all points at origin → horizontal distance = 0 → return 0.0
    test('returns 0.0 when all points are the same (zero-distance)', () {
      final landmarks = List.filled(6, Offset.zero);
      final ear = computeEAR(landmarks);
      expect(ear, equals(0.0));
    });
  });

  group('computeMeanEAR', () {
    test('averages left and right eye EAR values', () {
      // Left eye open (EAR ≈ 0.5)
      final leftEye = [
        const Offset(0.0, 0.0),
        const Offset(0.25, 0.25),
        const Offset(0.75, 0.25),
        const Offset(1.0, 0.0),
        const Offset(0.75, -0.25),
        const Offset(0.25, -0.25),
      ];
      // Right eye blinking (EAR ≈ 0.02)
      final rightEye = [
        const Offset(0.0, 0.0),
        const Offset(0.25, 0.01),
        const Offset(0.75, 0.01),
        const Offset(1.0, 0.0),
        const Offset(0.75, -0.01),
        const Offset(0.25, -0.01),
      ];
      final mean = computeMeanEAR(leftEye, rightEye);
      expect(mean, closeTo(0.26, 0.01));
    });
  });
}
