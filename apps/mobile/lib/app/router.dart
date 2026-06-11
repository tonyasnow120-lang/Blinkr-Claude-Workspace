import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/verify_screen.dart';
import '../features/auth/screens/setup_profile_screen.dart';
import '../features/auth/screens/sign_in_success_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/challenge/screens/create_challenge_screen.dart';
import '../features/challenge/screens/join_challenge_screen.dart';
import '../features/match/screens/lobby_screen.dart';
import '../features/match/screens/countdown_screen.dart';
import '../features/match/screens/contest_screen.dart';
import '../features/match/screens/result_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/legal/screens/legal_screen.dart';
import '../features/matchmaking/screens/friends_list_screen.dart';
import '../features/matchmaking/screens/user_search_screen.dart';
import '../features/matchmaking/screens/contacts_match_screen.dart';
import '../features/matchmaking/screens/qr_match_screen.dart';
import '../features/matchmaking/screens/qr_scanner_screen.dart';
import '../features/matchmaking/screens/proximity_screen.dart';

// Validates challenge codes: 9 uppercase alphanumeric chars, no O/0/I/1
// (M9, GAP-9). Length must match the backend's shortCode generator (9 chars
// from a 32-char alphabet = 45 bits of entropy).
final _codePattern = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{9}$');

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

/// Transition vocabulary — all on black, so cross-fades read as one
/// continuous surface rather than two pages swapping.
///
/// Fade + slight upward rise: auth flow and primary destinations. Mirrors
/// the entrance animations the screens themselves use.
CustomTransitionPage<void> _fadeRise(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Horizontal push with parallax: stepping deeper into the challenge flow.
/// Incoming page slides in from the right while the outgoing page drifts
/// left at quarter speed.
CustomTransitionPage<void> _slidePush(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final inCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final outCurve = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeInOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.25, 0),
          ).animate(outCurve),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(inCurve),
            child: FadeTransition(opacity: inCurve, child: child),
          ),
        );
      },
    );

/// Rise from the bottom: profile reads as an overlay sheet.
CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );

/// Quick plain fade: game-critical handoffs (countdown, contest) where a
/// long transition would eat reaction time, plus the callback spinner.
CustomTransitionPage<void> _quickFade(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );

/// Fade + scale-up reveal: the result screen lands with weight.
CustomTransitionPage<void> _fadeScale(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

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
      final isPublic = path == '/' || path == '/login' || path.startsWith('/verify') || path == '/auth/callback' || path.startsWith('/legal/');

      // Redirect unauthenticated users away from protected routes (C2)
      if (!isAuthenticated && !isPublic) return '/';

      // Any authenticated user landing on an auth entry screen — fresh
      // sign-in (login / magic-link callback) or returning cold start on
      // the welcome screen — goes through the success animation, which
      // resolves home vs setup-profile while it plays. Returning sessions
      // get a shortened version of the animation.
      if (isAuthenticated && (path == '/login' || path == '/auth/callback')) {
        return '/auth/success';
      }
      if (isAuthenticated && path == '/') {
        return '/auth/success?returning=1';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _fadeRise(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _fadeRise(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/verify',
        pageBuilder: (context, state) =>
            _fadeRise(state, VerifyScreen(email: state.extra as String)),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _fadeRise(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/setup-profile',
        pageBuilder: (context, state) =>
            _fadeRise(state, const SetupProfileScreen()),
      ),
      // Post-sign-in success animation; resolves profile state while playing
      // and then routes to /home or /setup-profile.
      GoRoute(
        path: '/auth/success',
        pageBuilder: (context, state) => _quickFade(
          state,
          SignInSuccessScreen(
            returning: state.uri.queryParameters['returning'] == '1',
          ),
        ),
      ),
      // Deep link landing for magic link auth (blinkr://auth/callback#access_token=...)
      // supabase_flutter processes the URL fragment automatically; this route just
      // shows a spinner while the session is established, then redirect kicks in.
      GoRoute(
        path: '/auth/callback',
        pageBuilder: (context, state) =>
            _quickFade(state, const _AuthCallbackScreen()),
      ),
      GoRoute(
        path: '/challenge/create',
        pageBuilder: (context, state) {
          // extra (optional): { kind, opponentId, opponentName } for
          // targeted friend/contact/proximity invites. Default: link share.
          final extra = state.extra as Map<String, dynamic>?;
          return _slidePush(
            state,
            CreateChallengeScreen(
              kind: extra?['kind'] as String? ?? 'link',
              opponentId: extra?['opponentId'] as String?,
              opponentName: extra?['opponentName'] as String?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/challenge/join',
        pageBuilder: (context, state) =>
            _slidePush(state, const JoinChallengeScreen()),
      ),
      // Matchmaking (Features 2-5)
      GoRoute(
        path: '/friends',
        pageBuilder: (context, state) =>
            _slidePush(state, const FriendsListScreen()),
      ),
      GoRoute(
        path: '/friends/search',
        pageBuilder: (context, state) =>
            _slidePush(state, const UserSearchScreen()),
      ),
      GoRoute(
        path: '/contacts',
        pageBuilder: (context, state) =>
            _slidePush(state, const ContactsMatchScreen()),
      ),
      GoRoute(
        path: '/qr',
        pageBuilder: (context, state) =>
            _slidePush(state, const QrMatchScreen()),
      ),
      GoRoute(
        path: '/qr/scan',
        pageBuilder: (context, state) =>
            _quickFade(state, const QrScannerScreen()),
      ),
      GoRoute(
        path: '/nearby',
        pageBuilder: (context, state) =>
            _slidePush(state, const ProximityScreen()),
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
        pageBuilder: (context, state) => _slidePush(
          state,
          JoinChallengeScreen(code: state.pathParameters['code']),
        ),
      ),
      GoRoute(
        path: '/match/:id/lobby',
        pageBuilder: (context, state) => _slidePush(
          state,
          LobbyScreen(
            matchId: state.pathParameters['id']!,
            matchData: state.extra as Map<String, dynamic>? ?? {},
          ),
        ),
      ),
      GoRoute(
        path: '/match/:id/countdown',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final startsAt = extra?['startsAt'] != null
              ? DateTime.parse(extra!['startsAt'] as String)
              : DateTime.now().add(const Duration(seconds: 3));
          return _quickFade(
            state,
            CountdownScreen(
              matchId: state.pathParameters['id']!,
              startsAt: startsAt,
            ),
          );
        },
      ),
      GoRoute(
        path: '/match/:id/contest',
        pageBuilder: (context, state) => _quickFade(
          state,
          ContestScreen(matchId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/match/:id/result',
        pageBuilder: (context, state) => _fadeScale(
          state,
          ResultScreen(matchId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            _slideUp(state, const ProfileScreen()),
      ),
      // Legal documents — public, linked from the login screen footer.
      GoRoute(
        path: '/legal/terms',
        pageBuilder: (context, state) => _slideUp(
          state,
          const LegalScreen(document: LegalDocument.terms),
        ),
      ),
      GoRoute(
        path: '/legal/privacy',
        pageBuilder: (context, state) => _slideUp(
          state,
          const LegalScreen(document: LegalDocument.privacy),
        ),
      ),
    ],
  );
});
