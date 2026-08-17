import 'package:flutter/material.dart';

import '../../../core/theme/app_responsive.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/brand_logo.dart';
import 'create_account_screen.dart';
import 'email_sign_in_screen.dart';

/// First screen for a device with no account yet.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logoH = AppResponsive.isShort(context)
        ? AppResponsive.s(context, 160).clamp(130.0, 180.0)
        : AppResponsive.s(context, 200).clamp(160.0, 220.0);
    final displaySize = AppResponsive.displaySize(context);

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppResponsive.isShort(context)
                ? AppSpacing.sm
                : AppSpacing.md,
          ),
          Center(child: BrandLogo(height: logoH)),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Welcome to',
            style: AppText.title,
            textAlign: TextAlign.center,
          ),
          Text(
            'Match Word',
            style: AppText.display.copyWith(fontSize: displaySize),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'A fun word game where you play with friends, '
            'laugh, and connect.',
            style: AppText.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          BigButton(
            label: 'Create My Account',
            icon: Icons.person_add_alt_1,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreateAccountScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          BigButton(
            label: 'I Already Have an Account',
            variant: BigButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EmailSignInScreen(),
                ),
              );
            },
          ),
          SizedBox(
            height: AppResponsive.isShort(context)
                ? AppSpacing.sm
                : AppSpacing.md,
          ),
        ],
      ),
    );
  }
}
