import 'package:flutter/material.dart';
import '../../../core/livekit/livekit_service.dart';

class RemoteVideoFeed extends StatelessWidget {
  final Room room;

  const RemoteVideoFeed({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white38, size: 32),
            SizedBox(height: 8),
            Text(
              'Live video — coming in v1.1',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
