// Standalone "full journey" demo entry that chains Milestones 3, 4 and 5 into
// one continuous, backend-free experience:
//
//   Opening screen  →  make your character (M3)
//                   →  find / host a game, seats fill (M4)
//                   →  play a full game: clues, guesses, steals, halftime,
//                      scoring and the winner (M5)
//
// It mounts the REAL shipping screens (OpeningScreen, the character wizard, the
// lobby hub/room, and the play board) and only swaps the Supabase-backed
// services for in-memory stand-ins, so the whole game can be shown and recorded
// without a live backend or sign-in. Dev/demo tool only — never bundled into
// the shipping app (the real entry point remains lib/main.dart).
//
// Run for the web with:
//   flutter run -d web-server -t lib/demo_journey.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/character/character_controller.dart';
import 'features/character/character_creation_screen.dart';
import 'features/game/ai_player.dart';
import 'features/game/game_engine.dart';
import 'features/game/word_bank.dart';
import 'features/home/opening_screen.dart';
import 'features/lobby/join_by_code_screen.dart';
import 'features/lobby/lobby_controller.dart';
import 'features/lobby/lobby_room_screen.dart';
import 'features/lobby/upcoming_games_screen.dart';
import 'features/prizes/prize_controller.dart';
import 'features/prizes/prize_room_screen.dart';
import 'features/studio/studio_screen.dart';
import 'models/character.dart';
import 'models/game.dart';
import 'models/game_player.dart';
import 'models/game_preview.dart';
import 'models/prize.dart';
import 'models/profile.dart';
import 'services/audio_controller.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
import 'services/character_service.dart';
import 'services/device_service.dart';
import 'services/entitlement_service.dart';
import 'services/gameplay_service.dart';
import 'services/lobby_service.dart';
import 'services/prize_service.dart';
import 'services/profile_service.dart';
import 'services/trial_service.dart';

void main() {
  final charService = _InMemoryCharacterService()
    ..seed(const Character(
      displayName: 'Rosie',
      base: 'body-female',
      hair: 'hair-f1',
      outfit: 'outfit-f1',
      glasses: 'glasses-f-round',
    ));
  final prizeCtrl = PrizeController(PrizeService(_offlineClient()))
    ..seedForDemo(
      PrizeRoom(
        gamesPlayed: 12,
        gamesWon: 3,
        items: const [
          PrizeItem(
            id: 'trophy-win-cup',
            kind: 'trophy',
            title: 'Win Trophy',
            description: 'A trophy for every Match Word win.',
            assetPath: 'assets/images/trophies/trophy-first-win.png',
            sortOrder: 5,
            earned: true,
          ),
          PrizeItem(
            id: 'trophy-first-win',
            kind: 'trophy',
            title: 'First Win',
            description: 'Won your very first Match Word game.',
            assetPath: 'assets/images/trophies/trophy-first-win.png',
            sortOrder: 10,
            earned: true,
          ),
          PrizeItem(
            id: 'trophy-10-games',
            kind: 'trophy',
            title: '10 Games',
            description: 'Played 10 matches end to end.',
            assetPath: 'assets/images/trophies/trophy-10-games.png',
            sortOrder: 20,
            earned: true,
          ),
          PrizeItem(
            id: 'trophy-50-games',
            kind: 'trophy',
            title: '50 Games',
            description: 'Played 50 matches — a true studio regular.',
            assetPath: 'assets/images/trophies/trophy-50-games.png',
            sortOrder: 30,
            earned: false,
          ),
        ],
      ),
    );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(create: (_) => _DemoAuthController()),
        ChangeNotifierProvider<CharacterController>(
          create: (_) {
            final c = CharacterController(charService);
            unawaited(c.load());
            return c;
          },
        ),
        ChangeNotifierProvider<LobbyController>(
          create: (_) => LobbyController(_InMemoryLobbyService()),
        ),
        ChangeNotifierProvider<PrizeController>.value(value: prizeCtrl),
        Provider<GameplayService>.value(value: _DemoGameplayService()),
        ChangeNotifierProvider<AudioController>(
          create: (_) => AudioController(output: _SilentOutput()),
        ),
        Provider<EntitlementService>(
          create: (_) => EntitlementService(
            profileService: ProfileService(_offlineClient()),
            billingService: BillingService(_offlineClient()),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Match Word — Full Journey',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const OpeningScreen(),
        routes: {
          AppRoutes.character: (_) => const CharacterCreationScreen(),
          AppRoutes.upcomingGames: (_) => const UpcomingGamesScreen(),
          AppRoutes.lobbyRoom: (_) => const LobbyRoomScreen(),
          AppRoutes.joinByCode: (_) => const JoinByCodeScreen(),
          AppRoutes.studio: (_) => const StudioScreen(),
          AppRoutes.prizeRoom: (_) => const PrizeRoomScreen(),
        },
      ),
    ),
  );
}

