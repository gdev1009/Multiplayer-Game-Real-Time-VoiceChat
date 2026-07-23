import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soft cavity painted over an existing smile / closed mouth.
///
/// Avoids hard PNG sprites (they stretched into black bars on Guy Smiley).
class MouthOverlay extends StatelessWidget {
  const MouthOverlay({
    super.key,
    required this.open,
    required this.rect,
    this.opacity = 1,
    this.style = MouthStyle.hostSmile,
  });

  /// Amplitude 0..1.
  final double open;

  /// Normalised mouth rectangle inside the parent.
  final Rect rect;

  final double opacity;

  final MouthStyle style;

  @override
  Widget build(BuildContext context) {
    if (open < 0.08 || opacity <= 0) return const SizedBox.shrink();
    // Cap open so the cavity stays a mouth, not a chest-sized blotch.
    final o = open.clamp(0.0, 0.92);
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _MouthPainter(
            open: o,
            rect: rect,
            opacity: opacity.clamp(0.0, 1.0),
            style: style,
          ),
        ),
      ),
    );
  }
}

enum MouthStyle {
  /// Guy already smiles open — pulse a soft dark cavity over the teeth.
  hostSmile,

  /// Closed-mouth characters — draw a lip line that opens into a cavity.
  character,
}

class _MouthPainter extends CustomPainter {
  _MouthPainter({
    required this.open,
    required this.rect,
    required this.opacity,
    required this.style,
  });

  final double open;
  final Rect rect;
  final double opacity;
  final MouthStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Rect.fromLTWH(
      rect.left * size.width,
      rect.top * size.height,
      rect.width * size.width,
      rect.height * size.height,
    );
    final grow = 0.55 + open * 1.15;
    final cavity = Rect.fromCenter(
      center: base.center.translate(0, base.height * 0.08 * open),
      width: base.width * (0.92 + open * 0.08),
      height: base.height * grow,
    );

    final lip = Paint()
      ..color = const Color(0xFF8B3A44).withValues(alpha: 0.35 + open * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, base.height * 0.18)
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = const Color(0xFF2A0E18).withValues(alpha: (0.25 + open * 0.55) * opacity)
      ..style = PaintingStyle.fill;

    if (style == MouthStyle.character && open < 0.28) {
      // Closed → slight smile arc.
      final path = Path()
        ..moveTo(cavity.left, cavity.center.dy)
        ..quadraticBezierTo(
          cavity.center.dx,
          cavity.center.dy + cavity.height * 0.35,
          cavity.right,
          cavity.center.dy,
        );
      canvas.drawPath(path, lip);
      return;
    }

    canvas.drawOval(cavity, fill);

    if (open > 0.35 && style == MouthStyle.hostSmile) {
      // Soft upper teeth hint — no hard bar.
      final teeth = Rect.fromLTWH(
        cavity.left + cavity.width * 0.18,
        cavity.top + cavity.height * 0.12,
        cavity.width * 0.64,
        cavity.height * 0.22,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(teeth, Radius.circular(teeth.height * 0.35)),
        Paint()
          ..color = const Color(0xE8FFF5EA).withValues(alpha: 0.55 * open * opacity),
      );
    }

    // Soft lip rim (never a thick black stroke).
    canvas.drawOval(
      cavity.inflate(0.6),
      Paint()
        ..color = const Color(0xFF6E3038).withValues(alpha: 0.25 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, base.height * 0.12),
    );
  }

  @override
  bool shouldRepaint(covariant _MouthPainter old) =>
      old.open != open ||
      old.rect != rect ||
      old.opacity != opacity ||
      old.style != style;
}

/// Host-stage mouth cavity (over Guy's existing open smile).
/// Measured from teeth pixels on [host-stage.png] (880×1348).
const hostStageMouthRect = Rect.fromLTWH(0.22, 0.195, 0.24, 0.055);

/// Welcome-wave action mouth ROI (480×480) — smile band, not chest/tie.
const hostWelcomeMouthRect = Rect.fromLTWH(0.36, 0.195, 0.28, 0.075);

/// Generic action-frame mouth ROI (480×480 pose strips — figure centered).
const hostActionMouthRect = Rect.fromLTWH(0.34, 0.22, 0.30, 0.07);

/// Character base body mouth ROI (1254×1254 canvas).
const characterMouthRect = Rect.fromLTWH(0.40, 0.345, 0.20, 0.035);
