import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase/supabase_service.dart';

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
/// player to accept or dismiss it.
class ChallengeInviteNotifier extends StateNotifier<ChallengeInvite?> {
  final SupabaseService _supabase;
  String? _subscribedUserId;

  ChallengeInviteNotifier(this._supabase) : super(null);

  void updateUser(String? userId) {
    if (userId == _subscribedUserId) return;
    if (_subscribedUserId != null) {
      _supabase.unsubscribeFromUserInvites(_subscribedUserId!);
    }
    _subscribedUserId = userId;
    if (userId != null) {
      _supabase.subscribeToUserInvites(
        userId: userId,
        onChallengeInvite: (payload) {
          final invite = ChallengeInvite.fromPayload(payload);
          if (invite != null) state = invite;
        },
      );
    }
  }

  void dismiss() => state = null;

  @override
  void dispose() {
    if (_subscribedUserId != null) {
      _supabase.unsubscribeFromUserInvites(_subscribedUserId!);
    }
    super.dispose();
  }
}

final challengeInviteProvider =
    StateNotifierProvider<ChallengeInviteNotifier, ChallengeInvite?>((ref) {
  final notifier =
      ChallengeInviteNotifier(SupabaseService(Supabase.instance.client));
  ref.listen<User?>(currentUserProvider, (prev, next) {
    notifier.updateUser(next?.id);
  }, fireImmediately: true);
  return notifier;
});
