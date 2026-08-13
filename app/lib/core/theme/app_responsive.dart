import 'package:flutter/material.dart';

/// Layout helpers so screens stay comfortable on every phone.
///
/// **Typography is never shrunk for width.** Spacing / chrome can compress;
/// body, titles, and actions keep senior-readable sizes (Ronna / Honor Pro).
class AppResponsive {
  AppResponsive._();

  /// Logical width we designed most screens against.
  static const double designWidth = 390;

  /// Logical height we designed most screens against.
  static const double designHeight = 844;

  /// Cap content on very wide phones / small tablets.
  static const double contentMaxWidth = 560;

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static double widthOf(BuildContext context) => sizeOf(context).width;

  static double heightOf(BuildContext context) => sizeOf(context).height;

  /// True for compact-width phones (layout chrome only — not type).
  static bool isNarrow(BuildContext context) => widthOf(context) < 380;

  /// True when vertical room is tight (keyboard up or short devices).
  static bool isShort(BuildContext context) {
    final h = heightOf(context) - MediaQuery.viewInsetsOf(context).bottom;
    return h < 700;
  }

  /// Combined scale for spacing / icons / decorative sizes only.
  static double scaleOf(BuildContext context) {
    final size = sizeOf(context);
    final byWidth = (size.width / designWidth).clamp(0.88, 1.12);
    final byHeight = (size.height / designHeight).clamp(0.88, 1.12);
    return (byWidth * 0.6 + byHeight * 0.4).clamp(0.88, 1.12);
  }

  /// Scale a design-time chrome size (avatar, logo, icon). Not for body type.
  static double s(BuildContext context, double base) =>
      base * scaleOf(context);

  /// Comfortable gutters — keep horizontal room so large type wraps cleanly.
  static EdgeInsets pageInsets(BuildContext context) {
    final h = isNarrow(context) ? 18.0 : 24.0;
    final v = isShort(context) ? 16.0 : 24.0;
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  /// Large primary buttons — stay easy to tap even on short phones.
  static double buttonHeight(BuildContext context) =>
      isShort(context) ? 60.0 : 68.0;

  /// Soft-clamp OS font scaling. Floor is 1.0; allow up to 1.35 for seniors
  /// who bump system text size.
  static TextScaler textScalerOf(BuildContext context) {
    final raw = MediaQuery.textScalerOf(context).scale(1);
    return TextScaler.linear(raw.clamp(1.0, 1.35));
  }

  /// Hero / screen titles — stay large; only the tiniest phones ease slightly.
  static double displaySize(BuildContext context) =>
      widthOf(context) < 350 ? 36.0 : 40.0;

  /// Lobby share-code digits (FittedBox still protects overflow).
  static double codeSize(BuildContext context) =>
      widthOf(context) < 350 ? 48.0 : 56.0;
}
