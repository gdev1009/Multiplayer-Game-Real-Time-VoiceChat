import 'package:flutter/material.dart';

/// Grandma Mac brand palette.
///
/// Senior-first rule: always pair a dark foreground on a light background
/// (or vice-versa) so every screen keeps a high contrast ratio.
class AppColors {
  AppColors._();

  // Brand
  static const Color deepPurple = Color(0xFF5B2D8E);
  static const Color deepPurpleDark = Color(0xFF3B1A63);
  static const Color deepPurpleLight = Color(0xFF7B4FB0);
  static const Color lavender = Color(0xFFE9DDF7);
  static const Color lavenderSoft = Color(0xFFF4EDFB);
  static const Color warmBeige = Color(0xFFF7F1E6);
  static const Color gold = Color(0xFFD4A431);
  static const Color goldLight = Color(0xFFF0D98A);
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

  // ---------------------------------------------------------------------------
  // Premium surface treatments — soft depth without harsh shadows.
  // ---------------------------------------------------------------------------

  /// Gentle vertical page gradient (warm parchment feel).
  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBF7F0), warmBeige],
  );

  /// The rich brand gradient used for primary buttons and the app bar.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepPurpleLight, deepPurple],
  );

  /// The "studio" backdrop the character is presented on — a soft spotlight.
  static const RadialGradient stageGradient = RadialGradient(
    center: Alignment(0, -0.35),
    radius: 1.1,
    colors: [Color(0xFFFDFBFF), lavenderSoft, Color(0xFFDCC9F0)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Soft brand-tinted card shadow for premium elevation.
  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x225B2D8E),
          blurRadius: 24,
          offset: Offset(0, 10),
          spreadRadius: -6,
        ),
      ];

  /// A tighter shadow for smaller interactive tiles.
  static List<BoxShadow> get tileShadow => const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 12,
          offset: Offset(0, 4),
          spreadRadius: -2,
        ),
      ];
}
