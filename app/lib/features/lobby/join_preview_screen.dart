import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import '../../models/game_player.dart';
import '../../models/game_preview.dart';
import 'lobby_controller.dart';

/// Shows who is already in a game (and on which team) *before* the player
/// commits to joining, so friends can make sure they land on the same team.
///
/// Reached from [JoinByCodeScreen] after a successful `peekByCode`. Players can
/// tap any open (or studio-filled) seat to pick their own team; confirming
/// calls the seat-specific join and replaces the stack with the live room.
class JoinPreviewScreen extends StatefulWidget {
  const JoinPreviewScreen({super.key, required this.preview});

  final GamePreview preview;

  @override
  State<JoinPreviewScreen> createState() => _JoinPreviewScreenState();
}

class _JoinPreviewScreenState extends State<JoinPreviewScreen> {
  GamePreview get preview => widget.preview;

  /// The seat the player has picked (or the default suggestion). Null only when
  /// every seat is held by a human, or the player is already in the game.
  int? _selectedSeat;

  @override
  void initState() {
    super.initState();
    _selectedSeat = preview.alreadyMember ? null : _defaultSeat;
  }

  /// A seat is pickable when it's empty or held by a studio (AI) player — never
  /// a seat another human is already sitting in.
  bool _seatPickable(int seat) {
    final player = _playerAt(seat);
    return player == null || player.isAi;
  }

  GamePlayer? _playerAt(int seat) {
    for (final p in preview.players) {
      if (p.seat == seat) return p;
    }
    return null;
  }

  /// The seat we suggest by default: the lowest free seat, or — when the lobby
  /// was pre-filled with studio players — the lowest one we'd take over.
  int? get _defaultSeat {
    for (var seat = 0; seat < preview.maxPlayers; seat++) {
      if (_playerAt(seat) == null) return seat;
    }
    for (var seat = 0; seat < preview.maxPlayers; seat++) {
      if (_playerAt(seat)?.isAi ?? false) return seat;
    }
    return null;
  }

  void _pickSeat(int seat) {
    if (!_seatPickable(seat)) return;
    setState(() => _selectedSeat = seat);
  }

  Future<void> _confirm(BuildContext context) async {
    final seat = _selectedSeat;
    if (seat == null) return;
    final lobby = context.read<LobbyController>();
    final ok = await lobby.joinSeat(preview.code, seat);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.lobbyRoom);
    } else if (lobby.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lobby.error!, style: AppText.body),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      lobby.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobby = context.watch<LobbyController>();
    final mySeat = _selectedSeat;
    final myTeam = mySeat == null ? null : LobbyRoles.teamForSeat(mySeat);
    // Truly full only when no seat is pickable and we're not already in it.
    final isFull = _defaultSeat == null && !preview.alreadyMember;

    return AppPage(
      title: 'Join Game',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          HostGreeting(
            message: preview.alreadyMember
                ? "You're already in this game — welcome back!"
                : myTeam == null
                    ? "Here's who's already playing."
                    : "Tap an open seat to pick your spot. "
                        "You'll join Team $myTeam!",
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _TeamPreview(
                    team: 'A',
                    seats: const [0, 2],
                    preview: preview,
                    mySeat: mySeat,
                    onPick: preview.alreadyMember ? null : _pickSeat,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TeamPreview(
                    team: 'B',
                    seats: const [1, 3],
                    preview: preview,
                    mySeat: mySeat,
                    onPick: preview.alreadyMember ? null : _pickSeat,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isFull)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warmBeige,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Text(
                'This game is full. Ask your friend to make room, or try '
                'another code.',
                style: AppText.body,
                textAlign: TextAlign.center,
              ),
            )
          else
            BigButton(
              label: preview.alreadyMember ? 'Return to Game' : 'Join Game',
              icon: Icons.login_rounded,
              isLoading: lobby.busy,
              onPressed: lobby.busy ? null : () => _confirm(context),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _TeamPreview extends StatelessWidget {
  const _TeamPreview({
    required this.team,
    required this.seats,
    required this.preview,
    required this.mySeat,
    required this.onPick,
  });

  final String team;
  final List<int> seats;
  final GamePreview preview;
  final int? mySeat;
  final void Function(int seat)? onPick;

  GamePlayer? _playerAt(int seat) {
    for (final p in preview.players) {
      if (p.seat == seat) return p;
    }
    return null;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(LobbyRoles.teamLabel(team), style: AppText.title),
          const SizedBox(height: AppSpacing.sm),
          for (final seat in seats)
            if (seat < preview.maxPlayers)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _PreviewSeat(
                  player: _playerAt(seat),
                  isMine: seat == mySeat,
                  onTap: onPick == null ? null : () => onPick!(seat),
                ),
              ),
        ],
      ),
    );
  }
}

class _PreviewSeat extends StatelessWidget {
  const _PreviewSeat({
    required this.player,
    required this.isMine,
    required this.onTap,
  });

  final GamePlayer? player;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final filled = player != null;
    // Empty seats and studio (AI) seats can be picked; a human's seat can't.
    final pickable = !isMine && (player == null || player!.isAi);
    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isMine
            ? AppColors.gold
            : filled
                ? AppColors.lavenderSoft
                : AppColors.warmBeige,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: isMine
            ? Border.all(color: AppColors.deepPurple, width: 2)
            : null,
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
              isMine
                  ? 'You'
                  : filled
                      ? player!.displayName
                      : 'Open seat',
              style: (filled || isMine) ? AppText.body : AppText.bodyMuted,
            ),
          ),
          if (filled && player!.isHost)
            const _Pill(label: 'Host', color: AppColors.gold)
          else if (isMine)
            const _Pill(label: 'Tap to sit', color: AppColors.lavender)
          else if (pickable && onTap != null)
            const Icon(Icons.touch_app_rounded, color: AppColors.deepPurple),
        ],
      ),
    );

    if (onTap == null || !pickable) return content;
    return Semantics(
      button: true,
      label: 'Pick this seat',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: content,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

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
