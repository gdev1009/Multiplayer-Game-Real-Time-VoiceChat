import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/models/game.dart';
import 'package:match_word/models/game_player.dart';
import 'package:match_word/models/game_preview.dart';
import 'package:match_word/services/lobby_failure.dart';

void main() {
  group('LobbyRoles seat mapping', () {
    test('teams alternate A/B by seat parity', () {
      expect(LobbyRoles.teamForSeat(0), 'A');
      expect(LobbyRoles.teamForSeat(1), 'B');
      expect(LobbyRoles.teamForSeat(2), 'A');
      expect(LobbyRoles.teamForSeat(3), 'B');
    });

    test('roles match the SQL mw_seat_role output', () {
      expect(LobbyRoles.roleForSeat(0), 'A1');
      expect(LobbyRoles.roleForSeat(1), 'B1');
      expect(LobbyRoles.roleForSeat(2), 'A2');
      expect(LobbyRoles.roleForSeat(3), 'B2');
    });

    test('team label is friendly', () {
      expect(LobbyRoles.teamLabel('A'), 'Team A');
      expect(LobbyRoles.teamLabel('B'), 'Team B');
    });
  });

  group('Game.fromMap', () {
    test('parses a lobby row', () {
      final game = Game.fromMap({
        'id': 'g1',
        'code': '0421',
        'host_id': 'u1',
        'status': 'lobby',
        'is_public': true,
        'max_players': 4,
        'created_at': '2026-07-06T12:00:00Z',
      });
      expect(game.code, '0421');
      expect(game.status, GameStatus.lobby);
      expect(game.isOpen, isTrue);
      expect(game.isPublic, isTrue);
      expect(game.maxPlayers, 4);
    });

    test('maps in_progress status', () {
      final game = Game.fromMap({
        'id': 'g1',
        'code': '0001',
        'host_id': 'u1',
        'status': 'in_progress',
        'is_public': false,
        'max_players': 4,
        'created_at': '2026-07-06T12:00:00Z',
        'started_at': '2026-07-06T12:05:00Z',
      });
      expect(game.status, GameStatus.inProgress);
      expect(game.isOpen, isFalse);
      expect(game.startedAt, isNotNull);
    });
  });

  group('GamePlayer.fromMap', () {
    test('parses a human seat', () {
      final p = GamePlayer.fromMap({
        'id': 'p1',
        'game_id': 'g1',
        'profile_id': 'u1',
        'display_name': 'Rosa',
        'first_name': 'Rosa',
        'is_ai': false,
        'is_host': true,
        'seat': 0,
        'team': 'A',
        'role': 'A1',
      });
      expect(p.isHuman, isTrue);
      expect(p.isHost, isTrue);
      expect(p.team, 'A');
      expect(p.role, 'A1');
    });

    test('a computer seat has no profile id', () {
      final p = GamePlayer.fromMap({
        'id': 'p2',
        'game_id': 'g1',
        'profile_id': null,
        'display_name': 'Sunny',
        'first_name': 'Sunny',
        'is_ai': true,
        'is_host': false,
        'seat': 1,
        'team': 'B',
        'role': 'B1',
      });
      expect(p.isHuman, isFalse);
      expect(p.isAi, isTrue);
    });
  });

  group('LobbyFailure.fromReason', () {
    test('maps known reasons to friendly messages', () {
      expect(LobbyFailure.fromReason('not_found').code, 'not_found');
      expect(LobbyFailure.fromReason('full').message, contains('full'));
      expect(
        LobbyFailure.fromReason('need_more_players').code,
        'need_more_players',
      );
    });

    test('falls back for unknown reasons', () {
      final f = LobbyFailure.fromReason('mystery');
      expect(f.message, contains('Something went wrong'));
      expect(f.code, 'mystery');
    });
  });

  group('Game occupancy (open-games list)', () {
    Game gameWith({int? playerCount, int maxPlayers = 4}) => Game.fromMap({
          'id': 'g1',
          'code': '1234',
          'host_id': 'u1',
          'status': 'lobby',
          'is_public': true,
          'max_players': maxPlayers,
          'created_at': '2026-07-06T12:00:00Z',
          if (playerCount != null) 'player_count': playerCount,
        });

    test('parses player_count and computes seats available', () {
      final g = gameWith(playerCount: 2);
      expect(g.playerCount, 2);
      expect(g.seatsAvailable, 2);
      expect(g.isFull, isFalse);
    });

    test('a game at capacity reports full', () {
      final g = gameWith(playerCount: 4);
      expect(g.isFull, isTrue);
      expect(g.seatsAvailable, 0);
    });

    test('an unknown count leaves occupancy null (never falsely full)', () {
      final g = gameWith();
      expect(g.playerCount, isNull);
      expect(g.seatsAvailable, isNull);
      expect(g.isFull, isFalse);
    });
  });

  group('GamePreview (join-by-code roster peek)', () {
    Map<String, dynamic> seat(int s, {bool ai = false, bool host = false}) => {
          'seat': s,
          'team': LobbyRoles.teamForSeat(s),
          'role': LobbyRoles.roleForSeat(s),
          'display_name': ai ? 'Sunny' : 'Rosa',
          'is_host': host,
          'is_ai': ai,
        };

    test('parses the peek payload into a roster', () {
      final p = GamePreview.fromMap({
        'game_id': 'g1',
        'code': '4827',
        'max_players': 4,
        'seats_taken': 2,
        'already_member': false,
        'players': [seat(0, host: true), seat(1)],
      });
      expect(p.gameId, 'g1');
      expect(p.code, '4827');
      expect(p.seatsTaken, 2);
      expect(p.seatsAvailable, 2);
      expect(p.isFull, isFalse);
      expect(p.players.first.isHost, isTrue);
      expect(p.players.first.team, 'A');
    });

    test('a lobby full of humans reports full', () {
      final p = GamePreview.fromMap({
        'game_id': 'g1',
        'code': '4827',
        'max_players': 4,
        'seats_taken': 4,
        'already_member': false,
        'players': [seat(0, host: true), seat(1), seat(2), seat(3)],
      });
      expect(p.isFull, isTrue);
      expect(p.seatsAvailable, 0);
    });

    test('an empty players array is tolerated', () {
      final p = GamePreview.fromMap({
        'game_id': 'g1',
        'code': '4827',
        'max_players': 4,
        'seats_taken': 0,
        'already_member': false,
        'players': <dynamic>[],
      });
      expect(p.players, isEmpty);
      expect(p.seatsAvailable, 4);
    });
  });

  group('Pick-your-seat (join preview seat selection)', () {
    Map<String, dynamic> seat(int s, {bool ai = false, bool host = false}) => {
          'seat': s,
          'team': LobbyRoles.teamForSeat(s),
          'role': LobbyRoles.roleForSeat(s),
          'display_name': ai ? 'Sunny' : 'Rosa',
          'is_host': host,
          'is_ai': ai,
        };

    // Mirrors the JoinPreviewScreen rule: a seat is pickable when it's empty
    // or held by a studio (AI) player — never when a human already sits there.
    bool pickable(GamePreview p, int s) {
      GamePlayer? player;
      for (final x in p.players) {
        if (x.seat == s) player = x;
      }
      return player == null || player.isAi;
    }

    test('a human host seat is not pickable, open + AI seats are', () {
      final p = GamePreview.fromMap({
        'game_id': 'g1',
        'code': '4827',
        'max_players': 4,
        'seats_taken': 2,
        'already_member': false,
        'players': [seat(0, host: true), seat(2, ai: true)],
      });
      expect(pickable(p, 0), isFalse, reason: 'human host');
      expect(pickable(p, 1), isTrue, reason: 'open seat');
      expect(pickable(p, 2), isTrue, reason: 'studio player, can take over');
      expect(pickable(p, 3), isTrue, reason: 'open seat');
    });

    test('a friend can pick a seat on the host\'s team', () {
      // Host is on seat 0 (Team A); picking seat 2 also lands on Team A.
      expect(LobbyRoles.teamForSeat(0), 'A');
      expect(LobbyRoles.teamForSeat(2), 'A');
      // ...while seats 1 and 3 are Team B.
      expect(LobbyRoles.teamForSeat(1), 'B');
      expect(LobbyRoles.teamForSeat(3), 'B');
    });
  });
}
