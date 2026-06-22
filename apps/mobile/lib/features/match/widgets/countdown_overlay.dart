import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/audio/countdown_sound.dart';
import '../../../core/theme/app_colors.dart';

class CountdownOverlay extends StatefulWidget {
  final DateTime startsAt;
  final VoidCallback onComplete;

  const CountdownOverlay({
    super.key,
    required this.startsAt,
    required this.onComplete,
  });

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay> {
  late Timer _timer;
  int _remaining = 3;
  final _sound = CountdownSoundPlayer();
  int? _lastAnnounced;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    final diff = widget.startsAt.difference(now).inSeconds;
    if (diff <= 0) {
      _timer.cancel();
      if (_lastAnnounced != 0) {
        _lastAnnounced = 0;
        _sound.playGo();
      }
      if (mounted) widget.onComplete();
    } else {
      if (diff != _lastAnnounced) {
        _lastAnnounced = diff;
        _sound.playTick();
      }
      if (mounted) setState(() => _remaining = diff);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _sound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.dark.background.withOpacity(0.7),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            '$_remaining',
            key: ValueKey(_remaining),
            style: const TextStyle(
              color: AppColors.dark.foreground,
              fontSize: 120,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
