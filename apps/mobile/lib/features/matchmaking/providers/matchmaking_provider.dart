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

  /// Realtime channels for every challenge created this session. QR
  /// regeneration creates a new challenge/channel without tearing down the
  /// previous one — a `challenge.accepted` broadcast for a code that was
  /// accepted right as it expired client-side can still arrive on the old
  /// channel, and must still resolve to the lobby.
  final List<RealtimeChannel> _channels = [];
  bool _resolved = false;

  MatchmakingNotifier(this._service) : super(const MatchmakingState());

  Future<void> createChallenge({
    String kind = 'link',
    String? opponentId,
  }) async {
    // Re-creating (e.g. QR regeneration) cancels the previous pending code,
    // but keeps listening on its realtime channel (see _channels above).
    await _cancelPending();
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
    final channel = Supabase.instance.client.channel('challenge:$challengeId')
      ..onBroadcast(
        event: 'challenge.accepted',
        callback: (payload) {
          final matchId = payload['matchId'] as String?;
          if (matchId != null) _onAccepted(matchId);
        },
      )
      ..subscribe();
    _channels.add(channel);
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
    await _cancelPending();
    await _removeChannels();
    if (mounted) state = const MatchmakingState();
  }

  /// Best-effort cancel of the current pending code (also expires
  /// server-side via TTL). Does not remove realtime channels — see
  /// _channels.
  Future<void> _cancelPending() async {
    final code = state.code;
    if (code != null && state.phase == MatchmakingPhase.waiting) {
      unawaited(_service.cancelChallenge(code).catchError((_) {}));
    }
  }

  Future<void> _removeChannels() async {
    for (final channel in _channels) {
      await Supabase.instance.client.removeChannel(channel);
    }
    _channels.clear();
  }

  @override
  void dispose() {
    _cancelPending();
    _removeChannels();
    super.dispose();
  }
}

/// autoDispose so abandoning a share/QR screen tears down the Realtime
/// subscription and cancels the pending challenge.
final matchmakingNotifierProvider = StateNotifierProvider.autoDispose<
    MatchmakingNotifier, MatchmakingState>((ref) {
  return MatchmakingNotifier(ref.watch(matchmakingServiceProvider));
});
