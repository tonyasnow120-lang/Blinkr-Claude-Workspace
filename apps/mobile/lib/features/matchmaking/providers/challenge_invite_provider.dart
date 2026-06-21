import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase/supabase_service.dart';
import '../matchmaking_service.dart';
import 'matchmaking_provider.dart';

/// An incoming targeted challenge (friend/contact/proximity) from another
/// player, delivered over Realtime while this user's app is running.
class ChallengeInvite {
  final String code;
  final String challengerName;
  final String kind;

  const ChallengeInvite({
    required this.code,
    required this.challengerName,
    required this.kind,
  });

  static ChallengeInvite? fromPayload(Map<String, dynamic> payload) {
    final code = payload['code'] as String?;
    if (code == null) return null;
    return ChallengeInvite(
      code: code,
      challengerName: payload['challengerName'] as String? ?? 'Someone',
      kind: payload['kind'] as String? ?? 'link',
    );
  }
}

/// Subscribes to `user:{userId}` for `challenge.invite` broadcasts for as
/// long as a session is active, re-subscribing whenever the signed-in user
/// changes. Surfaces the most recent invite so the app shell can prompt the
/// player to accept or deny it.
///
/// Realtime broadcast delivery has proven unreliable elsewhere in the app
/// (see the QR matchmaking fix), so this also polls
/// `GET /v1/challenges/incoming` every few seconds as a fallback.
class ChallengeInviteNotifier extends StateNotifier<ChallengeInvite?> {
  final SupabaseService _supabase;
  final MatchmakingService _service;
  String? _subscribedUserId;
  String? _dismissedCode;
  Timer? _pollTimer;

  ChallengeInviteNotifier(this._supabase, this._service) : super(null);

  void updateUser(String? userId) {
    if (userId == _subscribedUserId) return;
    if (_subscribedUserId != null) {
      _supabase.unsubscribeFromUserInvites(_subscribedUserId!);
    }
    _pollTimer?.cancel();
    _pollTimer = null;
    _subscribedUserId = userId;
    _dismissedCode = null;
    if (userId != null) {
      _supabase.subscribeToUserInvites(
        userId: userId,
        onChallengeInvite: (payload) {
          final invite = ChallengeInvite.fromPayload(payload);
          if (invite != null && invite.code != _dismissedCode) {
            state = invite;
          }
        },
      );
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final incoming = await _service.getIncomingChallenge();
        if (incoming == null) return;
        final invite = ChallengeInvite.fromPayload(incoming);
        if (invite != null && invite.code != _dismissedCode) {
          if (state?.code != invite.code) state = invite;
        }
      } catch (_) {
        // Best-effort — the realtime broadcast may still land.
      }
    });
  }

  /// Dismiss (deny) the current invite — clears it locally and suppresses
  /// re-showing it for this same challenge until a new one arrives.
  void dismiss() {
    _dismissedCode = state?.code;
    state = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_subscribedUserId != null) {
      _supabase.unsubscribeFromUserInvites(_subscribedUserId!);
    }
    super.dispose();
  }
}

final challengeInviteProvider =
    StateNotifierProvider<ChallengeInviteNotifier, ChallengeInvite?>((ref) {
  final notifier = ChallengeInviteNotifier(
    SupabaseService(Supabase.instance.client),
    ref.watch(matchmakingServiceProvider),
  );
  ref.listen<User?>(currentUserProvider, (prev, next) {
    notifier.updateUser(next?.id);
  }, fireImmediately: true);
  return notifier;
});
