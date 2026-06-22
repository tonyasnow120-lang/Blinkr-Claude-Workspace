import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/match_provider.dart';
import '../widgets/camera_feed.dart';
import '../widgets/remote_video_feed.dart';
import '../widgets/powerup_overlay.dart';
import 'capture_editor_screen.dart';
import '../../profile/providers/profile_provider.dart';
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

  /// Grabs the opponent's current video frame and opens the editor. Saved
  /// shots land in the player's collage (and become photo-bomb ammo). Unlike
  /// power-ups this can be used repeatedly.
  Future<void> _captureOpponent() async {
    final notifier = ref.read(matchNotifierProvider(widget.matchId).notifier);
    final bytes = await notifier.captureOpponentFrame();
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('NO OPPONENT VIDEO TO CAPTURE YET.'),
      ));
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CaptureEditorScreen(imageBytes: bytes),
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(userPhotosProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('SAVED TO YOUR COLLAGE.'),
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
      backgroundColor: context.colors.background,
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
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          matchState.videoConnected && room != null
                              ? RemoteVideoFeed(room: room)
                              : Container(
                                  color: AppColors.dark.surface,
                                  child: Center(
                                    child: Text(
                                      'OPPONENT',
                                      style: TextStyle(color: AppColors.dark.ink(0.54)),
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
                                Text(
                                  "DON'T ",
                                  style: TextStyle(
                                    color: context.colors.foreground,
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
                          // Grab a reaction shot of the opponent for the
                          // collage / future photo bombs.
                          Positioned(
                            top: 8,
                            left: 8,
                            child: _CaptureButton(onPressed: _captureOpponent),
                          ),
                          // Distraction power-ups — each usable once per
                          // match. Vertical rail on the left edge.
                          Positioned(
                            left: 20,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _PowerUpButton(
                                    label: 'Swarm',
                                    used: _usedPowerUps.contains('eye_swarm'),
                                    onPressed: () => _firePowerUp('eye_swarm'),
                                    child: const LineEyeIcon(
                                        size: 20, color: AppColors.dark.foreground),
                                  ),
                                  const SizedBox(height: 18),
                                  _PowerUpButton(
                                    label: 'Flash',
                                    used: _usedPowerUps.contains('flash'),
                                    onPressed: () => _firePowerUp('flash'),
                                    child: const Icon(Icons.bolt,
                                        color: AppColors.dark.foreground, size: 22),
                                  ),
                                  const SizedBox(height: 18),
                                  _PowerUpButton(
                                    label: 'Photos',
                                    used: _usedPowerUps.contains('photo_bomb'),
                                    onPressed: () => _firePowerUp('photo_bomb'),
                                    child: const Icon(Icons.collections,
                                        color: AppColors.dark.foreground, size: 20),
                                  ),
                                  const SizedBox(height: 18),
                                  _PowerUpButton(
                                    label: 'Shake',
                                    used: _usedPowerUps.contains('shake'),
                                    onPressed: () => _firePowerUp('shake'),
                                    child: const Icon(Icons.vibration,
                                        color: AppColors.dark.foreground, size: 22),
                                  ),
                                  const SizedBox(height: 18),
                                  _PowerUpButton(
                                    label: 'Glitch',
                                    used: _usedPowerUps.contains('glitch'),
                                    onPressed: () => _firePowerUp('glitch'),
                                    child: const Icon(Icons.broken_image,
                                        color: AppColors.dark.foreground, size: 20),
                                  ),
                                  const SizedBox(height: 18),
                                  _PowerUpButton(
                                    label: 'Taunt',
                                    used: _usedPowerUps.contains('taunt'),
                                    onPressed: () => _firePowerUp('taunt'),
                                    child: const Icon(Icons.campaign,
                                        color: AppColors.dark.foreground, size: 22),
                                  ),
                                ],
                              ),
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
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.dark.surface,
                        title: Text('ABANDON MATCH?',
                            style: TextStyle(color: context.colors.foreground)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('ABANDON',
                                style: TextStyle(color: AppColors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) await notifier.abandon();
                  },
                  child: Text('QUIT', style: TextStyle(color: context.colors.ink(0.54))),
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
          color: AppColors.dark.background.withOpacity(0.4),
          border: Border.all(color: AppColors.dark.ink(0.24)),
        ),
        child: Icon(Icons.cameraswitch, color: context.colors.foreground, size: 18),
      ),
    );
  }
}

/// Snaps a still of the opponent's feed. Lives on the feed itself so it reads
/// as "capture what you're looking at".
class _CaptureButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CaptureButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.dark.background.withOpacity(0.4),
          border: Border.all(color: AppColors.dark.ink(0.24)),
        ),
        child: Icon(Icons.camera_alt, color: context.colors.foreground, size: 20),
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
                color: AppColors.dark.foreground.withOpacity(0.08),
                border: Border.all(color: AppColors.dark.ink(0.24)),
              ),
              child: Center(child: child),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.dark.ink(0.38),
              fontSize: 8,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
