import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/match_provider.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String matchId;
  final Map<String, dynamic> matchData;

  const LobbyScreen({
    super.key,
    required this.matchId,
    required this.matchData,
  });

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchNotifierProvider(widget.matchId));

    ref.listen(matchNotifierProvider(widget.matchId), (prev, next) {
      if (next.phase == MatchPhase.countdown) {
        context.pushReplacement(
          '/match/${widget.matchId}/countdown',
          extra: {'startsAt': next.countdownStartsAt?.toIso8601String()},
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Lobby',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              if (!_ready)
                FilledButton(
                  onPressed: () async {
                    setState(() => _ready = true);
                    await ref
                        .read(matchNotifierProvider(widget.matchId).notifier)
                        .markReady();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "I'm Ready",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                )
              else
                Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Waiting for opponent…',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
