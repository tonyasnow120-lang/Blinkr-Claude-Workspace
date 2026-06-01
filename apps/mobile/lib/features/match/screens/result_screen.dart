import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/match_provider.dart';
import '../widgets/win_animation.dart';
import '../../../core/security/screen_security.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String matchId;

  const ResultScreen({super.key, required this.matchId});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  @override
  void initState() {
    super.initState();
    // Block screenshots of result screen to protect match outcome privacy (GAP-15)
    ScreenSecurity.enableSecureMode();
  }

  @override
  void dispose() {
    ScreenSecurity.disableSecureMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchNotifierProvider(widget.matchId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final result = matchState.result;
    final abandoned = matchState.phase == MatchPhase.abandoned;

    final won = result != null && result.winnerId == currentUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (result != null)
            WinAnimation(won: won)
          else if (abandoned)
            const Center(
              child: Text(
                'Match abandoned',
                style: TextStyle(color: Colors.white54, fontSize: 24),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(
            bottom: 48,
            left: 32,
            right: 32,
            child: SafeArea(
              child: Column(
                children: [
                  if (result != null) ...[
                    Text(
                      'Duration: ${((result.durationMs ?? 0) / 1000).toStringAsFixed(1)}s',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reason: ${result.reason}',
                      style: TextStyle(color: Colors.white.withOpacity(0.4)),
                    ),
                    const SizedBox(height: 24),
                  ],
                  FilledButton(
                    onPressed: () => context.go('/home'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
