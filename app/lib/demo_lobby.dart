// Standalone demo entry for the Milestone 4 lobby / game-code / matchmaking UI.
//
// This mounts the real M4 screens (Play-a-Game hub, Join-with-a-Code, and the
// live Game Room) driven by an *in-memory* lobby service, so the lobby can be
// run and screenshotted WITHOUT a live Supabase backend or sign-in. It is a
// developer/demo tool only and is never bundled into the shipping app (the
// real entry point remains lib/main.dart).
//
// Run for the web with:
//   flutter run -d web-server -t lib/demo_lobby.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/lobby/join_by_code_screen.dart';
import 'features/lobby/lobby_controller.dart';
import 'features/lobby/lobby_room_screen.dart';
import 'features/lobby/upcoming_games_screen.dart';
import 'features/studio/studio_screen.dart';
import 'models/game.dart';
import 'models/game_player.dart';
import 'models/game_preview.dart';
import 'services/auth_service.dart';
import 'services/device_service.dart';
import 'services/lobby_service.dart';
import 'services/profile_service.dart';
import 'services/trial_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(create: (_) => _DemoAuthController()),
        ChangeNotifierProvider<LobbyController>(
          create: (_) => LobbyController(_InMemoryLobbyService()),
        ),
      ],
      child: MaterialApp(
        title: 'Match Word — Lobby',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const UpcomingGamesScreen(),
        routes: {
          AppRoutes.upcomingGames: (_) => const UpcomingGamesScreen(),
          AppRoutes.lobbyRoom: (_) => const LobbyRoomScreen(),
          AppRoutes.joinByCode: (_) => const JoinByCodeScreen(),
          AppRoutes.studio: (_) => const StudioScreen(),
        },
      ),
    ),
  );
}

/// A throwaway offline Supabase client so the demo controllers can be
/// constructed without `Supabase.initialize`. It is never used to talk to the
/// network — every method that would touch it is overridden below.
SupabaseClient _offlineClient() =>
    SupabaseClient('https://demo.supabase.co', 'demo-anon-key');

/// Auth stand-in that reports a signed-in player named "Sunny" so the room's
/// personalised greeting renders, without any real sign-in.
class _DemoAuthController extends AuthController {
  _DemoAuthController()
      : super(
          AuthService(
            client: _offlineClient(),
            deviceService: DeviceService(),
            profileService: ProfileService(_sharedClient),
            trialService: TrialService(_sharedClient),
          ),
        );

  static final SupabaseClient _sharedClient = _offlineClient();

  @override
  String? get rememberedName => 'Sunny';
}

/// An in-memory [LobbyService] that plays back a believable lobby without a
/// backend: it seeds a few open public games, hands out a shareable code when
/// you host or join, seats the host, and fills the remaining seats with studio
/// players on demand — all pushed through streams exactly like Realtime.
class _InMemoryLobbyService extends LobbyService {
  _InMemoryLobbyService() : super(_offlineClient());

  static const String _hostId = 'demo-host';
  static const List<String> _fillNames = ['Rosa', 'Walter', 'Mabel'];

  final StreamController<List<GamePlayer>> _playersCtrl =
      StreamController<List<GamePlayer>>.broadcast();
  final StreamController<Game?> _gameCtrl =
      StreamController<Game?>.broadcast();

  Game? _game;
  List<GamePlayer> _players = const [];

