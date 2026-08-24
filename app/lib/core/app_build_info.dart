/// The build number this app was compiled with, shown in the UI.
///
/// Testers report "TestFlight says Build 6" while we ship 84+, so the number
/// has to be visible inside the app to tell an install apart from a stale one.
/// CI passes `--dart-define=MW_BUILD=<n>`; [_fallback] must track `pubspec.yaml`
/// for local builds that skip the define.
class AppBuildInfo {
  const AppBuildInfo._();

  static const String _fallback = '87';

  static const String versionName = '1.0.0';

  static const String buildNumber =
      String.fromEnvironment('MW_BUILD', defaultValue: _fallback);

  /// Short label for screen corners, e.g. "Build 86".
  static String get shortLabel => 'Build $buildNumber';

  /// Full label for support / acceptance checks, e.g. "1.0.0 (86)".
  static String get fullLabel => '$versionName ($buildNumber)';
}
