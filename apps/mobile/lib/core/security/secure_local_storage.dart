import 'package:supabase_flutter/supabase_flutter.dart';

// flutter_secure_storage removed in v1.0 — caused Android Keystore deadlocks
// on test devices. SecureLocalStorage is a no-op shim so the rest of the
// codebase compiles. Re-wire with actual secure storage in v1.1.
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => false;

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<void> persistSession(String persistSessionString) async {}

  @override
  Future<void> removePersistedSession() async {}
}
