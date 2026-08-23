import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription.dart';

/// Store billing facade — syncs entitlements and prepares purchase / restore.
class BillingService {
  BillingService(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return const {};
  }

  Future<SubscriptionEntitlement> fetchEntitlement() async {
    if (_client.auth.currentUser == null) {
      return SubscriptionEntitlement.none();
    }
    try {
      final res = _asMap(await _client.rpc('mw_my_subscription'));
      if (res['ok'] != true) return SubscriptionEntitlement.none();
      return SubscriptionEntitlement.fromMap(res);
    } on PostgrestException catch (e) {
      debugPrint('[BillingService] mw_my_subscription: ${e.message}');
      return SubscriptionEntitlement.none();
    }
  }

  /// Syncs a purchase / restore / expiry into Supabase.
  Future<bool> syncSubscription({
    required String status,
    String? store,
    DateTime? periodEnd,
    String? originalTxId,
    String productId = kMatchWordMonthlyProductId,
  }) async {
    if (_client.auth.currentUser == null) return false;
    try {
      final res = _asMap(await _client.rpc('mw_sync_subscription', params: {
        'p_status': status,
        'p_store': store,
        'p_period_end': periodEnd?.toUtc().toIso8601String(),
        'p_original_tx_id': originalTxId,
        'p_product_id': productId,
      },),);
      return res['ok'] == true;
    } on PostgrestException catch (e) {
      debugPrint('[BillingService] mw_sync_subscription: ${e.message}');
      return false;
    }
  }

  /// Placeholder until StoreKit / Play Billing products are live.
  Future<BillingActionResult> purchaseMonthly() async {
    return const BillingActionResult(
      ok: false,
      message:
          'Subscriptions will be available once TestFlight and the store '
          'products are ready. Thank you for your patience.',
    );
  }

  /// Placeholder restore — checks the server entitlement (including tester grants).
  Future<BillingActionResult> restorePurchases() async {
    final sub = await fetchEntitlement();
    if (sub.isPaidActive) {
      return const BillingActionResult(
        ok: true,
        message: 'Your membership is active. Enjoy Match Word!',
      );
    }
    return const BillingActionResult(
      ok: false,
      message:
          'No subscription found yet. Once the App Store product is live, '
          'Restore Purchases will bring it back.',
    );
  }
}

class BillingActionResult {
  const BillingActionResult({required this.ok, required this.message});
  final bool ok;
  final String message;
}
