import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/game.dart';
import '../../models/game_player.dart';
import '../../services/gameplay_service.dart';
import 'game_engine.dart';

/// Drives the live gameplay screen (Milestone 5).
///
/// The controller keeps the authoritative [MatchState] and exposes the four
/// player actions — give a clue, make a guess, move to the next word, and start
/// the second half. It runs the pure [MatchEngine] locally for instant feedback
/// and, when a [GameplayService] is supplied, mirrors each action to the server
/// and reconciles against the realtime `game_state` / `game_plays` streams so
/// every device stays in sync.
///
/// With no service (AI-only / demo) it is fully self-contained and offline.
class GameplayController extends ChangeNotifier {
  GameplayController({
    GameplayService? service,
    Game? game,
  })  : _service = service,
        _gameId = game?.id;

  final GameplayService? _service;
  final String? _gameId;

  MatchState? _state;
  MatchState? get state => _state;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  StreamSubscription<GameStateRow?>? _stateSub;
  StreamSubscription<List<PlayEntry>>? _playsSub;

  /// Whether we run purely locally (no backend wired).
  bool get isLocal => _service == null || _gameId == null;

  // ---------------------------------------------------------------------------
  // Start
  // ---------------------------------------------------------------------------

  /// Begins a local match from the given words + roster (AI-only / demo).
  void startLocal({
    required List<String> words,
    required Map<String, String> names,
    MatchConfig config = const MatchConfig(),
  }) {
    _state = MatchEngine.start(words: words, names: names, config: config);
    notifyListeners();
  }

  /// Begins a server-backed match: asks the host RPC to deal words, loads the
  /// roster's role→name map, and subscribes to the realtime streams.
  Future<void> startOnline({required List<GamePlayer> players}) async {
    final service = _service;
    final gameId = _gameId;
    if (service == null || gameId == null) return;

    await _guard(() async {
      await service.beginPlay(gameId);
      final words = await service.loadWords(gameId);
      final names = {for (final p in players) p.role: p.displayName};
      // Seed a local state so the UI renders instantly; the stream will refine.
      _state ??= MatchEngine.start(words: words, names: names);
      _subscribe(service, gameId, names, words);
    });
  }

  void _subscribe(
    GameplayService service,
    String gameId,
    Map<String, String> names,
    List<String> words,
  ) {
    _stateSub?.cancel();
    _playsSub?.cancel();
    _stateSub = service.watchState(gameId).listen(
      (row) {
        if (row != null) _applyServerState(row, names, words);
      },
      onError: (Object _) {},
    );
    _playsSub = service.watchPlays(gameId).listen(
      (feed) {
        final s = _state;
        if (s != null) {
          _state = s.copyWith(feed: feed);
          notifyListeners();
        }
      },
      onError: (Object _) {},
    );
  }

  /// Rebuilds the local [MatchState] from an authoritative server row so the
  /// two never drift.
  void _applyServerState(
    GameStateRow row,
    Map<String, String> names,
    List<String> words,
  ) {
    final s = _state;
    _state = MatchState(
      config: MatchConfig(
        wordsPerHalf: row.wordsPerHalf,
        maxExchanges: row.maxExchanges,
        wordValue: row.wordValue,
      ),
      words: words,
      names: names,
      phase: row.phase,
      wordIndex: row.wordIndex,
      cluingTeam: row.cluingTeam,
      step: row.step,
      exchangeCount: row.exchangeCount,
      scoreA: row.scoreA,
      scoreB: row.scoreB,
      pendingClue: row.pendingClue,
      feed: s?.feed ?? const [],
      lastOutcome: row.lastOutcome,
      hostLine: row.hostLine,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Player actions
  // ---------------------------------------------------------------------------

  Future<void> submitClue(String text) => _act(
        local: (s) => MatchEngine.submitClue(s, text),
        remote: (svc, id) => svc.submitClue(id, text),
      );

  Future<void> submitGuess(String text) => _act(
        local: (s) => MatchEngine.submitGuess(s, text),
        remote: (svc, id) => svc.submitGuess(id, text),
      );

  Future<void> nextWord() => _act(
        local: MatchEngine.nextWord,
        remote: (svc, id) => svc.nextWord(id),
      );

  Future<void> beginSecondHalf() => _act(
        local: MatchEngine.beginSecondHalf,
        remote: (svc, id) => svc.beginSecondHalf(id),
      );

  /// Applies an action locally (optimistic) and, when online, to the server.
  Future<void> _act({
    required MatchState Function(MatchState) local,
    required Future<void> Function(GameplayService, String) remote,
  }) async {
    final s = _state;
    if (s == null) return;

    if (isLocal) {
      _state = local(s);
      notifyListeners();
      return;
    }

    // Optimistic local update, then confirm with the server (the stream will
    // deliver the authoritative result).
    _state = local(s);
    notifyListeners();
    await _guard(() => remote(_service!, _gameId!));
  }

  // ---------------------------------------------------------------------------
  // Plumbing
  // ---------------------------------------------------------------------------

  Future<void> _guard(Future<void> Function() run) async {
    _error = null;
    _busy = true;
    notifyListeners();
    try {
      await run();
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _playsSub?.cancel();
    super.dispose();
  }
}
