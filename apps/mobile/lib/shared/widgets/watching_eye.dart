import 'package:flutter/material.dart';
import 'line_eye.dart';

/// The canonical animated "watching eye" — rotating dial rings, an outward
/// pulse, and a blinking eye whose iris wanders on a slow path. This is the
/// home screen's eye, reused everywhere an eye graphic appears so every
/// representation of the eye in the app is the same.
///
/// Set [crying] to add falling tears (strictly black & white, no color
/// change) for the match-abandoned screen.
class WatchingEye extends StatefulWidget {
  final double height;
  final bool wander;
  final bool crying;
  final Color color;
  final Color background;

  const WatchingEye({
    super.key,
    this.height = 230,
    this.wander = true,
    this.crying = false,
    this.color = Colors.white,
    this.background = Colors.black,
  });

  @override
  State<WatchingEye> createState() => _WatchingEyeState();
}

class _WatchingEyeState extends State<WatchingEye>
    with TickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  late final AnimationController _arcCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _wanderCtrl;
  late final AnimationController _tearCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();
    _arcCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 32))
          ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();
    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4600))
      ..repeat();
    _wanderCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 11))
          ..repeat();
    _tearCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    _arcCtrl.dispose();
    _pulseCtrl.dispose();
    _blinkCtrl.dispose();
    _wanderCtrl.dispose();
    _tearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: Listenable.merge(
              [_rotCtrl, _arcCtrl, _pulseCtrl, _blinkCtrl, _wanderCtrl, _tearCtrl]),
          builder: (context, _) => CustomPaint(
            size: Size(constraints.maxWidth, widget.height),
            painter: _WatchingEyePainter(
              rotation: _rotCtrl.value,
              arcRotation: _arcCtrl.value,
              pulse: _pulseCtrl.value,
              blink: _blinkCtrl.value,
              wander: widget.wander ? _wanderCtrl.value : 0,
              crying: widget.crying,
              tearPhase: _tearCtrl.value,
              color: widget.color,
              background: widget.background,
            ),
          ),
        ),
      ),
    );
  }
}

class _WatchingEyePainter extends CustomPainter {
  final double rotation;
  final double arcRotation;
  final double pulse;
  final double blink;
  final double wander;
  final bool crying;
  final double tearPhase;
  final Color color;
  final Color background;

  const _WatchingEyePainter({
    required this.rotation,
    required this.arcRotation,
    required this.pulse,
    required this.blink,
    required this.wander,
    required this.crying,
    required this.tearPhase,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.height;
    LineEye.drawRings(canvas, center, base,
        rotation: rotation, arcRotation: arcRotation, color: color);
    LineEye.drawPulseRings(canvas, center, base, pulse, color: color);
    LineEye.drawEye(
      canvas,
      center,
      base,
      blink: blink,
      wander: wander,
      crying: crying,
      tearPhase: tearPhase,
      color: color,
      background: background,
    );
  }

  @override
  bool shouldRepaint(_WatchingEyePainter old) =>
      old.rotation != rotation ||
      old.arcRotation != arcRotation ||
      old.pulse != pulse ||
      old.blink != blink ||
      old.wander != wander ||
      old.crying != crying ||
      old.tearPhase != tearPhase ||
      old.color != color ||
      old.background != background;
}
