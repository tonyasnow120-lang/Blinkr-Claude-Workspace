import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final AnimationController _rotCtrl;
  late final AnimationController _arcCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _entranceCtrl;

  late final Animation<double> _wordOpacity;
  late final Animation<double> _wordSlide;
  late final Animation<double> _btnOpacity;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();

    _rotCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();

    _arcCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 32))
      ..repeat();

    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3800))
      ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1900));

    _wordOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.18, 0.65, curve: Curves.easeOut),
    );

    _wordSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.18, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _btnOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotCtrl.dispose();
    _arcCtrl.dispose();
    _blinkCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final size = MediaQuery.sizeOf(context);
    final eyeCenterY = size.height * 0.38;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Continuous background animations
          AnimatedBuilder(
            animation:
                Listenable.merge([_pulseCtrl, _rotCtrl, _arcCtrl, _blinkCtrl]),
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _SplashPainter(
                pulse: _pulseCtrl.value,
                rotation: _rotCtrl.value,
                arcRotation: _arcCtrl.value,
                blink: _blinkCtrl.value,
                eyeCenterY: eyeCenterY,
              ),
            ),
          ),

          // Wordmark
          Positioned(
            bottom: size.height * 0.275,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _entranceCtrl,
              builder: (_, child) => Opacity(
                opacity: _wordOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _wordSlide.value),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'BLINKR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w200,
                          letterSpacing: 13,
                        ),
                      ),
                      const SizedBox(width: 3),
                      _BlinkingCursor(),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Container(
                    width: 40,
                    height: 0.5,
                    color: Colors.white.withAlpha(71),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    'FIRST TO BLINK LOSES.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Get Started button
          Positioned(
            bottom: 48,
            left: 40,
            right: 40,
            child: AnimatedBuilder(
              animation: _btnOpacity,
              builder: (_, child) =>
                  Opacity(opacity: _btnOpacity.value, child: child),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.push('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'GET STARTED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Music toggle
          const Positioned(
            top: 8,
            right: 8,
            child: SafeArea(child: MusicToggleButton()),
          ),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
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
        child: const Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: Text(
            '|',
            style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w100),
          ),
        ),
      );
}

class _SplashPainter extends CustomPainter {
  final double pulse;
  final double rotation;
  final double arcRotation;
  final double blink;
  final double eyeCenterY;

  const _SplashPainter({
    required this.pulse,
    required this.rotation,
    required this.arcRotation,
    required this.blink,
    required this.eyeCenterY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, eyeCenterY);
    _drawRings(canvas, center, size);
    _drawPulseRings(canvas, center, size);
    _drawEye(canvas, center, size);
  }

  void _drawRings(Canvas canvas, Offset center, Size size) {
    final innerR = size.width * 0.335;
    final outerR = size.width * 0.487;
    final p = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // inner clockwise
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi * 2);
    for (int i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final isMajor = i % 6 == 0;
      p.color = Colors.white.withAlpha(isMajor ? 128 : 31);
      final len = isMajor ? 12.0 : 6.0;
      canvas.drawLine(
        Offset(math.cos(a) * (innerR - len), math.sin(a) * (innerR - len)),
        Offset(math.cos(a) * innerR, math.sin(a) * innerR),
        p,
      );
    }
    canvas.restore();

    // outer counter-clockwise
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-arcRotation * math.pi * 2);
    for (int i = 0; i < 36; i++) {
      final a = i * math.pi / 18;
      final isLong = i % 3 == 0;
      p.color = Colors.white.withAlpha(isLong ? 56 : 13);
      final len = isLong ? 10.0 : 5.0;
      canvas.drawLine(
        Offset(math.cos(a) * (outerR - len), math.sin(a) * (outerR - len)),
        Offset(math.cos(a) * outerR, math.sin(a) * outerR),
        p,
      );
    }
    canvas.restore();
  }

  void _drawPulseRings(Canvas canvas, Offset center, Size size) {
    final baseR = size.width * 0.365;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 0; i < 3; i++) {
      final t = (pulse + i / 3.0) % 1.0;
      final scale = 0.08 + t * 2.85;
      final alpha = t < 0.15
          ? ((t / 0.15) * 153).round()
          : ((1 - t) * 153).round();
      if (alpha <= 0) continue;
      p.color = Colors.white.withAlpha(alpha);
      canvas.drawCircle(center, baseR * scale, p);
    }
  }

  void _drawEye(Canvas canvas, Offset center, Size size) {
    final eyeW = size.width * 0.285;
    final eyeH = eyeW * 0.44;

    // Double-blink envelope: two blink events per cycle
    double lidT = 0.0;
    final t = blink;
    if (t >= 0.28 && t <= 0.37) {
      final bt = (t - 0.28) / 0.09;
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

    final irisScale = 1.0 - lidT * 0.08;
    final irisR = eyeH * 0.88;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(irisScale, irisScale);
    canvas.translate(-center.dx, -center.dy);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withAlpha(230);

    canvas.drawCircle(center, irisR, strokePaint);

    strokePaint.color = Colors.white.withAlpha(76);
    strokePaint.strokeWidth = 0.5;
    canvas.drawCircle(center, irisR * 0.7, strokePaint);

    canvas.drawCircle(center, irisR * 0.44, Paint()..color = Colors.white);

    canvas.drawCircle(
      Offset(center.dx + irisR * 0.27, center.dy - irisR * 0.3),
      irisR * 0.17,
      Paint()..color = Colors.black.withAlpha(140),
    );

    canvas.restore();

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
  }

  @override
  bool shouldRepaint(_SplashPainter old) =>
      old.pulse != pulse ||
      old.rotation != rotation ||
      old.arcRotation != arcRotation ||
      old.blink != blink;
}
