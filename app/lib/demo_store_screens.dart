// Autoplay all shipping screens for store / journey screenshots.
//
//   flutter build web -t lib/demo_store_screens.dart --no-tree-shake-icons
//   python3 tools/capture_store_screenshots.py --serve
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/screens/create_account_screen.dart';
import 'features/auth/screens/daily_login_screen.dart';
import 'features/auth/screens/email_sign_in_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/billing/paywall_screen.dart';
import 'features/character/character_catalog.dart';
import 'features/character/character_controller.dart';
import 'features/character/character_creation_screen.dart';
import 'features/friends/friend_controller.dart';
import 'features/friends/friends_screen.dart';
import 'features/game/ai_player.dart';
import 'features/game/game_engine.dart';
import 'features/game/gameplay_controller.dart';
import 'features/game/play_screen.dart';
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
import 'models/friend.dart';
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
import 'services/friend_service.dart';
import 'services/gameplay_service.dart';
import 'services/lobby_service.dart';
import 'services/prize_service.dart';
import 'services/profile_service.dart';
import 'services/trial_service.dart';

const List<String> kStoreScenes = [
  '01_welcome',
  '02_create_account',
  '03_daily_login',
  '04_email_sign_in',
  '05_opening_home',
  '06_character_builder',
  '07_upcoming_games',
  '08_studio',
  '09_join_by_code',
  '10_lobby_room',
  '11_play_kickoff',
  '12_play_clue',
  '12b_play_bubbles',
  '13_play_winner',
  '14_prize_room',
  '15_paywall',
  '16_friends',
];

void main() {
  final charService = _InMemoryCharacterService()..seed(_rosie());
  final prizeCtrl = PrizeController(PrizeService(_offlineClient()))
    ..seedForDemo(_demoPrizeRoom());
  final billing = BillingService(_offlineClient());
  final gameplay = GameplayController()
    ..startLocal(
      words: WordBank.deal(16, random: Random(20260714)),
      names: const {
        'A1': 'Greg',
        'A2': 'Buddy',
        'B1': 'Rosie',
        'B2': 'Pearl',
      },
      myRole: 'A1',
      aiByRole: const {
        'A1': false,
        'A2': true,
        'B1': true,
        'B2': true,
      },
      charactersByRole: {
        'A1': _greg(),
        'A2': _buddy(),
        'B1': _rosieSeat(),
        'B2': _pearl(),
      },
    );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => _DemoAuthController(),
        ),
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
        ChangeNotifierProvider<GameplayController>.value(value: gameplay),
        ChangeNotifierProvider<AudioController>(
          create: (_) => AudioController(output: _SilentOutput()),
        ),
        ChangeNotifierProvider<FriendController>(
          create: (_) => FriendController(_DemoFriendService()),
        ),
        Provider<BillingService>.value(value: billing),
        Provider<EntitlementService>(
          create: (_) => EntitlementService(
            profileService: ProfileService(_offlineClient()),
            billingService: billing,
          ),
        ),
        Provider<GameplayService>.value(value: _DemoGameplayService()),
      ],
      child: const StoreScreensApp(),
    ),
  );
}

class StoreScreensApp extends StatelessWidget {
  const StoreScreensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Match Word — Store Screens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _StoreSequencer(),
    );
  }
}

class _StoreSequencer extends StatefulWidget {
  const _StoreSequencer();

  @override
  State<_StoreSequencer> createState() => _StoreSequencerState();
}

class _StoreSequencerState extends State<_StoreSequencer> {
  static const _startScene = String.fromEnvironment(
    'STORE_START',
    defaultValue: '01_welcome',
  );

  late int _index;
  Timer? _timer;

  String get _scene => kStoreScenes[_index];

