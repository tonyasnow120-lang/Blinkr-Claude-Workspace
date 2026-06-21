/// Consistent error vocabulary for all five matchmaking flows.
sealed class MatchmakingError implements Exception {
  final String message;
  const MatchmakingError(this.message);

  /// Maps raw exceptions (ApiClient throws `Exception(friendlyMessage)`)
  /// onto the matchmaking error taxonomy.
  factory MatchmakingError.from(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    final lower = msg.toLowerCase();
    if (lower.contains('expired') || lower.contains('gone')) {
      return MatchmakingExpired(msg);
    }
    if (lower.contains('already been accepted') || lower.contains('no longer pending')) {
      return MatchmakingAlreadyAccepted(msg);
    }
    if (lower.contains('not found')) {
      return MatchmakingNotFound(msg);
    }
    if (lower.contains('connection') || lower.contains('timed out') || lower.contains('internet')) {
      return MatchmakingNetworkError(msg);
    }
    return MatchmakingUnknown(msg);
  }

  /// Whether showing a retry button makes sense for this error.
  bool get retryable => this is MatchmakingNetworkError || this is MatchmakingUnknown;

  @override
  String toString() => message;
}

class MatchmakingExpired extends MatchmakingError {
  const MatchmakingExpired([super.message = 'This challenge has expired.']);
}

class MatchmakingAlreadyAccepted extends MatchmakingError {
  const MatchmakingAlreadyAccepted(
      [super.message = 'This challenge has already been accepted.']);
}

class MatchmakingNotFound extends MatchmakingError {
  const MatchmakingNotFound([super.message = 'Challenge not found.']);
}

class MatchmakingNetworkError extends MatchmakingError {
  const MatchmakingNetworkError(
      [super.message = 'Network error — check your connection.']);
}

class MatchmakingPermissionDenied extends MatchmakingError {
  const MatchmakingPermissionDenied(super.message);
}

class MatchmakingUnknown extends MatchmakingError {
  const MatchmakingUnknown(super.message);
}
