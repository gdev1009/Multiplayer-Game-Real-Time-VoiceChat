/// A trophy or novelty prize from the Prize Room catalog.
class PrizeItem {
  const PrizeItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.assetPath,
    required this.sortOrder,
    required this.earned,
    this.earnedAt,
  });

  final String id;

  /// `trophy` or `prize`.
  final String kind;
  final String title;
  final String description;
  final String assetPath;
  final int sortOrder;
  final bool earned;
  final DateTime? earnedAt;

  bool get isTrophy => kind == 'trophy';

  factory PrizeItem.fromMap(Map<String, dynamic> map) {
    return PrizeItem(
      id: map['id'] as String,
      kind: (map['kind'] as String?) ?? 'prize',
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      assetPath: (map['asset_path'] as String?) ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      earned: (map['earned'] as bool?) ?? false,
      earnedAt: map['earned_at'] == null
          ? null
          : DateTime.tryParse(map['earned_at'] as String),
    );
  }
}

/// Snapshot of the caller's Prize Room shelves + play stats.
class PrizeRoom {
  const PrizeRoom({
    required this.gamesPlayed,
    required this.gamesWon,
    required this.items,
    this.gamesTied = 0,
  });

  final int gamesPlayed;
  final int gamesWon;
  final int gamesTied;
  final List<PrizeItem> items;

  int get gamesLost =>
      (gamesPlayed - gamesWon - gamesTied).clamp(0, gamesPlayed);

  List<PrizeItem> get trophies =>
      items.where((i) => i.isTrophy).toList(growable: false);

  List<PrizeItem> get prizes =>
      items.where((i) => !i.isTrophy).toList(growable: false);

  int get earnedCount => items.where((i) => i.earned).length;

  /// Shelf "expansion" level: empty → starter → growing → packed.
  int get roomLevel {
    final n = earnedCount;
    if (n >= 5) return 3;
    if (n >= 3) return 2;
    if (n >= 1) return 1;
    return 0;
  }

  factory PrizeRoom.empty() =>
      const PrizeRoom(gamesPlayed: 0, gamesWon: 0, items: []);

  factory PrizeRoom.fromMap(Map<String, dynamic> map) {
    final raw = (map['items'] as List?) ?? const [];
    return PrizeRoom(
      gamesPlayed: (map['games_played'] as num?)?.toInt() ?? 0,
      gamesWon: (map['games_won'] as num?)?.toInt() ?? 0,
      gamesTied: (map['games_tied'] as num?)?.toInt() ?? 0,
      items: raw
          .map((r) => PrizeItem.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList(growable: false),
    );
  }
}
