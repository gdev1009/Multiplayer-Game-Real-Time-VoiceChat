import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/game.dart';
import '../../models/game_player.dart';
import '../../services/lobby_failure.dart';
import '../../services/lobby_service.dart';

/// Drives the lobby feature: creating/joining games, listing open games, and
/// keeping the current room in sync via Supabase Realtime.
class LobbyController extends ChangeNotifier {
  LobbyController(this._service);

  final LobbyService _service;

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

  Future<bool> quickMatch() => _enter(() => _service.quickMatch());

  Future<bool> _enter(Future<Game> Function() action) {
    return _run(() async {
      final game = await action();
      _game = game;
      _players = await _service.loadPlayers(game.id);
      _subscribe(game.id);
    });
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
    await _playersSub?.cancel();
    await _gameSub?.cancel();
    _playersSub = null;
    _gameSub = null;
  }

  @override
  void dispose() {
    _playersSub?.cancel();
    _gameSub?.cancel();
    super.dispose();
  }
}
