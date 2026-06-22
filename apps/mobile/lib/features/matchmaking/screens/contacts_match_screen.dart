import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../matchmaking_error.dart';
import '../providers/matchmaking_provider.dart';
import '../services/contacts_service.dart';
import '../widgets/player_tile.dart';

final contactsServiceProvider = Provider<ContactsService>((ref) {
  return ContactsService(ref.watch(matchmakingServiceProvider));
});

/// Contact discovery (Feature 2). Flow: privacy disclosure → OS permission
/// → hashed lookup → list of contacts on Blinkr with one-tap challenge.
class ContactsMatchScreen extends ConsumerStatefulWidget {
  const ContactsMatchScreen({super.key});

  @override
  ConsumerState<ContactsMatchScreen> createState() =>
      _ContactsMatchScreenState();
}

enum _Stage { disclosure, loading, list, error }

class _ContactsMatchScreenState extends ConsumerState<ContactsMatchScreen> {
  _Stage _stage = _Stage.disclosure;
  List<MatchedContact> _matches = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    // Skip the disclosure if permission was already granted previously.
    Future.microtask(() async {
      if (await ref.read(contactsServiceProvider).hasPermission()) {
        _load();
      }
    });
  }

  Future<void> _onDisclosureAccepted() async {
    final service = ref.read(contactsServiceProvider);
    try {
      // The OS prompt fires only now — after the rationale was shown.
      final granted = await service.requestPermission();
      if (!granted) {
        setState(() {
          _stage = _Stage.error;
          _error = 'Contacts permission was not granted.';
        });
        return;
      }
      await _load();
    } on MatchmakingError catch (e) {
      setState(() {
        _stage = _Stage.error;
        _error = e.message;
      });
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _stage = _Stage.loading);
    try {
      final matches = await ref
          .read(contactsServiceProvider)
          .findFriendsOnBlinkr(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _stage = _Stage.list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e is MatchmakingError
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _challenge(MatchedContact contact) {
    context.push('/challenge/create', extra: {
      'kind': 'contact',
      'opponentId': contact.userId,
      'opponentName': contact.contactName,
    });
  }

  Widget _disclosure(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.contacts_outlined, color: colors.foreground, size: 48),
          const SizedBox(height: 24),
          Text(
            'FIND FRIENDS FROM YOUR CONTACTS',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: colors.foreground, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Here\'s exactly what happens:\n\n'
            '•  Phone numbers from your contacts are scrambled (hashed) on '
            'your phone.\n'
            '•  Only those scrambled codes are sent to Blinkr to check for '
            'matches — never names, never actual numbers.\n'
            '•  Nothing is stored on our servers, and numbers never appear '
            'in logs.\n'
            '•  Only players who allow contact discovery will appear.',
            style: TextStyle(color: colors.ink(0.6), height: 1.5),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _onDisclosureAccepted,
            style: FilledButton.styleFrom(
              backgroundColor: colors.foreground,
              foregroundColor: colors.background,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('CONTINUE',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.pop(),
            child: Text('NOT NOW', style: TextStyle(color: colors.ink(0.5))),
          ),
        ],
      ),
    );
  }

  Widget _list(AppColors colors) {
    if (_matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'None of your contacts are on Blinkr yet.\nChallenge them with an invite link instead!',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.ink(0.5), height: 1.5),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _matches.length,
      itemBuilder: (context, i) {
        final contact = _matches[i];
        return PlayerTile(
          title: contact.contactName,
          subtitle: '@${contact.username}',
          avatarUrl: contact.avatarUrl,
          trailing: ChallengeButton(onPressed: () => _challenge(contact)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.foreground,
        title: const Text('CONTACTS'),
        actions: [
          if (_stage == _Stage.list)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => _load(forceRefresh: true),
            ),
          const MusicToggleButton(),
        ],
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.disclosure => _disclosure(colors),
          _Stage.loading =>
            Center(child: CircularProgressIndicator(color: colors.foreground)),
          _Stage.list => _list(colors),
          _Stage.error => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Something went wrong.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.red),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _load(forceRefresh: true),
                      child: Text('RETRY',
                          style: TextStyle(color: colors.foreground)),
                    ),
                  ],
                ),
              ),
            ),
        },
      ),
    );
  }
}
