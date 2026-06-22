import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/proximity_provider.dart';
import '../widgets/player_tile.dart';
import '../widgets/proximity_map.dart';

/// GPS radius matching (Feature 5). A visibility toggle gates everything:
/// location is shared only while it's on, heartbeats every 30s, expires
/// after 10 minutes, and leaving the screen goes invisible immediately.
class ProximityScreen extends ConsumerStatefulWidget {
  const ProximityScreen({super.key});

  @override
  ConsumerState<ProximityScreen> createState() => _ProximityScreenState();
}

class _ProximityScreenState extends ConsumerState<ProximityScreen> {
  static const _disclosureSeenKey = 'proximity_disclosure_seen_v1';
  bool? _disclosureSeen;
  bool _showMap = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(
            () => _disclosureSeen = prefs.getBool(_disclosureSeenKey) ?? false);
      }
    });
  }

  Future<void> _acceptDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disclosureSeenKey, true);
    if (mounted) setState(() => _disclosureSeen = true);
  }

  void _challenge(Map<String, dynamic> player) {
    context.push('/challenge/create', extra: {
      'kind': 'proximity',
      'opponentId': player['id'],
      'opponentName': player['displayName'] ?? player['username'],
    });
  }

  Widget _disclosure() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.near_me_outlined, color: colors.foreground, size: 48),
          const SizedBox(height: 24),
          Text(
            'PLAY PEOPLE NEARBY',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: colors.foreground, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Before you turn this on, know how it works:\n\n'
            '•  Your location is shared ONLY while the visibility toggle is '
            'on, and is deleted the moment you turn it off or leave this '
            'screen.\n'
            '•  Other players never see your coordinates — only roughly how '
            'far away you are (e.g. "~45m away").\n'
            '•  Visibility switches off automatically after 10 minutes.',
            style: TextStyle(color: colors.ink(0.6), height: 1.5),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _acceptDisclosure,
            style: FilledButton.styleFrom(
              backgroundColor: colors.foreground,
              foregroundColor: colors.background,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('GOT IT',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(proximityNotifierProvider);
    final notifier = ref.read(proximityNotifierProvider.notifier);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.foreground,
        title: const Text('NEARBY'),
        actions: [
          if (state.visible) ...[
            IconButton(
              icon: Icon(_showMap ? Icons.list : Icons.map_outlined),
              tooltip: _showMap ? 'Show list' : 'Show map',
              onPressed: () => setState(() => _showMap = !_showMap),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: notifier.refresh,
            ),
          ],
          const MusicToggleButton(),
        ],
      ),
      body: SafeArea(
        child: _disclosureSeen == null
            ? Center(
                child: CircularProgressIndicator(color: colors.foreground))
            : !_disclosureSeen!
                ? _disclosure()
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: SwitchListTile(
                          value: state.visible,
                          onChanged:
                              state.busy ? null : (on) => notifier.setVisible(on),
                          activeColor: colors.foreground,
                          activeTrackColor: AppColors.acid.withOpacity(0.5),
                          title: Text(
                            'Make me visible to nearby players',
                            style: TextStyle(color: colors.foreground),
                          ),
                          subtitle: Text(
                            state.visible
                                ? 'Visible — auto-off in 10 minutes'
                                : 'Invisible',
                            style: TextStyle(
                                color: colors.ink(0.5),
                                fontSize: 12),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            state.error!.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.red),
                          ),
                        ),
                      Expanded(
                        child: !state.visible
                            ? Center(
                                child: Text(
                                  state.busy
                                      ? 'Finding your location…'
                                      : 'Turn on visibility to see\nwho\'s around you',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: colors.ink(0.4),
                                      height: 1.5),
                                ),
                              )
                            : _showMap && state.myLat != null && state.myLng != null
                                ? Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                    child: ProximityMap(
                                      myLat: state.myLat!,
                                      myLng: state.myLng!,
                                      nearby: state.nearby,
                                      onChallenge: _challenge,
                                    ),
                                  )
                                : state.nearby.isEmpty
                                ? Center(
                                    child: Text(
                                      'Nobody nearby right now.\nThey need this screen open too!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: colors.ink(0.4),
                                          height: 1.5),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    itemCount: state.nearby.length,
                                    itemBuilder: (context, i) {
                                      final player = state.nearby[i];
                                      final wins = player['wins'] ?? 0;
                                      final losses = player['losses'] ?? 0;
                                      final total = (wins as int) + (losses as int);
                                      final winRate = total == 0
                                          ? '—'
                                          : '${(wins * 100 / total).round()}%';
                                      return PlayerTile(
                                        title: (player['displayName'] ??
                                            player['username']) as String,
                                        subtitle:
                                            '~${player['distanceMeters']}m away · $winRate win rate',
                                        avatarUrl:
                                            player['avatarUrl'] as String?,
                                        trailing: ChallengeButton(
                                            onPressed: () =>
                                                _challenge(player)),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
