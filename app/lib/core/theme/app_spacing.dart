/// Consistent spacing scale. Generous by default for senior-friendly layouts.
class AppSpacing {
  AppSpacing._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Minimum interactive target per the spec (48x48pt).
  static const double minTapTarget = 48;

  /// Standard height for the large primary buttons used across the app.
  static const double buttonHeight = 64;

  /// Page horizontal padding.
  static const double pagePadding = 24;
}
