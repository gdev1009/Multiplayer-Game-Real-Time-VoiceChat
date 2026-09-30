import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:match_word/features/billing/trial_policy.dart';
import 'package:match_word/services/billing_service.dart';

void main() {
  BillingService offline() => BillingService(
        SupabaseClient('https://offline.supabase.co', 'offline-anon-key'),
      );

  group('Before the store sells the membership', () {
    test('checkout stays off and shows the planned price', () async {
      final billing = offline();
      expect(await billing.prepare(), isFalse);
      expect(billing.checkoutReady, isFalse);
      expect(billing.priceLabel, TrialPolicy.monthlyPriceLabel);
    });

    test('Subscribe explains instead of failing', () async {
      final result = await offline().purchaseMonthly();
      expect(result.ok, isFalse);
      expect(result.message, contains('Keep Playing'));
    });

    test('Restore reports no membership without a store', () async {
      final result = await offline().restorePurchases();
      expect(result.ok, isFalse);
      expect(result.message, contains('No membership found'));
    });
  });
}
