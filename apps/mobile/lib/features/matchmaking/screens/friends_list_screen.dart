import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/friends_provider.dart';
import '../widgets/player_tile.dart';

/// Friends list with incoming requests on top (Feature 3). Challenging a
/// friend sends a targeted invite (push notification) and moves the
/// challenger to the waiting screen.
class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  void _challenge(BuildContext context, Map<String, dynamic> friend) {
    context.push('/challenge/create', extra: {
      'kind': 'friend',
      'opponentId': friend['userId'],
      'opponentName': friend['displayName'] ?? friend['username'],
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(friendsNotifierProvider);
    final notifier = ref.read(friendsNotifierProvider.notifier);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.foreground,
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: 'Find players',
            onPressed: () => context.push('/friends/search'),
          ),
          const MusicToggleButton(),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.background,
          onRefresh: notifier.refresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(state.error!.message,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              if (state.incomingRequests.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Text(
                    'FRIEND REQUESTS',
                    style: TextStyle(
                      color: colors.ink(0.5),
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                for (final req in state.incomingRequests)
                  PlayerTile(
                    title: req['username'] as String,
                    subtitle: '${req['wins'] ?? 0} W · ${req['losses'] ?? 0} L',
                    avatarUrl: req['avatarUrl'] as String?,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.greenAccent),
                          onPressed: () =>
                              notifier.accept(req['friendshipId'] as String),
                        ),
                        IconButton(
                          icon: Icon(Icons.cancel, color: colors.ink(0.38)),
                          onPressed: () =>
                              notifier.decline(req['friendshipId'] as String),
                        ),
                      ],
                    ),
                  ),
                Divider(color: colors.ink(0.12), height: 32),
              ],
              if (state.loading && state.friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: Center(
                      child: CircularProgressIndicator(color: colors.foreground)),
                )
              else if (state.friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: Column(
                    children: [
                      Text(
                        'No friends yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: colors.ink(0.5), fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push('/friends/search'),
                        child: Text('Find players',
                            style: TextStyle(color: colors.foreground)),
                      ),
                    ],
                  ),
                )
              else
                for (final friend in state.friends)
                  PlayerTile(
                    title: (friend['displayName'] ??
                        friend['username']) as String,
                    subtitle:
                        '${friend['wins'] ?? 0} W · ${friend['losses'] ?? 0} L',
                    avatarUrl: friend['avatarUrl'] as String?,
                    trailing: ChallengeButton(
                        onPressed: () => _challenge(context, friend)),
                  ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
