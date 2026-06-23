import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A faint soft-light noise overlay laid over every screen root (≈4.5%).
/// Static (fixed seed) so it never shimmers, and [IgnorePointer] so taps fall
/// through to the content beneath.
class InkGrain extends StatelessWidget {
  final double opacity;

  const InkGrain({super.key, this.opacity = 0.045});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GrainPainter(opacity),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final double opacity;

  _GrainPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7);
    final paint = Paint()..blendMode = BlendMode.softLight;
    // One fleck per ~700px², capped so very large canvases stay cheap.
    final count = (size.width * size.height / 700).clamp(0, 2200).toInt();
    for (var i = 0; i < count; i++) {
      final dx = r.nextDouble() * size.width;
      final dy = r.nextDouble() * size.height;
      paint.color = (r.nextBool() ? AppColors.chalk : AppColors.bg)
          .withOpacity(opacity * (0.5 + r.nextDouble() * 0.5));
      canvas.drawRect(Rect.fromLTWH(dx, dy, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.opacity != opacity;
}
