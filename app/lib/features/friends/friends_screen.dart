import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import '../../models/friend.dart';
import '../character/idle_character_preview.dart';
import '../lobby/lobby_controller.dart';
import 'friend_controller.dart';

/// The Friends screen.
///
/// Shows incoming friend requests to accept, the player's friends (each of whom
/// can be invited to a new game or removed), and a gentle explanation of how
/// friends are made — after playing a game together. Senior-first: big rows,
/// one clear action each, no clutter.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FriendController>().refresh();
    });
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

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppText.body),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _run(Future<bool> Function() action, {String? success}) async {
    final friends = context.read<FriendController>();
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      if (success != null) _toast(success);
    } else if (friends.error != null) {
      _showError(friends.error!);
      friends.clearError();
    }
  }

  /// "Invite to a game": open a fresh private room, seat the host, invite the
  /// friend, then enter the lobby so the host can wait for them.
  Future<void> _inviteToGame(Friend friend) async {
    final lobby = context.read<LobbyController>();
    final friends = context.read<FriendController>();

    final created = await lobby.createGame();
    if (!mounted) return;
    final game = lobby.game;
    if (!created || game == null) {
      if (lobby.error != null) {
        _showError(lobby.error!);
        lobby.clearError();
      }
      return;
    }

    final invited = await friends.inviteFriend(game.id, friend.id);
    if (!mounted) return;
    if (!invited && friends.error != null) {
      _showError(friends.error!);
      friends.clearError();
    } else {
      _toast('Invited ${friend.displayName}. They can join from their games.');
    }
    await Navigator.of(context).pushNamed(AppRoutes.lobbyRoom);
  }

  Future<void> _confirmRemove(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${friend.displayName}?', style: AppText.title),
        content: const Text(
          'You can always add each other again after a game.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep', style: AppText.action),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: AppText.action.copyWith(color: AppColors.deepPurple),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => context.read<FriendController>().removeFriend(friend.id),
        success: 'Removed ${friend.displayName}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = context.watch<FriendController>();

    return AppPage(
      title: 'Friends',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          const HostGreeting(
            message: 'These are the players you have met and matched with. '
                'Invite a friend to a game any time!',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!friends.loaded && friends.busy)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (friends.requests.isNotEmpty) ...[
              const _SectionHeader(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Friend requests',
              ),
              const SizedBox(height: AppSpacing.sm),
              ...friends.requests.map(
                (r) => _RequestTile(
                  request: r,
                  onAccept: () => _run(
                    () => context
                        .read<FriendController>()
                        .acceptRequest(r.fromId),
                    success: 'You and ${r.displayName} are now friends!',
                  ),
                  onDecline: () => _run(
                    () => context
                        .read<FriendController>()
                        .declineRequest(r.fromId),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const _SectionHeader(
              icon: Icons.groups_rounded,
              title: 'Your friends',
            ),
            const SizedBox(height: AppSpacing.sm),
            if (friends.friends.isEmpty)
              const _EmptyFriends()
            else
              ...friends.friends.map(
                (f) => _FriendTile(
                  friend: f,
                  busy: friends.busy,
                  onInvite: () => _inviteToGame(f),
                  onRemove: () => _confirmRemove(f),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 28, color: AppColors.deepPurple),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppText.title),
      ],
    );
  }
}

/// A round avatar that shows a friend's saved character (or a friendly clay
/// placeholder if they haven't built one yet).
class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.friend});

  final Friend friend;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: IdleCharacterPreview(
        character: friend.character,
        size: _size,
        animatePoses: false,
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _FriendAvatar(
                friend: Friend(
                  id: request.fromId,
                  displayName: request.displayName,
                  character: request.character,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.displayName, style: AppText.title),
                    const SizedBox(height: 2),
                    const Text(
                      'wants to be your friend',
                      style: AppText.bodyMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: BigButton(
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  onPressed: onAccept,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: BigButton(
                  label: 'Not now',
                  variant: BigButtonVariant.secondary,
                  onPressed: onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.busy,
    required this.onInvite,
    required this.onRemove,
  });

  final Friend friend;
  final bool busy;
  final VoidCallback onInvite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _FriendAvatar(friend: friend),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(friend.displayName, style: AppText.title),
              ),
              IconButton(
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.person_remove_alt_1_outlined, size: 26),
                color: AppColors.textSecondary,
                tooltip: 'Remove friend',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          BigButton(
            label: 'Invite to a Game',
            icon: Icons.videogame_asset_rounded,
            variant: BigButtonVariant.secondary,
            onPressed: busy ? null : onInvite,
          ),
        ],
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Column(
        children: [
          Icon(
            Icons.emoji_people_rounded,
            size: 64,
            color: AppColors.deepPurple,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'No friends yet',
            style: AppText.title,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Play a game with someone, then tap "Add friend" when it ends. '
            'They will show up here.',
            style: AppText.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppColors.softShadow,
      ),
      child: child,
    );
  }
}
