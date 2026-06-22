import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import '../../../core/theme/app_colors.dart';

/// Renders the opponent's live video track, if one is currently subscribed.
/// Falls back to a placeholder while waiting for the opponent's camera to
/// connect or publish.
class RemoteVideoFeed extends StatefulWidget {
  final livekit.Room room;

  const RemoteVideoFeed({super.key, required this.room});

  @override
  State<RemoteVideoFeed> createState() => _RemoteVideoFeedState();
}

class _RemoteVideoFeedState extends State<RemoteVideoFeed> {
  livekit.VideoTrack? _videoTrack;
  livekit.EventsListener<livekit.RoomEvent>? _listener;

  @override
  void initState() {
    super.initState();
    _findExistingTrack();
    _listener = widget.room.createListener()
      ..on<livekit.TrackSubscribedEvent>((event) {
        if (event.track is livekit.VideoTrack) {
          setState(() => _videoTrack = event.track as livekit.VideoTrack);
        }
      })
      ..on<livekit.TrackUnsubscribedEvent>((event) {
        if (event.track == _videoTrack) {
          setState(() => _videoTrack = null);
        }
      });
  }

  void _findExistingTrack() {
    for (final participant in widget.room.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        final track = pub.track;
        if (track is livekit.VideoTrack) {
          _videoTrack = track;
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = _videoTrack;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dark.foreground.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: track != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: livekit.VideoTrackRenderer(track),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off, color: AppColors.dark.ink(0.38), size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'WAITING FOR OPPONENT\'S VIDEO…',
                    style: TextStyle(color: AppColors.dark.ink(0.38), fontSize: 13),
                  ),
                ],
              ),
            ),
    );
  }
}
