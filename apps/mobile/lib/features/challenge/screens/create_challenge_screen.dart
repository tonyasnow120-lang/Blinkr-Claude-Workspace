import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/graffiti_highlight.dart';
import '../../../shared/widgets/line_eye.dart';
import '../../matchmaking/providers/matchmaking_provider.dart';

/// Challenger-side waiting screen for every matchmaking flow.
///
/// kind 'link' (default): creates a shareable challenge — code, copy and
/// native share sheet. kind 'friend'/'contact'/'proximity' (with
/// [opponentId]): sends a targeted invite and waits.
///
/// In all cases the screen listens for the opponent joining via Realtime
/// and navigates both players into the shared lobby automatically.
class CreateChallengeScreen extends ConsumerStatefulWidget {
  final String kind;
  final String? opponentId;
  final String? opponentName;

  const CreateChallengeScreen({
    super.key,
    this.kind = 'link',
    this.opponentId,
    this.opponentName,
  });

  @override
  ConsumerState<CreateChallengeScreen> createState() =>
      _CreateChallengeScreenState();
}

class _CreateChallengeScreenState
    extends ConsumerState<CreateChallengeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(matchmakingNotifierProvider.notifier).createChallenge(
            kind: widget.kind,
            opponentId: widget.opponentId,
          ),
    );
  }

  Future<void> _share(MatchmakingState state) async {
    final link = state.deepLink;
    if (link == null) return;
    await Share.share(
      'Think you can outstare me? 👁️ Accept my Blinkr challenge: $link',
      subject: 'Blinkr challenge',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingNotifierProvider);

    ref.listen(matchmakingNotifierProvider, (prev, next) {
      if (next.phase == MatchmakingPhase.ready && next.matchData != null) {
        final matchId = next.matchData!['matchId'] as String;
        context.pushReplacement('/match/$matchId/lobby', extra: next.matchData);
      }
    });

    final targeted = widget.opponentId != null;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.foreground,
        title: const Text('Challenge'),
        actions: const [MusicToggleButton()],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.12,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.05,
                  child: LineEyeIcon(size: 300, color: colors.foreground),
                ),
              ),
            ),
            Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.phase == MatchmakingPhase.creating ||
                  state.phase == MatchmakingPhase.idle)
                Center(
                    child: CircularProgressIndicator(color: colors.foreground))
              else if (state.phase == MatchmakingPhase.error)
                Column(
                  children: [
                    Text(
                      state.error?.message ?? 'Something went wrong.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref
                          .read(matchmakingNotifierProvider.notifier)
                          .createChallenge(
                            kind: widget.kind,
                            opponentId: widget.opponentId,
                          ),
                      child: Text('Retry',
                          style: TextStyle(color: colors.foreground)),
                    ),
                  ],
                )
              else if (targeted) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'CHALLENGE A ',
                      style: TextStyle(
                        color: colors.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 5,
                      ),
                    ),
                    GraffitiHighlight(
                      child: Text(
                        'FRIEND',
                        style: TextStyle(
                          color: AppColors.acidInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LineEyeIcon(size: 56, color: colors.foreground),
                const SizedBox(height: 24),
                Text(
                  'Challenge sent to ${widget.opponentName ?? 'your opponent'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.foreground, fontSize: 20),
                ),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: colors.foreground, strokeWidth: 2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Waiting for them to accept…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.ink(0.5)),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'CHALLENGE A ',
                      style: TextStyle(
                        color: colors.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 5,
                      ),
                    ),
                    GraffitiHighlight(
                      child: Text(
                        'FRIEND',
                        style: TextStyle(
                          color: AppColors.acidInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: colors.ink(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    state.code ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _share(state),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share invite link'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.foreground,
                    foregroundColor: colors.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    final link = state.deepLink;
                    if (link == null) return;
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.foreground,
                    side: BorderSide(color: colors.ink(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Waiting for opponent…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.ink(0.5)),
                ),
              ],
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}
