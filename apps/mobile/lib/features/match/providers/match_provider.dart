import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import '../../../core/blink_detection/blink_detector.dart';
import '../../../core/blink_detection/blink_event.dart';
import '../../../core/blink_detection/face_tracking_service.dart';
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
  final livekit.CameraPosition cameraPosition;

  const MatchState({
    this.phase = MatchPhase.lobby,
    this.countdownStartsAt,
    this.result,
    this.error,
    this.opponentReady = false,
    this.videoConnected = false,
    this.cameraPosition = livekit.CameraPosition.front,
  });

  MatchState copyWith({
    MatchPhase? phase,
    DateTime? countdownStartsAt,
    MatchResult? result,
    String? error,
    bool? opponentReady,
    bool? videoConnected,
    livekit.CameraPosition? cameraPosition,
  }) =>
      MatchState(
        phase: phase ?? this.phase,
        countdownStartsAt: countdownStartsAt ?? this.countdownStartsAt,
        result: result ?? this.result,
        error: error,
        opponentReady: opponentReady ?? this.opponentReady,
        videoConnected: videoConnected ?? this.videoConnected,
        cameraPosition: cameraPosition ?? this.cameraPosition,
      );
}

class MatchNotifier extends StateNotifier<MatchState> {
  final String matchId;
  final ApiClient _api;
  final SupabaseService _supabase;
  final LiveKitService _livekit;
  final BlinkDetector _blinkDetector = BlinkDetector();
  FaceTrackingService? _faceTracking;
  StreamSubscription<BlinkEvent>? _blinkSub;
  final StreamController<PowerUpEvent> _powerUpController =
      StreamController<PowerUpEvent>.broadcast();

  /// Incoming power-ups fired by the opponent (own ones are filtered out).
  Stream<PowerUpEvent> get powerUpStream => _powerUpController.stream;

  Timer? _pollTimer;

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
    _startPolling();
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
      if (mounted) {
        state = state.copyWith(videoConnected: true);
        // If the match went live before the video connected (slow token
        // fetch), start face tracking now that a camera track exists.
        if (state.phase == MatchPhase.live) _startFaceTracking();
      }
    } catch (e) {
      // Video is best-effort — the match still works without it.
    }
  }

  /// Starts polling the front-facing camera track for blinks. No-op when
  /// video isn't connected — blink detection requires a LiveKit camera
  /// track. Safe to call again after [switchCamera] to repoint at the
  /// dedicated front-facing capture.
  void _startFaceTracking() {
    final track = _livekit.blinkDetectionTrack;
    if (track == null) return;
    (_faceTracking ??= FaceTrackingService(_blinkDetector)).start(track);
  }

  /// Toggles which camera is published to the opponent between front and
  /// back. The front camera keeps running for blink detection either way.
  Future<void> switchCamera() async {
    await _livekit.switchCamera();
    if (!mounted) return;
    state = state.copyWith(cameraPosition: _livekit.cameraPosition);
    if (state.phase == MatchPhase.live) _startFaceTracking();
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
        final startsAt = DateTime.tryParse(payload['startsAt'] as String? ?? '');
        if (startsAt != null) _handleCountdown(startsAt);
      },
      onLive: (_) => _handleLive(),
      onResult: (payload) {
        final winnerId = payload['winnerId'] as String?;
        final loserId = payload['loserId'] as String?;
        if (winnerId == null || loserId == null) return;
        _handleResult(MatchResult(
          winnerId: winnerId,
          loserId: loserId,
          reason: payload['reason'] as String? ?? 'blink',
          durationMs: payload['durationMs'] as int?,
        ));
      },
      onAbandoned: (_) => _handleAbandoned(),
    );
  }

  // Phase transitions are idempotent so the Realtime broadcast and the
  // polling fallback can both fire without double-starting detection or
  // regressing the phase.

  void _handleCountdown(DateTime startsAt) {
    if (!mounted || state.phase != MatchPhase.lobby) return;
    state = state.copyWith(
      phase: MatchPhase.countdown,
      countdownStartsAt: startsAt,
    );
  }

  void _handleLive() {
    if (!mounted ||
        state.phase == MatchPhase.live ||
        state.phase == MatchPhase.result ||
        state.phase == MatchPhase.abandoned) {
      return;
    }
    state = state.copyWith(phase: MatchPhase.live);
    _startBlinkDetection();
    _startFaceTracking();
  }

  void _handleResult(MatchResult result) {
    if (!mounted ||
        state.phase == MatchPhase.result ||
        state.phase == MatchPhase.abandoned) {
      return;
    }
    state = state.copyWith(phase: MatchPhase.result, result: result);
    _faceTracking?.stop();
    _blinkSub?.cancel();
    _stopPolling();
  }

  void _handleAbandoned() {
    if (!mounted || state.phase == MatchPhase.abandoned) return;
    state = state.copyWith(phase: MatchPhase.abandoned);
    _faceTracking?.stop();
    _blinkSub?.cancel();
    _stopPolling();
  }

  /// Polling fallback for the match's server state. Realtime broadcasts are
  /// the fast path, but they can be dropped (the challenge-accept flow has
  /// the same fallback for the same reason) — without this, a missed
  /// `match.countdown_start` strands both players in the lobby.
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      try {
        final res = await _api.get(ApiEndpoints.matchById(matchId));
        if (!mounted) return;
        _applyServerState(res['data'] as Map<String, dynamic>);
      } catch (_) {
        // Best-effort — keep polling, the broadcast may still land.
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _applyServerState(Map<String, dynamic> match) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final opponentReady = match['playerOneId'] == myId
        ? match['playerTwoReady'] == true
        : match['playerOneReady'] == true;
    if (opponentReady && !state.opponentReady) {
      state = state.copyWith(opponentReady: true);
    }

    switch (match['status'] as String?) {
      case 'countdown':
        final startsAt =
            DateTime.tryParse(match['startedAt'] as String? ?? '');
        if (startsAt != null) _handleCountdown(startsAt);
        break;
      case 'live':
        _handleLive();
        break;
      case 'completed':
        final winnerId = match['winnerId'] as String?;
        final loserId = match['loserId'] as String?;
        if (winnerId == null || loserId == null) break;
        _handleResult(MatchResult(
          winnerId: winnerId,
          loserId: loserId,
          reason: match['resultReason'] as String? ?? 'blink',
          durationMs: match['durationMs'] as int?,
        ));
        break;
      case 'abandoned':
        _handleAbandoned();
        break;
    }
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
    _stopPolling();
    _faceTracking?.dispose();
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
