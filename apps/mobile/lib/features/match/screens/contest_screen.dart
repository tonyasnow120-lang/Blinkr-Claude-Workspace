import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/match_provider.dart';
import '../widgets/camera_feed.dart';
import '../widgets/remote_video_feed.dart';
import '../../../core/security/screen_security.dart';
import '../../../core/audio/background_music.dart';

class ContestScreen extends ConsumerStatefulWidget {
  final String matchId;

  const ContestScreen({super.key, required this.matchId});

  @override
  ConsumerState<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends ConsumerState<ContestScreen> {
  @override
  void initState() {
    super.initState();
    // Block screenshots and screen recording during live contest (GAP-15)
    ScreenSecurity.enableSecureMode();
  }

  @override
  void dispose() {
    ScreenSecurity.disableSecureMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(matchNotifierProvider(widget.matchId).notifier);
    final matchState = ref.watch(matchNotifierProvider(widget.matchId));
    final room = notifier.livekit.room;

    ref.listen(matchNotifierProvider(widget.matchId), (prev, next) {
      if (next.phase == MatchPhase.result || next.phase == MatchPhase.abandoned) {
        context.pushReplacement('/match/${widget.matchId}/result');
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
                      child: matchState.videoConnected && room != null
                          ? RemoteVideoFeed(room: room)
                          : Container(
                              color: Colors.grey[900],
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
                    child: CameraFeed(
                      blinkDetector: notifier.blinkDetector,
                      localVideoTrack: matchState.videoConnected
                          ? notifier.livekit.localVideoTrack
                          : null,
                    ),
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
            // Quit sits top-right, so the music toggle takes top-left.
            const Positioned(
              top: 8,
              left: 8,
              child: MusicToggleButton(),
            ),
          ],
        ),
      ),
    );
  }
}
