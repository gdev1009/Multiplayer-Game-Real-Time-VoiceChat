/// Match Word free-trial + membership rules.
///
/// An expired trial only blocks play once the store actually sells the
/// membership ([BillingService.checkoutReady]); before that a tester whose
/// trial lapsed could neither subscribe nor play.
class TrialPolicy {
  const TrialPolicy._();

  /// Length of the no-card free trial.
  static const int lengthDays = 5;

  /// When remaining days are at or below this, show the urgent countdown banner.
  /// With a 5-day trial: soft banner on days 1–2, countdown on days 3–5.
  static const int countdownAtOrBelowDays = 3;

  /// Paid membership price used until the store reports its own price.
  static const String monthlyPriceLabel = r'$6.99 CAD';

  static const String termsUrl =
      'https://grandmamac.com/matchword/terms-of-service.html';
  static const String privacyUrl =
      'https://grandmamac.com/matchword/privacy-policy.html';
}
