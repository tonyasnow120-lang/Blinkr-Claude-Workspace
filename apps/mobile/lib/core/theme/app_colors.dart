import 'package:flutter/material.dart';

/// Acid-Ink design system tokens. Near-black foundations, chalk-white ink
/// ladder, a single neon-green accent, and red for loss/destructive only.
class AppColors {
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color foreground;

  // --- Accent ---
  static const acid = Color(0xFF39FF14);
  static const acidDim = Color(0xFF1A7A08);
  static const acidInk = Color(0xFF1A1F00);

  // --- Pop (≤2% emphasis) ---
  static const fuchsia = Color(0xFFFF00CC);
  static const purple = Color(0xFF9B00FF);

  // --- Semantic ---
  static const red = Color(0xFFFF3B30);

  // --- Border ---
  static const borderDefault = Color(0xFF2A2A22);

  // --- Const-safe aliases (use in default params and const expressions) ---
  static const chalk = Color(0xFFF0EDE0);
  static const bg = Color(0xFF080808);

  const AppColors._({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.foreground,
  });

  static const dark = AppColors._(
    background: Color(0xFF080808),
    surface: Color(0xFF111110),
    surfaceRaised: Color(0xFF1A1C18),
    foreground: Color(0xFFF0EDE0),
  );

  static const light = AppColors._(
    background: Color(0xFFF0EDE0),
    surface: Color(0xFFE4E1D6),
    surfaceRaised: Color(0xFFD8D5CA),
    foreground: Color(0xFF080808),
  );

  Color ink(double opacity) => foreground.withOpacity(opacity);
}

extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
}
