import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';

/// Toggles between Blinkr's dark and light looks. Styled like
/// [MusicToggleButton] — a faint circular outline button — so it sits
/// naturally in the same corner of a screen.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;
    final ink = context.colors.foreground;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => ref.read(themeModeProvider.notifier).toggle(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ink.withOpacity(0.3), width: 0.8),
          ),
          child: Center(
            child: ThemeToggleIcon(size: 15, color: ink.withOpacity(0.78), isDark: isDark),
          ),
        ),
      ),
    );
  }
}

/// Small line-art "contrast dial" — a circle with one half filled. The
/// filled half mirrors the look you'll switch *to*, matching the thin,
/// minimal-stroke style of [LineEyeIcon].
class ThemeToggleIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool isDark;

  const ThemeToggleIcon({
    super.key,
    this.size = 18,
    this.color = AppColors.chalk,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ThemeToggleIconPainter(color: color, isDark: isDark),
    );
  }
}

class _ThemeToggleIconPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  _ThemeToggleIconPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - size.width * 0.06;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..color = color;

    final half = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..arcTo(rect, -math.pi / 2, math.pi, false)
      ..close();

    canvas.save();
    if (isDark) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(half, Paint()..color = color);
    canvas.restore();

    canvas.drawCircle(center, radius, stroke);
  }

  @override
  bool shouldRepaint(_ThemeToggleIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isDark != isDark;
}
