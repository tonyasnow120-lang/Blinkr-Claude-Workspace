import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

final backgroundMusicProvider =
    ChangeNotifierProvider<BackgroundMusicController>((ref) {
  final controller = BackgroundMusicController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Loops the app-wide background track. Started once at app level; the mute
/// toggle only silences the music (volume 0) so the loop position is kept and
/// unmuting resumes mid-phrase instead of restarting. Mute preference
/// persists across launches. Playback pauses while the app is backgrounded.
class BackgroundMusicController extends ChangeNotifier
    with WidgetsBindingObserver {
  static const _volume = 0.35;
  static const _mutedPrefKey = 'background_music_muted';

  final AudioPlayer _player = AudioPlayer();
  bool _muted = false;
  bool _started = false;

  bool get muted => _muted;

  BackgroundMusicController() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Idempotent — safe to call from any screen; only the first call plays.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(_mutedPrefKey) ?? false;
      notifyListeners();

      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(
        AssetSource('audio/background_music.mp3'),
        volume: _muted ? 0.0 : _volume,
      );
    } catch (e) {
      // Music is decorative — never let an audio failure affect the app.
      debugPrint('BLINKR: background music failed to start: $e');
    }
  }

  Future<void> toggleMuted() async {
    _muted = !_muted;
    notifyListeners();
    try {
      await _player.setVolume(_muted ? 0.0 : _volume);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedPrefKey, _muted);
    } catch (e) {
      debugPrint('BLINKR: background music toggle failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _player.pause();
    } else if (state == AppLifecycleState.resumed) {
      _player.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }
}

/// Small music on/off toggle, styled to the app's thin white-on-black line
/// work. Drop into an AppBar's actions or position in a corner on full-bleed
/// screens.
class MusicToggleButton extends ConsumerWidget {
  const MusicToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(backgroundMusicProvider).muted;
    final ink = context.colors.foreground;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => ref.read(backgroundMusicProvider).toggleMuted(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ink.withOpacity(muted ? 0.16 : 0.3),
              width: 0.8,
            ),
          ),
          child: Icon(
            muted ? Icons.music_off_outlined : Icons.music_note_outlined,
            size: 15,
            color: ink.withOpacity(muted ? 0.38 : 0.78),
          ),
        ),
      ),
    );
  }
}
