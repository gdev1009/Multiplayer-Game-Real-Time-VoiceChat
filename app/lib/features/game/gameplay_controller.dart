import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/character.dart';
import '../../models/game.dart';
import '../../models/game_player.dart';
import '../../services/gameplay_service.dart';
import 'ai_player.dart';
import 'game_engine.dart';

/// Drives the live gameplay screen.
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

  /// When true (welcome intro still playing), humans and AI cannot submit.
  bool Function()? inputBlocked;

  /// True when the local human may type a clue/guess (intro finished + on clock).
  bool get isMyTurn {
    if (inputBlocked?.call() ?? false) return false;
    if (isLocal) return true;
    final role = onClockRole;
    return role != null && role == _myRole;
  }
  String? get error => _error;

  StreamSubscription<GameStateRow?>? _stateSub;
  StreamSubscription<List<PlayEntry>>? _playsSub;

  // Server roster / identity, captured when the online match starts.
  Map<String, bool> _aiByRole = const {}; // role -> is this seat a computer?
  String? _myRole; // the local human's seat role (A1/A2/B1/B2), or null.

  // Other seated humans (not me, not computers), for the post-game "Add friend"
  // offer. Empty in a solo/AI-only game.
  List<({String profileId, String name})> _humanCoPlayers = const [];

  /// The other human players in this match — used by the end-of-game screen to
  /// let the player add them as friends.
  List<({String profileId, String name})> get humanCoPlayers => _humanCoPlayers;
  List<String> _words = const []; // the dealt secret words, in play order.
  bool _isHost = false;
  Timer? _aiTimer;
  String? _pendingBeat; // the beat a host action is scheduled for (move/advance).

  Map<String, String> _names = const {}; // role -> display name, for polling.
  Timer? _pollTimer; // realtime fallback: re-fetch state on a short interval.
  bool _reloadingWords = false; // guards a single word re-fetch at a time.

  /// The server timestamp of the last state row we applied. A row that is not
  /// strictly newer is dropped, so a late / out-of-order realtime UPDATE can
  /// never revert a fresher score or phase back to an earlier value (which was
  /// making earned points disappear).
  DateTime _lastAppliedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

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
  ///
  /// Pass [aiByRole] + [charactersByRole] to drive computer seats and show
  /// clay looks on the stage for local matches.
  void startLocal({
    required List<String> words,
    required Map<String, String> names,
    MatchConfig config = const MatchConfig(),
    Map<String, Character>? charactersByRole,
    Map<String, bool>? aiByRole,
    String? myRole,
  }) {
    _words = List<String>.of(words);
    _names = Map<String, String>.of(names);
    _charactersByRole = charactersByRole ?? const {};
    _aiByRole = aiByRole ?? const {};
    _myRole = myRole;
    _isHost = true;
    _state = MatchEngine.start(words: words, names: names, config: config);
    notifyListeners();
    _maybeDriveComputer();
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
    // Remember the other *human* seats so the end-of-game screen can offer to
    // add them as friends. Computer seats and myself are skipped.
    final coPlayers = <({String profileId, String name})>[];
    for (final p in players) {
      if (uid != null && p.profileId == uid) {
        _myRole = p.role;
        continue;
      }
      if (!p.isAi && p.profileId != null) {
        coPlayers.add((profileId: p.profileId!, name: p.displayName));
      }
    }
    _humanCoPlayers = coPlayers;

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
      // Need a full deal — a partial list desyncs YOUR WORD from server grading.
      final need = const MatchConfig().totalWords;
      while (words.length < need && tries < 20) {
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
    _names = names;
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
    // Realtime replication is not guaranteed to be enabled on every Supabase
    // project, and even when it is a row can arrive late. Poll the
    // authoritative state on a short interval so every device converges quickly
    // (this is what makes the busts / scores sync promptly across phones).
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) async {
      try {
        final row = await service.loadState(gameId);
        if (row != null) _applyServerState(row, _names);
      } catch (_) {
        // Ignore transient poll failures; the next tick retries.
      }
    });
  }

  /// Rebuilds the local [MatchState] from an authoritative server row so the
  /// two never drift.
  void _applyServerState(
    GameStateRow row,
    Map<String, String> names, {
    List<PlayEntry>? feed,
    bool forceWordsReload = false,
  }) {
    // Drop stale / out-of-order rows: only advance when the server wrote this
    // row at or after the last one we applied. This stops a delayed realtime
    // UPDATE from wiping a freshly earned score back to zero.
    if (row.updatedAt.isBefore(_lastAppliedAt)) return;
    _lastAppliedAt = row.updatedAt;

    final prior = _state;
    final need = prior?.config.totalWords ?? const MatchConfig().totalWords;
    final wordChanged = prior != null && prior.wordIndex != row.wordIndex;
    if (forceWordsReload || wordChanged || _words.length < need) {
      _reloadWords(names);
    }

    final s = prior;
    _state = MatchState(
      config: MatchConfig(
        wordsPerHalf: row.wordsPerHalf,
        maxExchanges: row.maxExchanges,
        wordValue: row.wordValue,
      ),
      words: _words,
      names: names.isNotEmpty ? names : (s?.names ?? const {}),
      phase: row.phase,
      wordIndex: row.wordIndex,
      cluingTeam: row.cluingTeam,
      step: row.step,
      exchangeCount: row.exchangeCount,
      scoreA: row.scoreA,
      scoreB: row.scoreB,
      pendingClue: row.pendingClue,
      feed: feed ?? s?.feed ?? const [],
      lastOutcome: row.lastOutcome,
      hostLine: row.hostLine,
    );
    notifyListeners();
    _maybeDriveComputer();
  }

  /// Patches one secret into the local cache + live state (server truth).
  void _patchSecret(int wordIndex, String word) {
    final trimmed = word.trim();
    if (trimmed.isEmpty || wordIndex < 0) return;
    if (wordIndex >= _words.length) {
      _words = [
        ..._words,
        ...List.filled(wordIndex - _words.length + 1, ''),
      ];
    } else {
      _words = List<String>.of(_words);
    }
    _words[wordIndex] = trimmed;
    final cur = _state;
    if (cur == null) return;
    _state = MatchState(
      config: cur.config,
      words: List.unmodifiable(_words),
      names: cur.names,
      phase: cur.phase,
      wordIndex: cur.wordIndex,
      cluingTeam: cur.cluingTeam,
      step: cur.step,
      exchangeCount: cur.exchangeCount,
      scoreA: cur.scoreA,
      scoreB: cur.scoreB,
      pendingClue: cur.pendingClue,
      feed: cur.feed,
      lastOutcome: cur.lastOutcome,
      hostLine: cur.hostLine,
    );
  }

  /// Background one-shot re-fetch of the dealt words when the local cache is
  /// empty, so the host can drive computer guesses and scoring can match.
  Future<void> _reloadWords(Map<String, String> names) async {
    if (_reloadingWords) return;
    final service = _service;
    final gameId = _gameId;
    if (service == null || gameId == null) return;
    _reloadingWords = true;
    try {
      final words = await service.loadWords(gameId);
      final need = _state?.config.totalWords ?? const MatchConfig().totalWords;
      if (words.length >= need) {
        _words = words;
        final row = await service.loadState(gameId);
        if (row != null) {
          _lastAppliedAt =
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          _applyServerState(row, names);
        }
      }
    } catch (_) {
      // Ignore; the periodic poll will try again.
    } finally {
      _reloadingWords = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Host-driven flow: play computer seats + keep the match moving
  // ---------------------------------------------------------------------------

  /// The host device keeps the whole match flowing so a table that includes
  /// computer players actually plays through and scores accrue:
  ///  * it plays any computer-filled seat that is on the clock (a gentle clue
  ///    for a filled clue-giver, the answer for a filled guesser),
  ///  * it advances the short "resolved" celebration beat to the next word, and
  ///  * it leaves halftime for the second half after a calm pause.
  ///
  /// Only the host runs this; every other device just renders the authoritative
  /// result. Each action is scheduled per game "beat" and is *retried* if that
  /// beat recurs (e.g. the authoritative state reverted after a dropped
  /// request), so the game can never get permanently stuck waiting on a
  /// computer seat — the bug that left matches frozen at 0 – 0.
  void _maybeDriveComputer() {
    // Online: only the host drives. Local demos: drive whenever AI seats are set.
    if (!isLocal && !_isHost) return;
    if (isLocal && _aiByRole.isEmpty) return;
    final s = _state;
    if (s == null) {
      _aiTimer?.cancel();
      _pendingBeat = null;
      return;
    }

    // Hold all AI / timeout beats until Guy finishes the long welcome intro.
    if (inputBlocked?.call() ?? false) {
      _scheduleHostBeat(
        'introWait|${s.wordIndex}|${s.exchangeCount}',
        const Duration(milliseconds: 400),
        _maybeDriveComputer,
      );
      return;
    }

    // Leave halftime for the second half after a pause to read the switch.
    if (s.phase == GamePhase.halftime) {
      _scheduleHostBeat(
        'half|${s.wordIndex}',
        const Duration(milliseconds: 6500),
        beginSecondHalf,
      );
      return;
    }

    // Advance the resolved beat after Guy finishes the outcome GIF + voice.
    if (s.step == TurnStep.resolved &&
        (s.phase == GamePhase.firstHalf || s.phase == GamePhase.secondHalf)) {
      final hold = s.lastOutcome == WordOutcome.guessed
          ? const Duration(milliseconds: 7500)
          : const Duration(milliseconds: 8000);
      _scheduleHostBeat(
        'next|${s.wordIndex}|${s.lastOutcome}',
        hold,
        nextWord,
      );
      return;
    }

    // Otherwise there's nothing to drive unless a turn is active.
    if (!s.isTurnActive) {
      _aiTimer?.cancel();
      _pendingBeat = null;
      return;
    }

    final role = onClockRole;
    if (role == null || !(_aiByRole[role] ?? false)) {
      // Human on the clock — Ronna: 15–20s to guess before the buzzer.
      if (s.step == TurnStep.awaitingGuess && (isLocal || _isHost)) {
        _scheduleHostBeat(
          'guessTimeout|${s.wordIndex}|${s.exchangeCount}|${s.cluingTeam}',
          Duration(seconds: s.config.guessSeconds),
          () {
            unawaited(timeoutGuess());
          },
        );
      } else {
        _aiTimer?.cancel();
        _pendingBeat = null;
      }
      return;
    }

    // A computer seat is on the clock — play it after a short, natural pause.
    // If the secret word hasn't arrived yet, wait (and kick a reload); empty
    // guesses would never score and burn exchanges down to a 0-point reveal.
    if (s.secretWord.trim().isEmpty ||
        _words.length < s.config.totalWords) {
      _aiTimer?.cancel();
      _pendingBeat = null;
      _reloadWords(_names);
      // Retry this beat shortly once words arrive.
      _scheduleHostBeat(
        'reload|${s.wordIndex}|${s.step}',
        const Duration(milliseconds: 900),
        _maybeDriveComputer,
      );
      return;
    }

    // Give Guy time to finish the previous line before the next AI beat.
    final aiDelay = s.lastOutcome == WordOutcome.wrong
        ? const Duration(milliseconds: 5200)
        : const Duration(milliseconds: 3200);
    _scheduleHostBeat(
      'ai|${s.wordIndex}|${s.step}|${s.cluingTeam}|${s.exchangeCount}',
      aiDelay,
      () {
        if (inputBlocked?.call() ?? false) {
          _maybeDriveComputer();
          return;
        }
        _driveComputerSeat();
      },
    );
  }

  Future<void> _driveComputerSeat() async {
    if (inputBlocked?.call() ?? false) {
      _maybeDriveComputer();
      return;
    }
    final cur = _state;
    if (cur == null || !cur.isTurnActive) return;
    final curRole = onClockRole;
    if (curRole == null || !(_aiByRole[curRole] ?? false)) return;
    // Always pull the server secret before AI acts — never trust a stale cache.
    final secret = await _serverSecretFor(cur.wordIndex) ?? cur.secretWord.trim();
    if (secret.isEmpty) {
      _reloadWords(_names);
      return;
    }
    _patchSecret(cur.wordIndex, secret);
    notifyListeners();
    final latest = _state;
    if (latest == null || !latest.isTurnActive) return;
    if (latest.step == TurnStep.awaitingClue) {
      await submitClue(AiPlayer.clueFor(secret, variant: latest.wordIndex));
    } else if (latest.step == TurnStep.awaitingGuess) {
      await submitGuess(
        AiPlayer.guessFor(
          secret,
          seed: latest.wordIndex * 31 + latest.exchangeCount,
        ),
      );
    }
  }

  /// Server-authoritative secret for [wordIndex], or null if unavailable.
  Future<String?> _serverSecretFor(int wordIndex) async {
    final service = _service;
    final gameId = _gameId;
    if (service == null || gameId == null) return null;
    try {
      final at = await service.loadWordAt(gameId, wordIndex);
      if (at != null && at.isNotEmpty) return at;
      // Clue-giver / host path.
      final peeked = await service.peekSecret(gameId);
      return peeked;
    } catch (_) {
      return null;
    }
  }

  /// Reloads dealt words when the local cache is incomplete or the current
  /// secret is empty, then patches [MatchState.words] so grading matches the
  /// server.
  Future<void> _ensureWordsFresh() async {
    final s = _state;
    if (s == null) return;
    final service = _service;
    final gameId = _gameId;
    if (service == null || gameId == null) return;
    try {
      final fresh = await service.loadWordAt(gameId, s.wordIndex);
      if (fresh != null && fresh.isNotEmpty) {
        _patchSecret(s.wordIndex, fresh);
        notifyListeners();
      }
      final words = await service.loadWords(gameId);
      final need = s.config.totalWords;
      if (words.length >= need) {
        _words = words;
        final cur = _state;
        if (cur != null) {
          _state = MatchState(
            config: cur.config,
            words: List.unmodifiable(_words),
            names: cur.names,
            phase: cur.phase,
            wordIndex: cur.wordIndex,
            cluingTeam: cur.cluingTeam,
            step: cur.step,
            exchangeCount: cur.exchangeCount,
            scoreA: cur.scoreA,
            scoreB: cur.scoreB,
            pendingClue: cur.pendingClue,
            feed: cur.feed,
            lastOutcome: cur.lastOutcome,
            hostLine: cur.hostLine,
          );
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Schedules a single host-driven [action] for a game [beat]. While that beat
  /// is still pending (its timer is live) we don't double-schedule; once the
  /// timer fires the guard clears, so a beat that recurs — because the
  /// authoritative state reverted after a failed/late request — is retried
  /// rather than stalling the match.
  void _scheduleHostBeat(String beat, Duration delay, VoidCallback action) {
    if (beat == _pendingBeat && (_aiTimer?.isActive ?? false)) return;
    _pendingBeat = beat;
    _aiTimer?.cancel();
    _aiTimer = Timer(delay, () {
      _pendingBeat = null;
      action();
    });
  }

  // ---------------------------------------------------------------------------
  // Player actions
  // ---------------------------------------------------------------------------

  Future<void> submitClue(String text) async {
    if (inputBlocked?.call() ?? false) return;
    return _act(
      local: (s) => MatchEngine.submitClue(s, text),
      remote: (svc, id) => svc.submitClue(id, text),
    );
  }

  /// Guess clock expired — buzzer path (wrong / steal / reveal).
  Future<void> timeoutGuess() async {
    final s = _state;
    if (s == null || s.step != TurnStep.awaitingGuess) return;
    if (isLocal) {
      return _act(
        local: MatchEngine.timeoutGuess,
        remote: (_, __) async {},
      );
    }
    // Online: only the host advances the clock; submit a miss token.
    if (!_isHost) return;
    await submitGuess('TIME');
  }

  Future<void> submitGuess(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (isLocal) {
      return _act(
        local: (cur) => MatchEngine.submitGuess(cur, trimmed),
        remote: (svc, id) async {
          await svc.submitGuess(id, trimmed);
        },
      );
    }

    // Online: never optimistically grade against a possibly-stale client
    // cache. Sync the server secret, call the RPC, then take state + feed from
    // the server so a correct guess resolves immediately (no more guesses).
    final s = _state;
    if (s == null || s.step != TurnStep.awaitingGuess) return;

    await _ensureWordsFresh();
    final secret = await _serverSecretFor(s.wordIndex);
    if (secret != null && secret.isNotEmpty) {
      _patchSecret(s.wordIndex, secret);
    }

    final previous = _state!;
    // Provisional bubble (no ✓/✗) until the server grades.
    final pending = PlayEntry(
      kind: PlayKind.guess,
      team: previous.cluingTeam,
      role: previous.guesserRole,
      playerName: previous.guesserName,
      text: trimmed,
      wordIndex: previous.wordIndex,
    );
    _state = previous.copyWith(feed: [...previous.feed, pending]);
    notifyListeners();

    final service = _service!;
    final gameId = _gameId!;
    final ok = await _guard(() async {
      final res = await service.submitGuess(gameId, trimmed);
      final gradedWord = (res['word'] as String?)?.trim();
      final idx = (res['word_index'] as num?)?.toInt() ?? previous.wordIndex;
      if (gradedWord != null && gradedWord.isNotEmpty) {
        _patchSecret(idx, gradedWord);
      }
      final row = await service.loadState(gameId);
      final plays = await service.loadPlays(gameId);
      if (row != null) {
        // Allow this fresh row even if timestamps are equal.
        _lastAppliedAt =
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        _applyServerState(row, previous.names, feed: plays);
      }
    });
    if (!ok) {
      try {
        final row = await service.loadState(gameId);
        final plays = await service.loadPlays(gameId);
        if (row != null) {
          _lastAppliedAt =
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          _applyServerState(row, previous.names, feed: plays);
        } else {
          _state = previous;
          notifyListeners();
        }
      } catch (_) {
        _state = previous;
        notifyListeners();
      }
    }
    _maybeDriveComputer();
  }

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
      // Local AI seats only advance when we drive them after each action.
      _maybeDriveComputer();
      return;
    }

    // Optimistic local update so the UI responds instantly, then confirm with
    // the server. Roll back if the RPC fails so a wrong local score never sticks.
    final previous = s;
    _state = local(s);
    notifyListeners();
    // A local action may hand the clock to a computer seat — drive it.
    _maybeDriveComputer();
    final service = _service!;
    final gameId = _gameId!;
    final ok = await _guard(() async {
      await remote(service, gameId);
      final row = await service.loadState(gameId);
      if (row != null) _applyServerState(row, _state?.names ?? const {});
    });
    if (!ok) {
      // Prefer a fresh server row; otherwise restore the pre-action snapshot.
      try {
        final row = await service.loadState(gameId);
        if (row != null) {
          _applyServerState(row, previous.names);
        } else {
          _state = previous;
          notifyListeners();
        }
      } catch (_) {
        _state = previous;
        notifyListeners();
      }
      _maybeDriveComputer();
    }
  }

  // ---------------------------------------------------------------------------
  // Plumbing
  // ---------------------------------------------------------------------------

  /// Runs [run]; returns false when it throws (and sets [_error]).
  Future<bool> _guard(Future<void> Function() run) async {
    _error = null;
    _busy = true;
    notifyListeners();
    try {
      await run();
      return true;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      return false;
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
