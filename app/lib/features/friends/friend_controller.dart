import 'package:flutter/foundation.dart';

import '../../models/friend.dart';
import '../../services/friend_service.dart';

/// Drives the Friends feature (Milestone 7): the friends list, incoming
/// requests, and pending game invitations, plus the actions that change them.
class FriendController extends ChangeNotifier {
  FriendController(this._service);

  final FriendService _service;

  List<Friend> _friends = const [];
  List<Friend> get friends => _friends;

  List<FriendRequest> _requests = const [];
  List<FriendRequest> get requests => _requests;

  List<GameInvite> _invites = const [];
  List<GameInvite> get invites => _invites;

  bool _busy = false;
  bool get busy => _busy;

  bool _loaded = false;

  /// Whether the first load has completed at least once (so the UI can show a
  /// spinner only on the very first open).
  bool get loaded => _loaded;

  String? _error;
  String? get error => _error;

  /// Total count that deserves the player's attention (requests + invites),
  /// used for the badge on the Opening screen's Friends button.
  int get attentionCount => _requests.length + _invites.length;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Reloads friends, requests and invites together.
  Future<void> refresh() async {
    _error = null;
    _setBusy(true);
    try {
      final results = await Future.wait([
        _service.listFriends(),
        _service.listRequests(),
        _service.listInvites(),
      ]);
      _friends = results[0] as List<Friend>;
      _requests = results[1] as List<FriendRequest>;
      _invites = results[2] as List<GameInvite>;
      _loaded = true;
    } on FriendFailure catch (f) {
      _error = f.message;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    } finally {
      _setBusy(false);
    }
  }

  /// Loads only the badge counts (requests + invites) without disturbing the
  /// friends list — cheap enough to call whenever the Opening screen appears.
  Future<void> refreshBadges() async {
    try {
      final results = await Future.wait([
        _service.listRequests(),
        _service.listInvites(),
      ]);
      _requests = results[0] as List<FriendRequest>;
      _invites = results[1] as List<GameInvite>;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Badges are best-effort; leave the last-known counts on failure.
    }
  }

  /// Sends a friend request to a co-player. Returns true on success.
  Future<bool> addFriend(String otherId) =>
      _act(() => _service.sendRequest(otherId));

  Future<bool> acceptRequest(String otherId) =>
      _act(() => _service.respondRequest(otherId, accept: true));

  Future<bool> declineRequest(String otherId) =>
      _act(() => _service.respondRequest(otherId, accept: false));

  Future<bool> removeFriend(String otherId) =>
      _act(() => _service.removeFriend(otherId));

  Future<bool> inviteFriend(String gameId, String friendId) =>
      _act(() => _service.inviteFriend(gameId, friendId), refreshAfter: false);

  /// Accepts an invite; returns the game id to enter, or null on failure.
  Future<String?> acceptInvite(String gameId) async {
    _error = null;
    _setBusy(true);
    try {
      final res = await _service.respondInvite(gameId, accept: true);
      _invites = _invites.where((i) => i.gameId != gameId).toList();
      return res['game_id'] as String?;
    } on FriendFailure catch (f) {
      _error = f.message;
      return null;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      return null;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> declineInvite(String gameId) =>
      _act(() => _service.respondInvite(gameId, accept: false));

  Future<bool> _act(
    Future<void> Function() action, {
    bool refreshAfter = true,
  }) async {
    _error = null;
    _setBusy(true);
    var ok = true;
    try {
      await action();
    } on FriendFailure catch (f) {
      _error = f.message;
      ok = false;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      ok = false;
    } finally {
      _setBusy(false);
    }
    if (ok && refreshAfter) await refresh();
    return ok;
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
