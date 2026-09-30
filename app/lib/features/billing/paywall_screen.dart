import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Membership screen: subscribe, restore, or (before the store sells the
/// membership) a friendly note with Keep Playing.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<EntitlementService>().refresh();
      if (mounted) setState(() {});
    });
  }

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

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing useful to show a player if the browser will not open.
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.read<BillingService>();
    final entitlement = context.read<EntitlementService>();
    final args = ModalRoute.of(context)?.settings.arguments;
    final gap = AppResponsive.sectionGap(context);
    final price = billing.priceLabel;
    final live = billing.checkoutReady;
    final level = entitlement.lastLevel;
    final member = live && level == AccessLevel.subscribed;
    final expired = level == AccessLevel.expired;

    final String title;
    final String greeting;
    if (!live) {
      title = 'About membership';
      greeting = 'Match Word will be $price a month once membership opens in '
          'the store. Nothing to pay for now. Tap Keep Playing and enjoy '
          'the game.';
    } else if (member) {
      title = 'You are a member';
      greeting = 'Your membership is active. Thank you for playing '
          'Match Word!';
    } else if (expired) {
      title = 'Keep playing Match Word';
      greeting = 'Your free trial has been a joy. For $price a month you keep '
          'Match Word ad-free, whenever you are ready.';
    } else {
      title = 'Match Word membership';
      greeting = 'Enjoy your free trial. When it ends, keep playing for '
          '$price a month.';
    }
    final hostLine =
        args is String && args.trim().isNotEmpty ? args.trim() : greeting;

    return AppPage(
      title: 'Membership',
      showBack: !(live && expired),
      compactAppBar: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: gap),
          Text(
            title,
            style: AppText.display.copyWith(
              fontSize: AppResponsive.displaySize(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: gap),
          HostGreeting(message: hostLine),
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
          if (!live) ...[
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
          ] else if (!member) ...[
            BigButton(
              label: _busy ? 'Please wait…' : 'Subscribe for $price a month',
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
            SizedBox(height: gap),
            Text(
              'Monthly membership, $price per month. It renews each month '
              'until you cancel in your App Store or Google Play account '
              'settings. Cancel anytime.',
              style: AppText.bodyMuted.copyWith(
                fontSize: AppResponsive.bodySize(context) - 2,
              ),
              textAlign: TextAlign.center,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _open(TrialPolicy.termsUrl),
                  child: const Text('Terms of Use', style: AppText.caption),
                ),
                TextButton(
                  onPressed: () => _open(TrialPolicy.privacyUrl),
                  child: const Text('Privacy Policy', style: AppText.caption),
                ),
              ],
            ),
          ],
          SizedBox(height: gap),
          TextButton(
            onPressed: _busy ? null : () => _close(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(
              live && !member ? 'Not now' : 'Back to Home',
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