  Game _newGame({required bool isPublic, String code = '4827'}) => Game(
        id: 'demo-game',
        code: code,
        hostId: _hostId,
        status: GameStatus.lobby,
        isPublic: isPublic,
        maxPlayers: 4,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

  GamePlayer _seat({
    required int seat,
    required String name,
    required bool isAi,
  }) =>
      GamePlayer(
        id: 'seat-$seat',
        gameId: 'demo-game',
        profileId: isAi ? null : _hostId,
        displayName: name,
        firstName: name,
        isAi: isAi,
        isHost: seat == 0,
        seat: seat,
        team: LobbyRoles.teamForSeat(seat),
        role: LobbyRoles.roleForSeat(seat),
      );

  void _startWith({required bool isPublic, String code = '4827'}) {
    _game = _newGame(isPublic: isPublic, code: code);
    _players = [_seat(seat: 0, name: 'Sunny', isAi: false)];
  }

  @override
  Future<Game> createGame({bool isPublic = false}) async {
    _startWith(isPublic: isPublic);
    return _game!;
  }

  @override
  Future<Game> joinByCode(String code) async {
    // Join an existing game: the host is already seated, you take seat 1.
    _game = _newGame(isPublic: false, code: code.isEmpty ? '4827' : code);
    _players = [
      _seat(seat: 0, name: 'Grace', isAi: false),
      _seat(seat: 1, name: 'Sunny', isAi: false),
    ];
    return _game!;
  }

  @override
  Future<Game> joinSeat(String code, int seat) async {
    // Pick-your-seat: the host holds seat 0; you land in the seat you tapped,
    // taking over the AI there if needed.
    _game = _newGame(isPublic: false, code: code.isEmpty ? '4827' : code);
    _players = [
      _seat(seat: 0, name: 'Grace', isAi: false),
      _seat(seat: seat, name: 'Sunny', isAi: false),
    ];
    _players.sort((a, b) => a.seat.compareTo(b.seat));
    return _game!;
  }

  @override
  Future<GamePreview> peekByCode(String code) async {
    // Show a friend's game with the host + one AI already seated, so the
    // preview's "you'll join Team B" highlight has something to point at.
    final seats = [
      _seat(seat: 0, name: 'Grace', isAi: false),
      _seat(seat: 2, name: 'Walter', isAi: true),
    ];
    return GamePreview(
      gameId: 'demo-game',
      code: code.isEmpty ? '4827' : code,
      maxPlayers: 4,
      seatsTaken: seats.length,
      alreadyMember: false,
      players: seats,
    );
  }

  @override
  Future<Game> quickMatch() async {
    // Mirrors migration 0011: land the solo player in a fresh public game with
    // the seats left OPEN. The LobbyController's "looking for players" countdown
    // then calls fillSeats() when it elapses — so the demo exercises the real
    // pre-AI wait path instead of faking its own fill here.
    _startWith(isPublic: true, code: '3591');
    return _game!;
  }

  @override
  Future<List<GamePlayer>> loadPlayers(String gameId) async =>
      List<GamePlayer>.of(_players);

  @override
  Future<void> fillSeats(String gameId) async {
    final next = List<GamePlayer>.of(_players);
    for (var seat = 0; seat < 4; seat++) {
      final taken = next.any((p) => p.seat == seat);
      if (!taken) {
        next.add(_seat(seat: seat, name: _fillNames[(seat - 1) % 3], isAi: true));
      }
    }
    next.sort((a, b) => a.seat.compareTo(b.seat));
    _players = next;
    _playersCtrl.add(List<GamePlayer>.of(_players));
  }

  @override
  Future<void> startGame(String gameId) async {
    final game = _game;
    if (game == null) return;
    _game = Game(
      id: game.id,
      code: game.code,
      hostId: game.hostId,
      status: GameStatus.inProgress,
      isPublic: game.isPublic,
      maxPlayers: game.maxPlayers,
      createdAt: game.createdAt,
      startedAt: DateTime.now(),
      expiresAt: game.expiresAt,
    );
    _gameCtrl.add(_game);
  }

  @override
  Future<void> leaveGame(String gameId) async {
    _game = null;
    _players = const [];
  }

  @override
  Future<Game> loadGame(String gameId) async => _game!;

  @override
  Future<List<Game>> listOpenGames() async => [
        _newGame(isPublic: true, code: '2048').copyWith(playerCount: 2),
        _newGame(isPublic: true, code: '7310').copyWith(playerCount: 1),
        _newGame(isPublic: true, code: '5629').copyWith(playerCount: 3),
      ];

  @override
  Stream<List<GamePlayer>> watchPlayers(String gameId) => _playersCtrl.stream;

  @override
  Stream<Game?> watchGame(String gameId) => _gameCtrl.stream;

  @override
  bool isHostOf(Game game) => game.hostId == _hostId;
}

/// Small local helper so the demo can set a live occupancy count on the seeded
/// open games without a backend.
extension _GameCount on Game {
  Game copyWith({int? playerCount}) => Game(
        id: id,
        code: code,
        hostId: hostId,
        status: status,
        isPublic: isPublic,
        maxPlayers: maxPlayers,
        createdAt: createdAt,
        startedAt: startedAt,
        expiresAt: expiresAt,
        playerCount: playerCount ?? this.playerCount,
      );
}
