import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../providers/match_provider.dart';
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

  static const _durations = {
    'eye_swarm': Duration(milliseconds: 3000),
    'flash': Duration(milliseconds: 1200),
    'photo_bomb': Duration(milliseconds: 3600),
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
  }

  @override
  void dispose() {
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
                child: LineEyeIcon(size: d.size, color: Colors.white),
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
    return Container(color: Colors.white.withOpacity(opacity));
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
              borderRadius: BorderRadius.circular(12),
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
