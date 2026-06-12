import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';
import '../../../shared/widgets/watching_eye.dart';
import '../../profile/providers/profile_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;

  late final Animation<double> _headerOpacity;
  late final Animation<double> _headerSlide;
  late final Animation<double> _eyeOpacity;
  late final Animation<double> _statsOpacity;
  late final Animation<double> _btnOpacity;
  late final Animation<double> _btnSlide;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));

    _headerOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _headerSlide = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
      ),
    );
    _eyeOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.18, 0.60, curve: Curves.easeOut),
    );
    _statsOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.42, 0.78, curve: Curves.easeOut),
    );
    _btnOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.58, 1.0, curve: Curves.easeOut),
    );
    _btnSlide = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.58, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final size = MediaQuery.sizeOf(context);
    final profile = ref.watch(profileProvider);

    final displayName = profile.maybeWhen(
      data: (data) {
        final user = data['users'] as Map<String, dynamic>?;
        // Drizzle serializes columns with camelCase keys
        return (user?['displayName'] ??
            user?['display_name'] ??
            user?['username']) as String?;
      },
      orElse: () => null,
    );
    final stats = profile.maybeWhen(
      data: (data) => data['user_stats'] as Map<String, dynamic>?,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'BLINKR',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        actions: [
          const MusicToggleButton(),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            // Home is normally pushed from the profile hub — pop back to it
            // rather than stacking another copy. Push covers deep links.
            onPressed: () =>
                context.canPop() ? context.pop() : context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _entranceCtrl,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Greeting + headline + cycling tagline
              Opacity(
                opacity: _headerOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _headerSlide.value),
                  child: Column(
                    children: [
                      if (displayName != null) ...[
                        Text(
                          'WELCOME BACK, ${displayName.toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(115),
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 3.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      const Text(
                        'READY TO STARE?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w200,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _TaglineCycler(),
                    ],
                  ),
                ),
              ),

              // The eye, staring back
              Opacity(
                opacity: _eyeOpacity.value,
                child: const WatchingEye(height: 230),
              ),

              // Live record strip
              Opacity(
                opacity: _statsOpacity.value,
                child: stats == null
                    ? const SizedBox(height: 14)
                    : _StatsStrip(stats: stats),
              ),

              const Spacer(flex: 2),

              // Actions
              Opacity(
                opacity: _btnOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _btnSlide.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => context.push('/challenge/create'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'CHALLENGE A FRIEND',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => context.push('/challenge/join'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withAlpha(115),
                                width: 0.8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'JOIN WITH A CODE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Matchmaking shortcuts: friends, contacts, QR, nearby
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: const [
                            _MatchmakingShortcut(
                              icon: Icons.people_outline,
                              label: 'FRIENDS',
                              route: '/friends',
                            ),
                            _MatchmakingShortcut(
                              icon: Icons.contacts_outlined,
                              label: 'CONTACTS',
                              route: '/contacts',
                            ),
                            _MatchmakingShortcut(
                              icon: Icons.qr_code_2,
                              label: 'QR',
                              route: '/qr',
                            ),
                            _MatchmakingShortcut(
                              icon: Icons.near_me_outlined,
                              label: 'NEARBY',
                              route: '/nearby',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rotates through taglines with a cross-fade every few seconds.
class _TaglineCycler extends StatefulWidget {
  const _TaglineCycler();

  @override
  State<_TaglineCycler> createState() => _TaglineCyclerState();
}

class _TaglineCyclerState extends State<_TaglineCycler> {
  static const _lines = [
    'FIRST TO BLINK LOSES.',
    'STARE THEM DOWN.',
    'NO MERCY. NO BLINKING.',
    'HOLD YOUR NERVE.',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      child: Text(
        _lines[_index],
        key: ValueKey(_index),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withAlpha(140),
          fontSize: 9.5,
          fontWeight: FontWeight.w300,
          letterSpacing: 5,
        ),
      ),
    );
  }
}

/// Wins / streak / losses in the thin letterspaced strip style.
class _StatsStrip extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    Widget item(String label, Object? value) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${value ?? 0}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w200,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha(102),
                fontSize: 8,
                fontWeight: FontWeight.w400,
                letterSpacing: 3,
              ),
            ),
          ],
        );

    Widget divider() => Container(
          width: 0.5,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 28),
          color: Colors.white.withAlpha(46),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item('WINS', stats['wins']),
        divider(),
        item('STREAK', stats['currentStreak'] ?? stats['current_streak']),
        divider(),
        item('LOSSES', stats['losses']),
      ],
    );
  }
}
