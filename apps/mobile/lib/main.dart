import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: set env vars SUPABASE_URL and SUPABASE_ANON_KEY
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  // TODO: add google-services.json (Android) and GoogleService-Info.plist (iOS)
  await Firebase.initializeApp();

  runApp(const ProviderScope(child: BlinkrApp()));
}
