import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/blinkr_button.dart';
import '../../../shared/widgets/ink_enter.dart';
import '../../../shared/widgets/ink_scaffold.dart';
import '../../../shared/widgets/watching_eye.dart';

/// Welcome — the cold open. Centered eye + wordmark, the tagline, and the one
/// CTA into sign-in. Full-bleed dark with the screen-11 ink splatter behind.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return InkScaffold(
      splatSeed: 11,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              top: 8,
              right: 8,
              child: MusicToggleButton(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 64),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // The eye, staring back — above the splatter.
                  InkEnter(
                    child: Opacity(
                      opacity: 0.85,
                      child: WatchingEye(
                        height: 180,
                        color: colors.foreground,
                        background: colors.background,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Wordmark.
                  InkEnter(
                    delay: const Duration(milliseconds: 120),
                    child: _Wordmark(color: colors.foreground),
                  ),
                  const SizedBox(height: 8),

                  // Tagline.
                  InkEnter(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'STARE. BLINK. LOSE.',
                      style: AppText.label(
                        size: 13,
                        weight: FontWeight.w600,
                        color: colors.ink(0.55),
                        letterSpacing: 2.8,
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

                  // Primary CTA.
                  InkEnter(
                    delay: const Duration(milliseconds: 320),
                    child: BlinkrButton.accent(
                      label: 'ACCEPT THE CHALLENGE',
                      onPressed: () => context.push('/login'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ghost link into the explainer.
                  InkEnter(
                    delay: const Duration(milliseconds: 380),
                    child: GestureDetector(
                      onTap: () => context.push('/onboarding?next=/login'),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'HOW IT WORKS',
                          style: AppText.label(
                            size: 12,
                            weight: FontWeight.w600,
                            color: colors.ink(0.45),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bebas Neue logotype with a mono cursor that blinks every 960ms.
class _Wordmark extends StatefulWidget {
  final Color color;
  const _Wordmark({required this.color});

  @override
  State<_Wordmark> createState() => _WordmarkState();
}

class _WordmarkState extends State<_Wordmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 960))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'BLINKR',
          style: AppText.display(
            size: 56,
            color: widget.color,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(width: 4),
        FadeTransition(
          opacity: _ctrl,
          child: Text(
            '_',
            style: AppText.mono(size: 40, color: AppColors.acid),
          ),
        ),
      ],
    );
  }
}
