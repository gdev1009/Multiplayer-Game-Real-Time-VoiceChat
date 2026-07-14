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

/// "Check Upcoming Games" — the Milestone 4 lobby hub.
///
/// From here a player can quick-match with strangers, start their own game,
/// join with a 4-digit code, or pick from the list of open games.
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

    return AppPage(
      title: 'Play a Game',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          const HostGreeting(
            message: 'Ready to play? Find a game, start your own, '
                'or type a friend\'s code.',
          ),
          const SizedBox(height: AppSpacing.lg),
          BigButton(
            label: 'Find a Game',
            icon: Icons.search_rounded,
            isLoading: lobby.busy,
            onPressed:
                lobby.busy ? null : () => _enterRoom(() => lobby.quickMatch()),
          ),
          const SizedBox(height: AppSpacing.md),
          BigButton(
            label: 'Start a New Game',
            icon: Icons.add_circle_outline_rounded,
            onPressed: lobby.busy
                ? null
                : () => _enterRoom(() => lobby.createGame(isPublic: true)),
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
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              const Text('Open games', style: AppText.title),
              const Spacer(),
              IconButton(
                onPressed: lobby.busy ? null : () => lobby.refreshOpenGames(),
                icon: const Icon(Icons.refresh_rounded, size: 30),
                tooltip: 'Refresh',
                color: AppColors.deepPurple,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _OpenGamesList(onJoin: _enterRoom)),
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
      return const SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: AppSpacing.xl),
            Icon(
              Icons.event_available_rounded,
              size: 72,
              color: AppColors.deepPurple,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'No open games right now',
              style: AppText.title,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Tap "Start a New Game" to open one, and friends can join with '
              'your code.',
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: games.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _OpenGameTile(
        game: games[i],
        onJoin: () => onJoin(
          () => context.read<LobbyController>().joinByCode(games[i].code),
        ),
      ),
    );
  }
}

class _OpenGameTile extends StatelessWidget {
  const _OpenGameTile({required this.game, required this.onJoin});

  final Game game;
  final VoidCallback onJoin;

  /// Live occupancy for the tile, e.g. "2 / 4 players". Falls back to a simple
  /// capacity label if the count is unknown for any reason.
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
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Game ${game.code}', style: AppText.title),
                const SizedBox(height: 2),
                Text(
                  _playersLabel(game),
                  style: AppText.bodyMuted,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 108,
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
