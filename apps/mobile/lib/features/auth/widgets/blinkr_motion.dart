import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/watching_eye.dart';

/// The animated "watching eye" graphic shared by the auth screens — see
/// [WatchingEye] for the canonical implementation.
class BlinkrEyeGraphic extends StatelessWidget {
  final double height;

  const BlinkrEyeGraphic({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return WatchingEye(
      height: height,
      color: colors.foreground,
      background: colors.background,
    );
  }
}


/// The "BLINKR" wordmark with a blinking text-cursor, used on auth screens.
class BlinkrWordmark extends StatelessWidget {
  final double fontSize;

  const BlinkrWordmark({super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'BLINKR',
          style: TextStyle(
            color: colors.foreground,
            fontSize: fontSize,
            fontWeight: FontWeight.w200,
            letterSpacing: 10,
          ),
        ),
        const SizedBox(width: 3),
        BlinkrCursor(fontSize: fontSize - 2),
      ],
    );
  }
}

/// A blinking "|" text cursor, fading in and out on a loop.
class BlinkrCursor extends StatefulWidget {
  final double fontSize;
  const BlinkrCursor({super.key, this.fontSize = 32});

  @override
  State<BlinkrCursor> createState() => _BlinkrCursorState();
}

class _BlinkrCursorState extends State<BlinkrCursor>
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
              color: context.colors.foreground,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w100,
            ),
          ),
        ),
      );
}

/// A text field with an animated white underline that expands on focus,
/// matching the login screen's email field styling.
class UnderlineTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback? onSubmit;
  final String hintText;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  const UnderlineTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onSubmit,
    required this.hintText,
    this.textInputAction = TextInputAction.done,
    this.inputFormatters,
  });

  @override
  State<UnderlineTextField> createState() => _UnderlineTextFieldState();
}

class _UnderlineTextFieldState extends State<UnderlineTextField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lineCtrl;
  late final Animation<double> _lineWidth;
  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _lineWidth = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeOut);

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(() {
      _focusNode.hasFocus ? _lineCtrl.forward() : _lineCtrl.reverse();
    });
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: (_) => widget.onSubmit?.call(),
          autocorrect: false,
          inputFormatters: widget.inputFormatters,
          style: TextStyle(
            color: colors.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: colors.ink(0.2),
              fontWeight: FontWeight.w200,
              letterSpacing: 0.5,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: colors.ink(0.3), width: 0.5),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent, width: 0),
            ),
            contentPadding: const EdgeInsets.only(bottom: 8),
          ),
          cursorColor: colors.foreground,
          cursorWidth: 1.2,
        ),
        AnimatedBuilder(
          animation: _lineWidth,
          builder: (_, __) => Container(
            height: 0.5,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _lineWidth.value,
              child: Container(color: colors.foreground),
            ),
          ),
        ),
      ],
    );
  }
}
