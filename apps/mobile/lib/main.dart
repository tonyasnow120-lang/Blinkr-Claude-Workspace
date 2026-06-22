import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show a loading screen immediately — proves Dart is running if visible.
  // Any subsequent failure replaces this with an error screen.
  runApp(const _LoadingApp());

  // In debug builds, surface widget errors as red text to aid development.
  // In release builds use a generic message to avoid leaking internal details.
  ErrorWidget.builder = (details) {
    final message = kDebugMode
        ? 'UI ERROR:\n${details.exceptionAsString()}'
        : 'SOMETHING WENT WRONG.\nPLEASE RESTART THE APP.';
    return _ErrorOverlay(message: message);
  };

  debugPrint('BLINKR: main() starting');
  // Strip trailing slashes — a trailing slash on SUPABASE_URL causes GoTrue to
  // receive double-slash paths (e.g. //auth/v1/otp) which it rejects as invalid.
  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL').trimRight().replaceAll(RegExp(r'/+$'), '');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY').trim();

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const _StartupErrorApp(
      message: 'BUILD MISCONFIGURATION: SUPABASE_URL / SUPABASE_ANON_KEY '
          'DART-DEFINES ARE EMPTY.\n\nADD THESE AS GITHUB SECRETS AND '
          'TRIGGER A FRESH BUILD.',
    ));
    return;
  }

  try {
    // Note: SecureLocalStorage (flutter_secure_storage) caused Android Keystore
    // deadlocks on the test device. Using default SharedPreferences storage so
    // startup is not blocked. Encrypted storage to be re-enabled in v1.1 with
    // a per-device compatibility check.
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
      ),
    ).timeout(const Duration(seconds: 15));
  } on TimeoutException {
    runApp(const _StartupErrorApp(
      message: 'STARTUP TIMED OUT CONNECTING TO SUPABASE.\nPLEASE CHECK YOUR INTERNET CONNECTION AND RESTART.',
    ));
    return;
  } catch (e) {
    runApp(_StartupErrorApp(message: 'SUPABASE INIT FAILED:\n$e'));
    return;
  }

  debugPrint('BLINKR: Supabase initialized OK');
  // Firebase/FCM removed: firebase_messaging auto-initializes at the native
  // plugin layer (before Dart runs) and was hanging the app on startup.
  // Push notifications will be re-added in v1.1 once core flow is stable.
  debugPrint('BLINKR: calling runApp');
  runApp(const ProviderScope(child: BlinkrApp()));
}

/// Shown immediately on startup before any async work — proves Dart is running.
class _LoadingApp extends StatelessWidget {
  const _LoadingApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.dark.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BLINKR',
                style: TextStyle(
                  color: AppColors.dark.foreground,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(color: AppColors.dark.foreground),
            ],
          ),
        ),
      ),
    );
  }
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

/// Used by ErrorWidget.builder — must NOT create a MaterialApp because it is
/// inserted in place inside an already-running MaterialApp.router widget tree.
class _ErrorOverlay extends StatelessWidget {
  final String message;
  const _ErrorOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.dark.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            style: const TextStyle(color: AppColors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
