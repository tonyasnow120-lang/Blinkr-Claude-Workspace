import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/blinkr_button.dart';
import '../../../shared/widgets/ink_enter.dart';
import '../../../shared/widgets/ink_scaffold.dart';
import '../../../shared/widgets/watching_eye.dart';
import '../../matchmaking/providers/matchmaking_provider.dart';

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
      'THINK YOU CAN OUTSTARE ME? Accept my Blinkr challenge: $link',
      subject: 'BLINKR CHALLENGE',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingNotifierProvider);
    final colors = context.colors;
    final targeted = widget.opponentId != null;

    ref.listen(matchmakingNotifierProvider, (prev, next) {
      if (next.phase == MatchmakingPhase.ready && next.matchData != null) {
        final matchId = next.matchData!['matchId'] as String;
        context.pushReplacement('/match/$matchId/lobby', extra: next.matchData);
      }
    });

    return InkScaffold(
      splatSeed: 68,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back,
                        color: colors.foreground, size: 20),
                  ),
                  Text(
                    'CHALLENGE',
                    style: AppText.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: colors.foreground,
                      letterSpacing: 3,
                    ),
                  ),
                  const MusicToggleButton(),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _buildContent(state, colors, targeted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      MatchmakingState state, AppColors colors, bool targeted) {
    if (state.phase == MatchmakingPhase.creating ||
        state.phase == MatchmakingPhase.idle) {
      return _buildLoading(colors);
    }

    if (state.phase == MatchmakingPhase.error) {
      return _buildError(state, colors);
    }

    if (targeted) {
      return _buildTargeted(state, colors);
    }

    return _buildLinkChallenge(state, colors);
  }

  Widget _buildLoading(AppColors colors) {
    return Column(
      children: [
        const SizedBox(height: 80),
        InkEnter(
          child: Opacity(
            opacity: 0.55,
            child: WatchingEye(
              height: 120,
              color: colors.foreground,
              background: colors.background,
            ),
          ),
        ),
        const SizedBox(height: 32),
        InkEnter(
          delay: const Duration(milliseconds: 120),
          child: Text(
            'CREATING...',
            style: AppText.label(
              size: 13,
              weight: FontWeight.w600,
              color: colors.ink(0.45),
              letterSpacing: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(MatchmakingState state, AppColors colors) {
    return Column(
      children: [
        const SizedBox(height: 80),
        Text(
          state.error?.message ?? 'SOMETHING WENT WRONG.',
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, color: AppColors.red),
        ),
        const SizedBox(height: 24),
        BlinkrButton.ghost(
          label: 'RETRY',
          onPressed: () => ref
              .read(matchmakingNotifierProvider.notifier)
              .createChallenge(
                kind: widget.kind,
                opponentId: widget.opponentId,
              ),
        ),
      ],
    );
  }

  Widget _buildTargeted(MatchmakingState state, AppColors colors) {
    return Column(
      children: [
        const SizedBox(height: 40),
        InkEnter(
          child: Text(
            'CHALLENGE SENT',
            style: AppText.display(
              size: 44,
              color: colors.foreground,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkEnter(
          delay: const Duration(milliseconds: 100),
          child: Opacity(
            opacity: 0.55,
            child: WatchingEye(
              height: 100,
              color: colors.foreground,
              background: colors.background,
            ),
          ),
        ),
        const SizedBox(height: 24),
        InkEnter(
          delay: const Duration(milliseconds: 180),
          child: Text(
            'WAITING FOR ${(widget.opponentName ?? 'OPPONENT').toUpperCase()}',
            textAlign: TextAlign.center,
            style: AppText.label(
              size: 12,
              weight: FontWeight.w600,
              color: colors.ink(0.45),
              letterSpacing: 2.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkEnter(
          delay: const Duration(milliseconds: 240),
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              color: AppColors.acid,
              strokeWidth: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkChallenge(MatchmakingState state, AppColors colors) {
    return Column(
      children: [
        const SizedBox(height: 40),

        // Title
        InkEnter(
          child: Text(
            'CHALLENGE\nA FRIEND',
            textAlign: TextAlign.center,
            style: AppText.display(
              size: 44,
              color: colors.foreground,
              letterSpacing: 2,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Code block
        InkEnter(
          delay: const Duration(milliseconds: 120),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surfaceInsetDark,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: AppColors.acid.withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                Text(
                  'YOUR CODE',
                  style: AppText.label(
                    size: 10,
                    weight: FontWeight.w600,
                    color: colors.ink(0.4),
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.code ?? '------',
                  textAlign: TextAlign.center,
                  style: AppText.mono(
                    size: 36,
                    weight: FontWeight.w700,
                    color: AppColors.acid,
                    letterSpacing: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Share button
        InkEnter(
          delay: const Duration(milliseconds: 200),
          child: BlinkrButton.accent(
            label: 'SHARE INVITE LINK',
            onPressed: () => _share(state),
          ),
        ),
        const SizedBox(height: 12),

        // Copy button
        InkEnter(
          delay: const Duration(milliseconds: 260),
          child: BlinkrButton.ghost(
            label: 'COPY LINK',
            onPressed: () {
              final link = state.deepLink;
              if (link == null) return;
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.dark.surfaceRaised,
                  content: Text(
                    'LINK COPIED.',
                    style: AppText.label(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.acid,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),

        // Waiting state
        InkEnter(
          delay: const Duration(milliseconds: 320),
          child: Column(
            children: [
              Opacity(
                opacity: 0.55,
                child: WatchingEye(
                  height: 80,
                  color: colors.foreground,
                  background: colors.background,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'WAITING FOR OPPONENT...',
                style: AppText.label(
                  size: 11,
                  weight: FontWeight.w500,
                  color: colors.ink(0.4),
                  letterSpacing: 2.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
