import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum BlinkrAccentVariant { acid, ghost, danger }

/// A small status marker — sharp 2px corners, Barlow Condensed 600 UPPERCASE.
/// - **acid** — acid border + text (LIVE / active).
/// - **ghost** — ink-20 border + ink-55 text (PENDING / idle).
/// - **danger** — red border + text.
class BlinkrChip extends StatelessWidget {
  final String label;
  final BlinkrAccentVariant variant;

  const BlinkrChip({
    super.key,
    required this.label,
    this.variant = BlinkrAccentVariant.ghost,
  });

  @override
  Widget build(BuildContext context) {
    final (border, text) = _colors(variant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppText.label(size: 10, weight: FontWeight.w600, color: text),
      ),
    );
  }
}

/// A pill variant of [BlinkrChip] — same palette, fully rounded.
class BlinkrBadge extends StatelessWidget {
  final String label;
  final BlinkrAccentVariant variant;
  final bool filled;

  const BlinkrBadge({
    super.key,
    required this.label,
    this.variant = BlinkrAccentVariant.acid,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final (border, text) = _colors(variant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? border : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppText.label(
          size: 10,
          weight: FontWeight.w700,
          color: filled ? AppColors.chalk : text,
        ),
      ),
    );
  }
}

(Color, Color) _colors(BlinkrAccentVariant v) {
  switch (v) {
    case BlinkrAccentVariant.acid:
      return (AppColors.acid, AppColors.acid);
    case BlinkrAccentVariant.ghost:
      return (AppColors.chalkInk(0.20), AppColors.chalkInk(0.55));
    case BlinkrAccentVariant.danger:
      return (AppColors.red, AppColors.red);
  }
}
