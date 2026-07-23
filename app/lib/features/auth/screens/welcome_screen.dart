import 'package:flutter/material.dart';

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
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Image.asset(
              'assets/images/grandmac-logo.jpg',
              height: 140,
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
          const Text(
            'Match Word',
            style: AppText.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'A fun word game where you play with friends, '
            'laugh, and connect.',
            style: AppText.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
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
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
