import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/challenge_provider.dart';

class JoinChallengeScreen extends ConsumerStatefulWidget {
  final String? code;
  const JoinChallengeScreen({super.key, this.code});

  @override
  ConsumerState<JoinChallengeScreen> createState() =>
      _JoinChallengeScreenState();
}

class _JoinChallengeScreenState extends ConsumerState<JoinChallengeScreen> {
  late final TextEditingController _codeController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.code ?? '');
    if (widget.code != null && widget.code!.isNotEmpty) {
      Future.microtask(_accept);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref
        .read(challengeNotifierProvider.notifier)
        .acceptChallenge(code);

    if (mounted) {
      setState(() => _loading = false);
      if (result != null) {
        context.push('/match/${result['matchId']}/lobby', extra: result);
      } else {
        final state = ref.read(challengeNotifierProvider);
        setState(() => _error = state.error ?? 'Failed to join challenge.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Join Challenge'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Enter the 6-letter code',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              maxLength: 6,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'XXXXXX',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  letterSpacing: 8,
                  fontSize: 28,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _accept,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Accept Challenge',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
