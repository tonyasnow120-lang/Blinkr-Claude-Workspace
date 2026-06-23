import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Full-bleed atmospheric ink splatter that sits **behind** all screen content
/// (z-index -1 equivalent). Each screen passes a unique [seed] so no two
/// backgrounds repeat. Green-dominant, semi-transparent; [intensity] scales
/// every blob's opacity (resting default 0.5, per the design tweaks).
class InkSplat extends StatelessWidget {
  final int seed;
  final double intensity;

  const InkSplat({super.key, required this.seed, this.intensity = 0.5});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _InkSplatPainter(seed: seed, intensity: intensity),
      ),
    );
  }
}

class _InkSplatPainter extends CustomPainter {
  final int seed;
  final double intensity;

  _InkSplatPainter({required this.seed, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);

    // Soft green-dominant washes — large, faint radial blobs.
    const blobCount = 14;
    for (var i = 0; i < blobCount; i++) {
      final cx = r.nextDouble() * size.width;
      final cy = r.nextDouble() * size.height;
      final radius = 36 + r.nextDouble() * 150;
      final baseOp = (0.03 + r.nextDouble() * 0.07) * intensity;
      // ~12% of blobs get a rare pop hue; the rest are acid green.
      final color = r.nextDouble() > 0.88 ? AppColors.fuchsia : AppColors.acid;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, cy),
            radius,
            [color.withOpacity(baseOp), color.withOpacity(0)],
          ),
      );
    }

    // Sharp specks — scattered flecks of acid that read as spray.
    final speck = Paint();
    for (var i = 0; i < 12; i++) {
      final cx = r.nextDouble() * size.width;
      final cy = r.nextDouble() * size.height;
      speck.color =
          AppColors.acid.withOpacity((0.05 + r.nextDouble() * 0.12) * intensity);
      canvas.drawCircle(Offset(cx, cy), 0.8 + r.nextDouble() * 2.2, speck);
    }
  }

  @override
  bool shouldRepaint(_InkSplatPainter old) =>
      old.seed != seed || old.intensity != intensity;
}
