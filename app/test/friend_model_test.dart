import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/models/friend.dart';

void main() {
  group('Friend.fromMap', () {
    test('parses id, name and cosmetic character layers', () {
      final friend = Friend.fromMap({
        'id': 'u-1',
        'display_name': 'Rosa',
        'base': 'body-female',
        'hair': 'hair-f2',
        'hat': null,
      });
      expect(friend.id, 'u-1');
      expect(friend.displayName, 'Rosa');
      expect(friend.character.base, 'body-female');
      expect(friend.character.hair, 'hair-f2');
      expect(friend.character.hat, isNull);
    });

    test('uses a friendly fallback when the name is blank', () {
      final friend = Friend.fromMap({'id': 'u-2', 'display_name': '  '});
      expect(friend.displayName, 'A friend');
    });
  });

  group('FriendRequest.fromMap', () {
    test('maps the requester id into fromId', () {
      final req = FriendRequest.fromMap({'id': 'u-9', 'display_name': 'Sam'});
      expect(req.fromId, 'u-9');
      expect(req.displayName, 'Sam');
    });
  });

  group('GameInvite.fromMap', () {
    test('parses game id, code and inviter name', () {
      final invite = GameInvite.fromMap({
        'game_id': 'g-1',
        'code': '4821',
        'inviter_name': 'Rosa',
      });
      expect(invite.gameId, 'g-1');
      expect(invite.code, '4821');
      expect(invite.inviterName, 'Rosa');
    });

    test('falls back when the inviter name is missing', () {
      final invite = GameInvite.fromMap({'game_id': 'g-2', 'code': '0000'});
      expect(invite.inviterName, 'A friend');
    });
  });
}
