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

  /// Signs in with Apple.
  ///
  /// Trust boundary: Identity token validation is delegated to Supabase Auth.
  /// Supabase validates Apple identity tokens against Apple's JWKS endpoint
  /// (https://appleid.apple.com/auth/keys) before issuing a session JWT.
  /// The SHA-256 hashed nonce is enforced by supabase_flutter, satisfying
  /// Apple's Sign In with Apple specification. (GAP-3, GAP-4)
  Future<void> signInWithApple() async {
    await _supabase.auth.signInWithApple();
  }

  /// Signs in with Google.
  ///
  /// Trust boundary: Identity token validation is delegated to Supabase Auth.
  /// Supabase validates Google identity tokens against Google's JWKS endpoint
  /// (https://www.googleapis.com/oauth2/v3/certs) before issuing a session JWT.
  /// PKCE is enforced by supabase_flutter's built-in OAuth handler. (GAP-3, GAP-4)
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(OAuthProvider.google);
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

  /// Signs the user out, invalidating the session server-side first (GAP-20).
  Future<void> signOut() async {
    // Invalidate the session on the Supabase side via the backend admin endpoint.
    // This prevents revoked tokens from remaining valid until their expiry.
    try {
      await _api.post('/v1/auth/logout');
    } catch (_) {
      // Continue with local sign-out regardless of backend availability
    }
    await _supabase.auth.signOut();
  }
}