class _SilentOutput implements SoundOutput {
  @override
  bool get isSilent => true;
  @override
  Future<void> configure() async {}
  @override
  Future<void> playLoop(String asset, double volume) async {}
  @override
  Future<void> playMusicOnce(String asset, double volume,
      {Duration maxWait = const Duration(seconds: 16)}) async {}
  @override
  Future<void> stopLoop() async {}
  @override
  Future<void> setLoopVolume(double volume) async {}
  @override
  Future<void> playOneShot(String asset, double volume,
      {bool voice = false, double playbackRate = 1.0, bool fromFile = false, bool awaitCompletion = false, Duration maxWait = const Duration(seconds: 50)}) async {}
  @override
  Future<void> stopVoice() async {}
  @override
  Future<void> stopSfx() async {}
  @override
  Future<void> reconfigureAudioSession() async {}
  @override
  Future<void> stopAll() async {}
  @override
  Future<void> releaseForSpeechInput() async {}
  @override
  void dispose() {}
}

/// A throwaway offline Supabase client so the demo controllers can be
/// constructed without `Supabase.initialize`. It is never used to talk to the
/// network — every method that would touch it is overridden below.
SupabaseClient _offlineClient() =>
    SupabaseClient('https://demo.supabase.co', 'demo-anon-key');

/// Auth stand-in that reports a signed-in player named "Sunny" so the opening
/// screen's personalised greeting renders, without any real sign-in.
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

  @override
  Profile? get profile => Profile(
        id: 'demo-host',
        firstName: 'Sunny',
        deviceId: 'demo-device',
        trialStartedAt:
            DateTime.now().toUtc().subtract(const Duration(days: 2)),
        trialUsed: true,
        createdAt: DateTime.now().toUtc().subtract(const Duration(days: 10)),
        gamesPlayed: 12,
        gamesWon: 3,
      );

  // Sign-out is a no-op in the demo so the recording never dead-ends.
  @override
  Future<void> signOut() async {}
}

/// A backend-free stand-in for [CharacterService].
class _InMemoryCharacterService implements CharacterService {
  Character? _stored;

  void seed(Character c) => _stored = c;

  @override
  Future<Character?> loadCharacter() async => _stored;

  @override
  Future<void> saveCharacter(Character character) async => _stored = character;

  @override
  Future<bool> hasCharacter() async => _stored != null;
}

/// An in-memory [LobbyService] that plays back a believable lobby without a
/// backend: it seeds a few open public games, hands out a shareable code when
/// you host or join, seats the host, and fills the remaining seats with studio
/// players on demand — all pushed through streams exactly like Realtime.
class _InMemoryLobbyService extends LobbyService {
  _InMemoryLobbyService() : super(_offlineClient());

  static const String _hostId = 'demo-host';

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
    _game = _newGame(isPublic: false, code: code.isEmpty ? '4827' : code);
    _players = [
      _seat(seat: 0, name: 'Grace', isAi: false),
      _seat(seat: 1, name: 'Sunny', isAi: false),
    ];
    return _game!;
  }

  @override
  Future<Game> joinSeat(String code, int seat) async {
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
    // then calls fillSeats() when it elapses.
    _startWith(isPublic: true, code: '3591');
    return _game!;
  }

  @override
  Future<List<GamePlayer>> loadPlayers(String gameId) async =>
      List<GamePlayer>.of(_players);

  @override
  Future<void> fillSeats(String gameId) async {
    final next = List<GamePlayer>.of(_players);
    final openSeats = <int>[
      for (var seat = 0; seat < 4; seat++)
        if (!next.any((p) => p.seat == seat)) seat,
    ];
    final names = AiPlayer.fillNamesForGame(
      gameId,
      count: openSeats.length,
      taken: next.map((p) => p.displayName),
    );
    for (var i = 0; i < openSeats.length; i++) {
      next.add(_seat(seat: openSeats[i], name: names[i], isAi: true));
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

/// A backend-free [GameplayService]: the host hand-off deals a seeded word deck
/// and the play screen runs entirely on the local [MatchEngine] (the real
/// online controller applies every action optimistically, and with no-op writes
/// + empty realtime streams that local state simply stands). This lets the
/// unified journey reach the play board through the REAL lobby → play hand-off.
class _DemoGameplayService extends GameplayService {
  _DemoGameplayService() : super(_offlineClient());

  // Seeded so the recorded game is reproducible:
  // Flower, Slipper, Clock, Robin, Sandwich, Quilt, Holiday, Garden.
  final List<String> _words = WordBank.deal(16, random: Random(20260629));

  @override
  String? get currentUserId => 'demo-host';

  @override
  Future<void> beginPlay(String gameId) async {}

  @override
  Future<List<String>> loadWords(String gameId) async =>
      List<String>.of(_words);

  @override
  Future<void> submitClue(String gameId, String text) async {}

  @override
  Future<Map<String, dynamic>> submitGuess(String gameId, String text) async =>
      const {};

  @override
  Future<void> nextWord(String gameId) async {}

  @override
  Future<void> beginSecondHalf(String gameId) async {}

  @override
  Stream<GameStateRow?> watchState(String gameId) =>
      const Stream<GameStateRow?>.empty();

  @override
  Stream<List<PlayEntry>> watchPlays(String gameId) =>
      const Stream<List<PlayEntry>>.empty();
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
