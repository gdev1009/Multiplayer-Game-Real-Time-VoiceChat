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

  // Server roster / identity, captured when the online match starts.
  Map<String, bool> _aiByRole = const {}; // role -> is this seat a computer?
  String? _myRole; // the local human's seat role (A1/A2/B1/B2), or null.

  // Other seated humans (not me, not computers), for the post-game "Add friend"
  // offer (Milestone 7). Empty in a solo/AI-only game.
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
    // Remember the other *human* seats so the end-of-game screen can offer to
    // add them as friends (Milestone 7). Computer seats and myself are skipped.
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
    Map<String, String> names,
  ) {
    // Drop stale / out-of-order rows: only advance when the server wrote this
    // row at or after the last one we applied. This stops a delayed realtime
    // UPDATE from wiping a freshly earned score back to zero.
    if (row.updatedAt.isBefore(_lastAppliedAt)) return;
    _lastAppliedAt = row.updatedAt;

    // If we somehow started without the dealt words, the secret word would be
    // empty and no guess could ever match. Re-fetch them once in the
    // background so scoring works.
    if (_words.isEmpty) _reloadWords(names);

    final s = _state;
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
      feed: s?.feed ?? const [],
      lastOutcome: row.lastOutcome,
      hostLine: row.hostLine,
    );
    notifyListeners();
    _maybeDriveComputer();
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
      if (words.isNotEmpty) {
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
    if (isLocal || !_isHost) return;
    final s = _state;
    if (s == null) {
      _aiTimer?.cancel();
      _pendingBeat = null;
      return;
    }

    // Leave halftime for the second half after a pause to read the switch.
    if (s.phase == GamePhase.halftime) {
      _scheduleHostBeat(
        'half|${s.wordIndex}',
        const Duration(milliseconds: 4500),
        beginSecondHalf,
      );
      return;
    }

    // Advance the resolved beat (word guessed or revealed) to the next word.
    if (s.step == TurnStep.resolved &&
        (s.phase == GamePhase.firstHalf || s.phase == GamePhase.secondHalf)) {
      _scheduleHostBeat(
        'next|${s.wordIndex}|${s.lastOutcome}',
        const Duration(milliseconds: 3000),
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
      // A human is on the clock — wait for them (cancel any stale AI timer).
      _aiTimer?.cancel();
      _pendingBeat = null;
      return;
    }

    // A computer seat is on the clock — play it after a short, natural pause.
    // If the secret word hasn't arrived yet, wait (and kick a reload); empty
    // guesses would never score and burn exchanges down to a 0-point reveal.
    if (s.secretWord.trim().isEmpty) {
      _aiTimer?.cancel();
      _pendingBeat = null;
      if (_words.isEmpty) _reloadWords(_names);
      return;
    }

    _scheduleHostBeat(
      'ai|${s.wordIndex}|${s.step}|${s.cluingTeam}|${s.exchangeCount}',
      const Duration(milliseconds: 1600),
      () {
        final cur = _state;
        if (cur == null || !cur.isTurnActive) return;
        final curRole = onClockRole;
        if (curRole == null || !(_aiByRole[curRole] ?? false)) return;
        final secret = cur.secretWord.trim();
        if (secret.isEmpty) return;
        if (cur.step == TurnStep.awaitingClue) {
          // Vary the clue by word so repeat games don't feel scripted.
          submitClue(AiPlayer.clueFor(secret, variant: cur.wordIndex));
        } else {
          // Seed the guess by word + exchange so a studio player's occasional
          // miss is stable for this turn but differs across turns.
          submitGuess(
            AiPlayer.guessFor(
              secret,
              seed: cur.wordIndex * 31 + cur.exchangeCount,
            ),
          );
        }
      },
    );
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
