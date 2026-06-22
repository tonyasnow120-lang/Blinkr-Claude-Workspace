import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import '../../../core/blink_detection/blink_detector.dart';
import '../../../core/theme/app_colors.dart';

/// Shows the local camera preview via the LiveKit local video track, once
/// published. Falls back to a placeholder while the camera is connecting.
class CameraFeed extends StatelessWidget {
  // ignore: unused_field
  final BlinkDetector blinkDetector;
  final livekit.LocalVideoTrack? localVideoTrack;
  final livekit.CameraPosition cameraPosition;

  const CameraFeed({
    super.key,
    required this.blinkDetector,
    this.localVideoTrack,
    this.cameraPosition = livekit.CameraPosition.front,
  });

  @override
  Widget build(BuildContext context) {
    final track = localVideoTrack;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ColoredBox(
        color: AppColors.dark.background,
        child: track != null
            ? livekit.VideoTrackRenderer(
                track,
                // Mirror the front camera so it behaves like a selfie
                // preview; the back camera should render unmirrored.
                mirrorMode: cameraPosition == livekit.CameraPosition.front
                    ? livekit.VideoViewMirrorMode.mirror
                    : livekit.VideoViewMirrorMode.off,
              )
            : Center(
                child: Icon(Icons.videocam_off, color: AppColors.dark.ink(0.54), size: 48),
              ),
      ),
    );
  }
}
