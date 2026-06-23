import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/blinkr_button.dart';
import '../../../shared/widgets/ink_enter.dart';
import '../../../shared/widgets/ink_scaffold.dart';
import '../../../shared/widgets/watching_eye.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _emailValid = false;
  bool _loading = false;
  String? _error;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onEmailChanged);
    _termsTap = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/terms');
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/privacy');
  }

  void _onEmailChanged() {
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(_emailCtrl.text.trim());
    if (valid != _emailValid) setState(() => _emailValid = valid);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _focusNode.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_emailValid || _loading) return;
    _focusNode.unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      await ref.read(authServiceProvider).signInWithOtp(email);
      if (mounted) context.push('/verify', extra: email);
    } catch (e) {
      String msg = e.toString();
      if (e is AuthException) msg = e.message;
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    try {
      await ref.read(authServiceProvider).signInWithApple();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return InkScaffold(
      splatSeed: 27,
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar — back + music toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.arrow_back,
                          color: colors.foreground, size: 20),
                    ),
                    const MusicToggleButton(),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Eye — smaller for login
                      InkEnter(
                        child: Opacity(
                          opacity: 0.55,
                          child: WatchingEye(
                            height: 100,
                            color: colors.foreground,
                            background: colors.background,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      InkEnter(
                        delay: const Duration(milliseconds: 100),
                        child: Text(
                          'WHO ARE YOU?',
                          style: AppText.display(
                            size: 52,
                            color: colors.foreground,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Subtitle
                      InkEnter(
                        delay: const Duration(milliseconds: 160),
                        child: Text(
                          "WE'LL SEND A CODE.",
                          style: AppText.label(
                            size: 13,
                            weight: FontWeight.w500,
                            color: colors.ink(0.45),
                            letterSpacing: 2.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Email input
                      InkEnter(
                        delay: const Duration(milliseconds: 240),
                        child: _EmailInput(
                          controller: _emailCtrl,
                          focusNode: _focusNode,
                          onSubmit: _submit,
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: AppText.body(
                            size: 12,
                            color: AppColors.red,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // CTA
                      InkEnter(
                        delay: const Duration(milliseconds: 320),
                        child: AnimatedOpacity(
                          opacity: _emailValid ? 1.0 : 0.38,
                          duration: const Duration(milliseconds: 250),
                          child: BlinkrButton.accent(
                            label: _loading ? '...' : 'CONTINUE',
                            onPressed:
                                (_emailValid && !_loading) ? _submit : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // OR divider
                      InkEnter(
                        delay: const Duration(milliseconds: 380),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                  height: 0.5, color: colors.ink(0.15)),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: AppText.label(
                                  size: 10,
                                  weight: FontWeight.w500,
                                  color: colors.ink(0.3),
                                  letterSpacing: 2.4,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                  height: 0.5, color: colors.ink(0.15)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Social buttons
                      InkEnter(
                        delay: const Duration(milliseconds: 440),
                        child: _SocialButton(
                          icon: Icon(Icons.apple,
                              color: colors.foreground, size: 18),
                          label: 'APPLE',
                          onTap: _signInWithApple,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkEnter(
                        delay: const Duration(milliseconds: 500),
                        child: _SocialButton(
                          icon: SizedBox(
                            width: 16,
                            height: 16,
                            child: CustomPaint(
                                painter: const _GoogleLogoPainter()),
                          ),
                          label: 'GOOGLE',
                          onTap: _signInWithGoogle,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Legal
                      InkEnter(
                        delay: const Duration(milliseconds: 540),
                        child: Text.rich(
                          TextSpan(
                            style: AppText.label(
                              size: 9,
                              weight: FontWeight.w400,
                              color: colors.ink(0.25),
                              letterSpacing: 1.5,
                              height: 1.8,
                            ),
                            children: [
                              const TextSpan(
                                  text: 'BY CONTINUING YOU AGREE TO OUR\n'),
                              TextSpan(
                                text: 'TERMS OF SERVICE',
                                style: TextStyle(
                                  color: colors.ink(0.45),
                                  decoration: TextDecoration.underline,
                                  decorationColor: colors.ink(0.2),
                                ),
                                recognizer: _termsTap,
                              ),
                              const TextSpan(text: '   ·   '),
                              TextSpan(
                                text: 'PRIVACY POLICY',
                                style: TextStyle(
                                  color: colors.ink(0.45),
                                  decoration: TextDecoration.underline,
                                  decorationColor: colors.ink(0.2),
                                ),
                                recognizer: _privacyTap,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Email input with focus-aware acid border ─────────────────────────────────
class _EmailInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _EmailInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  State<_EmailInput> createState() => _EmailInputState();
}

class _EmailInputState extends State<_EmailInput> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceInsetDark,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: focused ? AppColors.acid : AppColors.borderDefault,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => widget.onSubmit(),
        autocorrect: false,
        cursorColor: AppColors.acid,
        style: AppText.mono(size: 16, color: AppColors.chalk),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: InputBorder.none,
          hintText: 'you@example.com',
          hintStyle: AppText.label(
            size: 14,
            weight: FontWeight.w500,
            color: AppColors.chalkInk(0.30),
          ),
        ),
      ),
    );
  }
}

// ── Ghost social sign-in button ──────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  const _SocialButton(
      {required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.foreground,
          side: BorderSide(color: colors.ink(0.18), width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: AppText.label(
                size: 13,
                weight: FontWeight.w600,
                color: colors.foreground,
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Official Google "G" logo as four colored arcs plus the blue crossbar.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.22;
    final rect = Rect.fromCircle(
      center: center,
      radius: size.width / 2 - strokeWidth / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    const gap = 0.05;
    const quarter = math.pi / 2;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -quarter + gap, quarter - gap * 2, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, gap, quarter - gap * 2, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, quarter + gap, quarter - gap * 2, false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, math.pi + gap, quarter - gap * 2, false, paint);

    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - strokeWidth * 0.1,
        center.dy - strokeWidth / 2,
        size.width / 2 - center.dx + strokeWidth * 0.1,
        strokeWidth,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
