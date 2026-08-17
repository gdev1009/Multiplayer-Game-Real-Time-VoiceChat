import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Digits / letters with a black outline for a cleaner, more polished look
/// (PIN pad, join codes, lobby codes).
class OutlinedGlyph extends StatelessWidget {
  const OutlinedGlyph(
    this.text, {
    super.key,
    required this.style,
    this.fillColor = AppColors.deepPurple,
    this.outlineColor = const Color(0xFF1A1028),
    this.outlineWidth = 1.6,
  });

  final String text;
  final TextStyle style;
  final Color fillColor;
  final Color outlineColor;
  final double outlineWidth;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final base = style.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..color = outlineColor,
    );
    final fill = style.copyWith(color: fillColor);
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, style: base, textAlign: TextAlign.center),
        Text(text, style: fill, textAlign: TextAlign.center),
      ],
    );
  }
}
