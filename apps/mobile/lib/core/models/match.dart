import 'package:freezed_annotation/freezed_annotation.dart';

part 'match.freezed.dart';
part 'match.g.dart';

enum MatchStatus {
  waiting,
  countdown,
  live,
  adjudicating,
  completed,
  abandoned,
}

enum ResultReason { blink, gazeBreak, disconnect, simultaneous }

@freezed
class BlinkrMatch with _$BlinkrMatch {
  const factory BlinkrMatch({
    required String id,
    required String challengeId,
    required String playerOneId,
    required String playerTwoId,
    String? winnerId,
    String? loserId,
    required String livekitRoomName,
    required MatchStatus status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationMs,
    ResultReason? resultReason,
    required DateTime createdAt,
  }) = _BlinkrMatch;

  factory BlinkrMatch.fromJson(Map<String, dynamic> json) =>
      _$BlinkrMatchFromJson(json);
}
