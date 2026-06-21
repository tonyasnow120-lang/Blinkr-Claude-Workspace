class ApiEndpoints {
  static const String registerProfile = '/v1/auth/register-profile';
  static const String fcmToken = '/v1/auth/fcm-token';

  static const String me = '/v1/users/me';
  static const String myMatches = '/v1/users/me/matches';
  static const String myPhotos = '/v1/users/me/photos';
  static String deletePhoto(String id) => '/v1/users/me/photos/$id';
  static String userById(String id) => '/v1/users/$id';

  static const String createChallenge = '/v1/challenges';
  static const String incomingChallenge = '/v1/challenges/incoming';
  static String challengeByCode(String code) => '/v1/challenges/$code';
  static String acceptChallenge(String code) => '/v1/challenges/$code/accept';
  static String cancelChallenge(String code) => '/v1/challenges/$code';

  static String matchById(String id) => '/v1/matches/$id';
  static String matchToken(String id) => '/v1/matches/$id/token';
  static String matchReady(String id) => '/v1/matches/$id/ready';
  static String matchBlink(String id) => '/v1/matches/$id/blink';
  static String matchAbandon(String id) => '/v1/matches/$id/abandon';
  static String matchPowerup(String id) => '/v1/matches/$id/powerup';

  // Matchmaking
  static const String userSearch = '/v1/users/search';
  static const String friends = '/v1/friends';
  static const String friendRequests = '/v1/friends/requests';
  static String acceptFriendRequest(String id) => '/v1/friends/requests/$id/accept';
  static String declineFriendRequest(String id) => '/v1/friends/requests/$id/decline';
  static String blockUser(String userId) => '/v1/friends/$userId/block';
  static String unfriend(String userId) => '/v1/friends/$userId';
  static const String contactsMatch = '/v1/contacts/match';
  static const String contactsPhoneHash = '/v1/contacts/phone-hash';
  static const String contactsDiscovery = '/v1/contacts/discovery';
  static const String proximityLocation = '/v1/proximity/location';
  static const String proximityNearby = '/v1/proximity/nearby';
}
