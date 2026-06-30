import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../auth/auth_controller.dart';

/// Placeholder home shown after sign-in. The full Opening Screen & navigation
/// arrive in Milestone 2; this confirms Milestone 1 end-to-end.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final profile = controller.profile;
    final name = profile?.firstName ?? controller.rememberedName ?? 'friend';
    final trialDays = profile?.trialDaysRemaining ?? 0;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Icon(
            Icons.celebration_rounded,
            size: 88,
            color: AppColors.gold,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'You are signed in,',
            style: AppText.title,
            textAlign: TextAlign.center,
          ),
          Text(name, style: AppText.display, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          if (trialDays > 0)
            _TrialBanner(daysLeft: trialDays)
          else
            const Text(
              'Your account is ready.',
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
          const Spacer(),
          const Text(
            'The studio doors open next — coming in Milestone 2.',
            style: AppText.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          BigButton(
            label: 'Sign Out',
            variant: BigButtonVariant.secondary,
            icon: Icons.lock_outline,
            onPressed: () => controller.lock(),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left in your free trial',
        style: AppText.body,
        textAlign: TextAlign.center,
      ),
    );
  }
}
