import 'package:flutter/material.dart';

/// Layout helpers so screens stay comfortable on every phone.
///
/// Tuned for Ronna's **iPhone 12** (390×844 logical) as the primary target:
/// notch + home indicator + app bar leave ~700pt of body — content must
/// stay compact or it clips below the fold.
class AppResponsive {
  AppResponsive._();

  /// Logical width of iPhone 12 / 13 / 14.
  static const double designWidth = 390;

  /// Logical height of iPhone 12 / 13 / 14.
  static const double designHeight = 844;

  /// Cap content on very wide phones / small tablets.
  static const double contentMaxWidth = 560;

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static double widthOf(BuildContext context) => sizeOf(context).width;

  static double heightOf(BuildContext context) => sizeOf(context).height;

  /// True for compact-width phones (layout chrome only — not type).
  static bool isNarrow(BuildContext context) => widthOf(context) < 380;

  /// iPhone 12-class (and similar): ≤400 wide and ≤870 tall.
  ///
  /// Pro Max / Plus stay on the roomier path; SE / mini also compact.
  static bool isCompactPhone(BuildContext context) {
    final s = sizeOf(context);
    return s.width <= 400 && s.height <= 870;
  }

  /// Usable body height under notch, home indicator, keyboard, and app bar.
  static double bodyHeightOf(BuildContext context, {double appBar = 56}) {
    final size = sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    return (size.height - pad.top - pad.bottom - kb - appBar)
        .clamp(0.0, double.infinity);
  }

  /// True when vertical room is tight (iPhone 12, SE, keyboard open, etc.).
  static bool isShort(BuildContext context) {
    if (isCompactPhone(context)) return true;
    return bodyHeightOf(context) < 720;
  }

  /// Combined scale for spacing / icons / decorative sizes only.
  static double scaleOf(BuildContext context) {
    final size = sizeOf(context);
    final byWidth = (size.width / designWidth).clamp(0.78, 1.05);
    final byHeight = (size.height / designHeight).clamp(0.78, 1.05);
    final raw = byWidth * 0.55 + byHeight * 0.45;
    // Slightly smaller chrome on iPhone 12-class so stacks fit.
    return (isCompactPhone(context) ? raw * 0.92 : raw).clamp(0.78, 1.05);
  }

  /// Scale a design-time chrome size (avatar, logo, icon).
  static double s(BuildContext context, double base) =>
      base * scaleOf(context);

  /// Comfortable gutters — tight on iPhone 12 so tall pages fit.
  static EdgeInsets pageInsets(BuildContext context) {
    final compact = isCompactPhone(context) || isShort(context);
    final h = isNarrow(context) || compact ? 14.0 : 20.0;
    final v = compact ? 8.0 : 16.0;
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  /// Vertical gap between major blocks on a screen.
  static double sectionGap(BuildContext context) =>
      isCompactPhone(context) || isShort(context) ? 8.0 : 16.0;

  /// Primary buttons — large enough to tap, compact enough to stack.
  static double buttonHeight(BuildContext context) {
    if (isCompactPhone(context) || isShort(context)) return 48.0;
    return 56.0;
  }

  /// Soft-clamp OS font scaling so accessibility bumps don't blow layouts.
  static TextScaler textScalerOf(BuildContext context) {
    final raw = MediaQuery.textScalerOf(context).scale(1);
    final max = isCompactPhone(context) ? 1.1 : 1.2;
    return TextScaler.linear(raw.clamp(1.0, max));
  }

  /// Hero / screen titles.
  static double displaySize(BuildContext context) {
    if (widthOf(context) < 350) return 22.0;
    if (isCompactPhone(context)) return 24.0;
    return 26.0;
  }

  /// Body copy on compact phones (still senior-readable).
  static double bodySize(BuildContext context) =>
      isCompactPhone(context) || isShort(context) ? 15.0 : 16.0;

  /// Lobby share-code digits (FittedBox still protects overflow).
  static double codeSize(BuildContext context) {
    if (widthOf(context) < 350) return 26.0;
    if (isCompactPhone(context)) return 30.0;
    return 34.0;
  }
}
