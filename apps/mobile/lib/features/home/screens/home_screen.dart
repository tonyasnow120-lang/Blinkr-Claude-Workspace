import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ink_enter.dart';
import '../../../shared/widgets/ink_scaffold.dart';
import '../../../shared/widgets/stat_strip.dart';
import '../../../shared/widgets/watching_eye.dart';
import '../../profile/providers/profile_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    final colors = context.colors;
    final profile = ref.watch(profileProvider);

    final displayName = profile.maybeWhen(
      data: (data) {
        final user = data['users'] as Map<String, dynamic>?;
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

    return InkScaffold(
      splatSeed: 43,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/challenge/create'),
        backgroundColor: AppColors.acid,
        foregroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        elevation: 0,
        label: Text(
          '+ CREATE',
          style: AppText.label(
            size: 13,
            weight: FontWeight.w700,
            color: AppColors.bg,
            letterSpacing: 2,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _BottomNav(
        index: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          switch (i) {
            case 1:
              context.push('/friends');
            case 2:
              context.push('/history');
            case 3:
              context.push('/profile');
          }
        },
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: InkEnter(
                child: Row(
                  children: [
                    Text(
                      'BLINKR',
                      style: AppText.display(
                        size: 28,
                        color: colors.foreground,
                        letterSpacing: 3,
                      ),
                    ),
                    Text(
                      '_',
                      style: AppText.mono(size: 22, color: AppColors.acid),
                    ),
                    const Spacer(),
                    const MusicToggleButton(),
                    IconButton(
                      icon: Icon(Icons.notifications_none,
                          color: colors.ink(0.55), size: 22),
                      onPressed: () => context.push('/notifications'),
                    ),
                    GestureDetector(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.push('/profile'),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: colors.ink(0.15),
                        child: Icon(Icons.person,
                            color: colors.ink(0.45), size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Stat strip
            InkEnter(
              delay: const Duration(milliseconds: 80),
              child: stats != null
                  ? StatStrip(stats: [
                      StatItem(
                          label: 'Wins',
                          value: '${stats['wins'] ?? 0}'),
                      StatItem(
                          label: 'Streak',
                          value:
                              '${stats['currentStreak'] ?? stats['current_streak'] ?? 0}'),
                      StatItem(
                          label: 'Losses',
                          value: '${stats['losses'] ?? 0}'),
                    ])
                  : const SizedBox(height: 48),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    if (displayName != null) ...[
                      InkEnter(
                        delay: const Duration(milliseconds: 140),
                        child: Text(
                          'WELCOME BACK, ${displayName.toUpperCase()}',
                          style: AppText.label(
                            size: 11,
                            weight: FontWeight.w500,
                            color: colors.ink(0.45),
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Headline
                    InkEnter(
                      delay: const Duration(milliseconds: 200),
                      child: Text(
                        'READY TO\nSTARE?',
                        style: AppText.display(
                          size: 48,
                          color: colors.foreground,
                          letterSpacing: 2,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline cycler
                    InkEnter(
                      delay: const Duration(milliseconds: 260),
                      child: const _TaglineCycler(),
                    ),
                    const SizedBox(height: 24),

                    // Eye
                    InkEnter(
                      delay: const Duration(milliseconds: 320),
                      child: Center(
                        child: Opacity(
                          opacity: 0.7,
                          child: WatchingEye(
                            height: 180,
                            color: colors.foreground,
                            background: colors.background,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick actions
                    InkEnter(
                      delay: const Duration(milliseconds: 380),
                      child: Text(
                        'QUICK MATCH',
                        style: AppText.label(
                          size: 11,
                          weight: FontWeight.w600,
                          color: colors.ink(0.45),
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    InkEnter(
                      delay: const Duration(milliseconds: 420),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.people_outline,
                              label: 'FRIENDS',
                              onTap: () => context.push('/friends'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.qr_code_2,
                              label: 'QR CODE',
                              onTap: () => context.push('/qr'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.near_me_outlined,
                              label: 'NEARBY',
                              onTap: () => context.push('/nearby'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Join section
                    InkEnter(
                      delay: const Duration(milliseconds: 480),
                      child: _JoinCard(
                        onTap: () => context.push('/challenge/join'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tagline cycler ───────────────────────────────────────────────────────────
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
        style: AppText.label(
          size: 12,
          weight: FontWeight.w500,
          color: context.colors.ink(0.4),
          letterSpacing: 3.5,
        ),
      ),
    );
  }
}

// ── Action card ──────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.dark.surfaceRaised,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: colors.ink(0.1), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.ink(0.55), size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppText.label(
                size: 10,
                weight: FontWeight.w600,
                color: colors.ink(0.45),
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Join card ────────────────────────────────────────────────────────────────
class _JoinCard extends StatelessWidget {
  final VoidCallback onTap;

  const _JoinCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.dark.surfaceRaised,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: colors.ink(0.1), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.login, color: AppColors.acid, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JOIN WITH A CODE',
                    style: AppText.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: colors.foreground,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ENTER A CHALLENGE CODE FROM A FRIEND',
                    style: AppText.label(
                      size: 10,
                      weight: FontWeight.w500,
                      color: colors.ink(0.4),
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.ink(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Bottom nav ───────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dark.surfaceRaised,
        border: Border(
          top: BorderSide(color: AppColors.chalkInk(0.08), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'HOME',
                active: index == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'FRIENDS',
                active: index == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.history,
                activeIcon: Icons.history,
                label: 'HISTORY',
                active: index == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'PROFILE',
                active: index == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.acid : AppColors.chalkInk(0.4);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppText.label(
                size: 9,
                weight: FontWeight.w600,
                color: color,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
