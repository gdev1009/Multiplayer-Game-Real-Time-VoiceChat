import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import '../../models/game.dart';
import 'lobby_controller.dart';

/// "Check Upcoming Games" lobby hub.
class UpcomingGamesScreen extends StatefulWidget {
  const UpcomingGamesScreen({super.key});

  @override
  State<UpcomingGamesScreen> createState() => _UpcomingGamesScreenState();
}

class _UpcomingGamesScreenState extends State<UpcomingGamesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LobbyController>().refreshOpenGames();
    });
  }

  Future<void> _enterRoom(Future<bool> Function() action) async {
    final lobby = context.read<LobbyController>();
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      await Navigator.of(context).pushNamed(AppRoutes.lobbyRoom);
      if (mounted) context.read<LobbyController>().refreshOpenGames();
    } else if (lobby.error != null) {
      _showError(lobby.error!);
      lobby.clearError();
    }
  }

  void _showError(String message) {
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

    // Full-page scroll so greeting + actions + open games never overlap or
    // strand CTAs below the fold on real phones.
    return AppPage(
      title: 'Play a Game',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          const HostGreeting(
            message: 'Ready to play? Find a game, start your own, '
                'or type a friend\'s code.',
          ),
          const SizedBox(height: AppSpacing.md),
          BigButton(
            label: 'Find a Game',
            icon: Icons.search_rounded,
            isLoading: lobby.busy,
            onPressed:
                lobby.busy ? null : () => _enterRoom(() => lobby.quickMatch()),
          ),
          const SizedBox(height: AppSpacing.sm),
          BigButton(
            label: 'Start a New Game',
            icon: Icons.add_circle_outline_rounded,
            onPressed: lobby.busy
                ? null
                : () => _enterRoom(() => lobby.createGame(isPublic: true)),
          ),
          const SizedBox(height: AppSpacing.sm),
          BigButton(
            label: 'Join with a Code',
            icon: Icons.dialpad_rounded,
            variant: BigButtonVariant.secondary,
            onPressed: lobby.busy
                ? null
                : () => Navigator.of(context).pushNamed(AppRoutes.joinByCode),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Text('Open games', style: AppText.title),
              const Spacer(),
              IconButton(
                onPressed: lobby.busy ? null : () => lobby.refreshOpenGames(),
                icon: const Icon(Icons.refresh_rounded, size: 26),
                tooltip: 'Refresh',
                color: AppColors.deepPurple,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _OpenGamesList(onJoin: _enterRoom),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _OpenGamesList extends StatelessWidget {
  const _OpenGamesList({required this.onJoin});

  final Future<void> Function(Future<bool> Function()) onJoin;

  @override
  Widget build(BuildContext context) {
    final lobby = context.watch<LobbyController>();
    final games = lobby.openGames;

    if (games.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 56,
              color: AppColors.deepPurple,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'No open games right now. Start one or join with a code!',
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final game in games) ...[
          _OpenGameTile(
            game: game,
            onJoin: () => onJoin(
              () => context.read<LobbyController>().joinByCode(game.code),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _OpenGameTile extends StatelessWidget {
  const _OpenGameTile({required this.game, required this.onJoin});

  final Game game;
  final VoidCallback onJoin;

  static String _playersLabel(Game game) {
    final count = game.playerCount;
    if (count == null) return 'Up to ${game.maxPlayers} players';
    return '$count / ${game.maxPlayers} players';
  }

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Game ${game.code}',
                  style: AppText.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _playersLabel(game),
                  style: AppText.bodyMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 100,
            child: BigButton(
              label: 'Join',
              variant: BigButtonVariant.secondary,
              onPressed: onJoin,
            ),
          ),
        ],
      ),
    );
  }
}
