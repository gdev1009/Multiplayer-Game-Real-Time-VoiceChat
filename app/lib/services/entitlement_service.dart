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

  /// Trial ended and not subscribed — play is gated behind the paywall.
  expired,
}

/// Decides whether the player may enter games / studio.
///
/// Launch model (Ronna Aug 2026): free trial, then $6.99 CAD/month.
/// Ads / free-forever and tournaments are held for a later phase.
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

  AccessLevel? _last;

  /// Result of the most recent [refresh], if any.
  AccessLevel? get lastLevel => _last;

  /// Whether the store sells the membership, so an expired trial is gated.
  bool get paywallLive => _billing.checkoutReady;

  /// Refresh profile + subscription mirror and return the access level.
  Future<AccessLevel> refresh() async {
    await _billing
        .prepare()
        .timeout(const Duration(seconds: 8), onTimeout: () => false);
    final profile = await _profiles.currentProfile();
    _sub = await _billing.fetchEntitlement();
    return _last = evaluate(profile: profile, subscription: _sub);
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
    if (days <= TrialPolicy.countdownAtOrBelowDays) {
      return AccessLevel.trialCountdown;
    }
    return AccessLevel.trialEarly;
  }

  /// Play / studio require an active trial or paid membership — but only once
  /// checkout is live, so nobody is ever locked out with no way to pay.
  bool canPlay(AccessLevel level) {
    if (!paywallLive) return true;
    return level != AccessLevel.expired;
  }
}
