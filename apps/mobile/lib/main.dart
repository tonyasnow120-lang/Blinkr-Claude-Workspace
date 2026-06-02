import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'core/security/secure_local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Surface widget errors as visible red text instead of a silent black screen.
  ErrorWidget.builder = (details) => _StartupErrorApp(
    message: 'UI error:\n${details.exceptionAsString()}',
  );

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

  // Firebase is only required for push notifications — initialize best-effort
  // with a timeout so a hanging call never blocks runApp.
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
  } catch (_) {
    // Push notifications will be unavailable; core match flow still works.
  }

  runApp(const ProviderScope(child: BlinkrApp()));
}

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
