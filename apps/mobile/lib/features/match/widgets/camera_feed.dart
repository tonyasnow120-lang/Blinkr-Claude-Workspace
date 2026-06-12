import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import '../../../core/blink_detection/blink_detector.dart';

/// Shows the local camera preview via the LiveKit local video track, once
/// published. Falls back to a placeholder while the camera is connecting.
class CameraFeed extends StatelessWidget {
  // ignore: unused_field
  final BlinkDetector blinkDetector;
  final livekit.LocalVideoTrack? localVideoTrack;

  const CameraFeed({super.key, required this.blinkDetector, this.localVideoTrack});

  @override
  Widget build(BuildContext context) {
    final track = localVideoTrack;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.black,
        child: track != null
            ? livekit.VideoTrackRenderer(
                track,
                mirrorMode: livekit.VideoViewMirrorMode.mirror,
              )
            : const Center(
                child: Icon(Icons.videocam_off, color: Colors.white54, size: 48),
              ),
      ),
    );
  }
}
