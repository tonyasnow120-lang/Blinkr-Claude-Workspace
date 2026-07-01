import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'router.dart';
import '../core/audio/background_music.dart';
import '../core/security/app_lifecycle_observer.dart';
import '../core/theme/app_colors.dart';
import '../core/deep_links/deep_link_handler.dart';
import '../core/theme/theme_provider.dart';
import '../features/matchmaking/providers/challenge_invite_provider.dart';

class BlinkrApp extends ConsumerWidget {
  const BlinkrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('BLINKR: BlinkrApp.build() called');
    final GoRouter router;
    try {
      router = ref.watch(routerProvider);
      debugPrint('BLINKR: router created OK');
    } catch (e, st) {
      debugPrint('BLINKR: router error: $e\n$st');
      return _ErrorApp('Router failed:\n$e');
    }

    final themeMode = ref.watch(themeModeProvider);

    return AppLifecycleObserver(
      child: MaterialApp.router(
        title: 'Blinkr',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.acid,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.light.background,
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.light.background,
            foregroundColor: AppColors.light.foreground,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.acid,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.dark.background,
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.dark.background,
            foregroundColor: AppColors.dark.foreground,
            elevation: 0,
          ),
        ),
        routerConfig: router,
        builder: (context, child) => DeepLinkHandler(
          child: _ChallengeInviteListener(
            child: _MusicBootstrap(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

/// Starts the looping background music once the first frame is up, so audio
/// init can never delay or break startup.
class _MusicBootstrap extends ConsumerStatefulWidget {
  final Widget child;
  const _MusicBootstrap({required this.child});

  @override
  ConsumerState<_MusicBootstrap> createState() => _MusicBootstrapState();
}

class _MusicBootstrapState extends ConsumerState<_MusicBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backgroundMusicProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Listens for incoming targeted challenges (friend/contact/proximity) and
/// shows an accept/dismiss dialog over whatever screen is currently active.
class _ChallengeInviteListener extends ConsumerWidget {
  final Widget child;
  const _ChallengeInviteListener({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ChallengeInvite?>(challengeInviteProvider, (prev, next) {
      if (next == null) return;
      final dialogContext = rootNavigatorKey.currentContext;
      if (dialogContext == null) return;
      showDialog<void>(
        context: dialogContext,
        builder: (context) => AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('CHALLENGE.', style: TextStyle(color: context.colors.foreground)),
          content: Text(
            '${next.challengerName.toUpperCase()} WANTS TO BLINK AGAINST YOU.',
            style: TextStyle(color: context.colors.ink(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(challengeInviteProvider.notifier).dismiss();
                Navigator.of(context).pop();
              },
              child: const Text('DENY'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(challengeInviteProvider.notifier).dismiss();
                Navigator.of(context).pop();
                dialogContext.push('/match/${next.code}');
              },
              child: const Text('ACCEPT'),
            ),
          ],
        ),
      );
    });
    return child;
  }
}

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.dark.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              message,
              style: const TextStyle(color: AppColors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
