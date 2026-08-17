import 'package:flutter/material.dart';

import '../theme/app_responsive.dart';

/// Grandma Mac logo with a clean black outline (Ronna Aug 2026).
///
/// Outline is drawn *around* the image (no clip) so the tagline is never cut off.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 120,
    this.outlineWidth = 2.5,
  });

  final double height;
  final double outlineWidth;

  @override
  Widget build(BuildContext context) {
    final h = height.clamp(72.0, 240.0);
    final radius = AppResponsive.s(context, 12);
    return Semantics(
      label: 'Grandma Mac logo',
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: const Color(0xFF1A1028),
            width: outlineWidth,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          // Keep the tagline clear of the stroke / radius.
          padding: EdgeInsets.all(outlineWidth + 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              (radius - outlineWidth).clamp(4.0, radius),
            ),
            child: Image.asset(
              'assets/images/grandmac-logo.jpg',
              height: h,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
