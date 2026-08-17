import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Senior-first typography — calm, high-contrast, phone-fit.
///
/// Sized for real devices (~75% of the earlier oversized pass) so screens
/// fit without cut-off while staying above senior readability floors.
class AppText {
  AppText._();

  static const String _family = 'Roboto';

  static const TextStyle display = TextStyle(
    fontFamily: _family,
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.deepPurple,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    height: 1.28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// Primary on-screen actions (buttons).
  static const TextStyle action = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  static const TextStyle error = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.error,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
}
