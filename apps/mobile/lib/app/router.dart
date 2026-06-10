import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/verify_screen.dart';
import '../features/auth/screens/setup_profile_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/challenge/screens/create_challenge_screen.dart';
import '../features/challenge/screens/join_challenge_screen.dart';
import '../features/match/screens/lobby_screen.dart';
import '../features/match/screens/countdown_screen.dart';
import '../features/match/screens/contest_screen.dart';
import '../features/match/screens/result_screen.dart';
import '../features/profile/screens/profile_screen.dart';

// Validates challenge codes: 8 uppercase alphanumeric chars, no O/0/I/1 (M9, GAP-9)
final _codePattern = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$');

/// Shown while supabase_flutter processes the magic link deep link.
/// The auth state listener in the router's redirect fires once the session
/// is established and navigates to /home automatically.
class _AuthCallbackScreen extends StatelessWidget {
  const _AuthCallbackScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

/// Bridges a Stream to a Listenable so GoRouter re-runs its redirect
/// whenever Supabase auth state changes. Without this, signing in via
/// Google/Apple (or a magic link) establishes a session but the router
/// never re-evaluates — the user stays parked on /login until some other
/// navigation event (e.g. pressing back) finally triggers the redirect.
class _GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  debugPrint('BLINKR: routerProvider initializing');
  final refresh = _GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    errorBuilder: (context, state) {
      debugPrint('BLINKR: router errorBuilder: ${state.error}');
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Navigation error:\n${state.error}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    },
    redirect: (context, state) {
      debugPrint('BLINKR: redirect called for ${state.matchedLocation}');
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;
      final path = state.matchedLocation;

      // Public paths available without authentication
      final isPublic = path == '/' || path == '/login' || path.startsWith('/verify') || path == '/auth/callback';

      // Redirect unauthenticated users away from protected routes (C2)
      if (!isAuthenticated && !isPublic) return '/';

      // Redirect authenticated users away from auth screens (but allow setup-profile)
      if (isAuthenticated && (path == '/' || path == '/login')) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) =>
            VerifyScreen(email: state.extra as String),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/setup-profile',
        builder: (context, state) => const SetupProfileScreen(),
      ),
      // Deep link landing for magic link auth (blinkr://auth/callback#access_token=...)
      // supabase_flutter processes the URL fragment automatically; this route just
      // shows a spinner while the session is established, then redirect kicks in.
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) => const _AuthCallbackScreen(),
      ),
      GoRoute(
        path: '/challenge/create',
        builder: (context, state) => const CreateChallengeScreen(),
      ),
      GoRoute(
        path: '/challenge/join',
        builder: (context, state) => const JoinChallengeScreen(),
      ),
      // HTTPS Universal Link: https://blinkr.app/match/:code (GAP-9, primary)
      // Custom scheme blinkr://match/:code kept as fallback (see AndroidManifest.xml)
      GoRoute(
        path: '/match/:code',
        redirect: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          // Validate code format to prevent arbitrary navigation via crafted deep links (M9)
          if (!_codePattern.hasMatch(code)) return '/home';
          return null;
        },
        builder: (context, state) =>
            JoinChallengeScreen(code: state.pathParameters['code']),
      ),
      GoRoute(
        path: '/match/:id/lobby',
        builder: (context, state) => LobbyScreen(
          matchId: state.pathParameters['id']!,
          matchData: state.extra as Map<String, dynamic>? ?? {},
        ),
      ),
      GoRoute(
        path: '/match/:id/countdown',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final startsAt = extra?['startsAt'] != null
              ? DateTime.parse(extra!['startsAt'] as String)
              : DateTime.now().add(const Duration(seconds: 3));
          return CountdownScreen(
            matchId: state.pathParameters['id']!,
            startsAt: startsAt,
          );
        },
      ),
      GoRoute(
        path: '/match/:id/contest',
        builder: (context, state) =>
            ContestScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id/result',
        builder: (context, state) =>
            ResultScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
