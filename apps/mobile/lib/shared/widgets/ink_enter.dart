import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// The signature screen-entrance motion: opacity 0→1, an 8px upward slide, and
/// a 4→0px de-blur, on the sharp-out curve `cubic-bezier(0.2,0,0,1)`. Wrap a
/// screen's content (or stagger children with increasing [delay]).
///
/// Honours reduced-motion: if the platform requests it, the child renders
/// immediately with no animation.
class InkEnter extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const InkEnter({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  State<InkEnter> createState() => _InkEnterState();
}

class _InkEnterState extends State<InkEnter>
    with SingleTickerProviderStateMixin {
  // Sharp-out easing — fast start, settled finish. No bounce, no overshoot.
  static const _sharpOut = Cubic(0.2, 0, 0, 1);

  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t =
      CurvedAnimation(parent: _ctrl, curve: _sharpOut);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion → skip the animation entirely.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final v = _t.value;
        final blur = (1 - v) * 4.0;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 8.0),
            child: blur < 0.01
                ? child
                : ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: child,
                  ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
