import 'package:flutter/material.dart';

/// Semantic color tokens for Blinkr's two looks: the original dark theme
/// (white-on-black) and its light inversion (black-on-white). Both share
/// the same background/surface/foreground structure and opacity steps, so
/// translucent text, borders and fills read the same in either mode — just
/// inverted.
class AppColors {
  final Color background;
  final Color surface;
  final Color foreground;

  static const acid = Color(0xFFCCFF00);
  static const acidInk = Color(0xFF1A1F00);

  const AppColors._({
    required this.background,
    required this.surface,
    required this.foreground,
  });

  static const dark = AppColors._(
    background: Colors.black,
    surface: Color(0xFF1C1C1E),
    foreground: Colors.white,
  );

  static const light = AppColors._(
    background: Colors.white,
    surface: Color(0xFFF0F0F3),
    foreground: Colors.black,
  );

  /// [foreground] at the given opacity — the inversion-safe replacement for
  /// patterns like `Colors.white54` (-> `ink(0.54)`) or
  /// `Colors.white.withOpacity(0.6)` (-> `ink(0.6)`).
  Color ink(double opacity) => foreground.withOpacity(opacity);
}

extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
}
