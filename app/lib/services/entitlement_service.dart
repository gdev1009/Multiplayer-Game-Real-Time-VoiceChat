import '../features/billing/trial_policy.dart';
import '../models/profile.dart';
import '../models/subscription.dart';
import 'billing_service.dart';
import 'profile_service.dart';

/// Combined trial + paid access decision.
enum AccessLevel {
  /// Inside the free trial (early days: soft banner only).
  trialEarly,

  /// Later trial days: show countdown urgency (see [TrialPolicy]).
  trialCountdown,

  /// Paid / grace period from the store entitlement mirror.
  subscribed,

  /// Trial ended and no paid entitlement — soft-gate play.
  expired,
}

/// Decides whether the player may start or join a game.
class EntitlementService {
  EntitlementService({
    required ProfileService profileService,
    required BillingService billingService,
  })  : _profiles = profileService,
        _billing = billingService;

  final ProfileService _profiles;
  final BillingService _billing;

  SubscriptionEntitlement _sub = SubscriptionEntitlement.none();
  SubscriptionEntitlement get subscription => _sub;

  /// Refresh profile + subscription mirror and return the access level.
  Future<AccessLevel> refresh() async {
    final profile = await _profiles.currentProfile();
    _sub = await _billing.fetchEntitlement();
    return evaluate(profile: profile, subscription: _sub);
  }

  /// Pure evaluation (also usable with an already-loaded [Profile]).
  AccessLevel evaluate({
    Profile? profile,
    SubscriptionEntitlement? subscription,
  }) {
    final sub = subscription ?? _sub;
    if (sub.isPaidActive) return AccessLevel.subscribed;

    final days = profile?.trialDaysRemaining ?? 0;
    if (days <= 0) return AccessLevel.expired;
    // Day-3 through Day-5 of the 5-day trial (Ronna).
    if (days <= TrialPolicy.countdownAtOrBelowDays) {
      return AccessLevel.trialCountdown;
    }
    return AccessLevel.trialEarly;
  }

  /// Whether gameplay (create / join / quick match) is allowed.
  bool canPlay(AccessLevel level) => level != AccessLevel.expired;
}
