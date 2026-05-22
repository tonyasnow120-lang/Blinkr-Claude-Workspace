import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class AuthService {
  final SupabaseClient _supabase;
  final ApiClient _api;

  AuthService(this._supabase, this._api);

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateStream => _supabase.auth.onAuthStateChange;

  Future<void> signInWithOtp(String email) async {
    await _supabase.auth.signInWithOtp(email: email);
  }

  Future<void> verifyOtp(String email, String token) async {
    await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  Future<Map<String, dynamic>> registerProfile({
    required String username,
    String? displayName,
  }) async {
    final response = await _api.post(
      ApiEndpoints.registerProfile,
      body: {
        'username': username,
        if (displayName != null) 'displayName': displayName,
      },
    );
    return response['data'] as Map<String, dynamic>;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
