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

/// A distraction effect fired by the opponent. `type` is an open set —
/// unknown types are ignored by the overlay, so new effects (including
/// face-anchored AR lenses in v1.1) can ship server-first.
class PowerUpEvent {
  final String type;
  final List<String> photoUrls;

  const PowerUpEvent({required this.type, this.photoUrls = const []});
}

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
  final bool opponentReady;
  final bool videoConnected;

  const MatchState({
    this.phase = MatchPhase.lobby,
    this.countdownStartsAt,
    this.result,
    this.error,
    this.opponentReady = false,
    this.videoConnected = false,
  });

  MatchState copyWith({
    MatchPhase? phase,
    DateTime? countdownStartsAt,
    MatchResult? result,
    String? error,
    bool? opponentReady,
    bool? videoConnected,
  }) =>
      MatchState(
        phase: phase ?? this.phase,
        countdownStartsAt: countdownStartsAt ?? this.countdownStartsAt,
        result: result ?? this.result,
        error: error,
        opponentReady: opponentReady ?? this.opponentReady,
        videoConnected: videoConnected ?? this.videoConnected,
      );
}

class MatchNotifier extends StateNotifier<MatchState> {
  final String matchId;
  final ApiClient _api;
  final SupabaseService _supabase;
  final LiveKitService _livekit;
  final BlinkDetector _blinkDetector = BlinkDetector();
  StreamSubscription<BlinkEvent>? _blinkSub;
  final StreamController<PowerUpEvent> _powerUpController =
      StreamController<PowerUpEvent>.broadcast();

  /// Incoming power-ups fired by the opponent (own ones are filtered out).
  Stream<PowerUpEvent> get powerUpStream => _powerUpController.stream;

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
    _connectVideo();
  }

  LiveKitService get livekit => _livekit;

  Future<void> _connectVideo() async {
    try {
      final res = await _api.post(ApiEndpoints.matchToken(matchId));
      final data = res['data'] as Map<String, dynamic>;
      await _livekit.connect(
        url: data['livekitUrl'] as String,
        token: data['livekitToken'] as String,
      );
      if (mounted) state = state.copyWith(videoConnected: true);
    } catch (e) {
      // Video is best-effort — the match still works without it.
    }
  }

  void _subscribeToRealtime() {
    _supabase.subscribeToMatch(
      matchId: matchId,
      onOpponentJoined: (_) {},
      onPlayerReady: (payload) {
        final myId = Supabase.instance.client.auth.currentUser?.id;
        if (payload['userId'] != null && payload['userId'] != myId) {
          state = state.copyWith(opponentReady: true);
        }
      },
      onPowerUp: (payload) {
        final myId = Supabase.instance.client.auth.currentUser?.id;
        if (payload['fromUserId'] == myId) return;
        _powerUpController.add(PowerUpEvent(
          type: payload['type'] as String? ?? '',
          photoUrls: (payload['photoUrls'] as List?)?.cast<String>() ?? const [],
        ));
      },
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

  Future<void> firePowerUp(String type) async {
    await _api.post(ApiEndpoints.matchPowerup(matchId), body: {'type': type});
  }

  Future<void> abandon() async {
    await _api.post(ApiEndpoints.matchAbandon(matchId));
    state = state.copyWith(phase: MatchPhase.abandoned);
  }

  @override
  void dispose() {
    _blinkSub?.cancel();
    _blinkDetector.dispose();
    _powerUpController.close();
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
