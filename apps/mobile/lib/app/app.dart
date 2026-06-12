import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'router.dart';
import '../core/audio/background_music.dart';
import '../core/security/app_lifecycle_observer.dart';
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

    return AppLifecycleObserver(
      child: MaterialApp.router(
        title: 'Blinkr',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.white,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        routerConfig: router,
        builder: (context, child) => _ChallengeInviteListener(
          child: _MusicBootstrap(child: child ?? const SizedBox.shrink()),
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
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('Challenge!', style: TextStyle(color: Colors.white)),
          content: Text(
            '${next.challengerName} wants to blink against you.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(challengeInviteProvider.notifier).dismiss();
                Navigator.of(context).pop();
              },
              child: const Text('Deny'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(challengeInviteProvider.notifier).dismiss();
                Navigator.of(context).pop();
                dialogContext.push('/match/${next.code}');
              },
              child: const Text('Accept'),
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
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
