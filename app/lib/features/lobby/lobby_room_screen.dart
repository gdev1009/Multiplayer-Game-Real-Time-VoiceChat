import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import '../../models/game.dart';
import '../../models/game_player.dart';
import '../../services/gameplay_service.dart';
import '../auth/auth_controller.dart';
import '../game/gameplay_controller.dart';
import '../game/play_screen.dart';
import 'lobby_controller.dart';

/// The live game room (Milestone 4).
///
/// Shows the 4-digit code to share, both teams and their seats, and the host's
/// controls to add players and start. Stays in sync via Realtime.
class LobbyRoomScreen extends StatelessWidget {
  const LobbyRoomScreen({super.key});

  Future<bool> _confirmLeave(BuildContext context) async {
    await context.read<LobbyController>().leave();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final lobby = context.watch<LobbyController>();
    final game = lobby.game;

    if (game == null) {
      // Room was left/cancelled — bounce back to the hub.
      return const AppPage(
        title: 'Game Room',
        showBack: true,
        child: Center(child: Text('This game has ended.', style: AppText.body)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmLeave(context);
        if (context.mounted) Navigator.of(context).pop();
      },
      child: AppPage(
        title: 'Game Room',
        showBack: true,
        onBack: () async {
          await _confirmLeave(context);
          if (context.mounted) Navigator.of(context).pop();
        },
        child: game.status == GameStatus.inProgress
            ? _StartingPanel(game: game, players: lobby.players)
            : _LobbyBody(game: game, lobby: lobby),
      ),
    );
  }
}

class _LobbyBody extends StatelessWidget {
  const _LobbyBody({required this.game, required this.lobby});

  final Game game;
  final LobbyController lobby;

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppText.body),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _run(
      BuildContext context, Future<bool> Function() action,) async {
    final ok = await action();
    if (!context.mounted) return;
    if (!ok && lobby.error != null) {
      _showError(context, lobby.error!);
      lobby.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.read<AuthController>().profile?.firstName ??
        context.read<AuthController>().rememberedName ??
        'friend';
    final isHost = lobby.isHost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        HostGreeting(
          message: isHost
              ? 'Welcome, $name! Share your code so friends can join.'
              : 'Welcome, $name! Waiting for the game to start.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _CodeCard(code: game.code),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _TeamCard(
                  team: 'A',
                  seats: const [0, 2],
                  players: lobby.players,
                  maxPlayers: game.maxPlayers,
                ),
                const SizedBox(height: AppSpacing.md),
                _TeamCard(
                  team: 'B',
                  seats: const [1, 3],
                  players: lobby.players,
                  maxPlayers: game.maxPlayers,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (isHost) ...[
          if (!lobby.isFull)
            BigButton(
              label: 'Add Players',
              icon: Icons.group_add_rounded,
              variant: BigButtonVariant.secondary,
              onPressed: lobby.busy
                  ? null
                  : () => _run(context, () => lobby.fillSeats()),
            ),
          const SizedBox(height: AppSpacing.md),
          BigButton(
            label: 'Start Game',
            icon: Icons.play_arrow_rounded,
            isLoading: lobby.busy,
            onPressed: (!lobby.canStart || lobby.busy)
                ? null
                : () => _run(context, () => lobby.startGame()),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warmBeige,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Text(
              'Waiting for the host to start the game…',
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          const Text(
            'Your game code',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            code,
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                onPressed: () => _shareCode(context),
                icon: const Icon(Icons.ios_share_rounded,
                    color: Colors.white, size: 24,),
                label: const Text(
                  'Share code',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copied', style: AppText.body),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded,
                    color: Colors.white, size: 24,),
                label: const Text(
                  'Copy code',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opens the native share sheet so the host can send the code by text,
  /// email, or any messaging app — "share outside the app" per the spec.
  Future<void> _shareCode(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      'Join my Match Word game! Open Match Word, tap "Join with a Code", '
      'and enter $code.',
      subject: 'Match Word game code: $code',
      // Anchor the iPad share popover to this card.
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.seats,
    required this.players,
    required this.maxPlayers,
  });

  final String team;
  final List<int> seats;
  final List<GamePlayer> players;
  final int maxPlayers;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(LobbyRoles.teamLabel(team), style: AppText.title),
          const SizedBox(height: AppSpacing.sm),
          for (final seat in seats)
            if (seat < maxPlayers)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SeatTile(
                  seat: seat,
                  player: _playerAt(seat),
                ),
              ),
        ],
      ),
    );
  }

  GamePlayer? _playerAt(int seat) {
    for (final p in players) {
      if (p.seat == seat) return p;
    }
    return null;
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.player});

  final int seat;
  final GamePlayer? player;

  @override
  Widget build(BuildContext context) {
    final filled = player != null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: filled ? AppColors.lavenderSoft : AppColors.warmBeige,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: filled ? AppColors.deepPurple : AppColors.lavender,
            child: Icon(
              filled ? Icons.person_rounded : Icons.person_outline_rounded,
              color: filled ? Colors.white : AppColors.deepPurple,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              filled ? player!.displayName : 'Open seat',
              style: filled ? AppText.body : AppText.bodyMuted,
            ),
          ),
          if (filled && player!.isHost)
            const _Tag(label: 'Host', color: AppColors.gold),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.black,
        ),
      ),
    );
  }
}

class _StartingPanel extends StatefulWidget {
  const _StartingPanel({required this.game, required this.players});

  final Game game;
  final List<GamePlayer> players;

  @override
  State<_StartingPanel> createState() => _StartingPanelState();
}

class _StartingPanelState extends State<_StartingPanel> {
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    // Once the host flips the game to in-progress, everyone in the room hands
    // off to the live play screen. We scope a fresh GameplayController to that
    // screen so its streams are torn down cleanly when the game ends.
    WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
  }

  Future<void> _launch() async {
    if (_launched || !mounted) return;
    _launched = true;

    final service = context.read<GameplayService>();
    final controller = GameplayController(service: service, game: widget.game);
    // Deal words (host) / subscribe (everyone) before showing the screen.
    await controller.startOnline(players: widget.players);
    if (!mounted) {
      controller.dispose();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<GameplayController>.value(
          value: controller,
          child: const PlayScreen(),
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Spacer(),
        Icon(Icons.celebration_rounded, size: 96, color: AppColors.gold),
        SizedBox(height: AppSpacing.lg),
        Text(
          'The game is starting!',
          style: AppText.display,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Everyone is in. Get ready to play Match Word!',
          style: AppText.bodyMuted,
          textAlign: TextAlign.center,
        ),
        Spacer(),
      ],
    );
  }
}
