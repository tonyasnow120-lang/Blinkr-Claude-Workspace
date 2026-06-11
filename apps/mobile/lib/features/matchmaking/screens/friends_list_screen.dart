import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
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
          color: Colors.black,
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
                      color: Colors.white.withOpacity(0.5),
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
                          icon: const Icon(Icons.cancel, color: Colors.white38),
                          onPressed: () =>
                              notifier.decline(req['friendshipId'] as String),
                        ),
                      ],
                    ),
                  ),
                const Divider(color: Colors.white12, height: 32),
              ],
              if (state.loading && state.friends.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: Center(
                      child: CircularProgressIndicator(color: Colors.white)),
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
                            color: Colors.white.withOpacity(0.5), fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push('/friends/search'),
                        child: const Text('Find players',
                            style: TextStyle(color: Colors.white)),
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
