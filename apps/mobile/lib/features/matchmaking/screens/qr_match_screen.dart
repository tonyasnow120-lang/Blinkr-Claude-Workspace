import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/matchmaking_provider.dart';

/// QR matchmaking, display side (Feature 4). Shows a one-time challenge as
/// a QR code with a 60-second expiry countdown; auto-regenerates a fresh
/// code on expiry. Navigates to the lobby when the opponent scans and joins.
/// Leaving the screen cancels the pending challenge (autoDispose notifier).
class QrMatchScreen extends ConsumerStatefulWidget {
  const QrMatchScreen({super.key});

  @override
  ConsumerState<QrMatchScreen> createState() => _QrMatchScreenState();
}

class _QrMatchScreenState extends ConsumerState<QrMatchScreen> {
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_generate);
  }

  void _generate() {
    ref.read(matchmakingNotifierProvider.notifier).createChallenge(kind: 'qr');
  }

  void _startCountdown(DateTime expiresAt) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = expiresAt.difference(DateTime.now()).inSeconds;
      if (!mounted) return;
      if (left <= 0) {
        _ticker?.cancel();
        // Token expired before anyone scanned it — issue a fresh one.
        _generate();
      } else {
        setState(() => _secondsLeft = left);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingNotifierProvider);

    ref.listen(matchmakingNotifierProvider, (prev, next) {
      if (next.phase == MatchmakingPhase.ready && next.matchData != null) {
        _ticker?.cancel();
        final matchId = next.matchData!['matchId'] as String;
        context.pushReplacement('/match/$matchId/lobby', extra: next.matchData);
      } else if (next.phase == MatchmakingPhase.waiting &&
          prev?.challenge?['id'] != next.challenge?['id']) {
        final expiresAt = next.expiresAt;
        if (expiresAt != null) _startCountdown(expiresAt);
      }
    });

    final deepLink = state.deepLink;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.foreground,
        title: const Text('QR MATCH'),
        actions: const [MusicToggleButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.phase == MatchmakingPhase.error) ...[
                Text(
                  state.error?.message ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.red),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _generate,
                  child:
                      Text('RETRY', style: TextStyle(color: colors.foreground)),
                ),
              ] else if (deepLink == null)
                Center(
                    child: CircularProgressIndicator(color: colors.foreground))
              else ...[
                Text(
                  'HAVE YOUR OPPONENT SCAN THIS',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.foreground, fontSize: 20),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // QR spec requires high-contrast black-on-white for scanners.
                      color: const Color(0xFFF0EDE0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: QrImageView(
                      data: deepLink,
                      version: QrVersions.auto,
                      size: 240,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'New code in ${_secondsLeft}s',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.ink(0.5)),
                ),
                const SizedBox(height: 8),
                Text(
                  'WAITING FOR OPPONENT…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.ink(0.5)),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => context.push('/qr/scan'),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('SCAN THEIRS INSTEAD'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.foreground,
                    side: BorderSide(color: colors.ink(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
