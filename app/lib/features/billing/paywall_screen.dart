import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import '../../services/billing_service.dart';

/// Free-trial ended / subscribe prompt.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String? _message;
  bool _busy = false;

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
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.read<BillingService>();

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Keep playing Match Word',
              style: AppText.display, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          const HostGreeting(
            message:
                'Your free week has been a joy. For \$5.99 a month you can keep '
                'the studio lights on — no rush, just whenever you are ready.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '\$5.99 per month · Cancel anytime in your store account',
            style: AppText.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          if (_message != null) ...[
            Text(
              _message!,
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          BigButton(
            label: _busy ? 'Please wait…' : 'Subscribe — \$5.99 / month',
            icon: Icons.favorite_rounded,
            onPressed: _busy ? null : () => _run(billing.purchaseMonthly),
          ),
          const SizedBox(height: AppSpacing.md),
          BigButton(
            label: 'Restore Purchases',
            icon: Icons.restore_rounded,
            onPressed: _busy ? null : () => _run(billing.restorePurchases),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Not now', style: AppText.body),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
