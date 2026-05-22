class ApiEndpoints {
  static const String registerProfile = '/v1/auth/register-profile';
  static const String fcmToken = '/v1/auth/fcm-token';

  static const String me = '/v1/users/me';
  static const String myMatches = '/v1/users/me/matches';
  static String userById(String id) => '/v1/users/$id';

  static const String createChallenge = '/v1/challenges';
  static String challengeByCode(String code) => '/v1/challenges/$code';
  static String acceptChallenge(String code) => '/v1/challenges/$code/accept';
  static String cancelChallenge(String code) => '/v1/challenges/$code';

  static String matchById(String id) => '/v1/matches/$id';
  static String matchReady(String id) => '/v1/matches/$id/ready';
  static String matchBlink(String id) => '/v1/matches/$id/blink';
  static String matchAbandon(String id) => '/v1/matches/$id/abandon';
}
