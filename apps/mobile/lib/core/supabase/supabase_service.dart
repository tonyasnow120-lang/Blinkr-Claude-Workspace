import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  SupabaseClient get client => _client;

  /// `onBroadcast` callbacks receive the full message envelope
  /// `{event, payload, type}` — the data the server sent lives under the
  /// `payload` key. Unwrap it so handlers see the fields the backend
  /// broadcast (e.g. `startsAt`, `userId`).
  static Map<String, dynamic> _data(Map<String, dynamic> envelope) {
    final inner = envelope['payload'];
    return inner is Map ? Map<String, dynamic>.from(inner) : envelope;
  }

  RealtimeChannel matchChannel(String matchId) =>
      _client.channel('match:$matchId');

  void subscribeToMatch({
    required String matchId,
    required void Function(Map<String, dynamic> payload) onOpponentJoined,
    required void Function(Map<String, dynamic> payload) onCountdownStart,
    required void Function(Map<String, dynamic> payload) onLive,
    required void Function(Map<String, dynamic> payload) onResult,
    required void Function(Map<String, dynamic> payload) onAbandoned,
    void Function(Map<String, dynamic> payload)? onPlayerReady,
    void Function(Map<String, dynamic> payload)? onPowerUp,
  }) {
    matchChannel(matchId)
        .onBroadcast(
          event: 'match.opponent_joined',
          callback: (payload) => onOpponentJoined(_data(payload)),
        )
        .onBroadcast(
          event: 'match.player_ready',
          callback: (payload) => onPlayerReady?.call(_data(payload)),
        )
        .onBroadcast(
          event: 'match.powerup',
          callback: (payload) => onPowerUp?.call(_data(payload)),
        )
        .onBroadcast(
          event: 'match.countdown_start',
          callback: (payload) => onCountdownStart(_data(payload)),
        )
        .onBroadcast(
          event: 'match.live',
          callback: (payload) => onLive(_data(payload)),
        )
        .onBroadcast(
          event: 'match.result',
          callback: (payload) => onResult(_data(payload)),
        )
        .onBroadcast(
          event: 'match.abandoned',
          callback: (payload) => onAbandoned(_data(payload)),
        )
        .subscribe();
  }

  void unsubscribeFromMatch(String matchId) {
    _client.removeChannel(matchChannel(matchId));
  }

  RealtimeChannel userChannel(String userId) =>
      _client.channel('user:$userId');

  /// Notifies this user of incoming targeted challenges (friend/contact/
  /// proximity) while the app is running.
  void subscribeToUserInvites({
    required String userId,
    required void Function(Map<String, dynamic> payload) onChallengeInvite,
  }) {
    userChannel(userId)
        .onBroadcast(
          event: 'challenge.invite',
          callback: (payload) => onChallengeInvite(_data(payload)),
        )
        .subscribe();
  }

  void unsubscribeFromUserInvites(String userId) {
    _client.removeChannel(userChannel(userId));
  }
}
