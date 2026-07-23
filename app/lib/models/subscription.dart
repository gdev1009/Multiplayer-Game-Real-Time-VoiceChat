/// Monthly Match Word subscription product id (App Store + Play Console).
const String kMatchWordMonthlyProductId = 'matchword_monthly_599';

/// Mirrored entitlement row from Supabase `subscriptions`.
class SubscriptionEntitlement {
  const SubscriptionEntitlement({
    required this.status,
    required this.productId,
    this.store,
    this.currentPeriodEnd,
    this.originalTxId,
  });

  /// none | trialing | active | expired | grace
  final String status;
  final String productId;
  final String? store;
  final DateTime? currentPeriodEnd;
  final String? originalTxId;

  bool get isPaidActive =>
      status == 'active' || status == 'grace' || status == 'trialing';

  factory SubscriptionEntitlement.none() => const SubscriptionEntitlement(
        status: 'none',
        productId: kMatchWordMonthlyProductId,
      );

  factory SubscriptionEntitlement.fromMap(Map<String, dynamic> map) {
    return SubscriptionEntitlement(
      status: (map['status'] as String?) ?? 'none',
      productId: (map['product_id'] as String?) ?? kMatchWordMonthlyProductId,
      store: map['store'] as String?,
      currentPeriodEnd: map['current_period_end'] == null
          ? null
          : DateTime.tryParse(map['current_period_end'] as String),
      originalTxId: map['original_tx_id'] as String?,
    );
  }
}
