import '../../../shared/widgets/watching_eye.dart';

/// The same "watching eye" used everywhere else in the app, shedding tears —
/// shown when a match ends without a result (e.g. the opponent never joined
/// / abandoned).
class CryingEyeAnimation extends WatchingEye {
  const CryingEyeAnimation({super.key})
      : super(height: 220, crying: true);
}
