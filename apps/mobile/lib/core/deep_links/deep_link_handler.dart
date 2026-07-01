import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/router.dart';

/// Holds a challenge code captured from an invite deep link that arrived while
/// the user was signed out. Consumed once they authenticate.
final pendingChallengeCodeProvider = StateProvider<String?>((ref) => null);

/// Same alphabet/length as the backend shortCode generator and the router's
/// own validator: 9 chars, no O/0/I/1.
final _codePattern = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{9}$');

/// Captures incoming invite links and routes them into the join flow.
///
/// Handles both forms the backend emits:
///   - Universal link:  `https://<host>/match/CODE`
///   - Custom scheme:   `blinkr://match/CODE`
///
/// Auth-callback links (`blinkr://auth/callback`, `login-callback`, …) are
/// ignored here — supabase_flutter runs its own app_links subscription for
/// those. We only act on `/match/*` and `/challenge/*` links with a valid code.
class DeepLinkHandler extends ConsumerStatefulWidget {
  final Widget child;
  const DeepLinkHandler({super.key, required this.child});

  @override
  ConsumerState<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends ConsumerState<DeepLinkHandler> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();

    // Warm links — arriving while the app is already running.
    _linkSub = _appLinks.uriLinkStream.listen(_onUri, onError: (_) {});

    // Cold start — the link that launched the app. Defer navigation until the
    // first frame so the router's Navigator is mounted.
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onUri(uri));
      }
    }).catchError((_) {});

    // Resolve any code stashed while signed out, once the session appears.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _consumePending();
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _onUri(Uri uri) {
    final code = _extractCode(uri);
    if (code == null) return; // not an invite link — leave for other handlers

    final signedIn = Supabase.instance.client.auth.currentSession != null;
    if (signedIn) {
      _go(code);
    } else {
      // Stash it; the welcome/login flow runs, then _consumePending routes once
      // the session is established.
      ref.read(pendingChallengeCodeProvider.notifier).state = code;
    }
  }

  void _consumePending() {
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    if (!signedIn) return;
    final code = ref.read(pendingChallengeCodeProvider);
    if (code == null) return;
    ref.read(pendingChallengeCodeProvider.notifier).state = null;
    // Defer so the post-auth redirect (/auth/success -> /home) settles first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _go(code));
  }

  void _go(String code) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).push('/match/$code');
  }

  /// Normalises an invite URI to a challenge code, or null if it isn't one.
  String? _extractCode(Uri uri) {
    final List<String> segments;
    if (uri.scheme == 'blinkr') {
      // Custom scheme puts the first segment in the host:
      //   blinkr://match/CODE -> host='match', pathSegments=['CODE']
      segments =
          [uri.host, ...uri.pathSegments].where((s) => s.isNotEmpty).toList();
    } else {
      // https://<host>/match/CODE -> pathSegments=['match','CODE']
      segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    }

    if (segments.length < 2) return null;
    if (segments[0] != 'match' && segments[0] != 'challenge') return null;

    final code = segments[1].toUpperCase();
    return _codePattern.hasMatch(code) ? code : null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
