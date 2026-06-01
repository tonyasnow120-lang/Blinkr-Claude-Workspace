import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class RemoteVideoFeed extends StatelessWidget {
  final Room room;

  const RemoteVideoFeed({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final remoteParticipants = room.remoteParticipants.values.toList();
    if (remoteParticipants.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Waiting for opponent…',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final participant = remoteParticipants.first;
    final videoTrack = participant.videoTrackPublications.values
        .where((p) => !p.muted)
        .map((p) => p.track)
        .whereType<RemoteVideoTrack>()
        .firstOrNull;

    if (videoTrack == null) {
      return const Center(
        child: Text('No video', style: TextStyle(color: Colors.white54)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: VideoTrackRenderer(videoTrack),
    );
  }
}
