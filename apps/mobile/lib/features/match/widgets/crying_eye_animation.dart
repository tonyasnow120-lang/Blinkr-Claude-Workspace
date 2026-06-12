import 'package:flutter/material.dart';

/// A simple looping animation of an eye shedding tears, shown when a match
/// ends without a result (e.g. the opponent never joined / abandoned).
class CryingEyeAnimation extends StatefulWidget {
  const CryingEyeAnimation({super.key});

  @override
  State<CryingEyeAnimation> createState() => _CryingEyeAnimationState();
}

class _CryingEyeAnimationState extends State<CryingEyeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 150,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _CryingEyePainter(_controller.value),
        ),
      ),
    );
  }
}

class _CryingEyePainter extends CustomPainter {
  final double t;

  _CryingEyePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.32);
    final eyeWidth = size.width * 0.8;
    final eyeHeight = size.height * 0.32;

    // Sclera (almond eye shape).
    final eyePath = Path()
      ..moveTo(center.dx - eyeWidth / 2, center.dy)
      ..quadraticBezierTo(
        center.dx,
        center.dy - eyeHeight,
        center.dx + eyeWidth / 2,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy + eyeHeight * 0.8,
        center.dx - eyeWidth / 2,
        center.dy,
      );
    canvas.drawPath(eyePath, Paint()..color = Colors.white);

    // Iris + pupil + highlight.
    final irisRadius = eyeHeight * 0.62;
    final irisCenter = Offset(center.dx, center.dy + eyeHeight * 0.08);
    canvas.drawCircle(
        irisCenter, irisRadius, Paint()..color = const Color(0xFF4FC3F7));
    canvas.drawCircle(
        irisCenter, irisRadius * 0.5, Paint()..color = Colors.black);
    canvas.drawCircle(
      Offset(
          irisCenter.dx - irisRadius * 0.22, irisCenter.dy - irisRadius * 0.22),
      irisRadius * 0.16,
      Paint()..color = Colors.white70,
    );

    // Droopy upper eyelid for a sad expression.
    final lidPath = Path()
      ..moveTo(center.dx - eyeWidth / 2, center.dy - 4)
      ..quadraticBezierTo(
        center.dx,
        center.dy - eyeHeight - 12,
        center.dx + eyeWidth / 2,
        center.dy - 4,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy - eyeHeight * 0.35,
        center.dx - eyeWidth / 2,
        center.dy - 4,
      );
    canvas.drawPath(lidPath, Paint()..color = const Color(0xFF0D0D0F));

    // Eye outline.
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Tears falling from the lower lid, staggered.
    final dropStartY = center.dy + eyeHeight * 0.7;
    final dropEndY = size.height;
    final tearPaint = Paint()..color = const Color(0xFF81D4FA);
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final dy = dropStartY + (dropEndY - dropStartY) * phase;
      final opacity = (1 - phase * phase).clamp(0.0, 1.0);
      final dx = center.dx - eyeWidth * 0.22 + i * eyeWidth * 0.22;
      final scale = 0.7 + 0.3 * (1 - phase);
      _drawTeardrop(canvas, Offset(dx, dy), 6 * scale,
          tearPaint..color = const Color(0xFF81D4FA).withOpacity(opacity));
    }
  }

  /// Draws a downward-falling teardrop: a point at the top trailing into a
  /// rounded bottom.
  void _drawTeardrop(Canvas canvas, Offset tip, double radius, Paint paint) {
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

  @override
  bool shouldRepaint(covariant _CryingEyePainter oldDelegate) =>
      oldDelegate.t != t;
}
