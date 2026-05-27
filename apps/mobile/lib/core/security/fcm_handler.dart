import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Validated FCM message handler (GAP-7).
///
/// Never navigates or mutates state directly from FCM payload — always
/// re-fetches from the authenticated API after receiving a verified notification.
class FcmHandler {
  // Explicit allowlist of known notification types — unknown types are anomalies
  static const _validTypes = {'challenge_invite', 'match_result'};

  static void initialize() {
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  static void _handleMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;

    if (type == null || !_validTypes.contains(type)) {
      // Unknown type — could be an injection attempt; log and discard (GAP-7)
      if (kDebugMode) {
        debugPrint('[SECURITY] unknown_fcm_type: $type');
      }
      _logSecurityAnomaly('unknown_fcm_type', type ?? 'null');
      return;
    }

    // Route to the appropriate handler — caller must fetch state from the API,
    // NOT use any sensitive data embedded in the FCM payload
    switch (type) {
      case 'challenge_invite':
        _onChallengeInvite(message.data['code'] as String?);
        break;
      case 'match_result':
        _onMatchResult(message.data['matchId'] as String?);
        break;
    }
  }

  static void _onChallengeInvite(String? code) {
    // TODO: trigger navigation to join challenge screen and re-fetch challenge
    // from GET /v1/challenges/:code using the authenticated API client
  }

  static void _onMatchResult(String? matchId) {
    // TODO: trigger navigation to result screen and re-fetch match state
    // from GET /v1/matches/:id using the authenticated API client
  }

  static void _logSecurityAnomaly(String event, String detail) {
    // TODO: call the backend security event endpoint (non-blocking)
  }
}
