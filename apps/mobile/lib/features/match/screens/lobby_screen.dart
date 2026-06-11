import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/match_provider.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/audio/background_music.dart';
import '../../auth/providers/auth_provider.dart';

/// Shared match lobby — every matchmaking flow (link, contacts, friends,
/// QR, nearby) lands both players here. Shows both avatars with live ready
/// indicators; the countdown starts when both players have readied up
/// (server broadcasts `match.countdown_start` once both flags are set).
class LobbyScreen extends ConsumerStatefulWidget {
  final String matchId;
  final Map<String, dynamic> matchData;

  const LobbyScreen({
    super.key,
    required this.matchId,
    required this.matchData,
  });

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _ready = false;
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _opponent;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    try {
      final api = ref.read(apiClientProvider);
      final matchRes = await api.get(ApiEndpoints.matchById(widget.matchId));
      final match = matchRes['data'] as Map<String, dynamic>;
      final myId = Supabase.instance.client.auth.currentUser?.id;
      final p1 = match['playerOneId'] as String;
      final p2 = match['playerTwoId'] as String;
      final opponentId = myId == p1 ? p2 : p1;
      final meId = myId == p1 ? p1 : p2;

      final results = await Future.wait([
        api.get(ApiEndpoints.userById(meId)),
        api.get(ApiEndpoints.userById(opponentId)),
      ]);
      if (!mounted) return;
      setState(() {
        _me = results[0]['data'] as Map<String, dynamic>;
        _opponent = results[1]['data'] as Map<String, dynamic>;
      });
    } catch (_) {
      // Lobby still works without profiles — avatars just show placeholders.
    }
  }

  Widget _playerColumn(Map<String, dynamic>? user, {required bool ready}) {
    final name =
        (user?['displayName'] ?? user?['username'] ?? '…') as String;
    final avatarUrl = user?['avatarUrl'] as String?;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withOpacity(0.15),
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 28),
                    )
                  : null,
            ),
            if (ready)
              const Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.black,
                  child: Icon(Icons.check_circle,
                      color: Colors.greenAccent, size: 22),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 110,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ready ? 'READY' : 'NOT READY',
          style: TextStyle(
            color: ready ? Colors.greenAccent : Colors.white38,
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchNotifierProvider(widget.matchId));

    ref.listen(matchNotifierProvider(widget.matchId), (prev, next) {
      if (next.phase == MatchPhase.countdown) {
        context.pushReplacement(
          '/match/${widget.matchId}/countdown',
          extra: {'startsAt': next.countdownStartsAt?.toIso8601String()},
        );
      } else if (next.phase == MatchPhase.abandoned) {
        context.pushReplacement('/match/${widget.matchId}/result');
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: const [MusicToggleButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Lobby',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _playerColumn(_me, ready: _ready),
                  Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 20,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 4,
                    ),
                  ),
                  _playerColumn(_opponent, ready: matchState.opponentReady),
                ],
              ),
              const SizedBox(height: 48),
              if (!_ready)
                FilledButton(
                  onPressed: () async {
                    setState(() => _ready = true);
                    try {
                      await ref
                          .read(matchNotifierProvider(widget.matchId).notifier)
                          .markReady();
                    } catch (e) {
                      if (mounted) {
                        setState(() => _ready = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(e
                              .toString()
                              .replaceFirst('Exception: ', '')),
                        ));
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "I'm Ready 👁️",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                )
              else
                Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      matchState.opponentReady
                          ? 'Starting…'
                          : 'Waiting for opponent…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