  @override
  void initState() {
    super.initState();
    final start = kStoreScenes.indexOf(_startScene);
    _index = start >= 0 ? start : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepLobby();
      if (mounted) context.read<FriendController>().refresh();
    });
    final onlyOne = const bool.fromEnvironment('STORE_SINGLE', defaultValue: false);
    if (!onlyOne) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        setState(() => _index = (_index + 1) % kStoreScenes.length);
        _onSceneEntered(_scene);
      });
    }
    _onSceneEntered(_scene);
  }

  Future<void> _prepLobby() async {
    final lobby = context.read<LobbyController>();
    await lobby.createGame(isPublic: true);
    await lobby.fillSeats();
  }

  void _onSceneEntered(String scene) {
    if (scene == '06_character_builder') {
      final chars = context.read<CharacterController>();
      chars.startNew();
      chars.chooseOption(CharacterLayer.base, 'body-female');
      chars.chooseOption(CharacterLayer.hair, 'hair-f1');
      chars.chooseOption(CharacterLayer.outfit, 'outfit-f1');
    }
    final play = context.read<GameplayController>();
    final state = play.state;
    if (state == null) return;
    if (scene == '12_play_clue' && state.step == TurnStep.awaitingClue) {
      play.submitClue('Petals');
    } else if (scene == '12b_play_bubbles') {
      _seedAllSeatBubbles(play);
    } else if (scene == '13_play_winner') {
      _fastForwardToWinner(play);
    }
  }

  /// One steal cycle so A1, A2, B1, and B2 each have a speech bubble.
  void _seedAllSeatBubbles(GameplayController play) {
    play.startLocal(
      words: WordBank.deal(16, random: Random(20260714)),
      names: const {
        'A1': 'Greg',
        'A2': 'Buddy',
        'B1': 'Rosie',
        'B2': 'Pearl',
      },
      myRole: 'A1',
      aiByRole: const {
        'A1': false,
        'A2': false,
        'B1': false,
        'B2': false,
      },
      charactersByRole: {
        'A1': _greg(),
        'A2': _buddy(),
        'B1': _rosieSeat(),
        'B2': _pearl(),
      },
    );
    // Local engine updates are sync inside these Futures.
    play.submitClue('Sunny');
    play.submitGuess('Moon');
    play.submitClue('Warm');
    play.submitGuess('Coat');
  }

  void _fastForwardToWinner(GameplayController play) {
    for (var i = 0; i < 20; i++) {
      final s = play.state;
      if (s == null) return;
      if (s.isOver) return;
      if (s.isHalftime) {
        play.beginSecondHalf();
        continue;
      }
      if (s.step == TurnStep.resolved) {
        play.nextWord();
        continue;
      }
      if (s.step == TurnStep.awaitingClue) {
        play.submitClue(AiPlayer.clueFor(s.secretWord, variant: s.wordIndex));
      } else if (s.step == TurnStep.awaitingGuess) {
        play.submitGuess(i.isEven ? s.secretWord : 'Wrong');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenKey = switch (_scene) {
      '01_welcome' => 'welcome',
      '02_create_account' => 'create',
      '03_daily_login' => 'login',
      '04_email_sign_in' => 'email',
      '05_opening_home' => 'home',
      '06_character_builder' => 'character',
      '07_upcoming_games' => 'upcoming',
      '08_studio' => 'studio',
      '09_join_by_code' => 'join',
      '10_lobby_room' => 'lobby',
      _ => 'play',
    };
    return Title(
      title: 'STORE_SCENE:$_scene',
      color: const Color(0xFF5B2D8E),
      child: KeyedSubtree(
        key: ValueKey(screenKey),
        child: switch (_scene) {
          '01_welcome' => const WelcomeScreen(),
          '02_create_account' => const CreateAccountScreen(),
          '03_daily_login' => const DailyLoginScreen(),
          '04_email_sign_in' => const EmailSignInScreen(),
          '05_opening_home' => const OpeningScreen(),
          '06_character_builder' => const CharacterCreationScreen(),
          '07_upcoming_games' => const UpcomingGamesScreen(),
          '08_studio' => const StudioScreen(),
          '09_join_by_code' => const JoinByCodeScreen(),
          '10_lobby_room' => const LobbyRoomScreen(),
          '11_play_kickoff' ||
          '12_play_clue' ||
          '12b_play_bubbles' ||
          '13_play_winner' =>
            const PlayScreen(studioPass: true),
          '14_prize_room' => const PrizeRoomScreen(),
          '15_paywall' => const PaywallScreen(),
          '16_friends' => const FriendsScreen(),
          _ => const WelcomeScreen(),
        },
      ),
    );
  }
}

SupabaseClient _offlineClient() =>
    SupabaseClient('https://demo.supabase.co', 'demo-anon-key');

Character _rosie() => const Character(
      displayName: 'Rosie',
      base: 'body-female',
      hair: 'hair-f1',
      outfit: 'outfit-f1',
      glasses: 'glasses-f-round',
    );

/// Spec cast for the live studio (A Greg / B Rosie / A Buddy / B Pearl).
/// Buddy matches Ronna’s close-up: female, sun hat, glasses, purple top.
Character _greg() => const Character(
      displayName: 'Greg',
      base: 'body-male',
      hair: 'hair-m2',
      outfit: 'outfit-m4',
      glasses: 'glasses-m-round',
    );

Character _rosieSeat() => const Character(
      displayName: 'Rosie',
      base: 'body-female',
      hair: 'hair-f1',
      outfit: 'outfit-f3',
      glasses: 'glasses-f-round',
      earrings: 'earring-1',
    );

Character _buddy() => const Character(
      displayName: 'Buddy',
      base: 'body-female',
      hair: 'hair-f4',
      outfit: 'outfit-f5',
      glasses: 'glasses-f-cat',
      hat: 'hat-f-sun',
    );

Character _pearl() => const Character(
      displayName: 'Pearl',
      base: 'body-female',
      hair: 'hair-f8',
      outfit: 'outfit-f6',
      glasses: 'glasses-f-round',
      earrings: 'earring-2',
    );

PrizeRoom _demoPrizeRoom() => PrizeRoom(
      gamesPlayed: 12,
      gamesWon: 3,
      items: [
        const PrizeItem(
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
          earnedAt: DateTime.now().subtract(const Duration(days: 6)),
        ),
        const PrizeItem(
          id: 'trophy-10-games',
          kind: 'trophy',
          title: '10 Games',
          description: 'Played 10 matches end to end.',
          assetPath: 'assets/images/trophies/trophy-10-games.png',
          sortOrder: 20,
          earned: true,
        ),
        const PrizeItem(
          id: 'trophy-50-games',
          kind: 'trophy',
          title: '50 Games',
          description: 'Played 50 matches.',
          assetPath: 'assets/images/trophies/trophy-50-games.png',
          sortOrder: 30,
          earned: false,
        ),
      ],
    );

class _SilentOutput implements SoundOutput {
  @override
  bool get isSilent => true;

  @override
  bool get isLoopPlaying => false;
  @override
  Future<void> configure() async {}
  @override
  Future<void> playLoop(String asset, double volume) async {}
  @override
  Future<void> ensureLoop(String asset, double volume) async {}
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

class _DemoAuthController extends AuthController {
  _DemoAuthController()
      : super(
          AuthService(
            client: _offlineClient(),
            deviceService: DeviceService(),
            profileService: ProfileService(_offlineClient()),
            trialService: TrialService(_offlineClient()),
          ),
        );

  @override
  String? get rememberedName => 'Rosie';

  @override
  Profile? get profile => Profile(
        id: 'demo-host',
        firstName: 'Rosie',
        deviceId: 'demo-device',
        trialStartedAt: DateTime.now().toUtc(),
        trialUsed: true,
        createdAt: DateTime.now().toUtc(),
        gamesPlayed: 12,
        gamesWon: 3,
      );

  @override
  Future<void> signOut() async {}
}

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

class _InMemoryLobbyService extends LobbyService {
  _InMemoryLobbyService() : super(_offlineClient());

  static const String _hostId = 'demo-host';
  Game? _game;
  List<GamePlayer> _players = const [];
  final _playersCtrl = StreamController<List<GamePlayer>>.broadcast();
  final _gameCtrl = StreamController<Game?>.broadcast();

  GamePlayer _seat(int seat, String name, {required bool isAi}) => GamePlayer(
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

  @override
  Future<Game> createGame({bool isPublic = false}) async {
    _game = Game(
      id: 'demo-game',
      code: '4827',
      hostId: _hostId,
      status: GameStatus.lobby,
      isPublic: isPublic,
      maxPlayers: 4,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
    _players = [_seat(0, 'Rosie', isAi: false)];
    return _game!;
  }

  @override
  Future<void> fillSeats(String gameId) async {
    _players = [
      _seat(0, 'Rosie', isAi: false),
      _seat(1, 'Walter', isAi: true),
      _seat(2, 'Grace', isAi: true),
      _seat(3, 'Mabel', isAi: true),
    ];
    _playersCtrl.add(List.of(_players));
  }

  @override
  Future<Game> joinByCode(String code) => createGame(isPublic: false);

  @override
  Future<Game> joinSeat(String code, int seat) => createGame(isPublic: false);

  @override
  Future<Game> quickMatch() => createGame(isPublic: true);

  @override
  Future<GamePreview> peekByCode(String code) async {
    await createGame();
    return GamePreview(
      gameId: 'demo-game',
      code: '4827',
      maxPlayers: 4,
      seatsTaken: _players.length,
      alreadyMember: false,
      players: _players,
    );
  }

  @override
  Future<List<GamePlayer>> loadPlayers(String gameId) async => List.of(_players);

  @override
  Future<Game> loadGame(String gameId) async => _game!;

  @override
  Future<void> startGame(String gameId) async {}

  @override
  Future<void> leaveGame(String gameId) async {}

  @override
  Future<List<Game>> listOpenGames() async => [_game!];

  @override
  Stream<List<GamePlayer>> watchPlayers(String gameId) => _playersCtrl.stream;

  @override
  Stream<Game?> watchGame(String gameId) => _gameCtrl.stream;

  @override
  bool isHostOf(Game game) => game.hostId == _hostId;
}

class _DemoGameplayService extends GameplayService {
  _DemoGameplayService() : super(_offlineClient());

  @override
  String? get currentUserId => 'demo-host';

  @override
  Future<void> beginPlay(String gameId) async {}

  @override
  Future<List<String>> loadWords(String gameId) async =>
      WordBank.deal(16, random: Random(20260714));

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

class _DemoFriendService extends FriendService {
  _DemoFriendService() : super(_offlineClient());

  @override
  Future<List<Friend>> listFriends() async => [
        Friend(
          id: 'f1',
          displayName: 'Walter',
          character: AiPlayer.lookFor('A2:Walter', 'Walter'),
        ),
        Friend(
          id: 'f2',
          displayName: 'Grace',
          character: AiPlayer.lookFor('B1:Grace', 'Grace'),
        ),
      ];

  @override
  Future<List<FriendRequest>> listRequests() async => [
        FriendRequest(
          fromId: 'r1',
          displayName: 'Mabel',
          character: AiPlayer.lookFor('B2:Mabel', 'Mabel'),
        ),
      ];

  @override
  Future<List<GameInvite>> listInvites() async => const [];
}
