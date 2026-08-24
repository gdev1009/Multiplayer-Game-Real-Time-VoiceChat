import 'package:flutter/material.dart';

import '../app_build_info.dart';
import '../theme/app_colors.dart';

/// Small "Build 86" line so a tester can confirm which install they opened.
class BuildStamp extends StatelessWidget {
  const BuildStamp({super.key, this.onLight = false});

  /// True on pale backgrounds (Home); false on the purple gradient.
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'App version ${AppBuildInfo.fullLabel}',
      child: Text(
        'Match Word ${AppBuildInfo.fullLabel}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: onLight ? AppColors.textSecondary : Colors.white70,
        ),
      ),
    );
  }
}
