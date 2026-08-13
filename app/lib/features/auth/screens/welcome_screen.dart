import 'package:flutter/material.dart';

import '../../../core/theme/app_responsive.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/big_button.dart';
import 'create_account_screen.dart';
import 'email_sign_in_screen.dart';

/// First screen for a device with no account yet.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logoH = AppResponsive.s(context, 140).clamp(96.0, 140.0);
    final displaySize = AppResponsive.displaySize(context);

    return AppPage(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: AppResponsive.isShort(context)
                        ? AppSpacing.md
                        : AppSpacing.xl,
                  ),
                  Center(
                    child: Image.asset(
                      'assets/images/grandmac-logo.jpg',
                      height: logoH,
                      fit: BoxFit.contain,
                      semanticLabel: 'Grandma Mac logo',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'A fun word game where you play with friends, '
                    'laugh, and connect.',
                    style: AppText.bodyMuted,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
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
          const SizedBox(height: AppSpacing.md),
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
                ? AppSpacing.md
                : AppSpacing.xl,
          ),
        ],
      ),
    );
  }
}
