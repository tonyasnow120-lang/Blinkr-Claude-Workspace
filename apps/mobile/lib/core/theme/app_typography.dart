import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Acid-Ink type system — four strict lanes, each with a single family:
///
/// - **Display** (Bebas Neue): hero, screen titles. UPPERCASE, wide tracking.
/// - **Label** (Barlow Condensed 600–700): buttons, chips, nav, stat labels.
///   UPPERCASE, wide tracking.
/// - **Mono** (Share Tech Mono): codes, timers, stat values.
/// - **Body** (Inter): microcopy only. Sentence case, tight.
///
/// Default colour is chalk (the dark-theme foreground); pass [color] to override
/// on light surfaces. Never mix a family into the wrong role.
class AppText {
  AppText._();

  /// Bebas Neue — display / hero / screen title. Always render UPPERCASE text.
  static TextStyle display({
    double size = 52,
    Color? color,
    double letterSpacing = 1.5,
    double height = 1.0,
  }) =>
      GoogleFonts.bebasNeue(
        fontSize: size,
        color: color ?? AppColors.chalk,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Barlow Condensed — labels / buttons / chips / nav. Always UPPERCASE.
  static TextStyle label({
    double size = 13,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double letterSpacing = 1.3,
    double height = 1.1,
  }) =>
      GoogleFonts.barlowCondensed(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.chalk,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Share Tech Mono — codes / timers / stats. Case as-is.
  static TextStyle mono({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0,
    double height = 1.1,
  }) =>
      GoogleFonts.shareTechMono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.chalk,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Inter — body microcopy only. Sentence case, tight.
  static TextStyle body({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.4,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.chalk,
        height: height,
        letterSpacing: letterSpacing,
      );
}
