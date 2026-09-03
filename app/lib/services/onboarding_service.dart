import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import 'profile_service.dart';

/// First-launch walkthrough: local flag + optional Supabase profile flag.
class OnboardingService {
  OnboardingService(this._profiles);

  final ProfileService _profiles;

  /// Bump when walkthrough copy/layout must be shown again to existing testers.
  static const contentVersion = 3;
  static const seenKey = 'mw_onboarding_seen_v2';
  static const _versionKey = 'mw_onboarding_version';

  /// True if this install already finished or skipped the current walkthrough.
  Future<bool> localSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(_versionKey) ?? 0;
    if (version < contentVersion) return false;
    return prefs.getBool(seenKey) ?? false;
  }

  /// Show walkthrough if this device has not completed the current version.
  ///
  /// A content-version bump re-shows onboarding even when an older walkthrough
  /// was skipped (Ronna never saw the new pages on TestFlight).
  Future<bool> shouldShow({Profile? profile}) async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(_versionKey) ?? 0;
    if (version < contentVersion) return true;
    if (prefs.getBool(seenKey) ?? false) return false;
    // Only trust the profile flag once this install has the current version.
    if (profile?.onboardingSeen == true) return false;
    return true;
  }

  /// Persist locally, and on the profile when signed in.
  Future<void> markSeen({bool syncProfile = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_versionKey, contentVersion);
    await prefs.setBool(seenKey, true);
    if (syncProfile) {
      try {
        await _profiles.markOnboardingSeen();
      } catch (_) {
        // Offline / not signed in — local flag still prevents a repeat this install.
      }
    }
  }

  /// After sign-in: if the account already saw the *current* walkthrough,
  /// remember it locally. Older profile flags alone do not skip a new version.
  Future<void> syncFromProfile(Profile? profile) async {
    if (profile?.onboardingSeen != true) return;
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(_versionKey) ?? 0;
    if (version < contentVersion) return;
    await prefs.setBool(seenKey, true);
  }
}
