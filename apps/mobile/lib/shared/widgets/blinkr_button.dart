import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum BlinkrButtonVariant { accent, ghost, danger }

/// The one button in the system. Three variants:
/// - **accent** — acid fill, acid-ink text, neon glow that intensifies on press.
/// - **ghost** — transparent, chalk hairline border, chalk text.
/// - **danger** — red fill, chalk text.
///
/// Sharp corners (2px), Barlow Condensed 700 UPPERCASE, wide tracking, 52px tall
/// by default. The label is uppercased for you.
class BlinkrButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final BlinkrButtonVariant variant;
  final IconData? icon;
  final double height;
  final bool expand;

  const BlinkrButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BlinkrButtonVariant.accent,
    this.icon,
    this.height = 52,
    this.expand = true,
  });

  const BlinkrButton.accent({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.expand = true,
  }) : variant = BlinkrButtonVariant.accent;

  const BlinkrButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.expand = true,
  }) : variant = BlinkrButtonVariant.ghost;

  const BlinkrButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.expand = true,
  }) : variant = BlinkrButtonVariant.danger;

  @override
  State<BlinkrButton> createState() => _BlinkrButtonState();
}

class _BlinkrButtonState extends State<BlinkrButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final accent = widget.variant == BlinkrButtonVariant.accent;
    final ghost = widget.variant == BlinkrButtonVariant.ghost;

    final Color fill;
    final Color fg;
    final Border? border;
    switch (widget.variant) {
      case BlinkrButtonVariant.accent:
        fill = AppColors.acid;
        fg = AppColors.acidInk;
        border = null;
      case BlinkrButtonVariant.ghost:
        fill = Colors.transparent;
        fg = AppColors.chalk;
        border = Border.all(color: AppColors.chalkInk(0.30), width: 1);
      case BlinkrButtonVariant.danger:
        fill = AppColors.red;
        fg = AppColors.chalk;
        border = null;
    }

    // Neon glow on the accent button, swelling while pressed.
    final glow = accent
        ? [
            BoxShadow(
              color: AppColors.acid.withOpacity(_pressed ? 0.55 : 0.30),
              blurRadius: _pressed ? 26 : 16,
              spreadRadius: _pressed ? 1 : 0,
            ),
          ]
        : null;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label.toUpperCase(),
          style: AppText.label(size: 14, weight: FontWeight.w700, color: fg),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: const Cubic(0.2, 0, 0, 1),
          height: widget.height,
          width: widget.expand ? double.infinity : null,
          padding: widget.expand
              ? null
              : const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ghost && _pressed ? AppColors.chalkInk(0.06) : fill,
            borderRadius: BorderRadius.circular(2),
            border: border,
            boxShadow: glow,
          ),
          child: child,
        ),
      ),
    );
  }
}
