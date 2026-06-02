import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'router.dart';
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
      ),
    );
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
