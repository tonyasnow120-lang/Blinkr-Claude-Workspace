import 'package:livekit_client/livekit_client.dart' as livekit;

/// Thin wrapper around the LiveKit client — joins the match's video room and
/// enables the local camera/microphone so both players see and hear each
/// other for the duration of the match.
class LiveKitService {
  livekit.Room? _room;
  livekit.Room? get room => _room;

  livekit.CameraPosition _cameraPosition = livekit.CameraPosition.front;
  livekit.CameraPosition get cameraPosition => _cameraPosition;

  /// Dedicated front-facing capture used for blink detection while the
  /// published track has been switched to the back camera. Null whenever
  /// the published track is already front-facing (it doubles as the blink
  /// detection source in that case).
  livekit.LocalVideoTrack? _frontFacingTrack;

  /// The local camera track currently published to the opponent — null
  /// until `connect` finishes enabling the camera.
  livekit.LocalVideoTrack? get localVideoTrack {
    final publications = _room?.localParticipant?.videoTrackPublications;
    if (publications == null) return null;
    for (final pub in publications) {
      final track = pub.track;
      if (track is livekit.LocalVideoTrack) return track;
    }
    return null;
  }

  /// The track blink detection should read frames from: always front-facing,
  /// regardless of which camera is currently published to the opponent.
  livekit.LocalVideoTrack? get blinkDetectionTrack =>
      _frontFacingTrack ?? localVideoTrack;

  Future<livekit.Room> connect({
    required String url,
    required String token,
  }) async {
    final room = livekit.Room(
      roomOptions: const livekit.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    await room.connect(url, token);
    await room.localParticipant?.setCameraEnabled(true);
    await room.localParticipant?.setMicrophoneEnabled(true);
    _room = room;
    return room;
  }

  /// Swaps the camera published to the opponent between front and back.
  ///
  /// When switching to the back camera, a second, unpublished front-facing
  /// capture is started so blink detection keeps working off the player's
  /// face. When switching back to front, that extra capture is torn down
  /// since the published track is front-facing again.
  Future<void> switchCamera() async {
    final participant = _room?.localParticipant;
    if (participant == null) return;

    final next = _cameraPosition == livekit.CameraPosition.front
        ? livekit.CameraPosition.back
        : livekit.CameraPosition.front;

    if (next == livekit.CameraPosition.back) {
      _frontFacingTrack ??= await livekit.LocalVideoTrack.createCameraTrack(
        const livekit.CameraCaptureOptions(
          cameraPosition: livekit.CameraPosition.front,
        ),
      );
      await _frontFacingTrack?.start();
    } else {
      await _frontFacingTrack?.stop();
      await _frontFacingTrack?.dispose();
      _frontFacingTrack = null;
    }

    await participant.setCameraEnabled(
      true,
      cameraCaptureOptions: livekit.CameraCaptureOptions(cameraPosition: next),
    );
    _cameraPosition = next;
  }

  Future<void> disconnect() async {
    await _frontFacingTrack?.stop();
    await _frontFacingTrack?.dispose();
    _frontFacingTrack = null;
    await _room?.disconnect();
    _room = null;
  }
}
