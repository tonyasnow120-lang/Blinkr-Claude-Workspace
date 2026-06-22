import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/match_provider.dart';
import '../widgets/win_animation.dart';
import '../widgets/crying_eye_animation.dart';
import '../../../core/security/screen_security.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';

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
      backgroundColor: context.colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (result != null)
            WinAnimation(won: won)
          else if (abandoned)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CryingEyeAnimation(),
                  const SizedBox(height: 16),
                  Text(
                    'MATCH ABANDONED',
                    style: TextStyle(color: AppColors.dark.ink(0.54), fontSize: 24),
                  ),
                ],
              ),
            )
          else
            Center(child: CircularProgressIndicator(color: context.colors.foreground)),
          Positioned(
            bottom: 48,
            left: 32,
            right: 32,
            child: SafeArea(
              child: Column(
                children: [
                  if (result != null) ...[
                    Text(
                      'DURATION: ${((result.durationMs ?? 0) / 1000).toStringAsFixed(1)}S',
                      style: TextStyle(color: context.colors.ink(0.6)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'REASON: ${result.reason.toUpperCase()}',
                      style: TextStyle(color: context.colors.ink(0.4)),
                    ),
                    const SizedBox(height: 24),
                  ],
                  FilledButton(
                    onPressed: () => context.go('/home'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.foreground,
                      foregroundColor: context.colors.background,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'BACK TO HOME',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 8,
            right: 8,
            child: SafeArea(child: MusicToggleButton()),
          ),
        ],
      ),
    );
  }
}
