// LiveKit stub — real integration deferred until flutter_webrtc is compatible
// with the final Flutter 3.22 engine API. Match logic and blink detection work
// without it; only the peer video panel shows a placeholder.

class Room {
  final Map<String, dynamic> remoteParticipants = {};
  Future<void> disconnect() async {}
}

class LiveKitService {
  Room? _room;
  Room? get room => _room;

  Future<Room> connect({
    required String url,
    required String token,
    void Function(dynamic)? onParticipantConnected,
    void Function(dynamic)? onParticipantDisconnected,
  }) async {
    _room = Room();
    return _room!;
  }

  Future<void> disconnect() async {
    _room = null;
  }
}
