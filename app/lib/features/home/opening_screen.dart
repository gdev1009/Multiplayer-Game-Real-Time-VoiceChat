import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import '../auth/auth_controller.dart';
import '../character/character_controller.dart';
import '../character/idle_character_preview.dart';

/// The Opening screen (Milestone 2).
///
/// Shown right after sign-in. Greets the player by name with the show host and
/// offers the two main actions: *Check Upcoming Games* and *Enter the Studio*.
/// One clear primary action per button, large targets, high contrast.
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen> {
  @override
  void initState() {
    super.initState();
    // Reload the saved character whenever the Opening screen appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CharacterController>().load();
    });
  }

  Future<void> _openCharacterBuilder({required bool edit}) async {
    final characters = context.read<CharacterController>();
    if (edit) {
      characters.startEdit();
    } else {
      characters.startNew();
    }
    await Navigator.of(context).pushNamed(AppRoutes.character);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final profile = controller.profile;
    // Prefer the name the player gave their character (what they think of as
    // "their" name) over the account's first name, which for quick-test
    // sign-ins is an auto-generated handle like "Tester 4138".
    final characterName =
        context.watch<CharacterController>().saved?.displayName.trim() ?? '';
    final name = characterName.isNotEmpty
        ? characterName
        : (profile?.firstName ?? controller.rememberedName ?? 'friend');
    final trialDays = profile?.trialDaysRemaining ?? 0;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Image.asset(
            'assets/images/grandmac-logo.jpg',
            height: 96,
            fit: BoxFit.contain,
            semanticLabel: 'Grandma Mac logo',
          ),
          const SizedBox(height: AppSpacing.lg),
          HostGreeting(
            message: 'Hello $name! So glad you are here. '
                'What would you like to do today?',
          ),
          if (trialDays > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            _TrialBanner(daysLeft: trialDays),
          ],
          const SizedBox(height: AppSpacing.lg),
          _CharacterCard(
            onCreate: () => _openCharacterBuilder(edit: false),
            onEdit: () => _openCharacterBuilder(edit: true),
          ),
          const Spacer(),
          BigButton(
            label: 'Check Upcoming Games',
            icon: Icons.event_available_rounded,
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.upcomingGames),
          ),
          const SizedBox(height: AppSpacing.md),
          BigButton(
            label: 'Enter the Studio',
            icon: Icons.theater_comedy_rounded,
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.studio),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton.icon(
              onPressed: () => controller.signOut(),
              icon: const Icon(Icons.lock_outline, size: 24),
              label: const Text('Sign Out', style: AppText.body),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Shows the player's character (or a prompt to make one) with a create/edit
/// action. This is the entry point into the Milestone 3 character builder.
class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.onCreate, required this.onEdit});

  final VoidCallback onCreate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final characters = context.watch<CharacterController>();
    final saved = characters.saved;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          if (saved != null)
            IdleCharacterPreview(character: saved, size: 92)
          else
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: AppColors.stageGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: AppColors.tileShadow,
              ),
              child: const Icon(
                Icons.face_retouching_natural,
                size: 46,
                color: AppColors.deepPurple,
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saved == null ? 'Make your character' : saved.displayName,
                  style: AppText.title,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  saved == null
                      ? 'Build a fun clay character to play with.'
                      : 'Tap to change your look.',
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: AppSpacing.sm),
                BigButton(
                  label: saved == null ? 'Create' : 'Edit',
                  icon: saved == null ? Icons.add : Icons.edit,
                  variant: BigButtonVariant.secondary,
                  onPressed: saved == null ? onCreate : onEdit,
                ),
              ],
            ),
          ),
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
        color: AppColors.warmBeige,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: Text(
        '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left in your free trial',
        style: AppText.body,
        textAlign: TextAlign.center,
      ),
    );
  }
}
