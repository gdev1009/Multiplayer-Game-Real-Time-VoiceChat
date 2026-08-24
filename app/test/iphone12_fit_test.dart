import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:match_word/core/theme/app_responsive.dart';
import 'package:match_word/core/widgets/big_button.dart';
import 'package:match_word/core/widgets/host_greeting.dart';
import 'package:match_word/features/billing/trial_policy.dart';
import 'package:match_word/services/billing_service.dart';
import 'package:match_word/services/entitlement_service.dart';
import 'package:match_word/services/profile_service.dart';

/// iPhone 12 / 13 / 14 logical size — Ronna's phone.
const Size kIphone12 = Size(390, 844);

/// A large phone that must keep the roomier layout.
const Size kIphoneProMax = Size(430, 932);

Widget _sized(Size size, Widget child) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  group('AppResponsive treats iPhone 12 as compact', () {
    testWidgets('iPhone 12 is compact and short', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _sized(
          kIphone12,
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(AppResponsive.isCompactPhone(ctx), isTrue);
      // Regression: isShort used to need < 720pt, so 844pt phones kept the
      // roomy layout and pushed buttons below the fold.
      expect(AppResponsive.isShort(ctx), isTrue);
      expect(AppResponsive.buttonHeight(ctx), lessThanOrEqualTo(48));
    });

    testWidgets('Pro Max keeps the roomy layout', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _sized(
          kIphoneProMax,
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(AppResponsive.isCompactPhone(ctx), isFalse);
      expect(AppResponsive.buttonHeight(ctx), 56);
    });
  });

  group('No overflow on iPhone 12', () {
    testWidgets('stacked buttons and greeting fit', (tester) async {
      await tester.pumpWidget(
        _sized(
          kIphone12,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HostGreeting(
                message: 'Start a new game and share the code, '
                    'or join with a friend’s code.',
              ),
              const SizedBox(height: 12),
              BigButton(label: 'Start New Game', onPressed: () {}),
              const SizedBox(height: 12),
              BigButton(
                label: 'Join with Code',
                variant: BigButtonVariant.secondary,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a long label shrinks instead of clipping', (tester) async {
      await tester.pumpWidget(
        _sized(
          kIphone12,
          BigButton(
            label: 'Check Upcoming Games and Tournaments',
            icon: Icons.event_available_rounded,
            onPressed: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Check Upcoming Games and Tournaments'), findsOneWidget);
    });
  });

  group('Testers are never locked out', () {
    EntitlementService service() {
      SupabaseClient offline() =>
          SupabaseClient('https://offline.supabase.co', 'offline-anon-key');
      return EntitlementService(
        profileService: ProfileService(offline()),
        billingService: BillingService(offline()),
      );
    }

    test('paywall enforcement stays off while checkout is a placeholder', () {
      expect(TrialPolicy.enforcePaywall, isFalse);
    });

    test('an expired trial can still play', () {
      // Ronna's trial lapsed and Subscribe could not complete, which left no
      // way into the game at all.
      expect(service().canPlay(AccessLevel.expired), isTrue);
    });

    test('active trial and subscribers can play', () {
      final s = service();
      expect(s.canPlay(AccessLevel.trialEarly), isTrue);
      expect(s.canPlay(AccessLevel.trialCountdown), isTrue);
      expect(s.canPlay(AccessLevel.subscribed), isTrue);
    });
  });
}
