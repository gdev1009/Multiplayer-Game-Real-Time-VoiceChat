import 'game_player.dart';

/// A read-only snapshot of a lobby fetched by its 4-digit code, used to show
/// "who's already in the game" before the player commits to joining.
///
/// Returned by `mw_peek_game` (see `supabase/migrations/0008_join_preview.sql`).
/// It carries only the safe-to-show roster fields — no profile ids.
class GamePreview {
  const GamePreview({
    required this.gameId,
    required this.code,
    required this.maxPlayers,
    required this.seatsTaken,
    required this.alreadyMember,
    required this.players,
  });

  final String gameId;
  final String code;
  final int maxPlayers;
  final int seatsTaken;

  /// Whether the current user is already seated in this game (so the confirm
  /// step can say "Return to game" instead of "Join").
  final bool alreadyMember;

  /// The seats currently taken, in play order.
  final List<GamePlayer> players;

  int get seatsAvailable => maxPlayers - seatsTaken;

  bool get isFull => seatsTaken >= maxPlayers;

  factory GamePreview.fromMap(Map<String, dynamic> map) {
    final rawPlayers = (map['players'] as List?) ?? const [];
    return GamePreview(
      gameId: map['game_id'] as String,
      code: (map['code'] as String?) ?? '',
      maxPlayers: (map['max_players'] as num?)?.toInt() ?? 4,
      seatsTaken: (map['seats_taken'] as num?)?.toInt() ?? 0,
      alreadyMember: (map['already_member'] as bool?) ?? false,
      players: rawPlayers
          .map<GamePlayer>(
            (r) => GamePreviewSeat.fromMap(Map<String, dynamic>.from(r as Map)),
          )
          .toList(),
    );
  }
}

/// Builds a [GamePlayer] from the trimmed peek payload, which omits ids/game_id
/// (those aren't needed to render the preview roster).
class GamePreviewSeat {
  const GamePreviewSeat._();

  static GamePlayer fromMap(Map<String, dynamic> map) {
    final seat = (map['seat'] as num?)?.toInt() ?? 0;
    return GamePlayer(
      id: 'preview-$seat',
      gameId: '',
      profileId: null,
      displayName: (map['display_name'] as String?) ?? '',
      firstName: (map['display_name'] as String?) ?? '',
      isAi: (map['is_ai'] as bool?) ?? false,
      isHost: (map['is_host'] as bool?) ?? false,
      seat: seat,
      team: (map['team'] as String?) ?? LobbyRoles.teamForSeat(seat),
      role: (map['role'] as String?) ?? LobbyRoles.roleForSeat(seat),
    );
  }
}
