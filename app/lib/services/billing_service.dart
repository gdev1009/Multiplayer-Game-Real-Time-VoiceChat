import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/billing/trial_policy.dart';
import '../models/subscription.dart';

/// App Store / Google Play checkout plus the Supabase entitlement mirror.
///
/// Checkout switches itself on: until the store returns the
/// [kMatchWordMonthlyProductId] product for this device, [checkoutReady] stays
/// false and the app keeps the free "Keep Playing" behaviour. Pass no [store]
/// (tests, web demos) to stay in that mode permanently.
class BillingService {
  BillingService(this._client, {InAppPurchase? store}) : _store = store;

  final SupabaseClient _client;
  final InAppPurchase? _store;

  ProductDetails? _product;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Future<bool>? _preparing;
  Completer<BillingActionResult>? _pendingBuy;
  Completer<bool>? _pendingRestore;
  bool _resynced = false;

  /// True once the store sells the monthly membership on this device.
  bool get checkoutReady => _product != null;

  /// Store-formatted price when known (matches what the checkout sheet shows).
  String get priceLabel => _product?.price ?? TrialPolicy.monthlyPriceLabel;

  String get _storeName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'app_store' : 'play_store';

  Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return const {};
  }

  /// Loads the store product once, then (signed in) re-checks the player's
  /// store membership so renewals and cancellations reach the mirror.
  Future<bool> prepare() async {
    final store = _store;
    if (store == null) return false;
    if (_product == null) {
      final ready = await (_preparing ??=
          _loadProduct(store).whenComplete(() => _preparing = null));
      if (!ready) return false;
    }
    if (!_resynced && _client.auth.currentUser != null) {
      _resynced = true;
      await _resync(store);
    }
    return true;
  }

  Future<bool> _loadProduct(InAppPurchase store) async {
    try {
      _purchaseSub ??= store.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('[BillingService] purchases: $e'),
      );
      if (!await store.isAvailable()) return false;
      final res = await store.queryProductDetails({kMatchWordMonthlyProductId});
      final matches = res.productDetails
          .where((p) => p.id == kMatchWordMonthlyProductId)
          .toList();
      if (matches.isEmpty) return false;
      _product = matches.first;
      return true;
    } catch (e) {
      debugPrint('[BillingService] product lookup: $e');
      return false;
    }
  }

  /// Both stores only report memberships that are active right now, so an
  /// empty answer means a lapsed one — but only for this device's store.
  Future<void> _resync(InAppPurchase store) async {
    final active = await _restoreFromStore(store);
    if (active != false) return;
    final sub = await fetchEntitlement();
    if (sub.status == 'active' && sub.store == _storeName) {
      await syncSubscription(status: 'expired', store: _storeName);
    }
  }

  /// true = store reported the membership, false = none, null = store error.
  Future<bool?> _restoreFromStore(InAppPurchase store) async {
    final waiter = _pendingRestore = Completer<bool>();
    try {
      await store.restorePurchases();
      return await waiter.future
          .timeout(const Duration(seconds: 6), onTimeout: () => false);
    } catch (e) {
      debugPrint('[BillingService] restore: $e');
      return null;
    } finally {
      if (identical(_pendingRestore, waiter)) _pendingRestore = null;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    final store = _store;
    if (store == null) return;
    if (purchases.isEmpty) _finishRestore(false);
    for (final p in purchases) {
      if (p.productID == kMatchWordMonthlyProductId) {
        await _handle(p);
      }
      if (p.pendingCompletePurchase) {
        try {
          await store.completePurchase(p);
        } catch (e) {
          debugPrint('[BillingService] completePurchase: $e');
        }
      }
    }
  }

  Future<void> _handle(PurchaseDetails p) async {
    switch (p.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await syncSubscription(
          status: 'active',
          store: _storeName,
          originalTxId: p.purchaseID,
        );
        _finishRestore(true);
        _finishBuy(
          const BillingActionResult(
            ok: true,
            message: 'Welcome to the Match Word membership. Enjoy the show!',
          ),
        );
      case PurchaseStatus.pending:
        _finishBuy(
          const BillingActionResult(
            ok: false,
            message: 'Your purchase is waiting on the store. Match Word '
                'unlocks as soon as it goes through.',
          ),
        );
      case PurchaseStatus.canceled:
        _finishBuy(
          const BillingActionResult(
            ok: false,
            message: 'No problem. Nothing was charged.',
          ),
        );
      case PurchaseStatus.error:
        debugPrint('[BillingService] purchase error: ${p.error}');
        _finishBuy(
          const BillingActionResult(
            ok: false,
            message: 'The store could not finish the purchase, and nothing '
                'was charged. Please try again in a moment.',
          ),
        );
    }
  }

  void _finishBuy(BillingActionResult result) {
    final c = _pendingBuy;
    _pendingBuy = null;
    if (c != null && !c.isCompleted) c.complete(result);
  }

  void _finishRestore(bool found) {
    final c = _pendingRestore;
    if (c != null && !c.isCompleted) c.complete(found);
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

  static const _notReady = BillingActionResult(
    ok: false,
    message: 'Membership is not open in the store just yet. '
        'Tap Keep Playing and enjoy the game.',
  );

  /// Opens the App Store / Google Play checkout for the monthly membership.
  Future<BillingActionResult> purchaseMonthly() async {
    final store = _store;
    if (store == null || !await prepare()) return _notReady;
    final waiter = _pendingBuy = Completer<BillingActionResult>();
    try {
      final started = await store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _product!),
      );
      if (!started) {
        _finishBuy(
          const BillingActionResult(
            ok: false,
            message: 'The store could not open right now. Please try again '
                'in a moment.',
          ),
        );
      }
    } catch (e) {
      debugPrint('[BillingService] buy: $e');
      _finishBuy(
        const BillingActionResult(
          ok: false,
          message: 'The store could not open right now. Please try again '
              'in a moment.',
        ),
      );
    }
    return waiter.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => const BillingActionResult(
        ok: false,
        message: 'Still waiting on the store. If you finished paying, tap '
            'Restore Purchases.',
      ),
    );
  }

  /// Brings back a membership bought on this Apple ID / Google account, and
  /// honours tester grants from the server mirror.
  Future<BillingActionResult> restorePurchases() async {
    final store = _store;
    if (store != null && await prepare()) {
      final found = await _restoreFromStore(store);
      if (found == true) {
        return const BillingActionResult(
          ok: true,
          message: 'Your membership is active. Enjoy Match Word!',
        );
      }
    }
    final sub = await fetchEntitlement();
    if (sub.isPaidActive) {
      return const BillingActionResult(
        ok: true,
        message: 'Your membership is active. Enjoy Match Word!',
      );
    }
    return const BillingActionResult(
      ok: false,
      message: 'No membership found on this account yet.',
    );
  }

  void dispose() {
    _purchaseSub?.cancel();
  }
}

class BillingActionResult {
  const BillingActionResult({required this.ok, required this.message});
  final bool ok;
  final String message;
}
