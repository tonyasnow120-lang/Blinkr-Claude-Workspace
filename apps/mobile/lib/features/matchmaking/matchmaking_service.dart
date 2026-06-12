import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

/// Thin API wrapper for the matchmaking endpoints. All calls ride the
/// existing authenticated ApiClient (Supabase JWT attached by interceptor)
/// — no re-authentication anywhere in these flows.
class MatchmakingService {
  final ApiClient _api;

  MatchmakingService(this._api);

  // ── Challenges (Features 1, 3, 4) ─────────────────────────────────────

  Future<Map<String, dynamic>> createChallenge({
    String kind = 'link',
    String? opponentId,
  }) async {
    final response = await _api.post(ApiEndpoints.createChallenge, body: {
      'kind': kind,
      if (opponentId != null) 'opponentId': opponentId,
    });
    return response['data'] as Map<String, dynamic>;
  }

  Future<void> cancelChallenge(String code) =>
      _api.delete(ApiEndpoints.cancelChallenge(code));

  /// Polled as a fallback to the `challenge.accepted` Realtime broadcast —
  /// returns the challenge's current status and, once accepted, the
  /// resulting matchId.
  Future<Map<String, dynamic>> getChallenge(String code) async {
    final response = await _api.get(ApiEndpoints.challengeByCode(code));
    return response['data'] as Map<String, dynamic>;
  }

  /// The challenger's own LiveKit credentials, fetched over authenticated
  /// HTTP after the `challenge.accepted` Realtime event delivers a matchId.
  Future<Map<String, dynamic>> getMatchToken(String matchId) async {
    final response = await _api.post(ApiEndpoints.matchToken(matchId));
    return response['data'] as Map<String, dynamic>;
  }

  // ── Friends (Feature 3) ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response =
        await _api.get(ApiEndpoints.userSearch, queryParams: {'q': query});
    return (response['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getFriends() async {
    final response = await _api.get(ApiEndpoints.friends);
    return response['data'] as Map<String, dynamic>;
  }

  Future<void> sendFriendRequest(String addresseeId) => _api
      .post(ApiEndpoints.friendRequests, body: {'addresseeId': addresseeId});

  Future<void> acceptFriendRequest(String friendshipId) =>
      _api.post(ApiEndpoints.acceptFriendRequest(friendshipId));

  Future<void> declineFriendRequest(String friendshipId) =>
      _api.post(ApiEndpoints.declineFriendRequest(friendshipId));

  Future<void> blockUser(String userId) =>
      _api.post(ApiEndpoints.blockUser(userId));

  Future<void> unfriend(String userId) =>
      _api.delete(ApiEndpoints.unfriend(userId));

  // ── Contacts (Feature 2) ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> matchContacts(List<String> hashes) async {
    final response =
        await _api.post(ApiEndpoints.contactsMatch, body: {'hashes': hashes});
    return (response['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> setPhoneHash(String? phoneHash) =>
      _api.put(ApiEndpoints.contactsPhoneHash, body: {'phoneHash': phoneHash});

  Future<void> setContactDiscovery(bool allow) =>
      _api.put(ApiEndpoints.contactsDiscovery, body: {'allow': allow});

  // ── Proximity (Feature 5) ─────────────────────────────────────────────

  Future<void> updateLocation(double lat, double lng) =>
      _api.put(ApiEndpoints.proximityLocation, body: {'lat': lat, 'lng': lng});

  Future<void> goInvisible() => _api.delete(ApiEndpoints.proximityLocation);

  Future<List<Map<String, dynamic>>> nearbyPlayers(
    double lat,
    double lng, {
    int radiusMeters = 500,
  }) async {
    final response = await _api.get(ApiEndpoints.proximityNearby, queryParams: {
      'lat': lat,
      'lng': lng,
      'radiusMeters': radiusMeters,
    });
    return (response['data'] as List).cast<Map<String, dynamic>>();
  }
}
