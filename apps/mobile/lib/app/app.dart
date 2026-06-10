import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'router.dart';
import '../core/audio/background_music.dart';
import '../core/security/app_lifecycle_observer.dart';

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
        builder: (context, child) =>
            _MusicBootstrap(child: child ?? const SizedBox.shrink()),
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
