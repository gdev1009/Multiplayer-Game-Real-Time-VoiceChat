import '../models/profile.dart';
import '../models/subscription.dart';
import 'billing_service.dart';
import 'profile_service.dart';

/// Combined trial + paid access decision.
enum AccessLevel {
  /// Inside the 7-day free trial (days 1–2: soft banner only).
  trialEarly,

  /// Trial days 3–7: show countdown urgency.
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
    if (days <= 4) return AccessLevel.trialCountdown; // Day-3 through Day-7
    return AccessLevel.trialEarly;
  }

  /// Whether gameplay (create / join / quick match) is allowed.
  bool canPlay(AccessLevel level) => level != AccessLevel.expired;
}
