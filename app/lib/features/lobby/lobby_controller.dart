import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/game.dart';
import '../../models/game_player.dart';
import '../../models/game_preview.dart';
import '../../services/lobby_failure.dart';
import '../../services/lobby_service.dart';

/// Drives the lobby feature: creating/joining games, listing open games, and
/// keeping the current room in sync via Supabase Realtime.
class LobbyController extends ChangeNotifier {
  LobbyController(this._service);

  final LobbyService _service;

  /// How long a quick-matched game waits for real players to join before the
  /// studio (AI) players fill the empty seats. This is the adjustable "dial" —
  /// raise it to give real matches more of a chance, lower it to start sooner.
  /// Set to [Duration.zero] to fill immediately (no wait).
  static Duration quickMatchFillDelay = const Duration(seconds: 90);

  // ---- Current room ---------------------------------------------------------
  Game? _game;
  Game? get game => _game;

  List<GamePlayer> _players = const [];
  List<GamePlayer> get players => _players;

  StreamSubscription<List<GamePlayer>>? _playersSub;
  StreamSubscription<Game?>? _gameSub;

  // ---- Open games list ------------------------------------------------------
  List<Game> _openGames = const [];
  List<Game> get openGames => _openGames;

  // ---- Transient UI state ---------------------------------------------------
  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  // ---- Quick-match "looking for players" wait -------------------------------
  Timer? _fillTimer;
  bool _awaitingFill = false;
  int _fillSecondsLeft = 0;

  /// Whether a quick-matched room is currently holding a seat open for real
  /// players before the studio players fill in.
  bool get awaitingFill => _awaitingFill;

  /// Seconds remaining before the studio players fill the empty seats.
  int get fillSecondsLeft => _fillSecondsLeft;

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  bool get isHost {
    final game = _game;
    return game != null && _service.isHostOf(game);
  }

  bool get isFull =>
      _game != null && _players.length >= _game!.maxPlayers;

  bool get canStart => isHost && _players.length >= 2 && _game?.isOpen == true;

  /// Runs a lobby action, funnelling [LobbyFailure] into [error] and returning
  /// whether it succeeded.
  Future<bool> _run(Future<void> Function() action) async {
    _error = null;
    _setBusy(true);
    try {
      await action();
      return true;
    } on LobbyFailure catch (f) {
      _error = f.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  // ---- Open games list ------------------------------------------------------
  Future<void> refreshOpenGames() async {
    await _run(() async {
      _openGames = await _service.listOpenGames();
    });
  }

  // ---- Enter a room ---------------------------------------------------------
  Future<bool> createGame({bool isPublic = false}) =>
      _enter(() => _service.createGame(isPublic: isPublic));

  Future<bool> joinByCode(String code) =>
      _enter(() => _service.joinByCode(code));

  /// Joins [code] into a specific [seat] the player picked in the preview, so
  /// they can choose their own team.
  Future<bool> joinSeat(String code, int seat) =>
      _enter(() => _service.joinSeat(code, seat));

  /// Fetches the roster for a code without joining, so the UI can show a
  /// preview + confirm step. Returns null (and sets [error]) on failure.
  Future<GamePreview?> peekByCode(String code) async {
    GamePreview? preview;
    final ok = await _run(() async {
      preview = await _service.peekByCode(code);
    });
    return ok ? preview : null;
  }

  /// Quick-matches into a game, then holds the empty seats open for
  /// [quickMatchFillDelay] so real players can join before the studio players
  /// fill in. If the room is already full (e.g. matched a busy lobby), no wait.
  Future<bool> quickMatch() async {
    final ok = await _enter(() => _service.quickMatch());
    if (ok && !isFull) _startFillCountdown();
    return ok;
  }

  Future<bool> _enter(Future<Game> Function() action) {
    _cancelFillCountdown();
    return _run(() async {
      final game = await action();
      _game = game;
      _players = await _service.loadPlayers(game.id);
      _subscribe(game.id);
    });
  }

  // ---- Quick-match auto-fill countdown --------------------------------------
  /// Starts the "looking for players" countdown. When it elapses, the studio
  /// players fill any seats still empty. Cancelled early if real players fill
  /// the room first, or the player leaves.
  void _startFillCountdown() {
    _cancelFillCountdown();
    final seconds = quickMatchFillDelay.inSeconds;
    if (seconds <= 0) {
      // No wait configured: fill right away.
      unawaited(fillSeats());
      return;
    }
    _awaitingFill = true;
    _fillSecondsLeft = seconds;
    notifyListeners();
    _fillTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fillSecondsLeft -= 1;
      if (_fillSecondsLeft <= 0 || isFull) {
        _cancelFillCountdown();
        if (!isFull) unawaited(fillSeats());
      } else {
        notifyListeners();
      }
    });
  }

  void _cancelFillCountdown() {
    _fillTimer?.cancel();
    _fillTimer = null;
    if (_awaitingFill) {
      _awaitingFill = false;
      _fillSecondsLeft = 0;
      notifyListeners();
    }
  }

  void _subscribe(String gameId) {
    _playersSub?.cancel();
    _gameSub?.cancel();
    // Realtime is a live convenience, not a requirement: the room already has
    // its seats from loadPlayers(). If a stream errors (e.g. a transient
    // connection drop) we keep the last-known state instead of crashing.
    _playersSub = _service.watchPlayers(gameId).listen(
      (rows) {
        _players = rows;
        // If real players filled the room during the wait, stop the countdown
        // so the studio players don't bump anyone.
        if (_awaitingFill && isFull) _cancelFillCountdown();
        notifyListeners();
      },
      onError: (Object _) {},
    );
    _gameSub = _service.watchGame(gameId).listen(
      (game) {
        if (game != null) _game = game;
        notifyListeners();
      },
      onError: (Object _) {},
    );
  }

  // ---- Host / room actions --------------------------------------------------
  Future<bool> fillSeats() async {
    final game = _game;
    if (game == null) return false;
    return _run(() => _service.fillSeats(game.id));
  }

  Future<bool> startGame() async {
    final game = _game;
    if (game == null) return false;
    return _run(() => _service.startGame(game.id));
  }

  /// Leaves the current room and clears local state.
  Future<void> leave() async {
    final game = _game;
    await _teardown();
    if (game != null) {
      try {
        await _service.leaveGame(game.id);
      } on LobbyFailure {
        // Leaving is best-effort; ignore failures on the way out.
      }
    }
    _game = null;
    _players = const [];
    notifyListeners();
  }

  Future<void> _teardown() async {
    _cancelFillCountdown();
    await _playersSub?.cancel();
    await _gameSub?.cancel();
    _playersSub = null;
    _gameSub = null;
  }

  @override
  void dispose() {
    _fillTimer?.cancel();
    _playersSub?.cancel();
    _gameSub?.cancel();
    super.dispose();
  }
}
