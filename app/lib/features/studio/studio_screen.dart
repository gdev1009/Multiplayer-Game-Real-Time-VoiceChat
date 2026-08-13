import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import '../lobby/lobby_controller.dart';

/// "Enter the Studio" destination.
///
/// The host-first path: start your own game and share the code with friends, or
/// join a friend's game with their code. Public matchmaking lives on the
/// "Check Upcoming Games" hub; the Studio is for playing with people you know.
class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key});

  Future<void> _startGame(BuildContext context) async {
    final lobby = context.read<LobbyController>();
    // Private game: it won't show up in public matchmaking; friends join with
    // the code the host shares.
    final ok = await lobby.createGame(isPublic: false);
    if (!context.mounted) return;
    if (ok) {
      await Navigator.of(context).pushNamed(AppRoutes.lobbyRoom);
    } else if (lobby.error != null) {
      _showError(context, lobby.error!);
      lobby.clearError();
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppText.body),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lobby = context.watch<LobbyController>();

    final iconSize = AppResponsive.s(context, 88).clamp(64.0, 88.0);

    return AppPage(
      title: 'The Studio',
      showBack: true,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: AppResponsive.isShort(context)
                        ? AppSpacing.md
                        : AppSpacing.lg,
                  ),
                  const HostGreeting(
                    message:
                        'Welcome to the studio! Start your own game and share the '
                        'code with friends, or join a game with a friend\'s code.',
                  ),
                  SizedBox(
                    height: AppResponsive.isShort(context)
                        ? AppSpacing.lg
                        : AppSpacing.xxl,
                  ),
                  Icon(
                    Icons.theater_comedy_rounded,
                    size: iconSize,
                    color: AppColors.gold,
                  ),
                ],
              ),
            ),
          ),
          BigButton(
            label: 'Start a New Game',
            icon: Icons.add_circle_outline_rounded,
            isLoading: lobby.busy,
            onPressed: lobby.busy ? null : () => _startGame(context),
          ),
          const SizedBox(height: AppSpacing.md),
          BigButton(
            label: 'Join with a Code',
            icon: Icons.dialpad_rounded,
            variant: BigButtonVariant.secondary,
            onPressed: lobby.busy
                ? null
                : () => Navigator.of(context).pushNamed(AppRoutes.joinByCode),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
