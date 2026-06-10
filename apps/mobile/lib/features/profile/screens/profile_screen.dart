import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';
import '../providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Profile'),
        actions: [
          const MusicToggleButton(),
          TextButton(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/');
            },
            child: const Text('Sign out', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: profile.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: Text(e.toString(), style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (data) {
          final user = data['users'] as Map<String, dynamic>?;
          final stats = data['user_stats'] as Map<String, dynamic>?;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white12,
                      backgroundImage: user?['avatar_url'] != null
                          ? NetworkImage(user!['avatar_url'] as String)
                          : null,
                      child: user?['avatar_url'] == null
                          ? const Icon(Icons.person, color: Colors.white, size: 36)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?['display_name'] as String? ??
                              user?['username'] as String? ??
                              '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@${user?['username'] ?? ''}',
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                if (stats != null) ...[
                  const Text(
                    'Stats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatTile(label: 'Wins', value: '${stats['wins'] ?? 0}'),
                      _StatTile(label: 'Losses', value: '${stats['losses'] ?? 0}'),
                      _StatTile(
                        label: 'Streak',
                        value: '${stats['current_streak'] ?? 0}',
                      ),
                      _StatTile(
                        label: 'Best',
                        value: '${stats['longest_streak'] ?? 0}',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }
}
