/// How a finished match counts toward Prize Room stats.
enum MatchOutcome { win, tie, loss }

extension MatchOutcomeRpc on MatchOutcome {
  String get rpcValue => switch (this) {
        MatchOutcome.win => 'win',
        MatchOutcome.tie => 'tie',
        MatchOutcome.loss => 'loss',
      };
}

/// Phase-1 clay win trophy art (one visual cup per [PrizeRoom.gamesWon]).
abstract final class PrizeAssets {
  static const winCup = 'assets/images/trophies/trophy-first-win.png';
  static const winCupId = 'trophy-win-cup';

  /// Novelty prize shelf — deferred past Phase 1 (Ronna Jul 2026).
  static const showNoveltyPrizes = false;

  /// Full Prize Room screen — Tier 2 / future (Ronna Aug 2026).
  /// Home uses the compact trophy badge + points popup instead.
  static const showPrizeRoomEntry = false;

  /// Ronna: players need this many trophies for the yearly tournament.
  static const yearlyTournamentTrophyQualifier = 50;
}

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

  /// Clay cups earned — one per win (Phase 1 retention loop).
  int get winTrophyCount => gamesWon;

  List<PrizeItem> get trophies =>
      items.where((i) => i.isTrophy).toList(growable: false);

  /// Milestone plaques (first win, 10/50 games) — not the per-win cups.
  List<PrizeItem> get milestoneTrophies => trophies
      .where((i) => i.id != PrizeAssets.winCupId)
      .toList(growable: false);

  List<PrizeItem> get prizes =>
      items.where((i) => !i.isTrophy).toList(growable: false);

  /// One shelf slot per win (capped for layout). Uses shared clay cup art.
  List<PrizeItem> winCups({int maxVisible = 12}) {
    final n = winTrophyCount.clamp(0, maxVisible);
    if (n == 0) return const [];
    String asset = PrizeAssets.winCup;
    for (final i in trophies) {
      if (i.id == PrizeAssets.winCupId && i.assetPath.isNotEmpty) {
        asset = i.assetPath;
        break;
      }
    }
    return List<PrizeItem>.generate(
      n,
      (i) => PrizeItem(
        id: 'win-cup-slot-$i',
        kind: 'trophy',
        title: n == 1 ? 'Trophy' : 'Trophy ${i + 1}',
        description: 'Trophy for a Match Word win.',
        assetPath: asset,
        sortOrder: i,
        earned: true,
      ),
      growable: false,
    );
  }

  int get earnedCount =>
      winTrophyCount + milestoneTrophies.where((i) => i.earned).length;

  /// Shelf "expansion" level: empty → starter → growing → packed.
  int get roomLevel {
    final n = earnedCount;
    if (n >= 5) return 3;
    if (n >= 3) return 2;
    if (n >= 1) return 1;
    return 0;
  }

  /// Short line for the Opening / sign-in welcome.
  String get signInTrophyLine {
    final n = winTrophyCount;
    if (n <= 0) {
      return 'Win a game to earn a trophy — come back and collect more!';
    }
    if (n == 1) {
      return 'You have 1 trophy. Ready for another win?';
    }
    return 'You have $n trophies. Ready for another win?';
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

  PrizeRoom copyWith({
    int? gamesPlayed,
    int? gamesWon,
    int? gamesTied,
    List<PrizeItem>? items,
  }) {
    return PrizeRoom(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      gamesTied: gamesTied ?? this.gamesTied,
      items: items ?? this.items,
    );
  }
}
