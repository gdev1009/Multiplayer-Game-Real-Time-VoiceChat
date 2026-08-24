import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/build_stamp.dart';
import '../../core/widgets/host_greeting.dart';
import '../../services/billing_service.dart';
import '../../services/entitlement_service.dart';
import 'trial_policy.dart';

/// Free-trial ended / subscribe prompt.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String? _message;
  bool _busy = false;

  /// Always leaves this screen — refreshing entitlement must never trap the
  /// player here if the call fails.
  Future<void> _close() async {
    try {
      await context.read<EntitlementService>().refresh();
    } catch (_) {
      // Ignore — leaving matters more than a fresh entitlement.
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _run(Future<BillingActionResult> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.message;
    });
    if (result.ok) {
      await context.read<EntitlementService>().refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.read<BillingService>();
    final args = ModalRoute.of(context)?.settings.arguments;
    final compact = AppResponsive.isCompactPhone(context);
    final gap = AppResponsive.sectionGap(context);
    // Store checkout is not live yet, so this screen only ever informs.
    const informational = !TrialPolicy.enforcePaywall;
    final greeting = args is String && args.trim().isNotEmpty
        ? args.trim()
        : informational
            ? 'Match Word will be ${TrialPolicy.monthlyPriceLabel} a month once '
                'the store is live. Nothing to pay while testing — tap '
                'Keep Playing and enjoy the game.'
            : compact
                ? 'Your free trial ended. Keep Match Word ad-free for '
                    '${TrialPolicy.monthlyPriceLabel}/month — whenever you are ready.'
                : 'Your free trial has been a joy. For ${TrialPolicy.monthlyPriceLabel} '
                    'a month you keep Match Word ad-free — no rush, just whenever '
                    'you are ready.';

    return AppPage(
      title: informational ? 'Membership' : null,
      showBack: informational,
      compactAppBar: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: gap),
          Text(
            informational ? 'About membership' : 'Keep playing Match Word',
            style: AppText.display.copyWith(
              fontSize: AppResponsive.displaySize(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: gap),
          HostGreeting(message: greeting),
          SizedBox(height: gap),
          Text(
            '${TrialPolicy.monthlyPriceLabel}/mo · Cancel anytime',
            style: AppText.bodyMuted.copyWith(
              fontSize: AppResponsive.bodySize(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: gap),
          if (_message != null) ...[
            Text(
              _message!,
              style: AppText.body.copyWith(
                fontSize: AppResponsive.bodySize(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: gap),
          ],
          // Primary action while testing is "get back to the game", never a
          // checkout that cannot complete.
          if (informational) ...[
            BigButton(
              label: 'Keep Playing',
              icon: Icons.play_arrow_rounded,
              onPressed: _busy ? null : () => _close(),
            ),
            SizedBox(height: gap),
            BigButton(
              label: 'Restore Purchases',
              icon: Icons.restore_rounded,
              variant: BigButtonVariant.secondary,
              onPressed: _busy ? null : () => _run(billing.restorePurchases),
            ),
          ] else ...[
            BigButton(
              label: _busy ? 'Please wait…' : 'Subscribe',
              icon: Icons.favorite_rounded,
              onPressed: _busy ? null : () => _run(billing.purchaseMonthly),
            ),
            SizedBox(height: gap),
            BigButton(
              label: 'Restore Purchases',
              icon: Icons.restore_rounded,
              variant: BigButtonVariant.secondary,
              onPressed: _busy ? null : () => _run(billing.restorePurchases),
            ),
          ],
          SizedBox(height: gap),
          TextButton(
            onPressed: _busy ? null : () => _close(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text(
              informational ? 'Back to Home' : 'Not now',
              style: AppText.body,
            ),
          ),
          const BuildStamp(onLight: true),
          SizedBox(height: gap),
        ],
      ),
    );
  }
}
