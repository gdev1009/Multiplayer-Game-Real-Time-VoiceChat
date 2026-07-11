import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/game/game_engine.dart';
import 'lobby_failure.dart';

/// A parsed `game_state` row — the server's authoritative match snapshot.
///
/// The client renders from this and reconciles its optimistic local engine
/// against it. Field names mirror `supabase/migrations/0007_gameplay.sql`.
class GameStateRow {
  const GameStateRow({
    required this.phase,
    required this.wordIndex,
    required this.cluingTeam,
    required this.step,
    required this.exchangeCount,
    required this.scoreA,
    required this.scoreB,
    required this.pendingClue,
    required this.lastOutcome,
    required this.hostLine,
    required this.wordsPerHalf,
    required this.maxExchanges,
    required this.wordValue,
  });

  final GamePhase phase;
  final int wordIndex;
  final String cluingTeam;
  final TurnStep step;
  final int exchangeCount;
  final int scoreA;
  final int scoreB;
  final String? pendingClue;
  final WordOutcome lastOutcome;
  final String hostLine;
  final int wordsPerHalf;
  final int maxExchanges;
  final int wordValue;

  static GamePhase _phase(String? v) => switch (v) {
        'halftime' => GamePhase.halftime,
        'second_half' => GamePhase.secondHalf,
        'game_over' => GamePhase.gameOver,
        _ => GamePhase.firstHalf,
      };

  static TurnStep _step(String? v) => switch (v) {
        'awaiting_guess' => TurnStep.awaitingGuess,
        'resolved' => TurnStep.resolved,
        _ => TurnStep.awaitingClue,
      };

  static WordOutcome _outcome(String? v) => switch (v) {
        'guessed' => WordOutcome.guessed,
        'revealed' => WordOutcome.revealed,
        _ => WordOutcome.none,
      };

  factory GameStateRow.fromMap(Map<String, dynamic> m) => GameStateRow(
        phase: _phase(m['phase'] as String?),
        wordIndex: (m['word_index'] as num?)?.toInt() ?? 0,
        cluingTeam: (m['cluing_team'] as String?) ?? 'A',
        step: _step(m['step'] as String?),
        exchangeCount: (m['exchange_count'] as num?)?.toInt() ?? 0,
        scoreA: (m['score_a'] as num?)?.toInt() ?? 0,
        scoreB: (m['score_b'] as num?)?.toInt() ?? 0,
        pendingClue: m['pending_clue'] as String?,
        lastOutcome: _outcome(m['last_outcome'] as String?),
        hostLine: (m['host_line'] as String?) ?? '',
        wordsPerHalf: (m['words_per_half'] as num?)?.toInt() ?? 4,
        maxExchanges: (m['max_exchanges'] as num?)?.toInt() ?? 5,
        wordValue: (m['word_value'] as num?)?.toInt() ?? 5,
      );
}

/// Maps a `game_plays` row to the engine's [PlayEntry].
PlayEntry playEntryFromMap(Map<String, dynamic> m) => PlayEntry(
      kind: (m['kind'] as String?) == 'guess' ? PlayKind.guess : PlayKind.clue,
      team: (m['team'] as String?) ?? 'A',
      role: (m['role'] as String?) ?? 'A1',
      playerName: (m['player_name'] as String?) ?? '',
      text: (m['text'] as String?) ?? '',
      wordIndex: (m['word_index'] as num?)?.toInt() ?? 0,
      correct: m['correct'] as bool?,
    );

/// Server-authoritative gameplay operations for Milestone 5.
///
/// Every mutation calls a `SECURITY DEFINER` Postgres function (see
/// `supabase/migrations/0007_gameplay.sql`); the client never writes to the
/// gameplay tables directly. Reads use RLS-scoped selects and Supabase Realtime
/// streams so the match stays in sync across devices.
class GameplayService {
  GameplayService(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const LobbyFailure('Something went wrong. Please try again.');
  }

  Future<Map<String, dynamic>> _callOk(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      final res = _asMap(await _client.rpc(fn, params: params));
      if (res['ok'] == true) return res;
      throw LobbyFailure.fromReason(res['reason'] as String?);
    } on PostgrestException catch (e) {
      throw LobbyFailure('Something went wrong. Please try again.', code: e.code);
    }
  }

  /// Host: deal the words and create the live match state.
  Future<void> beginPlay(String gameId) =>
      _callOk('mw_begin_play', {'p_game': gameId});

  /// The on-the-clock clue-giver submits a one-word clue.
  Future<void> submitClue(String gameId, String text) =>
      _callOk('mw_submit_clue', {'p_game': gameId, 'p_text': text});

  /// The on-the-clock guesser submits a guess.
  Future<void> submitGuess(String gameId, String text) =>
      _callOk('mw_submit_guess', {'p_game': gameId, 'p_text': text});

  /// Advance off the resolved beat to the next word / halftime / game-over.
  Future<void> nextWord(String gameId) =>
      _callOk('mw_next_word', {'p_game': gameId});

  /// Host: leave halftime and deal the second half with roles switched.
  Future<void> beginSecondHalf(String gameId) =>
      _callOk('mw_begin_second_half', {'p_game': gameId});

  /// Loads the dealt words for a game (members only), ordered by index.
  Future<List<String>> loadWords(String gameId) async {
    final rows = await _client
        .from('game_words')
        .select('word')
        .eq('game_id', gameId)
        .order('word_index');
    return rows.map<String>((r) => (r['word'] as String?) ?? '').toList();
  }

  /// Realtime stream of the authoritative match state.
  Stream<GameStateRow?> watchState(String gameId) {
    return _client
        .from('game_state')
        .stream(primaryKey: ['game_id'])
        .eq('game_id', gameId)
        .map((rows) => rows.isEmpty ? null : GameStateRow.fromMap(rows.first));
  }

  /// Realtime stream of the shared clue/guess feed, oldest first.
  Stream<List<PlayEntry>> watchPlays(String gameId) {
    return _client
        .from('game_plays')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .order('created_at')
        .map((rows) => rows.map(playEntryFromMap).toList());
  }
}
