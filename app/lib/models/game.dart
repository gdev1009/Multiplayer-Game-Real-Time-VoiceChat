/// A Match Word lobby / game room as stored in the Supabase `games` table.
enum GameStatus { lobby, inProgress, finished, cancelled }

GameStatus _statusFromString(String? value) {
  switch (value) {
    case 'in_progress':
      return GameStatus.inProgress;
    case 'finished':
      return GameStatus.finished;
    case 'cancelled':
      return GameStatus.cancelled;
    case 'lobby':
    default:
      return GameStatus.lobby;
  }
}

class Game {
  const Game({
    required this.id,
    required this.code,
    required this.hostId,
    required this.status,
    required this.isPublic,
    required this.maxPlayers,
    required this.createdAt,
    this.startedAt,
    this.expiresAt,
    this.playerCount,
  });

  final String id;
  final String code;
  final String hostId;
  final GameStatus status;
  final bool isPublic;
  final int maxPlayers;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? expiresAt;

  /// How many seats are currently taken, when known (e.g. from the open-games
  /// list). Null when the row was loaded without an occupancy count.
  final int? playerCount;

  bool get isOpen => status == GameStatus.lobby;

  /// Free seats remaining, when the [playerCount] is known.
  int? get seatsAvailable =>
      playerCount == null ? null : (maxPlayers - playerCount!);

  /// Whether every seat is taken, when the [playerCount] is known.
  bool get isFull => playerCount != null && playerCount! >= maxPlayers;

  factory Game.fromMap(Map<String, dynamic> map) {
    return Game(
      id: map['id'] as String,
      code: (map['code'] as String?) ?? '',
      hostId: (map['host_id'] as String?) ?? '',
      status: _statusFromString(map['status'] as String?),
      isPublic: (map['is_public'] as bool?) ?? false,
      maxPlayers: (map['max_players'] as int?) ?? 4,
      createdAt: DateTime.parse(map['created_at'] as String),
      startedAt: map['started_at'] == null
          ? null
          : DateTime.parse(map['started_at'] as String),
      expiresAt: map['expires_at'] == null
          ? null
          : DateTime.parse(map['expires_at'] as String),
      playerCount: (map['player_count'] as num?)?.toInt(),
    );
  }
}
