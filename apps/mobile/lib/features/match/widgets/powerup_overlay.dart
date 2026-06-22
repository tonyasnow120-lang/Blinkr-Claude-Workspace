import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/match_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/graffiti_highlight.dart';
import '../../../shared/widgets/line_eye.dart';

/// Full-screen, screen-space rendering of a power-up the opponent fired.
/// Purely visual — taps pass through. New effect types (including
/// face-anchored AR lenses planned for v1.1) get a new case in [_buildEffect];
/// unknown types complete immediately so older clients tolerate newer servers.
class PowerUpOverlay extends StatefulWidget {
  final PowerUpEvent event;
  final VoidCallback onDone;

  const PowerUpOverlay({super.key, required this.event, required this.onDone});

  @override
  State<PowerUpOverlay> createState() => _PowerUpOverlayState();
}

class _PowerUpOverlayState extends State<PowerUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _random = math.Random();
  late final List<_Drifter> _drifters;

  Timer? _hapticTimer;

  static const _durations = {
    'eye_swarm': Duration(milliseconds: 3000),
    'flash': Duration(milliseconds: 1200),
    'photo_bomb': Duration(milliseconds: 3600),
    'shake': Duration(milliseconds: 2200),
    'glitch': Duration(milliseconds: 1800),
    'taunt': Duration(milliseconds: 2400),
  };

  @override
  void initState() {
    super.initState();
    _drifters = List.generate(14, (_) => _Drifter.random(_random));
    _controller = AnimationController(
      vsync: this,
      duration:
          _durations[widget.event.type] ?? const Duration(milliseconds: 1),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();

    // Shake rattles the victim's phone with a burst of heavy haptics — the
    // physical jolt is most of the distraction; the visual is secondary.
    if (widget.event.type == 'shake') {
      HapticFeedback.heavyImpact();
      _hapticTimer = Timer.periodic(const Duration(milliseconds: 160), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        HapticFeedback.heavyImpact();
      });
    }
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _buildEffect(context, _controller.value),
      ),
    );
  }

  Widget _buildEffect(BuildContext context, double t) {
    switch (widget.event.type) {
      case 'eye_swarm':
        return _eyeSwarm(context, t);
      case 'flash':
        return _flash(t);
      case 'photo_bomb':
        return _photoBomb(context, t);
      case 'shake':
        return _shake(t);
      case 'glitch':
        return _glitch(t);
      case 'taunt':
        return _taunt(context, t);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _eyeSwarm(BuildContext context, double t) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        for (final d in _drifters)
          Positioned(
            left: (d.start.dx + d.velocity.dx * t) * size.width,
            top: (d.start.dy + d.velocity.dy * t) * size.height,
            child: Opacity(
              opacity: math.sin(math.pi * ((t + d.phase) % 1.0)) * 0.9,
              child: Transform.rotate(
                angle: math.sin((t + d.phase) * math.pi * 4) * 0.25,
                child: LineEyeIcon(size: d.size, color: AppColors.dark.foreground),
              ),
            ),
          ),
      ],
    );
  }

  Widget _flash(double t) {
    // Three quick white pulses.
    var opacity = 0.0;
    for (var k = 0; k < 3; k++) {
      final center = 0.15 + 0.3 * k;
      final tri = (1 - (t - center).abs() / 0.12).clamp(0.0, 1.0);
      opacity = math.max(opacity, tri * 0.85);
    }
    return Container(color: AppColors.dark.foreground.withOpacity(opacity));
  }

  /// Jitters an acid frame around the screen edges in time with the haptic
  /// burst fired from initState.
  Widget _shake(double t) {
    final intensity = (1 - t).clamp(0.0, 1.0);
    final dx = (_random.nextDouble() - 0.5) * 18 * intensity;
    final dy = (_random.nextDouble() - 0.5) * 18 * intensity;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.acid.withOpacity(0.55 * intensity),
            width: 6,
          ),
        ),
      ),
    );
  }

  /// RGB-split slices + scanlines that flicker over the opponent's feed.
  Widget _glitch(double t) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GlitchPainter(_random, t),
    );
  }

  /// A big acid graffiti word that sweeps across the screen with a wobble.
  Widget _taunt(BuildContext context, double t) {
    final size = MediaQuery.of(context).size;
    final x = (1.2 - 2.4 * t) * size.width;
    final wobble = math.sin(t * math.pi * 6) * 10;
    final appear = math.sin(math.pi * t).clamp(0.0, 1.0);
    return Stack(
      children: [
        Positioned(
          top: size.height * 0.42 + wobble,
          left: x,
          child: Opacity(
            opacity: appear,
            child: Transform.rotate(
              angle: -0.08,
              child: GraffitiHighlight(
                child: const Text(
                  'BLINK!',
                  style: TextStyle(
                    color: AppColors.acidInk,
                    fontSize: 54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoBomb(BuildContext context, double t) {
    final size = MediaQuery.of(context).size;
    final photos = widget.event.photoUrls;
    if (photos.isEmpty) return const SizedBox.shrink();
    final n = photos.length;
    return Stack(
      children: [
        for (var i = 0; i < n; i++)
          _photoTile(size, photos[i], i, n, t),
      ],
    );
  }

  Widget _photoTile(Size size, String url, int i, int n, double t) {
    // Each photo pops in/out within its own window of the timeline.
    final windowStart = i / (n + 1);
    final windowLen = 2.5 / (n + 1);
    final local = ((t - windowStart) / windowLen).clamp(0.0, 1.0);
    if (local <= 0 || local >= 1) return const SizedBox.shrink();
    final pop = math.sin(math.pi * local);

    final d = _drifters[i % _drifters.length];
    final w = size.width * 0.45;
    return Positioned(
      left: d.start.dx * (size.width - w),
      top: d.start.dy * (size.height - w),
      child: Opacity(
        opacity: pop.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: (d.phase - 0.5) * 0.6,
          child: Transform.scale(
            scale: 0.7 + 0.3 * pop,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                url,
                width: w,
                height: w,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws flickering RGB-split bands and faint scanlines for the glitch
/// power-up. Re-randomises every frame so the distortion crackles.
class _GlitchPainter extends CustomPainter {
  final math.Random r;
  final double t;

  _GlitchPainter(this.r, this.t);

  static const _bandColors = [
    Color(0xFF00FFFF), // cyan
    Color(0xFFFF00FF), // magenta
    AppColors.acid,
    AppColors.chalk,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final intensity = math.sin(math.pi * t);
    if (intensity <= 0) return;

    for (var i = 0; i < 14; i++) {
      if (r.nextDouble() > 0.65) continue;
      final y = r.nextDouble() * size.height;
      final h = 4 + r.nextDouble() * 30;
      final dx = (r.nextDouble() - 0.5) * 70 * intensity;
      final color = _bandColors[r.nextInt(_bandColors.length)]
          .withOpacity(0.35 * intensity);
      canvas.drawRect(
        Rect.fromLTWH(dx, y, size.width, h),
        Paint()
          ..color = color
          ..blendMode = BlendMode.screen,
      );
    }

    final scan = Paint()..color = AppColors.dark.background.withOpacity(0.12 * intensity);
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.5), scan);
    }
  }

  @override
  bool shouldRepaint(_GlitchPainter old) => true;
}

class _Drifter {
  final Offset start;
  final Offset velocity;
  final double size;
  final double phase;

  _Drifter(this.start, this.velocity, this.size, this.phase);

  factory _Drifter.random(math.Random r) => _Drifter(
        Offset(r.nextDouble(), r.nextDouble()),
        Offset(r.nextDouble() * 0.5 - 0.25, r.nextDouble() * 0.5 - 0.25),
        20 + r.nextDouble() * 40,
        r.nextDouble(),
      );
}
