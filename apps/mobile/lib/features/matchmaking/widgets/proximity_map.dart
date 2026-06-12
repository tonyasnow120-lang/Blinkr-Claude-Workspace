import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'player_tile.dart';
import '../../../shared/widgets/line_eye.dart';

/// Interactive map for the Nearby screen. The backend only ever returns
/// distance to other players (never their coordinates — see
/// proximity.ts), so each player is plotted at their real distance from
/// "you" along a per-player stable-but-arbitrary bearing. This keeps exact
/// directions private while still giving a sense of "how close" everyone
/// is, and the markers stay put across refreshes.
class ProximityMap extends StatelessWidget {
  final double myLat;
  final double myLng;
  final List<Map<String, dynamic>> nearby;
  final void Function(Map<String, dynamic> player) onChallenge;

  const ProximityMap({
    super.key,
    required this.myLat,
    required this.myLng,
    required this.nearby,
    required this.onChallenge,
  });

  static const _distance = Distance();

  /// Deterministic pseudo-bearing in [0, 360) derived from the player's id,
  /// so a given player's marker stays in the same place between heartbeats.
  double _bearingFor(String id) {
    final hash = id.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
    return (hash % 360).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final me = LatLng(myLat, myLng);

    final markers = <Marker>[
      Marker(
        point: me,
        width: 28,
        height: 28,
        child: const _SelfMarker(),
      ),
      for (final player in nearby)
        Marker(
          point: _distance.offset(
            me,
            ((player['distanceMeters'] as num?) ?? 0).toDouble(),
            _bearingFor(player['id'] as String),
          ),
          width: 44,
          height: 44,
          child: _PlayerMarker(
            player: player,
            onTap: () => _showPlayerSheet(context, player),
          ),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: me,
              initialZoom: 16,
              minZoom: 12,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              ColorFiltered(
                // Brighten + boost contrast on the dark basemap so streets,
                // labels and water stand out more clearly against the UI.
                colorFilter: const ColorFilter.matrix(<double>[
                  1.6, 0, 0, 0, 25,
                  0, 1.6, 0, 0, 25,
                  0, 0, 1.6, 0, 25,
                  0, 0, 0, 1, 0,
                ]),
                child: TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.blinkr.app',
                ),
              ),
              // Radius ring so "nearby" feels grounded in real distance.
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: me,
                    radius: 500,
                    useRadiusInMeter: true,
                    color: Colors.white.withOpacity(0.06),
                    borderColor: Colors.white.withOpacity(0.35),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(markers: markers),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                popupInitialDisplayDuration: Duration.zero,
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors © CARTO',
                    textStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: Colors.white.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Positions are approximate — exact directions are hidden for privacy',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerSheet(BuildContext context, Map<String, dynamic> player) {
    final wins = (player['wins'] ?? 0) as int;
    final losses = (player['losses'] ?? 0) as int;
    final total = wins + losses;
    final winRate = total == 0 ? '—' : '${(wins * 100 / total).round()}%';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: PlayerTile(
            title: (player['displayName'] ?? player['username']) as String,
            subtitle: '~${player['distanceMeters']}m away · $winRate win rate',
            avatarUrl: player['avatarUrl'] as String?,
            trailing: ChallengeButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                onChallenge(player);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SelfMarker extends StatelessWidget {
  const _SelfMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 8, spreadRadius: 2),
        ],
      ),
      child: const SizedBox(
        width: 18,
        height: 18,
        child: Center(child: LineEyeIcon(size: 13, color: Colors.black)),
      ),
    );
  }
}

class _PlayerMarker extends StatelessWidget {
  final Map<String, dynamic> player;
  final VoidCallback onTap;

  const _PlayerMarker({required this.player, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = player['avatarUrl'] as String?;
    final title = (player['displayName'] ?? player['username'] ?? '?') as String;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 4),
              ],
              image: avatarUrl != null
                  ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: avatarUrl == null
                ? Center(
                    child: Text(
                      title.isNotEmpty ? title[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                : null,
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '~${player['distanceMeters']}m',
              style: const TextStyle(color: Colors.white, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}
