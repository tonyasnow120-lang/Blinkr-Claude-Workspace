import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class WinAnimation extends StatelessWidget {
  final bool won;

  const WinAnimation({super.key, required this.won});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.dark.background.withOpacity(0.85),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // TODO: add Lottie JSON assets at assets/animations/{win,lose}.json
          // and register them in pubspec.yaml under flutter.assets
          Icon(
            won ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
            color: won ? AppColors.acid : AppColors.dark.ink(0.54),
            size: 96,
          ),
          const SizedBox(height: 24),
          Text(
            won ? 'YOU WON' : 'YOU BLINKED',
            style: const TextStyle(
              color: AppColors.chalk,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
