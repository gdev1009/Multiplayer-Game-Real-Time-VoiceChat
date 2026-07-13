import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/character.dart';
import '../../models/game.dart';
import '../../models/game_player.dart';
import '../../services/gameplay_service.dart';
import 'ai_player.dart';
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
        _gameId = game?.id,
        _hostId = game?.hostId;

  final GameplayService? _service;
  final String? _gameId;
  final String? _hostId;

  MatchState? _state;
  MatchState? get state => _state;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  StreamSubscription<GameStateRow?>? _stateSub;
  StreamSubscription<List<PlayEntry>>? _playsSub;
  Timer? _pollTimer;

  /// The server timestamp of the most recently applied state row. Used to
  /// ignore stale realtime rows that would otherwise roll the score/turn back.
  DateTime? _lastAppliedAt;

  // Server roster / identity, captured when the online match starts.
  Map<String, bool> _aiByRole = const {}; // role -> is this seat a computer?
  String? _myRole; // the local human's seat role (A1/A2/B1/B2), or null.
  List<String> _words = const []; // the dealt secret words, in play order.
  bool _isHost = false;
  Timer? _aiTimer;
  String? _lastAiBeat; // guards against driving the same beat twice.

  // role (A1/A2/B1/B2) -> the character to show on that podium.
  Map<String, Character> _charactersByRole = const {};

  /// The character to show for each seat role on the live stage. Humans use
  /// their saved character; computer seats get a friendly generated look.
  Map<String, Character> get charactersByRole => _charactersByRole;

  /// Whether we run purely locally (no backend wired).
  bool get isLocal => _service == null || _gameId == null;

  /// True on the device that created the game — the one that deals the words
  /// and drives the computer-filled seats.
  bool get isHost => _isHost;

  /// The local human's seat role (A1/A2/B1/B2), or null if they are only
  /// spectating / driving computer seats.
  String? get myRole => _myRole;

  /// The role that is on the clock right now (clue-giver or guesser), or null
  /// when there is nothing to act on (resolved / halftime / game over).
  String? get onClockRole {
    final s = _state;
    if (s == null || !s.isTurnActive) return null;
    return s.step == TurnStep.awaitingClue ? s.clueGiverRole : s.guesserRole;
  }

  /// The display name of whoever is on the clock, for a friendly wait message.
  String get onClockName {
    final s = _state;
    if (s == null) return '';
    return s.step == TurnStep.awaitingClue ? s.clueGiverName : s.guesserName;
  }

  /// True when it is the local human's turn to act (drives the input area).
  /// In a local/demo game (no roster) the single device always acts.
  bool get isMyTurn {
    if (isLocal) return true;
    final role = onClockRole;
    return role != null && role == _myRole;
  }

  /// True when the on-the-clock seat is a computer the host is driving, so the
  /// other devices can show "waiting" instead of an input they can't use.
  bool get waitingOnComputer {
    final role = onClockRole;
    return role != null && (_aiByRole[role] ?? false);
  }

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

  /// Begins a server-backed match: the host RPC deals the words, everyone loads
  /// the roster's role→name map and the dealt words, then subscribes to the
  /// realtime streams. Non-host devices never call the host-only deal RPC, so a
  /// joiner is no longer knocked out with a "not host" error (which previously
  /// left them stuck on the loading spinner).
  Future<void> startOnline({required List<GamePlayer> players}) async {
    final service = _service;
    final gameId = _gameId;
    if (service == null || gameId == null) return;

    // Capture identity + roster up front.
    final uid = service.currentUserId;
    _isHost = _hostId != null && _hostId == uid;
    _aiByRole = {for (final p in players) p.role: p.isAi};
    final names = {for (final p in players) p.role: p.displayName};
    _myRole = null;
    if (uid != null) {
      for (final p in players) {
        if (p.profileId == uid) {
          _myRole = p.role;
          break;
        }
      }
    }

    // Seed each podium with a look right away: computer seats get a generated
    // character; humans get a placeholder until their saved character loads.
    final looks = <String, Character>{};
    for (final p in players) {
      if (p.isAi || p.profileId == null) {
        looks[p.role] = AiPlayer.lookFor('${p.role}:${p.displayName}', p.displayName);
      }
    }
    _charactersByRole = looks;

    await _guard(() async {
      // Only the host deals the words; everyone else just waits for them to
      // appear (the host may still be dealing when a joiner arrives).
      if (_isHost) {
        await service.beginPlay(gameId);
      }
      var words = await service.loadWords(gameId);
      var tries = 0;
      while (words.isEmpty && tries < 20) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        words = await service.loadWords(gameId);
        tries++;
      }
      _words = words;
      // Pull every seated human's saved character so their real look shows on
      // the stage (computer seats keep their generated look).
      final humans = await service.loadCharacters(gameId);
      _charactersByRole = {..._charactersByRole, ...humans};
      // Seed a local state so the UI renders instantly; the realtime stream
      // refines it. Only seed from MatchEngine.start when a full deal is
      // present (it requires a full set of words); otherwise wait for the
      // authoritative row, which tolerates a partial/late deal.
      if (_state == null && words.length >= const MatchConfig().totalWords) {
        _state = MatchEngine.start(words: words, names: names);
      }
      _subscribe(service, gameId, names);
      // The host may already be on the clock for a computer seat (e.g. word 1
      // opens with an AI guesser): kick off auto-play from the seeded state.
      _maybeDriveComputer();
    });
  }

  void _subscribe(
    GameplayService service,
    String gameId,
    Map<String, String> names,
  ) {
    _stateSub?.cancel();
    _playsSub?.cancel();
    _pollTimer?.cancel();
    _stateSub = service.watchState(gameId).listen(
      (row) {
        if (row != null) _applyServerState(row, names);
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
    // Realtime replication can be delayed or disabled on a project, which left
    // the score/turn/host line stale on the devices that weren't acting. Poll
    // the authoritative state + feed on a gentle cadence as a fallback so every
    // device catches up within about a second even without realtime.
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) async {
      try {
        final row = await service.loadState(gameId);
        if (row != null) _applyServerState(row, names);
        final feed = await service.loadPlays(gameId);
        final s = _state;
        if (s != null && feed.length != s.feed.length) {
          _state = s.copyWith(feed: feed);
          notifyListeners();
        }
      } catch (_) {
        // Ignore transient poll errors; the next tick retries.
      }
    });
  }

  /// Rebuilds the local [MatchState] from an authoritative server row so the
  /// two never drift. Stale rows (older than the last one applied) are ignored
  /// so out-of-order realtime/poll deliveries can't roll the match backwards.
  void _applyServerState(
    GameStateRow row,
    Map<String, String> names,
  ) {
    final last = _lastAppliedAt;
    if (last != null && row.updatedAt.isBefore(last)) return;
    _lastAppliedAt = row.updatedAt;
    final s = _state;
    _state = MatchState(
      config: MatchConfig(
        wordsPerHalf: row.wordsPerHalf,
        maxExchanges: row.maxExchanges,
        wordValue: row.wordValue,
      ),
      words: _words,
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
    _maybeDriveComputer();
  }

  // ---------------------------------------------------------------------------
  // Computer-filled seats (host-driven)
  // ---------------------------------------------------------------------------

  /// When the on-the-clock seat is a computer, the host device plays it after a
  /// short, natural pause so the studio players take their turns automatically
  /// instead of stalling the game. Only the host runs this; every other device
  /// just watches the realtime result.
  void _maybeDriveComputer() {
    if (isLocal || !_isHost) return;
    final s = _state;
    if (s == null || !s.isTurnActive) {
      _aiTimer?.cancel();
      return;
    }

    final role = onClockRole;
    if (role == null || !(_aiByRole[role] ?? false)) {
      // A human is on the clock — nothing for the computer to do.
      return;
    }

    // Only schedule once per distinct beat (word + step + team + exchanges).
    final beat = '${s.wordIndex}|${s.step}|${s.cluingTeam}|${s.exchangeCount}';
    if (beat == _lastAiBeat) return;
    _lastAiBeat = beat;

    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 1600), () {
      final cur = _state;
      if (cur == null || !cur.isTurnActive) return;
      final curRole = onClockRole;
      if (curRole == null || !(_aiByRole[curRole] ?? false)) return;
      if (cur.step == TurnStep.awaitingClue) {
        submitClue(AiPlayer.clueFor(cur.secretWord));
      } else {
        submitGuess(AiPlayer.guessFor(cur.secretWord));
      }
    });
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

    // Optimistic local update so the UI responds instantly, then confirm with
    // the server. We re-fetch the authoritative state right after (rather than
    // relying solely on the realtime stream) so the score/phase always lands
    // even when realtime replication lags or isn't delivering row updates.
    _state = local(s);
    notifyListeners();
    // A local action may hand the clock to a computer seat — drive it.
    _maybeDriveComputer();
    final service = _service!;
    final gameId = _gameId!;
    await _guard(() async {
      await remote(service, gameId);
      final row = await service.loadState(gameId);
      if (row != null) _applyServerState(row, _state?.names ?? const {});
    });
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
    _aiTimer?.cancel();
    _pollTimer?.cancel();
    _stateSub?.cancel();
    _playsSub?.cancel();
    super.dispose();
  }
}
