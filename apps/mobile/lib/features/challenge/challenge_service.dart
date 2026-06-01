import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/challenge.dart';

class ChallengeService {
  final ApiClient _api;

  ChallengeService(this._api);

  Future<Map<String, dynamic>> createChallenge() async {
    final response = await _api.post(ApiEndpoints.createChallenge);
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getChallengeByCode(String code) async {
    final response = await _api.get(ApiEndpoints.challengeByCode(code));
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptChallenge(String code) async {
    final response = await _api.post(ApiEndpoints.acceptChallenge(code));
    return response['data'] as Map<String, dynamic>;
  }

  Future<void> cancelChallenge(String code) async {
    await _api.delete(ApiEndpoints.cancelChallenge(code));
  }
}
