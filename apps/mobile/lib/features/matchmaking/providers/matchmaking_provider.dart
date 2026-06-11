import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../matchmaking_error.dart';
import '../matchmaking_service.dart';

final matchmakingServiceProvider = Provider<MatchmakingService>((ref) {
  return MatchmakingService(ref.watch(apiClientProvider));
});

enum MatchmakingPhase { idle, creating, waiting, ready, error }

class MatchmakingState {
  final MatchmakingPhase phase;

  /// Created challenge: { id, code, kind, deepLink, deepLinkFallback, expiresAt }
  final Map<String, dynamic>? challenge;

  /// Set when the opponent accepts: { matchId, livekitToken, livekitUrl,
  /// livekitRoomName } — pass as `extra` when navigating to the lobby.
  final Map<String, dynamic>? matchData;

  final MatchmakingError? error;

  const MatchmakingState({
    this.phase = MatchmakingPhase.idle,
    this.challenge,
    this.matchData,
    this.error,
  });

  String? get code => challenge?['code'] as String?;
  String? get deepLink => challenge?['deepLink'] as String?;
  DateTime? get expiresAt {
    final raw = challenge?['expiresAt'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }
}

/// Drives the challenger side of every flow where someone waits for an
/// opponent: link shares (Feature 1), targeted friend/contact/proximity
/// invites (Features 2/3/5) and QR display (Feature 4).
///
/// Lifecycle: idle → creating → waiting —(challenge.accepted)→ ready.
/// The accepted event carries only the matchId; LiveKit credentials are
/// fetched over authenticated HTTP, never received via broadcast.
class MatchmakingNotifier extends StateNotifier<MatchmakingState> {
  final MatchmakingService _service;
  RealtimeChannel? _channel;
  bool _resolved = false;

  MatchmakingNotifier(this._service) : super(const MatchmakingState());

  Future<void> createChallenge({
    String kind = 'link',
    String? opponentId,
  }) async {
    // Re-creating (e.g. QR regeneration) cancels the previous pending code.
    await _teardown(cancelPending: true);
    _resolved = false;
    state = const MatchmakingState(phase: MatchmakingPhase.creating);

    try {
      final challenge =
          await _service.createChallenge(kind: kind, opponentId: opponentId);
      _subscribe(challenge['id'] as String);
      state = MatchmakingState(
        phase: MatchmakingPhase.waiting,
        challenge: challenge,
      );
    } catch (e) {
      state = MatchmakingState(
        phase: MatchmakingPhase.error,
        error: MatchmakingError.from(e),
      );
    }
  }

  void _subscribe(String challengeId) {
    _channel = Supabase.instance.client.channel('challenge:$challengeId')
      ..onBroadcast(
        event: 'challenge.accepted',
        callback: (payload) {
          final matchId = payload['matchId'] as String?;
          if (matchId != null) _onAccepted(matchId);
        },
      )
      ..subscribe();
  }

  Future<void> _onAccepted(String matchId) async {
    if (_resolved) return;
    _resolved = true;
    try {
      final matchData = await _service.getMatchToken(matchId);
      if (!mounted) return;
      state = MatchmakingState(
        phase: MatchmakingPhase.ready,
        challenge: state.challenge,
        matchData: matchData,
      );
    } catch (e) {
      if (!mounted) return;
      state = MatchmakingState(
        phase: MatchmakingPhase.error,
        challenge: state.challenge,
        error: MatchmakingError.from(e),
      );
    }
  }

  /// Cancels the pending challenge (player navigated away before an
  /// opponent joined). Safe to call from screen dispose.
  Future<void> cancel() async {
    await _teardown(cancelPending: true);
    if (mounted) state = const MatchmakingState();
  }

  Future<void> _teardown({required bool cancelPending}) async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await Supabase.instance.client.removeChannel(channel);
    }
    final code = state.code;
    if (cancelPending &&
        code != null &&
        state.phase == MatchmakingPhase.waiting) {
      // Best-effort: code also expires server-side via TTL.
      unawaited(_service.cancelChallenge(code).catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _teardown(cancelPending: true);
    super.dispose();
  }
}

/// autoDispose so abandoning a share/QR screen tears down the Realtime
/// subscription and cancels the pending challenge.
final matchmakingNotifierProvider = StateNotifierProvider.autoDispose<
    MatchmakingNotifier, MatchmakingState>((ref) {
  return MatchmakingNotifier(ref.watch(matchmakingServiceProvider));
});
