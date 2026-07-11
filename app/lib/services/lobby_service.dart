import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game.dart';
import '../models/game_player.dart';
import '../models/game_preview.dart';
import 'lobby_failure.dart';

/// Server-authoritative lobby operations for Milestone 4.
///
/// Every mutation calls a `SECURITY DEFINER` Postgres function (see
/// `supabase/migrations/0004_lobby.sql`); the client never writes to the
/// `games` / `game_players` tables directly. Reads use RLS-scoped selects and
/// Supabase Realtime streams so lobby state stays in sync across devices.
class LobbyService {
  LobbyService(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const LobbyFailure('Something went wrong. Please try again.');
  }

  /// Runs an RPC that returns a jsonb `{ ok, ... }` envelope, converting a
  /// failure into a [LobbyFailure]. Returns the map on success.
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

  /// Creates a new game (private by default) and returns it.
  Future<Game> createGame({bool isPublic = false}) async {
    final res = await _callOk('mw_create_game', {'p_is_public': isPublic});
    return loadGame(res['game_id'] as String);
  }

  /// Joins a game by its 4-digit [code] and returns it.
  Future<Game> joinByCode(String code) async {
    final res = await _callOk('mw_join_game', {'p_code': code.trim()});
    return loadGame(res['game_id'] as String);
  }

  /// Joins a game by [code] into a specific [seat] the player picked in the
  /// preview (taking over a studio player if that seat holds one), so friends
  /// can choose the same team. Returns the joined game.
  Future<Game> joinSeat(String code, int seat) async {
    final res = await _callOk(
      'mw_join_seat',
      {'p_code': code.trim(), 'p_seat': seat},
    );
    return loadGame(res['game_id'] as String);
  }

  /// Reads the roster for a 4-digit [code] *without* seating the caller, so the
  /// UI can show a "who's already here" confirm step before joining.
  Future<GamePreview> peekByCode(String code) async {
    final res = await _callOk('mw_peek_game', {'p_code': code.trim()});
    return GamePreview.fromMap(res);
  }

  /// Finds an open public game with a free seat, or creates one. Returns the
  /// joined game.
  Future<Game> quickMatch() async {
    final res = await _callOk('mw_quick_match');
    return loadGame(res['game_id'] as String);
  }

  /// Host action: fills the remaining empty seats with studio players.
  Future<void> fillSeats(String gameId) =>
      _callOk('mw_fill_seats', {'p_game': gameId});

  /// Host action: starts the game (lobby → in progress).
  Future<void> startGame(String gameId) =>
      _callOk('mw_start_game', {'p_game': gameId});

  /// Leaves the given game.
  Future<void> leaveGame(String gameId) =>
      _callOk('mw_leave_game', {'p_game': gameId});

  /// Loads a single game by id.
  Future<Game> loadGame(String gameId) async {
    final row = await _client
        .from('games')
        .select()
        .eq('id', gameId)
        .maybeSingle();
    if (row == null) {
      throw const LobbyFailure('That game is no longer available.');
    }
    return Game.fromMap(row);
  }

  /// Loads the current seats for a game, ordered by seat.
  Future<List<GamePlayer>> loadPlayers(String gameId) async {
    final rows = await _client
        .from('game_players')
        .select()
        .eq('game_id', gameId)
        .order('seat');
    return rows.map<GamePlayer>((r) => GamePlayer.fromMap(r)).toList();
  }

  /// Lists joinable public lobbies with their live player counts (for the
  /// "Check Upcoming Games" list). Full and expired games are excluded by the
  /// `mw_list_open_games` function.
  Future<List<Game>> listOpenGames() async {
    try {
      final res = await _client.rpc('mw_list_open_games');
      final rows = (res as List?) ?? const [];
      return rows
          .map<Game>((r) => Game.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw LobbyFailure('Something went wrong. Please try again.', code: e.code);
    }
  }

  /// Realtime stream of the seats in a game (updates as players join/leave).
  Stream<List<GamePlayer>> watchPlayers(String gameId) {
    return _client
        .from('game_players')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .order('seat')
        .map((rows) => rows.map(GamePlayer.fromMap).toList());
  }

  /// Realtime stream of a single game row (status/host changes).
  Stream<Game?> watchGame(String gameId) {
    return _client
        .from('games')
        .stream(primaryKey: ['id'])
        .eq('id', gameId)
        .map((rows) => rows.isEmpty ? null : Game.fromMap(rows.first));
  }

  /// Whether the current user hosts the given game.
  bool isHostOf(Game game) => _uid != null && game.hostId == _uid;
}
