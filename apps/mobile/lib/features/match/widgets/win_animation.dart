import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class WinAnimation extends StatelessWidget {
  final bool won;

  const WinAnimation({super.key, required this.won});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // TODO: add Lottie JSON assets at assets/animations/{win,lose}.json
          // and register them in pubspec.yaml under flutter.assets
          Icon(
            won ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
            color: won ? Colors.amber : Colors.white54,
            size: 96,
          ),
          const SizedBox(height: 24),
          Text(
            won ? 'You won! 🏆' : 'You blinked! 😅',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
