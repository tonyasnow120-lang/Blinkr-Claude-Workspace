import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/countdown_overlay.dart';
import '../../../core/theme/app_colors.dart';

class CountdownScreen extends ConsumerWidget {
  final String matchId;
  final DateTime startsAt;

  const CountdownScreen({
    super.key,
    required this.matchId,
    required this.startsAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CountdownOverlay(
            startsAt: startsAt,
            onComplete: () {
              context.pushReplacement('/match/$matchId/contest');
            },
          ),
        ],
      ),
    );
  }
}
