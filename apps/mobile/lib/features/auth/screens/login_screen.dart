import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/audio/background_music.dart';
import '../../../shared/widgets/watching_eye.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {

  // Animation controllers
  late final AnimationController _entranceCtrl;

  late final Animation<double> _headerOpacity;
  late final Animation<double> _headerSlide;
  late final Animation<double> _formOpacity;
  late final Animation<double> _formSlide;
  late final Animation<double> _btnOpacity;

  // Form state
  final _emailCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _formKey   = GlobalKey<FormState>();
  bool _emailValid = false;
  bool _loading    = false;
  String? _error;

  // Footer legal links
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));

    _headerOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _headerSlide = Tween<double>(begin: -14, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _formOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.3, 0.75, curve: Curves.easeOut),
    );
    _formSlide = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.3, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _btnOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entranceCtrl.forward();
    });

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
    _entranceCtrl.dispose();
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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // Back nav + music toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 16),
                      label: const Text(
                        'BACK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withAlpha(115),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                      ),
                    ),
                    const MusicToggleButton(),
                  ],
                ),
              ),

              // Eye + rings
              const WatchingEye(height: 200),

              // Wordmark
              AnimatedBuilder(
                animation: _entranceCtrl,
                builder: (_, child) => Opacity(
                  opacity: _headerOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _headerSlide.value),
                    child: child,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'BLINKR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 10,
                      ),
                    ),
                    const SizedBox(width: 3),
                    _BlinkingCursor(fontSize: 20),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Form
              Expanded(
                child: AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (_, child) => Opacity(
                    opacity: _formOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _formSlide.value),
                      child: child,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ENTER YOUR EMAIL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 4.5,
                            ),
                          ),
                          const SizedBox(height: 18),

                          _EmailField(
                            controller: _emailCtrl,
                            focusNode: _focusNode,
                            onSubmit: _submit,
                          ),

                          const SizedBox(height: 12),
                          const Text(
                            "WE'LL SEND YOU A SECURE LINK",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 2,
                            ),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                            ),
                          ],

                          // OR divider
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 30),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Container(
                                        height: 0.5,
                                        color: Colors.white.withAlpha(51))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Text(
                                    'OR CONTINUE WITH',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(76),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child: Container(
                                        height: 0.5,
                                        color: Colors.white.withAlpha(51))),
                              ],
                            ),
                          ),

                          // Social buttons
                          _SocialButton(
                            icon: const Icon(Icons.apple,
                                color: Colors.white, size: 18),
                            label: 'APPLE',
                            onTap: _signInWithApple,
                          ),
                          const SizedBox(height: 12),
                          _SocialButton(
                            icon: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CustomPaint(painter: _GoogleLogoPainter()),
                            ),
                            label: 'GOOGLE',
                            onTap: _signInWithGoogle,
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Continue button
              AnimatedBuilder(
                animation: _btnOpacity,
                builder: (_, child) =>
                    Opacity(opacity: _btnOpacity.value, child: child),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(36, 0, 36, 16),
                  child: Column(
                    children: [
                      AnimatedOpacity(
                        opacity: _emailValid ? 1.0 : 0.38,
                        duration: const Duration(milliseconds: 250),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed:
                                (_emailValid && !_loading) ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.white,
                              disabledForegroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.black),
                                  )
                                : const Text(
                                    'CONTINUE',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 4),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: Colors.white.withAlpha(51),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1.5,
                            height: 1.8,
                          ),
                          children: [
                            const TextSpan(
                                text: 'By continuing you agree to our\n'),
                            TextSpan(
                              text: 'Terms of Service',
                              style: const TextStyle(
                                color: Color(0x66FFFFFF),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0x33FFFFFF),
                              ),
                              recognizer: _termsTap,
                            ),
                            const TextSpan(text: '   ·   '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: Color(0x66FFFFFF),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0x33FFFFFF),
                              ),
                              recognizer: _privacyTap,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
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

// ── Animated underline email field ────────────────────────────────────────────
class _EmailField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _EmailField({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  State<_EmailField> createState() => _EmailFieldState();
}

class _EmailFieldState extends State<_EmailField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lineCtrl;
  late final Animation<double> _lineWidth;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _lineWidth =
        CurvedAnimation(parent: _lineCtrl, curve: Curves.easeOut);
    widget.focusNode.addListener(() {
      widget.focusNode.hasFocus
          ? _lineCtrl.forward()
          : _lineCtrl.reverse();
    });
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => widget.onSubmit(),
          autocorrect: false,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle: TextStyle(
              color: Colors.white.withAlpha(51),
              fontWeight: FontWeight.w200,
              letterSpacing: 0.5,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Colors.white.withAlpha(76), width: 0.5),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Colors.transparent, width: 0),
            ),
            contentPadding: const EdgeInsets.only(bottom: 8),
          ),
          cursorColor: Colors.white,
          cursorWidth: 1.2,
        ),
        // Animated white underline on focus
        AnimatedBuilder(
          animation: _lineWidth,
          builder: (_, __) => Container(
            height: 0.5,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _lineWidth.value,
              child: Container(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Social sign-in button ─────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  const _SocialButton(
      {required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withAlpha(46), width: 0.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Renders the official Google "G" logo as four colored arcs plus the blue
/// crossbar, avoiding the need to bundle an image asset.
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

    paint.color = const Color(0xFF4285F4); // blue
    canvas.drawArc(rect, -quarter + gap, quarter - gap * 2, false, paint);

    paint.color = const Color(0xFF34A853); // green
    canvas.drawArc(rect, gap, quarter - gap * 2, false, paint);

    paint.color = const Color(0xFFFBBC05); // yellow
    canvas.drawArc(rect, quarter + gap, quarter - gap * 2, false, paint);

    paint.color = const Color(0xFFEA4335); // red
    canvas.drawArc(rect, math.pi + gap, quarter - gap * 2, false, paint);

    // Blue crossbar — the horizontal stroke of the "G"
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

// ── Blinking cursor ───────────────────────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  final double fontSize;
  const _BlinkingCursor({this.fontSize = 32});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 960))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _ctrl,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            '|',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w100,
            ),
          ),
        ),
      );
}

