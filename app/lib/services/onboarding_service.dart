import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import 'profile_service.dart';

/// First-launch walkthrough: local flag + optional Supabase profile flag.
class OnboardingService {
  OnboardingService(this._profiles);

  final ProfileService _profiles;

  static const seenKey = 'mw_onboarding_seen';

  /// True if this install already finished or skipped onboarding.
  Future<bool> localSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(seenKey) ?? false;
  }

  /// Show walkthrough only if neither this device nor this account has seen it.
  Future<bool> shouldShow({Profile? profile}) async {
    if (profile?.onboardingSeen == true) return false;
    return !(await localSeen());
  }

  /// Persist locally, and on the profile when signed in.
  Future<void> markSeen({bool syncProfile = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey, true);
    if (syncProfile) {
      try {
        await _profiles.markOnboardingSeen();
      } catch (_) {
        // Offline / not signed in — local flag still prevents a repeat this install.
      }
    }
  }

  /// After sign-in: if the account already saw onboarding, remember it locally.
  Future<void> syncFromProfile(Profile? profile) async {
    if (profile?.onboardingSeen != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey, true);
  }
}
