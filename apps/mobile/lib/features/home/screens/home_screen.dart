import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';
import '../../profile/providers/profile_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  late final AnimationController _arcCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _wanderCtrl;
  late final AnimationController _entranceCtrl;

  late final Animation<double> _headerOpacity;
  late final Animation<double> _headerSlide;
  late final Animation<double> _eyeOpacity;
  late final Animation<double> _statsOpacity;
  late final Animation<double> _btnOpacity;
  late final Animation<double> _btnSlide;

  @override
  void initState() {
    super.initState();

    _rotCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();

    _arcCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 32))
      ..repeat();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();

    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4600))
      ..repeat();

    // Slow Lissajous wander — the iris drifts around, sizing you up.
    _wanderCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 11))
      ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));

    _headerOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _headerSlide = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
      ),
    );
    _eyeOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.18, 0.60, curve: Curves.easeOut),
    );
    _statsOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.42, 0.78, curve: Curves.easeOut),
    );
    _btnOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.58, 1.0, curve: Curves.easeOut),
    );
    _btnSlide = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.58, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    _arcCtrl.dispose();
    _pulseCtrl.dispose();
    _blinkCtrl.dispose();
    _wanderCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final size = MediaQuery.sizeOf(context);
    final profile = ref.watch(profileProvider);

    final displayName = profile.maybeWhen(
      data: (data) {
        final user = data['users'] as Map<String, dynamic>?;
        // Drizzle serializes columns with camelCase keys
        return (user?['displayName'] ??
            user?['display_name'] ??
            user?['username']) as String?;
      },
      orElse: () => null,
    );
    final stats = profile.maybeWhen(
      data: (data) => data['user_stats'] as Map<String, dynamic>?,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'BLINKR',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        actions: [
          const MusicToggleButton(),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            // Home is normally pushed from the profile hub — pop back to it
            // rather than stacking another copy. Push covers deep links.
            onPressed: () =>
                context.canPop() ? context.pop() : context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _entranceCtrl,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Greeting + headline + cycling tagline
              Opacity(
                opacity: _headerOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _headerSlide.value),
                  child: Column(
                    children: [
                      if (displayName != null) ...[
                        Text(
                          'WELCOME BACK, ${displayName.toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(115),
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 3.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      const Text(
                        'READY TO STARE?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w200,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _TaglineCycler(),
                    ],
                  ),
                ),
              ),

              // The eye, staring back
              Opacity(
                opacity: _eyeOpacity.value,
                child: SizedBox(
                  height: 230,
                  child: AnimatedBuilder(
                    animation: Listenable.merge(
                        [_rotCtrl, _arcCtrl, _pulseCtrl, _blinkCtrl, _wanderCtrl]),
                    builder: (_, __) => CustomPaint(
                      size: Size(size.width, 230),
                      painter: _WatchingEyePainter(
                        rotation: _rotCtrl.value,
                        arcRotation: _arcCtrl.value,
                        pulse: _pulseCtrl.value,
                        blink: _blinkCtrl.value,
                        wander: _wanderCtrl.value,
                      ),
                    ),
                  ),
                ),
              ),

              // Live record strip
              Opacity(
                opacity: _statsOpacity.value,
                child: stats == null
                    ? const SizedBox(height: 14)
                    : _StatsStrip(stats: stats),
              ),

              const Spacer(flex: 2),

              // Actions
              Opacity(
                opacity: _btnOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _btnSlide.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => context.push('/challenge/create'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'CHALLENGE A FRIEND',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => context.push('/challenge/join'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withAlpha(115),
                                width: 0.8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'JOIN WITH A CODE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rotates through taglines with a cross-fade every few seconds.
class _TaglineCycler extends StatefulWidget {
  const _TaglineCycler();

  @override
  State<_TaglineCycler> createState() => _TaglineCyclerState();
}

class _TaglineCyclerState extends State<_TaglineCycler> {
  static const _lines = [
    'FIRST TO BLINK LOSES.',
    'STARE THEM DOWN.',
    'NO MERCY. NO BLINKING.',
    'HOLD YOUR NERVE.',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      child: Text(
        _lines[_index],
        key: ValueKey(_index),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withAlpha(140),
          fontSize: 9.5,
          fontWeight: FontWeight.w300,
          letterSpacing: 5,
        ),
      ),
    );
  }
}

/// Wins / streak / losses in the thin letterspaced strip style.
class _StatsStrip extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    Widget item(String label, Object? value) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${value ?? 0}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w200,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha(102),
                fontSize: 8,
                fontWeight: FontWeight.w400,
                letterSpacing: 3,
              ),
            ),
          ],
        );

    Widget divider() => Container(
          width: 0.5,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 28),
          color: Colors.white.withAlpha(46),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item('WINS', stats['wins']),
        divider(),
        item('STREAK', stats['currentStreak'] ?? stats['current_streak']),
        divider(),
        item('LOSSES', stats['losses']),
      ],
    );
  }
}

/// The welcome screen's eye, but alive: the iris wanders on a slow Lissajous
/// path as if sizing up its next opponent, with an occasional double-blink.
class _WatchingEyePainter extends CustomPainter {
  final double rotation;
  final double arcRotation;
  final double pulse;
  final double blink;
  final double wander;

  const _WatchingEyePainter({
    required this.rotation,
    required this.arcRotation,
    required this.pulse,
    required this.blink,
    required this.wander,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.height; // rings sized off canvas height, not screen width
    _drawRings(canvas, center, base);
    _drawPulseRings(canvas, center, base);
    _drawEye(canvas, center, base);
  }

  void _drawRings(Canvas canvas, Offset center, double base) {
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

  void _drawPulseRings(Canvas canvas, Offset center, double base) {
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

  void _drawEye(Canvas canvas, Offset center, double base) {
    final eyeW = base * 0.62;
    final eyeH = eyeW * 0.44;

    // Double-blink envelope (same cadence family as the welcome screen)
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

    // Lissajous wander, eased to zero while blinking so the eye re-centers
    final wa = wander * math.pi * 2;
    final gaze = Offset(
      math.sin(wa) * math.cos(wa * 0.7),
      math.sin(wa * 1.3) * 0.45,
    ) * (irisR * 0.28 * (1.0 - lidT));
    final irisCenter = center + gaze;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withAlpha(230);

    canvas.drawCircle(irisCenter, irisR, strokePaint);

    strokePaint.color = Colors.white.withAlpha(76);
    strokePaint.strokeWidth = 0.5;
    canvas.drawCircle(irisCenter, irisR * 0.7, strokePaint);

    canvas.drawCircle(
        irisCenter, irisR * 0.44, Paint()..color = Colors.white);

    canvas.drawCircle(
      Offset(irisCenter.dx + irisR * 0.27, irisCenter.dy - irisR * 0.3),
      irisR * 0.17,
      Paint()..color = Colors.black.withAlpha(140),
    );

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
  bool shouldRepaint(_WatchingEyePainter old) =>
      old.rotation != rotation ||
      old.arcRotation != arcRotation ||
      old.pulse != pulse ||
      old.blink != blink ||
      old.wander != wander;
}
