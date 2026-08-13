import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Senior-first typography — large, calm, high-contrast.
///
/// Spec floors: body ≥ 18pt, actions ≥ 22pt. We stay well above those so
/// every phone (including premium Huawei / Honor handsets) stays easy to read.
class AppText {
  AppText._();

  static const String _family = 'Roboto';

  static const TextStyle display = TextStyle(
    fontFamily: _family,
    fontSize: 40,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.deepPurple,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _family,
    fontSize: 30,
    height: 1.28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// For primary on-screen actions (buttons). Well above the 22pt floor.
  static const TextStyle action = TextStyle(
    fontFamily: _family,
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  static const TextStyle error = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.error,
  );

  /// Small supporting captions — never below 18pt for seniors.
  static const TextStyle caption = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
}
