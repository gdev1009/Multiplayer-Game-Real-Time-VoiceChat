import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend.dart';

/// Raised when a friend / invite action can't be completed. The message is
/// already senior-friendly and safe to show in a snackbar.
class FriendFailure implements Exception {
  const FriendFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Server-authoritative friend + invite operations for Milestone 7.
///
/// Mirrors [LobbyService]: every mutation calls a `SECURITY DEFINER` Postgres
/// function (see `supabase/migrations/0014_friends.sql`); the client never
/// writes the `friendships` / `game_invites` tables directly. Only display
/// names and cosmetic character layers are ever read back — no personal info.
class FriendService {
  FriendService(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const FriendFailure('Something went wrong. Please try again.');
  }

  /// Runs an RPC returning a `{ ok, ... }` envelope, turning a failure into a
  /// [FriendFailure] with a calm message. Returns the map on success.
  Future<Map<String, dynamic>> _callOk(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      final res = _asMap(await _client.rpc(fn, params: params));
      if (res['ok'] == true) return res;
      throw FriendFailure(_reasonMessage(res['reason'] as String?));
    } on PostgrestException catch (e) {
      debugPrint('[FriendService] $fn failed: ${e.code} ${e.message}');
      throw FriendFailure(_friendlyFor(e));
    }
  }

  /// Runs an RPC that returns a jsonb array, mapping each row with [fromMap].
  Future<List<T>> _callList<T>(
    String fn,
    T Function(Map<String, dynamic>) fromMap,
  ) async {
    try {
      final res = await _client.rpc(fn);
      final rows = (res as List?) ?? const [];
      return rows
          .map<T>((r) => fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('[FriendService] $fn failed: ${e.code} ${e.message}');
      throw FriendFailure(_friendlyFor(e));
    }
  }

  String _reasonMessage(String? reason) {
    switch (reason) {
      case 'not_friends':
        return 'You can only invite people on your friends list.';
      case 'game_closed':
      case 'game_full':
        return 'That game is no longer open to join.';
      case 'no_such_player':
        return 'That player is no longer available.';
      case 'no_request':
        return 'That request is no longer available.';
      case 'no_invite':
        return 'That invitation is no longer available.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  String _friendlyFor(PostgrestException e) {
    final msg = e.message.toLowerCase();
    final missingSchema = e.code == '42883' ||
        e.code == '42P01' ||
        e.code == 'PGRST202' ||
        msg.contains('does not exist') ||
        msg.contains('could not find');
    if (missingSchema) {
      return 'Friends need a quick setup on the server first. '
          'Please contact support.';
    }
    return 'Something went wrong. Please try again.';
  }

  // ---- Friends --------------------------------------------------------------
  /// Sends a friend request to [otherId]. If they already asked me, we become
  /// friends right away. Returns the resulting status ('pending'/'accepted').
  Future<String> sendRequest(String otherId) async {
    final res = await _callOk('mw_send_friend_request', {'p_other': otherId});
    return (res['status'] as String?) ?? 'pending';
  }

  /// Accepts or declines a request the other player sent me.
  Future<void> respondRequest(String otherId, {required bool accept}) =>
      _callOk(
        'mw_respond_friend_request',
        {'p_other': otherId, 'p_accept': accept},
      );

  /// Removes a friendship (or withdraws a request I sent).
  Future<void> removeFriend(String otherId) =>
      _callOk('mw_remove_friend', {'p_other': otherId});

  Future<List<Friend>> listFriends() =>
      _callList('mw_list_friends', Friend.fromMap);

  Future<List<FriendRequest>> listRequests() =>
      _callList('mw_list_friend_requests', FriendRequest.fromMap);

  // ---- Invites --------------------------------------------------------------
  /// Invites [friendId] to the lobby [gameId] I'm hosting/in.
  Future<void> inviteFriend(String gameId, String friendId) =>
      _callOk('mw_invite_friend', {'p_game': gameId, 'p_friend': friendId});

  Future<List<GameInvite>> listInvites() =>
      _callList('mw_list_my_invites', GameInvite.fromMap);

  /// Accepts or declines an invite. On accept the caller is seated; the returned
  /// map carries `game_id` so the UI can enter that room.
  Future<Map<String, dynamic>> respondInvite(
    String gameId, {
    required bool accept,
  }) =>
      _callOk('mw_respond_invite', {'p_game': gameId, 'p_accept': accept});
}
