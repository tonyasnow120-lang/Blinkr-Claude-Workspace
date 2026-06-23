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
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ink_scaffold.dart';
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
        backgroundColor: AppColors.dark.surfaceRaised,
        content: Text(
          e.toString().replaceFirst('Exception: ', ''),
          style: AppText.label(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.red,
            letterSpacing: 1,
          ),
        ),
      ));
    }
  }

  Future<void> _captureOpponent() async {
    final notifier = ref.read(matchNotifierProvider(widget.matchId).notifier);
    final bytes = await notifier.captureOpponentFrame();
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.dark.surfaceRaised,
        content: Text(
          'NO OPPONENT VIDEO TO CAPTURE YET.',
          style: AppText.label(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.chalk,
            letterSpacing: 1,
          ),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.dark.surfaceRaised,
        content: Text(
          'SAVED TO YOUR COLLAGE.',
          style: AppText.label(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.acid,
            letterSpacing: 1,
          ),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(matchNotifierProvider(widget.matchId).notifier);
    final matchState = ref.watch(matchNotifierProvider(widget.matchId));
    final room = notifier.livekitService.room;
    final colors = context.colors;

    ref.listen(matchNotifierProvider(widget.matchId), (prev, next) {
      if (next.phase == MatchPhase.result || next.phase == MatchPhase.abandoned) {
        context.pushReplacement('/match/${widget.matchId}/result');
      }
    });

    return InkScaffold(
      splatSeed: 92,
      splatIntensity: 0.3,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main layout — opponent feed (60%) + local feed (40%)
            Column(
              children: [
                // Opponent video — 60%
                Expanded(
                  flex: 6,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        matchState.videoConnected && room != null
                            ? RemoteVideoFeed(room: room)
                            : Container(
                                color: AppColors.surfaceInsetDark,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      LineEyeIcon(
                                          size: 40,
                                          color: AppColors.chalkInk(0.2)),
                                      const SizedBox(height: 12),
                                      Text(
                                        'OPPONENT',
                                        style: AppText.label(
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: AppColors.chalkInk(0.3),
                                          letterSpacing: 3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                        // "DON'T BLINK." taunt
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.bg.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                "DON'T BLINK.",
                                style: AppText.display(
                                  size: 28,
                                  color: AppColors.acid,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // LIVE badge
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.red,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: AppText.label(
                                    size: 9,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Capture button
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _CaptureButton(onPressed: _captureOpponent),
                        ),

                        // Power-up rail — vertical left edge
                        Positioned(
                          left: 8,
                          top: 48,
                          bottom: 48,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PowerUpButton(
                                  label: 'Swarm',
                                  used: _usedPowerUps.contains('eye_swarm'),
                                  onPressed: () => _firePowerUp('eye_swarm'),
                                  child: const LineEyeIcon(
                                      size: 18, color: AppColors.chalk),
                                ),
                                const SizedBox(height: 12),
                                _PowerUpButton(
                                  label: 'Flash',
                                  used: _usedPowerUps.contains('flash'),
                                  onPressed: () => _firePowerUp('flash'),
                                  child: const Icon(Icons.bolt,
                                      color: AppColors.chalk, size: 20),
                                ),
                                const SizedBox(height: 12),
                                _PowerUpButton(
                                  label: 'Photos',
                                  used: _usedPowerUps.contains('photo_bomb'),
                                  onPressed: () => _firePowerUp('photo_bomb'),
                                  child: const Icon(Icons.collections,
                                      color: AppColors.chalk, size: 18),
                                ),
                                const SizedBox(height: 12),
                                _PowerUpButton(
                                  label: 'Shake',
                                  used: _usedPowerUps.contains('shake'),
                                  onPressed: () => _firePowerUp('shake'),
                                  child: const Icon(Icons.vibration,
                                      color: AppColors.chalk, size: 20),
                                ),
                                const SizedBox(height: 12),
                                _PowerUpButton(
                                  label: 'Glitch',
                                  used: _usedPowerUps.contains('glitch'),
                                  onPressed: () => _firePowerUp('glitch'),
                                  child: const Icon(Icons.broken_image,
                                      color: AppColors.chalk, size: 18),
                                ),
                                const SizedBox(height: 12),
                                _PowerUpButton(
                                  label: 'Taunt',
                                  used: _usedPowerUps.contains('taunt'),
                                  onPressed: () => _firePowerUp('taunt'),
                                  child: const Icon(Icons.campaign,
                                      color: AppColors.chalk, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                // Local camera — 40%
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CameraFeed(
                          blinkDetector: notifier.blinkDetector,
                          localVideoTrack: matchState.videoConnected
                              ? notifier.livekitService.localVideoTrack
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

            // Top-left: music toggle
            const Positioned(
              top: 4,
              left: 56,
              child: MusicToggleButton(),
            ),

            // Top-right: quit
            Positioned(
              top: 4,
              right: 8,
              child: GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.dark.surfaceRaised,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2)),
                      title: Text(
                        'ABANDON MATCH?',
                        style: AppText.display(
                          size: 24,
                          color: colors.foreground,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'CANCEL',
                            style: AppText.label(
                              size: 12,
                              weight: FontWeight.w600,
                              color: colors.ink(0.5),
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            'ABANDON',
                            style: AppText.label(
                              size: 12,
                              weight: FontWeight.w700,
                              color: AppColors.red,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) await notifier.abandon();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bg.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    'QUIT',
                    style: AppText.label(
                      size: 11,
                      weight: FontWeight.w600,
                      color: colors.ink(0.5),
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),

            // Power-up overlay
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

class _CameraSwitchButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CameraSwitchButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bg.withOpacity(0.5),
          border: Border.all(color: AppColors.chalkInk(0.2)),
        ),
        child: const Icon(Icons.cameraswitch, color: AppColors.chalk, size: 18),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CaptureButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bg.withOpacity(0.5),
          border: Border.all(color: AppColors.chalkInk(0.2)),
        ),
        child: const Icon(Icons.camera_alt, color: AppColors.chalk, size: 20),
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
          GestureDetector(
            onTap: used ? null : onPressed,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bg.withOpacity(0.5),
                border: Border.all(
                  color: used
                      ? AppColors.chalkInk(0.1)
                      : AppColors.acid.withOpacity(0.4),
                ),
              ),
              child: Center(child: child),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: AppText.label(
              size: 8,
              weight: FontWeight.w600,
              color: AppColors.chalkInk(0.35),
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
