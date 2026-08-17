import 'package:flutter/material.dart';

/// Layout helpers so screens stay comfortable on every phone.
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
    return h < 720;
  }

  /// Combined scale for spacing / icons / decorative sizes only.
  static double scaleOf(BuildContext context) {
    final size = sizeOf(context);
    final byWidth = (size.width / designWidth).clamp(0.82, 1.05);
    final byHeight = (size.height / designHeight).clamp(0.82, 1.05);
    return (byWidth * 0.55 + byHeight * 0.45).clamp(0.82, 1.05);
  }

  /// Scale a design-time chrome size (avatar, logo, icon).
  static double s(BuildContext context, double base) =>
      base * scaleOf(context);

  /// Comfortable gutters — slightly tighter so tall pages fit.
  static EdgeInsets pageInsets(BuildContext context) {
    final h = isNarrow(context) ? 16.0 : 20.0;
    final v = isShort(context) ? 12.0 : 18.0;
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  /// Primary buttons — easy to tap without eating the viewport.
  static double buttonHeight(BuildContext context) =>
      isShort(context) ? 48.0 : 52.0;

  /// Soft-clamp OS font scaling so accessibility bumps don't blow layouts.
  static TextScaler textScalerOf(BuildContext context) {
    final raw = MediaQuery.textScalerOf(context).scale(1);
    return TextScaler.linear(raw.clamp(1.0, 1.2));
  }

  /// Hero / screen titles.
  static double displaySize(BuildContext context) =>
      widthOf(context) < 350 ? 26.0 : 30.0;

  /// Lobby share-code digits (FittedBox still protects overflow).
  static double codeSize(BuildContext context) =>
      widthOf(context) < 350 ? 36.0 : 42.0;
}
