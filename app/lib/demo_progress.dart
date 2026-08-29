// Standalone autoplay demo for a *current* M3–M8 progress recording.
//
// Cycles through real shipping screens (Opening with idle Rosie, Prize Room,
// Lobby, live Studio Stage with AI characters + Guy Smiley) on a timer so a
// capture script can screenshot each beat without manual clicks.
//
// Run:
//   flutter build web -t lib/demo_progress.dart --no-tree-shake-icons
//   python3 -m http.server 8092 --directory build/web
//   python3 tools/capture_progress_reel.py
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/character/character_controller.dart';
import 'features/game/ai_player.dart';
import 'features/game/game_engine.dart';
import 'features/game/gameplay_controller.dart';
import 'features/game/play_screen.dart';
import 'features/game/word_bank.dart';
import 'features/home/opening_screen.dart';
import 'features/lobby/lobby_controller.dart';
import 'features/lobby/lobby_room_screen.dart';
import 'features/billing/paywall_screen.dart';
import 'features/prizes/prize_controller.dart';
import 'features/prizes/prize_room_screen.dart';
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

/// Scene keys the capture script watches for (exported via [ProgressSceneTag]).
const List<String> kProgressScenes = [
  '01_home_idle',
  '02_prize_room',
  '03_lobby_filled',
  '04_play_kickoff',
  '05_play_clue',
  '06_play_score',
  '07_halftime',
  '08_winner',
  '09_subscription_paywall',
];

void main() {
  final charService = _InMemoryCharacterService()
    ..seed(_rosie());
  final prizeCtrl = PrizeController(PrizeService(_offlineClient()))
    ..seedForDemo(_demoPrizeRoom());
  final billing = BillingService(_offlineClient());
  final gameplay = GameplayController()
    ..startLocal(
      words: WordBank.deal(16, random: Random(20260714)),
      names: const {
        'A1': 'Rosie',
        'A2': 'Walter',
        'B1': 'Grace',
        'B2': 'Mabel',
      },
      myRole: 'A1',
      aiByRole: const {
        'A1': false,
        'A2': true,
        'B1': true,
        'B2': true,
      },
      charactersByRole: {
        'A1': _rosie(),
        'A2': AiPlayer.lookFor('A2:Walter', 'Walter'),
        'B1': AiPlayer.lookFor('B1:Grace', 'Grace'),
        'B2': AiPlayer.lookFor('B2:Mabel', 'Mabel'),
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
        Provider<BillingService>.value(value: billing),
        Provider<EntitlementService>(
          create: (_) => EntitlementService(
            profileService: ProfileService(_offlineClient()),
            billingService: billing,
          ),
        ),
        Provider<GameplayService>.value(value: _DemoGameplayService()),
      ],
      child: const ProgressDemoApp(),
    ),
  );
}

class ProgressDemoApp extends StatelessWidget {
  const ProgressDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Match Word — Progress (M3–M8)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _ProgressSequencer(),
    );
  }
}

/// Advances through [kProgressScenes], exposing the active key viaSemantics
/// for the capture script (`document.querySelector('[data-scene]')`).
class _ProgressSequencer extends StatefulWidget {
  const _ProgressSequencer();

  @override
  State<_ProgressSequencer> createState() => _ProgressSequencerState();
}

class _ProgressSequencerState extends State<_ProgressSequencer> {
  int _index = 0;
  Timer? _timer;

  String get _scene => kProgressScenes[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepLobby());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % kProgressScenes.length;
      });
      _onSceneEntered(_scene);
    });
    _onSceneEntered(_scene);
  }

  Future<void> _prepLobby() async {
    final lobby = context.read<LobbyController>();
    await lobby.createGame(isPublic: true);
    await lobby.fillSeats();
  }

  void _onSceneEntered(String scene) {
    final play = context.read<GameplayController>();
    final state = play.state;
    if (state == null) return;

    // Jump the local match to representative beats for each play scene.
    if (scene == '04_play_kickoff') {
      // leave as dealt
    } else if (scene == '05_play_clue' && state.step == TurnStep.awaitingClue) {
      play.submitClue('Petals');
    } else if (scene == '06_play_score') {
      if (state.step == TurnStep.awaitingClue) play.submitClue('Petals');
      final s2 = play.state;
      if (s2 != null && s2.step == TurnStep.awaitingGuess) {
        play.submitGuess(s2.secretWord);
      }
    } else if (scene == '07_halftime' || scene == '08_winner') {
      _fastForward(play, toHalftime: scene == '07_halftime');
    }
  }

  void _fastForward(GameplayController play, {required bool toHalftime}) {
    // Force-drive a few turns so scores / phases look alive for the reel.
    for (var i = 0; i < 12; i++) {
      final s = play.state;
      if (s == null) return;
      if (toHalftime && s.isHalftime) return;
      if (!toHalftime && s.isOver) return;
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
        // Win most words so Team A looks strong for the winner beat.
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
    // Key by *screen family*, not every beat — remounting PlayScreen each
    // clue/score/halftime frame re-decodes every character PNG from scratch.
    final screenKey = switch (_scene) {
      '01_home_idle' => 'home',
      '02_prize_room' => 'prizes',
      '03_lobby_filled' => 'lobby',
      '09_subscription_paywall' => 'paywall',
      _ => 'play',
    };
    return Title(
      title: 'PROGRESS_SCENE:$_scene',
      color: const Color(0xFF5B2D8E),
      child: ProgressSceneTag(
        scene: _scene,
        child: KeyedSubtree(
          key: ValueKey(screenKey),
          child: switch (_scene) {
            '01_home_idle' => const OpeningScreen(),
            '02_prize_room' => const PrizeRoomScreen(),
            '03_lobby_filled' => const LobbyRoomScreen(),
            '04_play_kickoff' ||
            '05_play_clue' ||
            '06_play_score' ||
            '07_halftime' ||
            '08_winner' =>
              const PlayScreen(studioPass: true),
            '09_subscription_paywall' => const PaywallScreen(),
            _ => const OpeningScreen(),
          },
        ),
      ),
    );
  }
}

/// Marker widget: Flutter web exposes `data-scene` on the host element so
/// Puppeteer/Chrome can wait between captures.
class ProgressSceneTag extends StatelessWidget {
  const ProgressSceneTag({super.key, required this.scene, required this.child});
  final String scene;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HtmlElementViewIgnore(
      scene: scene,
      child: child,
    );
  }
}

/// Lightweight wrap that also paints an invisible semantics label browsers can
/// query via text content (`PROGRESS_SCENE:…`).
class HtmlElementViewIgnore extends StatelessWidget {
  const HtmlElementViewIgnore({
    super.key,
    required this.scene,
    required this.child,
  });
  final String scene;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          child: SizedBox(
            width: 1,
            height: 1,
            child: Text(
              'PROGRESS_SCENE:$scene',
              style: const TextStyle(fontSize: 1, color: Color(0x01000000)),
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Shared demo plumbing (mirrors demo_journey) ----

SupabaseClient _offlineClient() =>
    SupabaseClient('https://demo.supabase.co', 'demo-anon-key');

Character _rosie() => const Character(
      displayName: 'Rosie',
      base: 'body-female',
      hair: 'hair-f1',
      outfit: 'outfit-f1',
      glasses: 'glasses-f-round',
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
          description: 'Played 50 matches — a true studio regular.',
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
  Future<void> resumeLoopIfNeeded() async {}
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
  String? get rememberedName => 'Sunny';

  @override
  Profile? get profile => Profile(
        id: 'demo-host',
        firstName: 'Sunny',
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
