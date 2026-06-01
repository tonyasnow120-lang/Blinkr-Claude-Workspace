import 'package:freezed_annotation/freezed_annotation.dart';

part 'challenge.freezed.dart';
part 'challenge.g.dart';

enum ChallengeStatus { pending, accepted, expired, cancelled }

@freezed
class Challenge with _$Challenge {
  const factory Challenge({
    required String id,
    required String code,
    required String challengerId,
    String? opponentId,
    required ChallengeStatus status,
    required DateTime expiresAt,
    required DateTime createdAt,
    String? deepLink,
  }) = _Challenge;

  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);
}
