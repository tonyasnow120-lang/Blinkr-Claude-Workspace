import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/match_provider.dart';
import '../widgets/camera_feed.dart';
import '../widgets/remote_video_feed.dart';
import '../widgets/powerup_overlay.dart';
import '../../../core/security/screen_security.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/graffiti_highlight.dart';
import '../../../shared/widgets/line_eye.dart';

class ContestScreen extends ConsumerStatefulWidget {
  final String matchId;

  const ContestScreen({super.key, required this.matchId});

  @override
  ConsumerState<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends ConsumerState<ContestScreen> {
  StreamSubscription<PowerUpEvent>? _powerUpSub;
  PowerUpEvent? _activePowerUp;
  final Set<String> _usedPowerUps = {};

  @override
  void initState() {
    super.initState();
    // Block screenshots and screen recording during live contest (GAP-15)
    ScreenSecurity.enableSecureMode();
    _powerUpSub = ref
        .read(matchNotifierProvider(widget.matchId).notifier)
        .powerUpStream
        .listen((event) {
      if (mounted) setState(() => _activePowerUp = event);
    });
  }

  @override
  void dispose() {
    _powerUpSub?.cancel();
    ScreenSecurity.disableSecureMode();
    super.dispose();
  }

  Future<void> _firePowerUp(String type) async {
    setState(() => _usedPowerUps.add(type));
    try {
      await ref
          .read(matchNotifierProvider(widget.matchId).notifier)
          .firePowerUp(type);
    } catch (e) {
      if (!mounted) return;
      setState(() => _usedPowerUps.remove(type));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
      ));
    }
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          matchState.videoConnected && room != null
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
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "DON'T ",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w200,
                                    letterSpacing: 5,
                                  ),
                                ),
                                GraffitiHighlight(
                                  child: Text(
                                    'BLINK',
                                    style: TextStyle(
                                      color: AppColors.acidInk,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CameraFeed(
                            blinkDetector: notifier.blinkDetector,
                            localVideoTrack: matchState.videoConnected
                                ? notifier.livekit.localVideoTrack
                                : null,
                            cameraPosition: matchState.cameraPosition,
                          ),
                        ),
                        if (matchState.videoConnected)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: _CameraSwitchButton(
                              onPressed: () => notifier.switchCamera(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Distraction power-ups — each usable once per match.
            Positioned(
              left: 16,
              right: 16,
              bottom: 192,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PowerUpButton(
                    label: 'Swarm',
                    used: _usedPowerUps.contains('eye_swarm'),
                    onPressed: () => _firePowerUp('eye_swarm'),
                    child: const LineEyeIcon(size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  _PowerUpButton(
                    label: 'Flash',
                    used: _usedPowerUps.contains('flash'),
                    onPressed: () => _firePowerUp('flash'),
                    child:
                        const Icon(Icons.bolt, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  _PowerUpButton(
                    label: 'Photos',
                    used: _usedPowerUps.contains('photo_bomb'),
                    onPressed: () => _firePowerUp('photo_bomb'),
                    child: const Icon(Icons.collections,
                        color: Colors.white, size: 20),
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
            if (_activePowerUp != null)
              Positioned.fill(
                child: PowerUpOverlay(
                  key: ObjectKey(_activePowerUp),
                  event: _activePowerUp!,
                  onDone: () {
                    if (mounted) setState(() => _activePowerUp = null);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Switches which camera (front/back) is shown to the opponent. The front
/// camera keeps running for blink detection regardless of which is selected.
class _CameraSwitchButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CameraSwitchButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.4),
          border: Border.all(color: Colors.white24),
        ),
        child: const Icon(Icons.cameraswitch, color: Colors.white, size: 18),
      ),
    );
  }
}

class _PowerUpButton extends StatelessWidget {
  final String label;
  final bool used;
  final VoidCallback onPressed;
  final Widget child;

  const _PowerUpButton({
    required this.label,
    required this.used,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: used ? 0.25 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: used ? null : onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white24),
              ),
              child: Center(child: child),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
