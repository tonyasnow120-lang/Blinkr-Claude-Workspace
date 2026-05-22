import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/blink_detection/blink_detector.dart';
import '../../../core/blink_detection/blink_event.dart';
import '../../../core/livekit/livekit_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

enum MatchPhase { lobby, countdown, live, result, abandoned }

class MatchResult {
  final String winnerId;
  final String loserId;
  final String reason;
  final int? durationMs;

  const MatchResult({
    required this.winnerId,
    required this.loserId,
    required this.reason,
    this.durationMs,
  });
}

class MatchState {
  final MatchPhase phase;
  final DateTime? countdownStartsAt;
  final MatchResult? result;
  final String? error;

  const MatchState({
    this.phase = MatchPhase.lobby,
    this.countdownStartsAt,
    this.result,
    this.error,
  });

  MatchState copyWith({
    MatchPhase? phase,
    DateTime? countdownStartsAt,
    MatchResult? result,
    String? error,
  }) =>
      MatchState(
        phase: phase ?? this.phase,
        countdownStartsAt: countdownStartsAt ?? this.countdownStartsAt,
        result: result ?? this.result,
        error: error,
      );
}

class MatchNotifier extends StateNotifier<MatchState> {
  final String matchId;
  final ApiClient _api;
  final SupabaseService _supabase;
  final LiveKitService _livekit;
  final BlinkDetector _blinkDetector = BlinkDetector();
  StreamSubscription<BlinkEvent>? _blinkSub;

  MatchNotifier({
    required this.matchId,
    required ApiClient api,
    required SupabaseService supabase,
    required LiveKitService livekit,
  })  : _api = api,
        _supabase = supabase,
        _livekit = livekit,
        super(const MatchState()) {
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    _supabase.subscribeToMatch(
      matchId: matchId,
      onOpponentJoined: (_) {},
      onCountdownStart: (payload) {
        final startsAt = DateTime.parse(payload['startsAt'] as String);
        state = state.copyWith(
          phase: MatchPhase.countdown,
          countdownStartsAt: startsAt,
        );
      },
      onLive: (_) {
        state = state.copyWith(phase: MatchPhase.live);
        _startBlinkDetection();
      },
      onResult: (payload) {
        state = state.copyWith(
          phase: MatchPhase.result,
          result: MatchResult(
            winnerId: payload['winnerId'] as String,
            loserId: payload['loserId'] as String,
            reason: payload['reason'] as String,
            durationMs: payload['durationMs'] as int?,
          ),
        );
        _blinkSub?.cancel();
      },
      onAbandoned: (_) {
        state = state.copyWith(phase: MatchPhase.abandoned);
        _blinkSub?.cancel();
      },
    );
  }

  void _startBlinkDetection() {
    _blinkSub = _blinkDetector.blinkStream.listen((event) async {
      try {
        await _api.post(
          ApiEndpoints.matchBlink(matchId),
          body: {
            'detectedAt': event.detectedAt.toIso8601String(),
            'earValue': event.earValue,
            'eventType': event.type == BlinkEventType.blink ? 'blink' : 'gaze_break',
          },
        );
      } catch (_) {}
    });
  }

  BlinkDetector get blinkDetector => _blinkDetector;

  Future<void> markReady() async {
    await _api.post(ApiEndpoints.matchReady(matchId));
  }

  Future<void> abandon() async {
    await _api.post(ApiEndpoints.matchAbandon(matchId));
    state = state.copyWith(phase: MatchPhase.abandoned);
  }

  @override
  void dispose() {
    _blinkSub?.cancel();
    _blinkDetector.dispose();
    _supabase.unsubscribeFromMatch(matchId);
    _livekit.disconnect();
    super.dispose();
  }
}

final matchNotifierProvider =
    StateNotifierProvider.family<MatchNotifier, MatchState, String>(
  (ref, matchId) => MatchNotifier(
    matchId: matchId,
    api: ref.watch(apiClientProvider),
    supabase: SupabaseService(Supabase.instance.client),
    livekit: LiveKitService(),
  ),
);
