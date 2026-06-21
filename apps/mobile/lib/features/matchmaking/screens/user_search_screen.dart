import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/friends_provider.dart';
import '../widgets/player_tile.dart';

/// Username search (Feature 3). Debounced lookup with per-row actions
/// driven by the friendship status the backend annotates on each result.
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _challenge(Map<String, dynamic> user) {
    context.push('/challenge/create', extra: {
      'kind': 'friend',
      'opponentId': user['id'],
      'opponentName': user['displayName'] ?? user['username'],
    });
  }

  Widget _action(Map<String, dynamic> user, AppColors colors) {
    final status = user['friendshipStatus'] as String?;
    final requestedByMe = user['friendshipRequestedByMe'] == true;

    if (status == 'blocked') {
      return Text('Blocked',
          style: TextStyle(color: colors.ink(0.4), fontSize: 13));
    }
    if (status == 'accepted') {
      return ChallengeButton(onPressed: () => _challenge(user));
    }
    if (status == 'pending') {
      return Text(requestedByMe ? 'Requested' : 'Respond in Friends',
          style: TextStyle(color: colors.ink(0.4), fontSize: 13));
    }
    return OutlinedButton(
      onPressed: () async {
        try {
          await ref
              .read(userSearchNotifierProvider.notifier)
              .sendRequest(user['id'] as String);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    e.toString().replaceFirst('Exception: ', ''))));
          }
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.foreground,
        side: BorderSide(color: colors.ink(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text('Add Friend', style: TextStyle(fontSize: 13)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userSearchNotifierProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.foreground,
        title: const Text('Find players'),
        actions: const [MusicToggleButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (q) =>
                    ref.read(userSearchNotifierProvider.notifier).setQuery(q),
                style: TextStyle(color: colors.foreground),
                decoration: InputDecoration(
                  hintText: 'Search by username',
                  hintStyle: TextStyle(color: colors.ink(0.4)),
                  prefixIcon: Icon(Icons.search, color: colors.ink(0.4)),
                  filled: true,
                  fillColor: colors.ink(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (state.loading) const LinearProgressIndicator(minHeight: 1),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(state.error!.message,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              Expanded(
                child: state.results.isEmpty
                    ? Center(
                        child: Text(
                          state.query.length < 2
                              ? 'Type at least 2 characters'
                              : state.loading
                                  ? ''
                                  : 'No players found',
                          style: TextStyle(color: colors.ink(0.4)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.results.length,
                        itemBuilder: (context, i) {
                          final user = state.results[i];
                          final wins = user['wins'] ?? 0;
                          final losses = user['losses'] ?? 0;
                          return PlayerTile(
                            title: user['username'] as String,
                            subtitle: '$wins W · $losses L',
                            avatarUrl: user['avatarUrl'] as String?,
                            trailing: _action(user, colors),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
