import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/host_greeting.dart';
import '../../models/prize.dart';
import '../../services/entitlement_service.dart';
import '../auth/auth_controller.dart';
import '../character/character_controller.dart';
import '../character/idle_character_preview.dart';
import '../prizes/player_trophy_badge.dart';
import '../prizes/prize_controller.dart';

/// The Opening screen.
///
/// Shown right after sign-in. Greets the player by name with a win trophy
/// badge (tap for points). Primary actions: Upcoming Games + Enter the Studio.
/// Prize Room and tournaments are later-phase (Ronna Aug 2026).
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CharacterController>().load();
      context.read<PrizeController>().load();
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
    final characterName =
        context.watch<CharacterController>().saved?.displayName.trim() ?? '';
    final name = characterName.isNotEmpty
        ? characterName
        : (profile?.firstName ?? controller.rememberedName ?? 'friend');
    final trialDays = profile?.trialDaysRemaining ?? 0;
    final entitlement = context.read<EntitlementService>();
    final access = entitlement.evaluate(profile: profile);
    final prizes = context.watch<PrizeController>();

    final logoH = AppResponsive.s(context, 100).clamp(80.0, 120.0);
    final gap = AppResponsive.isShort(context) ? AppSpacing.sm : AppSpacing.md;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppResponsive.isShort(context)
                ? AppSpacing.xs
                : AppSpacing.sm,
          ),
          Center(child: BrandLogo(height: logoH, outlineWidth: 2)),
          SizedBox(height: gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: AppText.display.copyWith(
                    fontSize: AppResponsive.displaySize(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PlayerTrophyBadge(
                room: prizes.room,
                loading: prizes.loading,
              ),
            ],
          ),
          SizedBox(height: gap),
          const HostGreeting(
            message: 'So glad you are here. '
                'What would you like to do today?',
          ),
          if (access == AccessLevel.expired) ...[
            SizedBox(height: gap),
            const _TrialBanner(
              daysLeft: 0,
              expired: true,
            ),
          ] else if (trialDays > 0) ...[
            SizedBox(height: gap),
            _TrialBanner(
              daysLeft: trialDays,
              countdown: access == AccessLevel.trialCountdown,
            ),
          ],
          SizedBox(height: gap),
          _CharacterCard(
            onCreate: () => _openCharacterBuilder(edit: false),
            onEdit: () => _openCharacterBuilder(edit: true),
          ),
          const SizedBox(height: AppSpacing.lg),
          BigButton(
            label: 'Check Upcoming Games',
            icon: Icons.event_available_rounded,
            onPressed: () => _goPlay(context, access, AppRoutes.upcomingGames),
          ),
          const SizedBox(height: AppSpacing.sm),
          BigButton(
            label: 'Enter the Studio',
            icon: Icons.theater_comedy_rounded,
            onPressed: () => _goPlay(context, access, AppRoutes.studio),
          ),
          if (PrizeAssets.showPrizeRoomEntry) ...[
            const SizedBox(height: AppSpacing.sm),
            BigButton(
              label: 'Prize Room',
              icon: Icons.emoji_events_rounded,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.prizeRoom),
            ),
          ],
          TextButton.icon(
            onPressed: () => controller.signOut(),
            icon: const Icon(Icons.lock_outline, size: 20),
            label: const Text('Sign Out', style: AppText.caption),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Future<void> _goPlay(
    BuildContext context,
    AccessLevel access,
    String route,
  ) async {
    final entitlement = context.read<EntitlementService>();
    if (!entitlement.canPlay(access)) {
      await Navigator.of(context).pushNamed(AppRoutes.paywall);
      return;
    }
    await Navigator.of(context).pushNamed(route);
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.onCreate, required this.onEdit});

  final VoidCallback onCreate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final characters = context.watch<CharacterController>();
    final saved = characters.saved;
    final avatar = AppResponsive.s(context, 64).clamp(56.0, 72.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (saved != null)
                IdleCharacterPreview(
                  character: saved,
                  size: avatar,
                  animatePoses: false,
                )
              else
                Container(
                  width: avatar,
                  height: avatar,
                  decoration: BoxDecoration(
                    gradient: AppColors.stageGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    Icons.face_retouching_natural,
                    size: avatar * 0.5,
                    color: AppColors.deepPurple,
                  ),
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      saved == null ? 'Your character' : saved.displayName,
                      style: AppText.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      saved == null
                          ? 'Build a clay look to play with.'
                          : 'Tap Edit to change your look.',
                      style: AppText.bodyMuted,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
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
    );
  }
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner({
    required this.daysLeft,
    this.countdown = false,
    this.expired = false,
  });

  final int daysLeft;
  final bool countdown;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (expired) {
      text =
          'Your free trial has ended. Tap Subscribe when you are ready to keep playing.';
    } else if (countdown) {
      text =
          '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left in your free trial — '
          'enjoy them, and the studio will still be here.';
    } else {
      text =
          '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left in your free trial';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: expired
            ? () => Navigator.of(context).pushNamed(AppRoutes.paywall)
            : null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warmBeige,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Text(
            text,
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
