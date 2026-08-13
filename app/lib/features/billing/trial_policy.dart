/// Match Word free-trial + membership rules.
class TrialPolicy {
  const TrialPolicy._();

  /// Length of the no-card free trial.
  static const int lengthDays = 5;

  /// When remaining days are at or below this, show the urgent countdown banner.
  /// With a 5-day trial: soft banner on days 1–2, countdown on days 3–5.
  static const int countdownAtOrBelowDays = 3;

  /// Paid membership price shown in the paywall and store copy.
  static const String monthlyPriceLabel = r'$6.99 CAD';
}
