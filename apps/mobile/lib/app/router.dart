import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/verify_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/challenge/screens/create_challenge_screen.dart';
import '../features/challenge/screens/join_challenge_screen.dart';
import '../features/match/screens/lobby_screen.dart';
import '../features/match/screens/countdown_screen.dart';
import '../features/match/screens/contest_screen.dart';
import '../features/match/screens/result_screen.dart';
import '../features/profile/screens/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
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
        path: '/challenge/create',
        builder: (context, state) => const CreateChallengeScreen(),
      ),
      GoRoute(
        path: '/challenge/join',
        builder: (context, state) => const JoinChallengeScreen(),
      ),
      // Deep link entry: blinkr://match/:code
      GoRoute(
        path: '/match/:code',
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
