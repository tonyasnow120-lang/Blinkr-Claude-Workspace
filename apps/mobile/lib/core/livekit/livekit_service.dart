import 'package:livekit_client/livekit_client.dart';

class LiveKitService {
  Room? _room;

  Room? get room => _room;

  Future<Room> connect({
    required String url,
    required String token,
    void Function(Participant participant)? onParticipantConnected,
    void Function(Participant participant)? onParticipantDisconnected,
  }) async {
    _room = Room();

    final listener = _room!.createListener();

    if (onParticipantConnected != null) {
      listener.on<ParticipantConnectedEvent>(
        (event) => onParticipantConnected(event.participant),
      );
    }

    if (onParticipantDisconnected != null) {
      listener.on<ParticipantDisconnectedEvent>(
        (event) => onParticipantDisconnected(event.participant),
      );
    }

    await _room!.connect(url, token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ));

    return _room!;
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
    _room = null;
  }
}
