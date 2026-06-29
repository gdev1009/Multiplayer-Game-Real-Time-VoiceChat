import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Senior-first typography.
///
/// Minimums enforced by the spec: 18pt for body text, 22pt+ for game actions.
/// We size up from there for comfort.
class AppText {
  AppText._();

  static const String _family = 'Roboto';

  static const TextStyle display = TextStyle(
    fontFamily: _family,
    fontSize: 40,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: AppColors.deepPurple,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _family,
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontSize: 20, // > 18pt minimum
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// For primary on-screen actions (buttons). >= 22pt.
  static const TextStyle action = TextStyle(
    fontFamily: _family,
    fontSize: 24,
    height: 1.1,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle error = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.error,
  );
}
