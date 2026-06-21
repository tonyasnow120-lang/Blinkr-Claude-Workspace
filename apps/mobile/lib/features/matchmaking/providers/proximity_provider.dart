import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../matchmaking_error.dart';
import '../matchmaking_service.dart';
import 'matchmaking_provider.dart';

class ProximityState {
  final bool visible;
  final bool busy;
  final List<Map<String, dynamic>> nearby;
  final MatchmakingError? error;
  final double? myLat;
  final double? myLng;

  const ProximityState({
    this.visible = false,
    this.busy = false,
    this.nearby = const [],
    this.error,
    this.myLat,
    this.myLng,
  });

  ProximityState copyWith({
    bool? visible,
    bool? busy,
    List<Map<String, dynamic>>? nearby,
    MatchmakingError? error,
    double? myLat,
    double? myLng,
  }) =>
      ProximityState(
        visible: visible ?? this.visible,
        busy: busy ?? this.busy,
        nearby: nearby ?? this.nearby,
        error: error,
        myLat: myLat ?? this.myLat,
        myLng: myLng ?? this.myLng,
      );
}

/// GPS radius matching (Feature 5).
///
/// Privacy invariants:
///  - location updates run ONLY while the visibility toggle is on
///  - turning the toggle off (or leaving the screen — autoDispose) sends
///    the go-invisible call, which erases coordinates server-side
///  - visibility auto-expires after 10 minutes of being on
class ProximityNotifier extends StateNotifier<ProximityState> {
  final MatchmakingService _service;
  Timer? _heartbeat;
  Timer? _autoOff;

  static const _heartbeatInterval = Duration(seconds: 30);
  static const _autoOffAfter = Duration(minutes: 10);
  static const radiusMeters = 500;

  ProximityNotifier(this._service) : super(const ProximityState());

  Future<void> setVisible(bool on) async {
    if (on) {
      await _goVisible();
    } else {
      await _goInvisible();
    }
  }

  Future<void> _goVisible() async {
    state = state.copyWith(busy: true);
    try {
      final position = await _currentPosition();
      await _service.updateLocation(position.latitude, position.longitude);
      final nearby = await _service.nearbyPlayers(
        position.latitude,
        position.longitude,
        radiusMeters: radiusMeters,
      );
      if (!mounted) return;
      state = ProximityState(
        visible: true,
        nearby: nearby,
        myLat: position.latitude,
        myLng: position.longitude,
      );

      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _tick());
      _autoOff?.cancel();
      _autoOff = Timer(_autoOffAfter, _goInvisible);
    } catch (e) {
      if (!mounted) return;
      state = ProximityState(
        error: e is MatchmakingError ? e : MatchmakingError.from(e),
      );
    }
  }

  Future<void> _tick() async {
    try {
      final position = await _currentPosition();
      await _service.updateLocation(position.latitude, position.longitude);
      final nearby = await _service.nearbyPlayers(
        position.latitude,
        position.longitude,
        radiusMeters: radiusMeters,
      );
      if (mounted && state.visible) {
        state = state.copyWith(
          nearby: nearby,
          myLat: position.latitude,
          myLng: position.longitude,
        );
      }
    } catch (_) {
      // Transient heartbeat failures are tolerated; server-side staleness
      // (2 min) hides us automatically if they persist.
    }
  }

  Future<void> refresh() => state.visible ? _tick() : Future.value();

  Future<void> _goInvisible() async {
    _heartbeat?.cancel();
    _autoOff?.cancel();
    _heartbeat = null;
    _autoOff = null;
    try {
      await _service.goInvisible();
    } catch (_) {
      // Best-effort — staleness expiry covers a failed call.
    }
    if (mounted) state = const ProximityState();
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const MatchmakingPermissionDenied(
          'Location services are off. Enable them to find nearby players.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const MatchmakingPermissionDenied(
          'Location permission is required to find nearby players.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _autoOff?.cancel();
    if (state.visible) {
      // Fire-and-forget: erase server-side location on leave.
      _service.goInvisible().catchError((_) {});
    }
    super.dispose();
  }
}

final proximityNotifierProvider = StateNotifierProvider.autoDispose<
    ProximityNotifier, ProximityState>((ref) {
  return ProximityNotifier(ref.watch(matchmakingServiceProvider));
});
