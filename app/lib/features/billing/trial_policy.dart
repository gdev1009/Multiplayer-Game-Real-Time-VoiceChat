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

  /// Whether an expired trial blocks play.
  ///
  /// False while App Store / Play checkout is still a placeholder: a tester
  /// whose trial lapsed could not subscribe *or* play, which locked Ronna out
  /// of every screen past Subscribe. Flip to true only after real purchases
  /// work end to end.
  static const bool enforcePaywall = false;
}
