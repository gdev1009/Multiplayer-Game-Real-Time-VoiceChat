import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/big_button.dart';
import '../../../services/auth_failure.dart';
import '../auth_controller.dart';
import 'create_account_screen.dart';
import 'email_sign_in_screen.dart';

/// First screen for a device with no account yet. Warm, simple, one clear
/// primary action.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _quickTestSignIn(BuildContext context) async {
    try {
      await context.read<AuthController>().quickTestSignIn();
    } on AuthFailure catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

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
          if (AppConfig.easyTestAuth) ...[
            const SizedBox(height: AppSpacing.md),
            BigButton(
              label: 'Quick Test Sign-In',
              icon: Icons.flash_on_rounded,
              variant: BigButtonVariant.secondary,
              onPressed: () => _quickTestSignIn(context),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
