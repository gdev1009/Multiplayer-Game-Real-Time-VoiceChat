/// A single seat within a Match Word game (`game_players` table).
///
/// A seat with a null [profileId] is a computer-filled seat ([isAi]); the
/// player-facing UI never surfaces that wording — it simply shows another
/// studio player.
class GamePlayer {
  const GamePlayer({
    required this.id,
    required this.gameId,
    required this.profileId,
    required this.displayName,
    required this.firstName,
    required this.isAi,
    required this.isHost,
    required this.seat,
    required this.team,
    required this.role,
  });

  final String id;
  final String gameId;
  final String? profileId;
  final String displayName;
  final String firstName;
  final bool isAi;
  final bool isHost;
  final int seat;

  /// 'A' or 'B'.
  final String team;

  /// 'A1', 'A2', 'B1', or 'B2'.
  final String role;

  bool get isHuman => profileId != null;

  factory GamePlayer.fromMap(Map<String, dynamic> map) {
    return GamePlayer(
      id: map['id'] as String,
      gameId: map['game_id'] as String,
      profileId: map['profile_id'] as String?,
      displayName: (map['display_name'] as String?) ?? '',
      firstName: (map['first_name'] as String?) ?? '',
      isAi: (map['is_ai'] as bool?) ?? false,
      isHost: (map['is_host'] as bool?) ?? false,
      seat: (map['seat'] as int?) ?? 0,
      team: (map['team'] as String?) ?? 'A',
      role: (map['role'] as String?) ?? 'A1',
    );
  }
}

/// Pure helper mirroring the SQL `mw_seat_team` / `mw_seat_role` functions so
/// the client can label empty seats consistently with the server.
class LobbyRoles {
  const LobbyRoles._();

  /// 'A' for even seats, 'B' for odd seats.
  static String teamForSeat(int seat) => seat.isEven ? 'A' : 'B';

  /// e.g. seat 0 -> 'A1', seat 3 -> 'B2'.
  static String roleForSeat(int seat) => '${teamForSeat(seat)}${(seat ~/ 2) + 1}';

  /// A friendly team label for the UI ("Team A" / "Team B").
  static String teamLabel(String team) => 'Team $team';
}
