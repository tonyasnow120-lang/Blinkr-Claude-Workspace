import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../matchmaking_error.dart';
import '../matchmaking_service.dart';
import 'matchmaking_provider.dart';

class FriendsState {
  final bool loading;
  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> incomingRequests;
  final MatchmakingError? error;

  const FriendsState({
    this.loading = false,
    this.friends = const [],
    this.incomingRequests = const [],
    this.error,
  });
}

class FriendsNotifier extends StateNotifier<FriendsState> {
  final MatchmakingService _service;

  FriendsNotifier(this._service) : super(const FriendsState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = FriendsState(
      loading: true,
      friends: state.friends,
      incomingRequests: state.incomingRequests,
    );
    try {
      final data = await _service.getFriends();
      if (!mounted) return;
      state = FriendsState(
        friends: (data['friends'] as List).cast<Map<String, dynamic>>(),
        incomingRequests:
            (data['incomingRequests'] as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      if (!mounted) return;
      state = FriendsState(
        friends: state.friends,
        incomingRequests: state.incomingRequests,
        error: MatchmakingError.from(e),
      );
    }
  }

  Future<void> accept(String friendshipId) async {
    await _service.acceptFriendRequest(friendshipId);
    await refresh();
  }

  Future<void> decline(String friendshipId) async {
    await _service.declineFriendRequest(friendshipId);
    await refresh();
  }

  Future<void> unfriend(String userId) async {
    await _service.unfriend(userId);
    await refresh();
  }
}

final friendsNotifierProvider =
    StateNotifierProvider.autoDispose<FriendsNotifier, FriendsState>((ref) {
  return FriendsNotifier(ref.watch(matchmakingServiceProvider));
});

/// Debounced username search (Feature 3). UI sets the query; results expose
/// friendship status so each row can render the right action button.
class UserSearchState {
  final bool loading;
  final String query;
  final List<Map<String, dynamic>> results;
  final MatchmakingError? error;

  const UserSearchState({
    this.loading = false,
    this.query = '',
    this.results = const [],
    this.error,
  });
}

class UserSearchNotifier extends StateNotifier<UserSearchState> {
  final MatchmakingService _service;
  Timer? _debounce;

  UserSearchNotifier(this._service) : super(const UserSearchState());

  static const _debounceMs = 300;

  void setQuery(String query) {
    final q = query.trim().toLowerCase();
    _debounce?.cancel();
    if (q.length < 2) {
      state = UserSearchState(query: q);
      return;
    }
    state = UserSearchState(query: q, loading: true, results: state.results);
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () => _run(q));
  }

  Future<void> _run(String q) async {
    try {
      final results = await _service.searchUsers(q);
      if (!mounted || state.query != q) return;
      state = UserSearchState(query: q, results: results);
    } catch (e) {
      if (!mounted || state.query != q) return;
      state = UserSearchState(query: q, error: MatchmakingError.from(e));
    }
  }

  Future<void> sendRequest(String userId) async {
    await _service.sendFriendRequest(userId);
    // Reflect the new status in-place without a refetch round-trip.
    state = UserSearchState(
      query: state.query,
      results: [
        for (final r in state.results)
          if (r['id'] == userId)
            {...r, 'friendshipStatus': 'pending', 'friendshipRequestedByMe': true}
          else
            r,
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final userSearchNotifierProvider = StateNotifierProvider.autoDispose<
    UserSearchNotifier, UserSearchState>((ref) {
  return UserSearchNotifier(ref.watch(matchmakingServiceProvider));
});
