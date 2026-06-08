import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
    await _supabase.auth.signInWithOtp(
      email: email,
      emailRedirectTo: 'blinkr://auth/callback',
    );
  }

  Future<void> verifyOtp(String email, String token) async {
    // Supabase issues 'signup' tokens for first-time users and 'email' tokens
    // for returning users. Try email first; fall back to signup on failure.
    try {
      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
    } on AuthException {
      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
    }
  }

  /// Signs in with Apple using the native system sheet (iOS) or web flow (Android).
  ///
  /// Trust boundary: Identity token validation is delegated to Supabase Auth.
  /// Supabase validates Apple identity tokens against Apple's JWKS endpoint
  /// (https://appleid.apple.com/auth/keys) before issuing a session JWT.
  /// The SHA-256 hashed nonce is sent to Apple; the raw nonce is passed to
  /// Supabase for server-side verification. (GAP-3, GAP-4)
  Future<void> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken!,
      nonce: rawNonce,
    );
  }

  /// Signs in with Google using the native account picker.
  ///
  /// Trust boundary: Identity token validation is delegated to Supabase Auth.
  /// Supabase validates Google identity tokens against Google's JWKS endpoint
  /// (https://www.googleapis.com/oauth2/v3/certs) before issuing a session JWT.
  /// (GAP-3, GAP-4)
  Future<void> signInWithGoogle() async {
    const iosClientId =
        String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '');
    const webClientId =
        String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

    final googleSignIn = GoogleSignIn(
      clientId: iosClientId.isNotEmpty ? iosClientId : null,
      serverClientId: webClientId.isNotEmpty ? webClientId : null,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return; // user cancelled

    final googleAuth = await googleUser.authentication;

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken,
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

  /// Signs the user out, invalidating the session server-side first (GAP-20).
  Future<void> signOut() async {
    try {
      await _api.post('/v1/auth/logout');
    } catch (_) {
      // Continue with local sign-out regardless of backend availability
    }
    await _supabase.auth.signOut();
  }

  /// Generates a cryptographically secure random nonce for Apple Sign In.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }
}
