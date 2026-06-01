import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  SupabaseClient get client => _client;

  RealtimeChannel matchChannel(String matchId) =>
      _client.channel('match:$matchId');

  void subscribeToMatch({
    required String matchId,
    required void Function(Map<String, dynamic> payload) onOpponentJoined,
    required void Function(Map<String, dynamic> payload) onCountdownStart,
    required void Function(Map<String, dynamic> payload) onLive,
    required void Function(Map<String, dynamic> payload) onResult,
    required void Function(Map<String, dynamic> payload) onAbandoned,
  }) {
    matchChannel(matchId)
        .onBroadcast(
          event: 'match.opponent_joined',
          callback: (payload) => onOpponentJoined(payload),
        )
        .onBroadcast(
          event: 'match.countdown_start',
          callback: (payload) => onCountdownStart(payload),
        )
        .onBroadcast(
          event: 'match.live',
          callback: (payload) => onLive(payload),
        )
        .onBroadcast(
          event: 'match.result',
          callback: (payload) => onResult(payload),
        )
        .onBroadcast(
          event: 'match.abandoned',
          callback: (payload) => onAbandoned(payload),
        )
        .subscribe();
  }

  void unsubscribeFromMatch(String matchId) {
    _client.removeChannel(matchChannel(matchId));
  }
}
