import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'core/security/secure_local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wire flutter_secure_storage into Supabase session storage (GAP-1)
  // SecureLocalStorage wraps flutter_secure_storage, preventing session tokens
  // from landing in SharedPreferences (Android) or NSUserDefaults (iOS).
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(),
      autoRefreshToken: true,
    ),
  );

  await Firebase.initializeApp();

  runApp(const ProviderScope(child: BlinkrApp()));
}
