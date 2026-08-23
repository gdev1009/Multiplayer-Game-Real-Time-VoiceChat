import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import '../../core/widgets/outlined_glyph.dart';
import '../../models/character.dart';
import '../../models/game.dart';
import '../../models/game_player.dart';
import '../../services/gameplay_service.dart';
import '../auth/auth_controller.dart';
import '../character/character_controller.dart';
import '../character/idle_character_preview.dart';
import '../game/ai_player.dart';
import '../game/gameplay_controller.dart';
import '../game/play_screen.dart';
import 'lobby_controller.dart';

/// The live game room.
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

class _LobbyBody extends StatefulWidget {
  const _LobbyBody({required this.game, required this.lobby});

  final Game game;
  final LobbyController lobby;

  @override
  State<_LobbyBody> createState() => _LobbyBodyState();
}

class _LobbyBodyState extends State<_LobbyBody> {
  Map<String, Character> _characters = const {};
  String? _loadedForGame;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  @override
  void didUpdateWidget(covariant _LobbyBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.id != widget.game.id) {
      _loadedForGame = null;
      _loadCharacters();
    }
  }

  Future<void> _loadCharacters() async {
    final gameId = widget.game.id;
    if (_loadedForGame == gameId && _characters.isNotEmpty) return;
    try {
      final svc = context.read<GameplayService>();
      final map = await svc.loadCharacters(gameId);
      if (!mounted) return;
      setState(() {
        _characters = map;
        _loadedForGame = gameId;
      });
    } catch (_) {
      // Keep generated roster looks if character load fails.
      if (mounted) setState(() {});
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

  Future<void> _run(
      BuildContext context, Future<bool> Function() action,) async {
    final ok = await action();
    if (!context.mounted) return;
    if (!ok && widget.lobby.error != null) {
      _showError(context, widget.lobby.error!);
      widget.lobby.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobby = widget.lobby;
    final game = widget.game;
    // Recompute every rebuild so Add Players / Realtime fills never leave
    // generic silhouette avatars (shared list mutation skipped didUpdateWidget).
    final rosterLooks = AiPlayer.looksForSeats(
      game.id,
      lobby.players.map((p) => (role: p.role, name: p.displayName)),
    );
    // Prefer the character display name over the account first name.
    final isHost = lobby.isHost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        HostGreeting(
          message: isHost
              ? 'Share your code so friends can join.'
              : 'Waiting for the host to start the game.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _CodeCard(code: game.code),
        const SizedBox(height: AppSpacing.sm),
        if (lobby.awaitingFill) ...[
          _LookingForPlayers(secondsLeft: lobby.fillSecondsLeft),
          const SizedBox(height: AppSpacing.sm),
        ],
        _TeamCard(
          team: 'A',
          seats: const [0, 2],
          players: lobby.players,
          maxPlayers: game.maxPlayers,
          characters: _characters,
          rosterLooks: rosterLooks,
        ),
        const SizedBox(height: AppSpacing.sm),
        _TeamCard(
          team: 'B',
          seats: const [1, 3],
          players: lobby.players,
          maxPlayers: game.maxPlayers,
          characters: _characters,
          rosterLooks: rosterLooks,
        ),
        const SizedBox(height: AppSpacing.md),
        if (isHost) ...[
          if (!lobby.isFull)
            BigButton(
              label: 'Add Players',
              icon: Icons.group_add_rounded,
              variant: BigButtonVariant.secondary,
              isLoading: lobby.busy,
              onPressed: lobby.busy
                  ? null
                  : () => _run(context, () => lobby.fillSeats()),
            ),
          if (!lobby.isFull) const SizedBox(height: AppSpacing.sm),
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

/// A friendly "looking for players" banner shown while a quick-matched room
/// holds its seats open for real people, before the studio players fill in.
class _LookingForPlayers extends StatelessWidget {
  const _LookingForPlayers({required this.secondsLeft});

  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lavenderSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.deepPurpleLight, width: 2),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              secondsLeft > 0
                  ? 'Looking for players… studio players join in '
                      '$secondsLeft second${secondsLeft == 1 ? '' : 's'}.'
                  : 'Bringing in studio players…',
              style: AppText.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final codeSize = AppResponsive.codeSize(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Your game code',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: OutlinedGlyph(
              code,
              style: TextStyle(
                fontSize: codeSize,
                fontWeight: FontWeight.w800,
                letterSpacing: AppResponsive.isNarrow(context) ? 4 : 8,
                height: 1.05,
              ),
              fillColor: Colors.white,
              outlineColor: const Color(0xFF1A1028),
              outlineWidth: 2,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _shareCode(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text(
                  'Share',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () => _copyCode(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text(
                  'Copy',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareCode(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      'Join my Match Word game! Open Match Word, tap "Join with a Code", '
      'and enter $code.',
      subject: 'Match Word game code: $code',
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied', style: AppText.body),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.seats,
    required this.players,
    required this.maxPlayers,
    required this.characters,
    required this.rosterLooks,
  });

  final String team;
  final List<int> seats;
  final List<GamePlayer> players;
  final int maxPlayers;
  final Map<String, Character> characters;
  /// Unique AI looks for this match (hair/hat/glasses/outfit never twin).
  final Map<String, Character> rosterLooks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LobbyRoles.teamLabel(team),
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.deepPurple,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          for (final seat in seats)
            if (seat < maxPlayers)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _SeatTile(
                  seat: seat,
                  player: _playerAt(seat),
                  character: _characterFor(_playerAt(seat)),
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

  Character? _characterFor(GamePlayer? player) {
    if (player == null) return null;
    final fromServer = characters[player.role];
    if (fromServer != null && fromServer.base != null) return fromServer;
    return rosterLooks[player.role];
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.seat,
    required this.player,
    this.character,
  });

  final int seat;
  final GamePlayer? player;
  final Character? character;

  @override
  Widget build(BuildContext context) {
    final filled = player != null;
    Character? seatLook = character;
    // Fall back to the signed-in player's saved look for their own seat.
    final saved = context.watch<CharacterController>().saved;
    final myId = context.read<AuthController>().profile?.id;
    if (filled &&
        seatLook == null &&
        saved != null &&
        player!.profileId != null &&
        myId != null &&
        player!.profileId == myId) {
      seatLook = saved;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: filled ? AppColors.lavenderSoft : AppColors.warmBeige,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          _SeatAvatar(filled: filled, character: seatLook),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              filled ? player!.displayName : 'Open seat',
              style: filled ? AppText.body : AppText.bodyMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (filled && player!.isHost)
            const _Tag(label: 'Host', color: AppColors.gold),
        ],
      ),
    );
  }
}

class _SeatAvatar extends StatelessWidget {
  const _SeatAvatar({required this.filled, this.character});

  final bool filled;
  final Character? character;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    if (filled && character != null && character!.base != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: SizedBox(
          width: _size,
          height: _size,
          child: IdleCharacterPreview(
            character: character!,
            size: _size * 1.35,
            showBackdrop: false,
            animatePoses: false,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: filled ? AppColors.deepPurple : AppColors.lavender,
      child: Icon(
        filled ? Icons.person_rounded : Icons.person_outline_rounded,
        color: filled ? Colors.white : AppColors.deepPurple,
        size: 26,
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
          fontSize: 18,
          fontWeight: FontWeight.w800,
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
    // AppPage is scrollable, so Spacer() collapses — size to the viewport
    // and truly center the message.
    final media = MediaQuery.of(context);
    final minH = (media.size.height -
            media.padding.top -
            media.padding.bottom -
            kToolbarHeight -
            48)
        .clamp(280.0, media.size.height);

    return SizedBox(
      height: minH,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration_rounded, size: 72, color: AppColors.gold),
              SizedBox(height: AppSpacing.md),
              Text(
                'The game is starting!',
                style: AppText.display,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Everyone is in. Get ready to play Match Word!',
                style: AppText.bodyMuted,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
