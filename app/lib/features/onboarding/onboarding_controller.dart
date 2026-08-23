import 'package:flutter/foundation.dart';

import '../../models/profile.dart';
import '../../services/onboarding_service.dart';

/// Drives whether [AuthGate] shows the first-launch walkthrough.
class OnboardingController extends ChangeNotifier {
  OnboardingController(this._service);

  final OnboardingService _service;

  bool _ready = false;
  bool _seen = false;

  bool get ready => _ready;
  bool get shouldShow => _ready && !_seen;

  Future<void> load({Profile? profile}) async {
    await _service.syncFromProfile(profile);
    _seen = !await _service.shouldShow(profile: profile);
    _ready = true;
    notifyListeners();
  }

  Future<void> syncFromProfile(Profile? profile) async {
    await _service.syncFromProfile(profile);
    // Re-evaluate — never force-skip solely from profiles.onboarding_seen
    // (contentVersion bumps must re-show the walkthrough).
    final show = await _service.shouldShow(profile: profile);
    final seen = !show;
    if (seen != _seen) {
      _seen = seen;
      notifyListeners();
    }
  }

  Future<void> complete() async {
    if (_seen) {
      await _service.markSeen();
      return;
    }
    await _service.markSeen();
    _seen = true;
    notifyListeners();
  }
}
