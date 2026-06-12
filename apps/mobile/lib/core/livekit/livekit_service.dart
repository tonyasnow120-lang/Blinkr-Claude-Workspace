import 'package:livekit_client/livekit_client.dart' as livekit;

/// Thin wrapper around the LiveKit client — joins the match's video room and
/// enables the local camera/microphone so both players see and hear each
/// other for the duration of the match.
class LiveKitService {
  livekit.Room? _room;
  livekit.Room? get room => _room;

  /// The local camera track, once published — null until `connect` finishes
  /// enabling the camera.
  livekit.LocalVideoTrack? get localVideoTrack {
    final publications = _room?.localParticipant?.videoTrackPublications;
    if (publications == null) return null;
    for (final pub in publications) {
      final track = pub.track;
      if (track is livekit.LocalVideoTrack) return track;
    }
    return null;
  }

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

  Future<void> disconnect() async {
    await _room?.disconnect();
    _room = null;
  }
}
