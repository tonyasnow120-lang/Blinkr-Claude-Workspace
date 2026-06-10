import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/api/api_endpoints.dart';

/// Shown immediately after a session is established (Google, Apple, OTP or
/// magic link). Plays the success animation while the profile lookup runs
/// concurrently, then routes to /profile (existing profile) or /setup-profile
/// (first sign-in). The exit fade lands on black, matching the background of
/// both destinations, so the hand-off reads as one continuous transition.
///
/// [returning] marks a cold start with an existing session: the full sequence
/// plays compressed to 1.5s so frequent opens don't feel slow.
class SignInSuccessScreen extends ConsumerStatefulWidget {
  final bool returning;

  const SignInSuccessScreen({super.key, this.returning = false});

  @override
  ConsumerState<SignInSuccessScreen> createState() =>
      _SignInSuccessScreenState();
}

class _SignInSuccessScreenState extends ConsumerState<SignInSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _seqCtrl;
  late final AnimationController _rotCtrl;

  late final Animation<double> _canvasOpacity;
  late final Animation<double> _checkTrim;
  late final Animation<double> _pulse;
  late final Animation<double> _labelOpacity;
  late final Animation<double> _labelSlide;
  late final Animation<double> _welcomeOpacity;
  late final Animation<double> _welcomeSlide;
  late final Animation<double> _exitFade;

  late final Future<String> _destination;

  @override
  void initState() {
    super.initState();

    // Kick off the profile lookup immediately so it overlaps the animation
    // instead of adding latency after it.
    _destination = _resolveDestination();

    _rotCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();

    // All stage intervals are fractions of this duration, so a shorter
    // controller compresses the whole sequence proportionally.
    final durationMs = widget.returning ? 1500 : 2600;
    _seqCtrl = AnimationController(
        vsync: this, duration: Duration(milliseconds: durationMs));

    _canvasOpacity = CurvedAnimation(
      parent: _seqCtrl,
      curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
    );
    _checkTrim = CurvedAnimation(
      parent: _seqCtrl,
      curve: const Interval(0.16, 0.50, curve: Curves.easeOutCubic),
    );
    _pulse = CurvedAnimation(
      parent: _seqCtrl,
      curve: const Interval(0.50, 1.0, curve: Curves.easeOut),
    );
    _labelOpacity = CurvedAnimation(
      parent: _seqCtrl,
      curve: const Interval(0.42, 0.66, curve: Curves.easeOut),
    );
    _labelSlide = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(
        parent: _seqCtrl,
        curve: const Interval(0.42, 0.66, curve: Curves.easeOutCubic),
      ),
    );
    _welcomeOpacity = CurvedAnimation(
      parent: _seqCtrl,
      curve: const Interval(0.52, 0.78, curve: Curves.easeOut),
    );
    _welcomeSlide = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _seqCtrl,
        curve: const Interval(0.52, 0.78, curve: Curves.easeOutCubic),
      ),
    );
    _exitFade = CurvedAnimation(
      parent: _seqCtrl,
      curve: const Interval(0.88, 1.0, curve: Curves.easeIn),
    );

    _seqCtrl.forward();

    // Soft haptic as the checkmark completes (50% through the sequence).
    Future.delayed(Duration(milliseconds: durationMs ~/ 2), () {
      if (mounted) HapticFeedback.lightImpact();
    });

    _seqCtrl.addStatusListener((status) async {
      if (status != AnimationStatus.completed) return;
      final dest = await _destination;
      if (mounted) context.go(dest);
    });
  }

  Future<String> _resolveDestination() async {
    try {
      final api = ref.read(apiClientProvider);
      final profile = await api
          .getOrNull(ApiEndpoints.me)
          .timeout(const Duration(seconds: 5));
      // Existing users land on their profile page (the post-login hub);
      // first sign-ins go set one up.
      return profile != null ? '/profile' : '/setup-profile';
    } catch (_) {
      // Backend unreachable — profile screen shows its own error state.
      return '/profile';
    }
  }

  @override
  void dispose() {
    _seqCtrl.dispose();
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_seqCtrl, _rotCtrl]),
        builder: (_, __) => Opacity(
          opacity: 1.0 - _exitFade.value,
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Eye + rings with checkmark iris
                Opacity(
                  opacity: _canvasOpacity.value,
                  child: SizedBox(
                    width: size.width,
                    height: 220,
                    child: CustomPaint(
                      size: Size(size.width, 220),
                      painter: _SuccessEyePainter(
                        rotation: _rotCtrl.value,
                        checkTrim: _checkTrim.value,
                        pulse: _pulse.value,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 44),

                Opacity(
                  opacity: _labelOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _labelSlide.value),
                    child: const Text(
                      'SIGNED IN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 4.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Opacity(
                  opacity: _welcomeOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _welcomeSlide.value),
                    child: const Text(
                      'WELCOME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 10,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Same visual language as the login eye: rotating tick rings around the eye
/// outline, but the iris holds a checkmark that draws itself in, followed by
/// a single expanding pulse ring.
class _SuccessEyePainter extends CustomPainter {
  final double rotation;
  final double checkTrim;
  final double pulse;

  const _SuccessEyePainter({
    required this.rotation,
    required this.checkTrim,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    _drawRings(canvas, center, size);
    _drawPulse(canvas, center, size);
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
    canvas.rotate(-rotation * math.pi * 2 * 0.6);
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

  void _drawPulse(Canvas canvas, Offset center, Size size) {
    if (pulse <= 0.001 || pulse >= 0.999) return;
    final baseR = size.width * 0.194;
    final alpha = ((1 - pulse) * 110).round();
    if (alpha <= 0) return;
    canvas.drawCircle(
      center,
      baseR * (0.9 + pulse * 1.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Colors.white.withAlpha(alpha),
    );
  }

  void _drawEye(Canvas canvas, Offset center, Size size) {
    final eyeW = size.width * 0.31;
    final eyeH = eyeW * 0.44;

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

    // Checkmark replaces the pupil — drawn progressively via path trim.
    if (checkTrim > 0.001) {
      final check = Path()
        ..moveTo(center.dx - irisR * 0.42, center.dy + irisR * 0.02)
        ..lineTo(center.dx - irisR * 0.10, center.dy + irisR * 0.34)
        ..lineTo(center.dx + irisR * 0.46, center.dy - irisR * 0.30);

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
  bool shouldRepaint(_SuccessEyePainter old) => true;
}
