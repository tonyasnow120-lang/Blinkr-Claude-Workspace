import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum GraffitiVariant { marker, underline, outline }

class GraffitiHighlight extends StatelessWidget {
  final Widget child;
  final GraffitiVariant variant;
  final Color? color;
  final double rotate;
  final bool grime;
  final bool? drip;

  const GraffitiHighlight({
    super.key,
    required this.child,
    this.variant = GraffitiVariant.marker,
    this.color,
    this.rotate = -1.5,
    this.grime = true,
    this.drip,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.acid;
    final effectiveDrip = drip ?? (variant == GraffitiVariant.marker);

    return Padding(
      padding: EdgeInsets.only(
        left: 6,
        right: 6,
        top: 4,
        bottom: effectiveDrip ? 8 : 4,
      ),
      child: CustomPaint(
        painter: _GraffitiPainter(
          variant: variant,
          color: effectiveColor,
          rotate: rotate,
          grime: grime,
          drip: effectiveDrip,
        ),
        child: Padding(
          padding: variant == GraffitiVariant.marker
              ? const EdgeInsets.symmetric(horizontal: 3, vertical: 1)
              : const EdgeInsets.symmetric(horizontal: 1),
          child: child,
        ),
      ),
    );
  }
}

class _GraffitiPainter extends CustomPainter {
  final GraffitiVariant variant;
  final Color color;
  final double rotate;
  final bool grime;
  final bool drip;

  const _GraffitiPainter({
    required this.variant,
    required this.color,
    required this.rotate,
    required this.grime,
    required this.drip,
  });

  static const _markerPoly = [
    [0.00, 0.18], [0.06, 0.04], [0.19, 0.12], [0.33, 0.02],
    [0.48, 0.10], [0.63, 0.01], [0.78, 0.11], [0.92, 0.03],
    [1.00, 0.15], [0.97, 0.86], [0.84, 0.97], [0.70, 0.88],
    [0.55, 0.99], [0.41, 0.90], [0.27, 0.99], [0.14, 0.89],
    [0.03, 0.97],
  ];

  static const _underlinePoly = [
    [0.00, 0.35], [0.08, 0.65], [0.17, 0.30], [0.28, 0.70],
    [0.39, 0.35], [0.51, 0.72], [0.62, 0.32], [0.74, 0.68],
    [0.85, 0.33], [0.95, 0.66], [1.00, 0.40], [1.00, 1.00],
    [0.00, 1.00],
  ];

  Path _polyPath(List<List<double>> pts, Rect r) {
    final p = Path()
      ..moveTo(r.left + pts[0][0] * r.width, r.top + pts[0][1] * r.height);
    for (var i = 1; i < pts.length; i++) {
      p.lineTo(r.left + pts[i][0] * r.width, r.top + pts[i][1] * r.height);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rad = rotate * math.pi / 180;
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rad);
    canvas.translate(-cx, -cy);

    switch (variant) {
      case GraffitiVariant.marker:
        _paintMarker(canvas, size);
      case GraffitiVariant.underline:
        _paintUnderline(canvas, size);
      case GraffitiVariant.outline:
        _paintOutline(canvas, size);
    }

    if (drip && variant != GraffitiVariant.outline) {
      _paintDrip(canvas, size);
    }

    canvas.restore();

    if (grime) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rad);
      canvas.translate(-cx, -cy);
      _paintSpatter(canvas, size);
      canvas.restore();
    }
  }

  void _paintMarker(Canvas canvas, Size size) {
    final em = size.height;
    final rect = Rect.fromLTRB(
      -em * 0.05,
      -em * 0.06,
      size.width + em * 0.05,
      size.height + em * 0.06,
    );
    final path = _polyPath(_markerPoly, rect);

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(rect, Paint()..color = color);
    if (grime) _paintPatchy(canvas, rect);
    canvas.restore();
  }

  void _paintUnderline(Canvas canvas, Size size) {
    final em = size.height;
    final rect = Rect.fromLTRB(
      -em * 0.04,
      size.height - em * 0.38,
      size.width + em * 0.04,
      size.height + em * 0.04,
    );
    final path = _polyPath(_underlinePoly, rect);

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(rect, Paint()..color = color);
    if (grime) _paintPatchy(canvas, rect);
    canvas.restore();
  }

  void _paintOutline(Canvas canvas, Size size) {
    final pts = [
      [0.02, 0.08], [0.98, 0.00], [1.00, 0.92], [0.04, 1.00],
    ];
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = _polyPath(pts, rect);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintPatchy(Canvas canvas, Rect rect) {
    final patches = [
      (0.16, 0.26, 0.30, 0.40, const Color.fromRGBO(0, 0, 0, 0.20)),
      (0.82, 0.66, 0.25, 0.35, const Color.fromRGBO(0, 0, 0, 0.16)),
      (0.48, 0.92, 0.35, 0.20, const Color.fromRGBO(0, 0, 0, 0.12)),
      (0.34, 0.50, 0.06, 0.60, const Color.fromRGBO(255, 255, 255, 0.10)),
    ];

    for (final (pcx, pcy, prx, pry, pColor) in patches) {
      final cx = rect.left + pcx * rect.width;
      final cy = rect.top + pcy * rect.height;
      final rx = prx * rect.width;
      final ry = pry * rect.height;
      final r = math.max(rx, ry);

      canvas.save();
      canvas.translate(cx, cy);
      if (rx != ry) canvas.scale(1.0, ry / rx);
      canvas.drawCircle(
        Offset.zero,
        rx,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            r,
            [pColor, pColor.withOpacity(0)],
            [0.3, 0.65],
          ),
      );
      canvas.restore();
    }
  }

  void _paintSpatter(Canvas canvas, Size size) {
    final em = size.height;
    final spatterRect = Rect.fromLTRB(
      -em * 0.62,
      -em * 0.42,
      size.width + em * 0.62,
      size.height + em * 0.42,
    );

    const dots = [
      (0.01, 0.46, 1.4),
      (0.04, 0.14, 1.0),
      (0.07, 0.82, 1.2),
      (0.50, 0.02, 1.0),
      (0.28, 0.98, 0.9),
      (0.66, 0.99, 1.1),
      (0.99, 0.40, 1.4),
      (0.96, 0.78, 1.0),
      (0.93, 0.10, 0.9),
      (0.82, 0.04, 0.8),
    ];

    final paint = Paint()..color = color.withOpacity(0.5);
    for (final (dx, dy, r) in dots) {
      canvas.drawCircle(
        Offset(
          spatterRect.left + dx * spatterRect.width,
          spatterRect.top + dy * spatterRect.height,
        ),
        r,
        paint,
      );
    }
  }

  void _paintDrip(Canvas canvas, Size size) {
    final em = size.height;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(
          size.width * 0.32,
          size.height + em * 0.06,
          em * 0.12,
          em * 0.4,
        ),
        bottomLeft: Radius.circular(em * 0.072),
        bottomRight: Radius.circular(em * 0.072),
      ),
      Paint()..color = color.withOpacity(0.92),
    );
  }

  @override
  bool shouldRepaint(_GraffitiPainter old) =>
      old.variant != variant ||
      old.color != color ||
      old.rotate != rotate ||
      old.grime != grime ||
      old.drip != drip;
}
