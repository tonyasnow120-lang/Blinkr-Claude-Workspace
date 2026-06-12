import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared "line art eye" drawing primitives — the rotating dial rings, the
/// outward pulse rings, and the eye itself (iris/pupil/highlight with
/// double-blink eyelids). This is the canonical look used on the home
/// screen and reused everywhere else an eye graphic appears, so every eye
/// in the app shares the same proportions and motion language.
///
/// All sizes are derived from a single [base] dimension (the eye area's
/// height in the canonical usage) so the drawing scales uniformly.
class LineEye {
  static void drawRings(
    Canvas canvas,
    Offset center,
    double base, {
    required double rotation,
    required double arcRotation,
  }) {
    final innerR = base * 0.36;
    final outerR = base * 0.485;
    final p = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi * 2);
    for (int i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final isMajor = i % 6 == 0;
      p.color = Colors.white.withAlpha(isMajor ? 115 : 26);
      final len = isMajor ? 10.0 : 5.0;
      canvas.drawLine(
        Offset(math.cos(a) * (innerR - len), math.sin(a) * (innerR - len)),
        Offset(math.cos(a) * innerR, math.sin(a) * innerR),
        p,
      );
    }
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-arcRotation * math.pi * 2);
    for (int i = 0; i < 36; i++) {
      final a = i * math.pi / 18;
      final isLong = i % 3 == 0;
      p.color = Colors.white.withAlpha(isLong ? 51 : 13);
      final len = isLong ? 8.0 : 4.0;
      canvas.drawLine(
        Offset(math.cos(a) * (outerR - len), math.sin(a) * (outerR - len)),
        Offset(math.cos(a) * outerR, math.sin(a) * outerR),
        p,
      );
    }
    canvas.restore();
  }

  static void drawPulseRings(
      Canvas canvas, Offset center, double base, double pulse) {
    final baseR = base * 0.39;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 0; i < 3; i++) {
      final t = (pulse + i / 3.0) % 1.0;
      final scale = 0.08 + t * 2.4;
      final alpha =
          t < 0.15 ? ((t / 0.15) * 128).round() : ((1 - t) * 128).round();
      if (alpha <= 0) continue;
      p.color = Colors.white.withAlpha(alpha);
      canvas.drawCircle(center, baseR * scale, p);
    }
  }

  /// Draws the almond eye outline with iris/pupil/highlight and a
  /// double-blink eyelid animation.
  ///
  /// - [wander] (0 if omitted) drifts the iris on a slow Lissajous path.
  /// - [crying], combined with [tearPhase], adds falling tears below the
  ///   eye (strictly white/black, matching the rest of the graphic).
  /// - [checkmark] replaces the pupil + highlight with a checkmark that
  ///   draws itself in via [checkTrim] (used by the sign-in success eye).
  static void drawEye(
    Canvas canvas,
    Offset center,
    double base, {
    required double blink,
    double wander = 0,
    bool crying = false,
    double tearPhase = 0,
    bool checkmark = false,
    double checkTrim = 0,
  }) {
    final eyeW = base * 0.62;
    final eyeH = eyeW * 0.44;

    double lidT = 0.0;
    final t = blink;
    if (t >= 0.30 && t <= 0.38) {
      final bt = (t - 0.30) / 0.08;
      lidT = bt < 0.5 ? bt * 2 : (1 - bt) * 2;
    } else if (t >= 0.43 && t <= 0.49) {
      final bt = (t - 0.43) / 0.06;
      lidT = bt < 0.5 ? bt * 2 : (1 - bt) * 2;
    }

    final eyePath = Path()
      ..moveTo(center.dx - eyeW / 2, center.dy)
      ..quadraticBezierTo(
          center.dx, center.dy - eyeH, center.dx + eyeW / 2, center.dy)
      ..quadraticBezierTo(
          center.dx, center.dy + eyeH, center.dx - eyeW / 2, center.dy)
      ..close();

    canvas.save();
    canvas.clipPath(eyePath);

    final irisR = eyeH * 0.88;

    final wa = wander * math.pi * 2;
    final gaze = wander == 0
        ? Offset.zero
        : Offset(
              math.sin(wa) * math.cos(wa * 0.7),
              math.sin(wa * 1.3) * 0.45,
            ) *
            (irisR * 0.28 * (1.0 - lidT));
    final irisCenter = center + gaze;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withAlpha(230);
    canvas.drawCircle(irisCenter, irisR, strokePaint);

    strokePaint.color = Colors.white.withAlpha(76);
    strokePaint.strokeWidth = 0.5;
    canvas.drawCircle(irisCenter, irisR * 0.7, strokePaint);

    if (checkmark) {
      if (checkTrim > 0.001) {
        final check = Path()
          ..moveTo(irisCenter.dx - irisR * 0.42, irisCenter.dy + irisR * 0.02)
          ..lineTo(irisCenter.dx - irisR * 0.10, irisCenter.dy + irisR * 0.34)
          ..lineTo(irisCenter.dx + irisR * 0.46, irisCenter.dy - irisR * 0.30);

        for (final metric in check.computeMetrics()) {
          canvas.drawPath(
            metric.extractPath(0, metric.length * checkTrim),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
          );
        }
      }
    } else {
      canvas.drawCircle(
          irisCenter, irisR * 0.44, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(irisCenter.dx + irisR * 0.27, irisCenter.dy - irisR * 0.3),
        irisR * 0.17,
        Paint()..color = Colors.black.withAlpha(140),
      );
    }

    if (lidT > 0.001) {
      final lidPaint = Paint()..color = Colors.black;
      final lidOffset = eyeH * lidT;
      final pad = eyeW * 0.05;

      final upperLid = Path()
        ..moveTo(center.dx - eyeW / 2 - pad, center.dy)
        ..quadraticBezierTo(
            center.dx, center.dy - eyeH, center.dx + eyeW / 2 + pad, center.dy)
        ..lineTo(center.dx + eyeW / 2 + pad, center.dy - eyeH * 2.5)
        ..lineTo(center.dx - eyeW / 2 - pad, center.dy - eyeH * 2.5)
        ..close();

      canvas.save();
      canvas.translate(0, lidOffset);
      canvas.drawPath(upperLid, lidPaint);
      canvas.restore();

      final lowerLid = Path()
        ..moveTo(center.dx - eyeW / 2 - pad, center.dy)
        ..quadraticBezierTo(
            center.dx, center.dy + eyeH, center.dx + eyeW / 2 + pad, center.dy)
        ..lineTo(center.dx + eyeW / 2 + pad, center.dy + eyeH * 2.5)
        ..lineTo(center.dx - eyeW / 2 - pad, center.dy + eyeH * 2.5)
        ..close();

      canvas.save();
      canvas.translate(0, -lidOffset);
      canvas.drawPath(lowerLid, lidPaint);
      canvas.restore();
    }

    canvas.restore();

    canvas.drawPath(
      eyePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white,
    );

    if (crying) {
      _drawTears(canvas, center, eyeW, eyeH, tearPhase);
    }
  }

  static void _drawTears(
      Canvas canvas, Offset center, double eyeW, double eyeH, double tearPhase) {
    final dropStartY = center.dy + eyeH * 0.85;
    final dropEndY = center.dy + eyeH * 4.4;
    for (var i = 0; i < 3; i++) {
      final phase = (tearPhase + i / 3) % 1.0;
      final dy = dropStartY + (dropEndY - dropStartY) * phase;
      final opacity = (1 - phase * phase).clamp(0.0, 1.0);
      final dx = center.dx - eyeW * 0.22 + i * eyeW * 0.22;
      final scale = 0.7 + 0.3 * (1 - phase);
      _drawTeardrop(canvas, Offset(dx, dy), eyeH * 0.22 * scale,
          Paint()..color = Colors.white.withOpacity(opacity * 0.85));
    }
  }

  /// A downward-falling teardrop: a point at the top trailing into a rounded
  /// bottom.
  static void _drawTeardrop(
      Canvas canvas, Offset tip, double radius, Paint paint) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy - radius * 1.6)
      ..quadraticBezierTo(tip.dx - radius, tip.dy - radius * 0.2,
          tip.dx - radius, tip.dy + radius * 0.3)
      ..arcToPoint(
        Offset(tip.dx + radius, tip.dy + radius * 0.3),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..quadraticBezierTo(tip.dx + radius, tip.dy - radius * 0.2, tip.dx,
          tip.dy - radius * 1.6)
      ..close();
    canvas.drawPath(path, paint);
  }
}
