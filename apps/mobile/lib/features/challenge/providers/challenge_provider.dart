import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../challenge_service.dart';
import '../../auth/providers/auth_provider.dart';

final challengeServiceProvider = Provider<ChallengeService>((ref) {
  return ChallengeService(ref.watch(apiClientProvider));
});

class ChallengeState {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? data;

  const ChallengeState({this.loading = false, this.error, this.data});

  ChallengeState copyWith({
    bool? loading,
    String? error,
    Map<String, dynamic>? data,
  }) =>
      ChallengeState(
        loading: loading ?? this.loading,
        error: error,
        data: data ?? this.data,
      );
}

class ChallengeNotifier extends StateNotifier<ChallengeState> {
  final ChallengeService _service;

  ChallengeNotifier(this._service) : super(const ChallengeState());

  Future<void> createChallenge() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _service.createChallenge();
      state = state.copyWith(loading: false, data: data);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> acceptChallenge(String code) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _service.acceptChallenge(code);
      state = state.copyWith(loading: false, data: data);
      return data;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return null;
    }
  }

  Future<void> cancelChallenge(String code) async {
    await _service.cancelChallenge(code);
    state = const ChallengeState();
  }
}

final challengeNotifierProvider =
    StateNotifierProvider<ChallengeNotifier, ChallengeState>((ref) {
  return ChallengeNotifier(ref.watch(challengeServiceProvider));
});
