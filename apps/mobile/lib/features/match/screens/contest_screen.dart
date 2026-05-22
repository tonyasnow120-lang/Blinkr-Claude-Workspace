import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/match_provider.dart';
import '../widgets/camera_feed.dart';
import '../widgets/countdown_overlay.dart';

class ContestScreen extends ConsumerWidget {
  final String matchId;

  const ContestScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(matchNotifierProvider(matchId).notifier);
    final matchState = ref.watch(matchNotifierProvider(matchId));

    ref.listen(matchNotifierProvider(matchId), (prev, next) {
      if (next.phase == MatchPhase.result || next.phase == MatchPhase.abandoned) {
        context.pushReplacement('/match/$matchId/result');
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.grey[900],
                        // TODO: mount RemoteVideoFeed(room: livekitRoom) here
                        child: const Center(
                          child: Text(
                            'Opponent',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: CameraFeed(blinkDetector: notifier.blinkDetector),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text('Abandon match?',
                            style: TextStyle(color: Colors.white)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Abandon',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) await notifier.abandon();
                  },
                  child: const Text('Quit', style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
