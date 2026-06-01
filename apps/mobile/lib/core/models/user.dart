import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class BlinkrUser with _$BlinkrUser {
  const factory BlinkrUser({
    required String id,
    required String username,
    String? displayName,
    String? avatarUrl,
    String? fcmToken,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _BlinkrUser;

  factory BlinkrUser.fromJson(Map<String, dynamic> json) =>
      _$BlinkrUserFromJson(json);
}

@freezed
class UserStats with _$UserStats {
  const factory UserStats({
    required String userId,
    required int wins,
    required int losses,
    required int currentStreak,
    required int longestStreak,
    required DateTime updatedAt,
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
}
