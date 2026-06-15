import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/line_eye.dart';

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
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    final size = MediaQuery.sizeOf(context);
    final eyeCenterY = size.height * 0.38;

    return Scaffold(
      backgroundColor: colors.background,
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
                color: colors.foreground,
                background: colors.background,
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
                      Text(
                        'BLINKR',
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 34,
                          fontWeight: FontWeight.w200,
                          letterSpacing: 13,
                        ),
                      ),
                      const SizedBox(width: 3),
                      _BlinkingCursor(color: colors.foreground),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Container(
                    width: 40,
                    height: 0.5,
                    color: colors.ink(0.28),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    'FIRST TO BLINK LOSES.',
                    style: TextStyle(
                      color: colors.foreground,
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
                    backgroundColor: colors.foreground,
                    foregroundColor: colors.background,
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
  final Color color;
  const _BlinkingCursor({required this.color});

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
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            '|',
            style: TextStyle(
                color: widget.color,
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
  final Color color;
  final Color background;

  const _SplashPainter({
    required this.pulse,
    required this.rotation,
    required this.arcRotation,
    required this.blink,
    required this.eyeCenterY,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, eyeCenterY);
    final base = size.width;
    LineEye.drawRings(canvas, center, base,
        rotation: rotation, arcRotation: arcRotation, color: color);
    LineEye.drawPulseRings(canvas, center, base, pulse, color: color);
    LineEye.drawEye(canvas, center, base,
        blink: blink, color: color, background: background);
  }

  @override
  bool shouldRepaint(_SplashPainter old) =>
      old.pulse != pulse ||
      old.rotation != rotation ||
      old.arcRotation != arcRotation ||
      old.blink != blink ||
      old.color != color ||
      old.background != background;
}
