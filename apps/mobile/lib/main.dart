import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'core/security/secure_local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In debug builds, surface widget errors as red text to aid development.
  // In release builds use a generic message to avoid leaking internal details.
  ErrorWidget.builder = (details) {
    final message = kDebugMode
        ? 'UI error:\n${details.exceptionAsString()}'
        : 'Something went wrong.\nPlease restart the app.';
    return _ErrorOverlay(message: message);
  };

  debugPrint('BLINKR: main() starting');
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const _StartupErrorApp(
      message: 'Build misconfiguration: SUPABASE_URL / SUPABASE_ANON_KEY '
          'dart-defines are empty.\n\nAdd these as GitHub Secrets and '
          'trigger a fresh build.',
    ));
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
        autoRefreshToken: true,
      ),
    );
  } catch (e) {
    runApp(_StartupErrorApp(message: 'Supabase init failed:\n$e'));
    return;
  }

  debugPrint('BLINKR: Supabase initialized OK');

  // Firebase is only required for push notifications — initialize best-effort
  // with a timeout so a hanging call never blocks runApp.
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
    debugPrint('BLINKR: Firebase initialized OK');
  } catch (e) {
    debugPrint('BLINKR: Firebase init skipped: $e');
  }

  debugPrint('BLINKR: calling runApp');
  runApp(const ProviderScope(child: BlinkrApp()));
}

/// Used by runApp() when startup itself fails — safe to create a root MaterialApp here.
class _StartupErrorApp extends StatelessWidget {
  final String message;
  const _StartupErrorApp({required this.message});

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

/// Used by ErrorWidget.builder — must NOT create a MaterialApp because it is
/// inserted in place inside an already-running MaterialApp.router widget tree.
class _ErrorOverlay extends StatelessWidget {
  final String message;
  const _ErrorOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
