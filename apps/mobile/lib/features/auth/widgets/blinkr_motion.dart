import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The animated "watching eye" graphic shared by the auth screens — a
/// blinking eye surrounded by two slowly-rotating dial rings and an
/// outward pulse. Manages its own animation controllers, so it can be
/// dropped into any screen.
class BlinkrEyeGraphic extends StatefulWidget {
  final double height;

  const BlinkrEyeGraphic({super.key, this.height = 200});

  @override
  State<BlinkrEyeGraphic> createState() => _BlinkrEyeGraphicState();
}

class _BlinkrEyeGraphicState extends State<BlinkrEyeGraphic>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotCtrl;
  late final AnimationController _arcCtrl;
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();
    _rotCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();
    _arcCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 32))
          ..repeat();
    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000))
      ..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotCtrl.dispose();
    _arcCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      width: width,
      height: widget.height,
      child: AnimatedBuilder(
        animation:
            Listenable.merge([_pulseCtrl, _rotCtrl, _arcCtrl, _blinkCtrl]),
        builder: (_, __) => CustomPaint(
          size: Size(width, widget.height),
          painter: BlinkrEyePainter(
            pulse: _pulseCtrl.value,
            rotation: _rotCtrl.value,
            arcRotation: _arcCtrl.value,
            blink: _blinkCtrl.value,
          ),
        ),
      ),
    );
  }
}

/// Paints a blinking eye with two rotating dial rings and an outward pulse.
class BlinkrEyePainter extends CustomPainter {
  final double pulse;
  final double rotation;
  final double arcRotation;
  final double blink;

  const BlinkrEyePainter({
    required this.pulse,
    required this.rotation,
    required this.arcRotation,
    required this.blink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    _drawRings(canvas, center, size);
    _drawPulseRings(canvas, center, size);
    _drawEye(canvas, center, size);
  }

  void _drawRings(Canvas canvas, Offset center, Size size) {
    final innerR = size.width * 0.198;
    final outerR = size.width * 0.284;
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
      final len = isMajor ? 9.0 : 4.0;
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

  void _drawPulseRings(Canvas canvas, Offset center, Size size) {
    final baseR = size.width * 0.194;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 0; i < 3; i++) {
      final t = (pulse + i / 3.0) % 1.0;
      final scale = 0.08 + t * 2.85;
      final alpha = t < 0.15
          ? ((t / 0.15) * 128).round()
          : ((1 - t) * 128).round();
      if (alpha <= 0) continue;
      p.color = Colors.white.withAlpha(alpha);
      canvas.drawCircle(center, baseR * scale, p);
    }
  }

  void _drawEye(Canvas canvas, Offset center, Size size) {
    final eyeW = size.width * 0.31;
    final eyeH = eyeW * 0.44;

    double lidT = 0.0;
    final t = blink;
    if (t >= 0.30 && t <= 0.38) {
      final bt = (t - 0.30) / 0.08;
      lidT = bt < 0.5 ? bt * 2 : (1 - bt) * 2;
    } else if (t >= 0.42 && t <= 0.48) {
      final bt = (t - 0.42) / 0.06;
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
    final stroke = Paint()..style = PaintingStyle.stroke;

    stroke.strokeWidth = 1.1;
    stroke.color = Colors.white.withAlpha(230);
    canvas.drawCircle(center, irisR, stroke);

    stroke.strokeWidth = 0.5;
    stroke.color = Colors.white.withAlpha(76);
    canvas.drawCircle(center, irisR * 0.7, stroke);

    canvas.drawCircle(center, irisR * 0.44, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(center.dx + irisR * 0.27, center.dy - irisR * 0.3),
      irisR * 0.17,
      Paint()..color = Colors.black.withAlpha(140),
    );

    if (lidT > 0.001) {
      final lid = Paint()..color = Colors.black;
      final offset = eyeH * lidT;
      final pad = eyeW * 0.06;

      final upper = Path()
        ..moveTo(center.dx - eyeW / 2 - pad, center.dy)
        ..quadraticBezierTo(center.dx, center.dy - eyeH,
            center.dx + eyeW / 2 + pad, center.dy)
        ..lineTo(center.dx + eyeW / 2 + pad, center.dy - eyeH * 3)
        ..lineTo(center.dx - eyeW / 2 - pad, center.dy - eyeH * 3)
        ..close();

      final lower = Path()
        ..moveTo(center.dx - eyeW / 2 - pad, center.dy)
        ..quadraticBezierTo(center.dx, center.dy + eyeH,
            center.dx + eyeW / 2 + pad, center.dy)
        ..lineTo(center.dx + eyeW / 2 + pad, center.dy + eyeH * 3)
        ..lineTo(center.dx - eyeW / 2 - pad, center.dy + eyeH * 3)
        ..close();

      canvas.save();
      canvas.translate(0, offset);
      canvas.drawPath(upper, lid);
      canvas.restore();

      canvas.save();
      canvas.translate(0, -offset);
      canvas.drawPath(lower, lid);
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
  }

  @override
  bool shouldRepaint(BlinkrEyePainter old) => true;
}

/// The "BLINKR" wordmark with a blinking text-cursor, used on auth screens.
class BlinkrWordmark extends StatelessWidget {
  final double fontSize;

  const BlinkrWordmark({super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'BLINKR',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w200,
            letterSpacing: 10,
          ),
        ),
        const SizedBox(width: 3),
        BlinkrCursor(fontSize: fontSize - 2),
      ],
    );
  }
}

/// A blinking "|" text cursor, fading in and out on a loop.
class BlinkrCursor extends StatefulWidget {
  final double fontSize;
  const BlinkrCursor({super.key, this.fontSize = 32});

  @override
  State<BlinkrCursor> createState() => _BlinkrCursorState();
}

class _BlinkrCursorState extends State<BlinkrCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 960))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _ctrl,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            '|',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w100,
            ),
          ),
        ),
      );
}

/// A text field with an animated white underline that expands on focus,
/// matching the login screen's email field styling.
class UnderlineTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback? onSubmit;
  final String hintText;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  const UnderlineTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onSubmit,
    required this.hintText,
    this.textInputAction = TextInputAction.done,
    this.inputFormatters,
  });

  @override
  State<UnderlineTextField> createState() => _UnderlineTextFieldState();
}

class _UnderlineTextFieldState extends State<UnderlineTextField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lineCtrl;
  late final Animation<double> _lineWidth;
  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _lineWidth = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeOut);

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(() {
      _focusNode.hasFocus ? _lineCtrl.forward() : _lineCtrl.reverse();
    });
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: (_) => widget.onSubmit?.call(),
          autocorrect: false,
          inputFormatters: widget.inputFormatters,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: Colors.white.withAlpha(51),
              fontWeight: FontWeight.w200,
              letterSpacing: 0.5,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Colors.white.withAlpha(76), width: 0.5),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent, width: 0),
            ),
            contentPadding: const EdgeInsets.only(bottom: 8),
          ),
          cursorColor: Colors.white,
          cursorWidth: 1.2,
        ),
        AnimatedBuilder(
          animation: _lineWidth,
          builder: (_, __) => Container(
            height: 0.5,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _lineWidth.value,
              child: Container(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
