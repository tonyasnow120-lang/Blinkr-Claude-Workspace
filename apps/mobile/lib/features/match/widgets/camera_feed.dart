import 'package:flutter/material.dart';
import '../../../core/blink_detection/blink_detector.dart';

// Camera plugin removed in v1.0 to eliminate native-plugin startup hangs.
// Re-add camera: ^0.10.0 + permission_handler in v1.1 once core flow is stable.
class CameraFeed extends StatelessWidget {
  // ignore: unused_field
  final BlinkDetector blinkDetector;

  const CameraFeed({super.key, required this.blinkDetector});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.videocam_off, color: Colors.white54, size: 48),
        ),
      ),
    );
  }
}
