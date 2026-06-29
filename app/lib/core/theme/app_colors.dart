import 'package:flutter/material.dart';

/// Grandma Mac brand palette.
///
/// Senior-first rule: always pair a dark foreground on a light background
/// (or vice-versa) so every screen keeps a high contrast ratio.
class AppColors {
  AppColors._();

  // Brand
  static const Color deepPurple = Color(0xFF5B2D8E);
  static const Color lavender = Color(0xFFE9DDF7);
  static const Color warmBeige = Color(0xFFF7F1E6);
  static const Color gold = Color(0xFFD4A431);
  static const Color black = Color(0xFF1A1A1A);

  // Semantic
  static const Color background = warmBeige;
  static const Color surface = Colors.white;
  static const Color primary = deepPurple;
  static const Color onPrimary = Colors.white;
  static const Color textPrimary = black;
  static const Color textSecondary = Color(0xFF4A4458);
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF2E7D32);
  static const Color divider = Color(0xFFD8CDEA);
}
