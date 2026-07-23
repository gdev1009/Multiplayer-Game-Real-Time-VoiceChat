import 'character.dart';

/// Builds the cosmetic [Character] embedded in a friend / request row. The
/// friend functions return the same non-sensitive layer ids the live stage uses
/// (see `mw_list_friends`), plus the friend's display name — never any private
/// data. A friend who has not built a character yet simply has null layers.
Character _characterFrom(Map<String, dynamic> map) {
  return Character(
    displayName: (map['display_name'] as String?)?.trim() ?? '',
    base: map['base'] as String?,
    hair: map['hair'] as String?,
    outfit: map['outfit'] as String?,
    glasses: map['glasses'] as String?,
    hat: map['hat'] as String?,
    earrings: map['earrings'] as String?,
    accessory: map['accessory'] as String?,
  );
}

/// An accepted friend, shown in the friends list.
class Friend {
  const Friend({
    required this.id,
    required this.displayName,
    required this.character,
  });

  /// The friend's profile id — used to invite or remove them.
  final String id;
  final String displayName;

  /// The friend's cosmetic character for their avatar (may have null layers).
  final Character character;

  factory Friend.fromMap(Map<String, dynamic> map) {
    final name = (map['display_name'] as String?)?.trim() ?? '';
    return Friend(
      id: map['id'] as String,
      displayName: name.isEmpty ? 'A friend' : name,
      character: _characterFrom(map),
    );
  }
}

/// An incoming friend request (someone asked to be my friend).
class FriendRequest {
  const FriendRequest({
    required this.fromId,
    required this.displayName,
    required this.character,
  });

  /// The requester's profile id — used to accept or decline.
  final String fromId;
  final String displayName;
  final Character character;

  factory FriendRequest.fromMap(Map<String, dynamic> map) {
    final name = (map['display_name'] as String?)?.trim() ?? '';
    return FriendRequest(
      fromId: map['id'] as String,
      displayName: name.isEmpty ? 'A player' : name,
      character: _characterFrom(map),
    );
  }
}

/// A pending invitation to join a friend's lobby, shown on the games hub.
class GameInvite {
  const GameInvite({
    required this.gameId,
    required this.code,
    required this.inviterName,
  });

  final String gameId;
  final String code;
  final String inviterName;

  factory GameInvite.fromMap(Map<String, dynamic> map) {
    final name = (map['inviter_name'] as String?)?.trim() ?? '';
    return GameInvite(
      gameId: map['game_id'] as String,
      code: (map['code'] as String?)?.trim() ?? '',
      inviterName: name.isEmpty ? 'A friend' : name,
    );
  }
}
