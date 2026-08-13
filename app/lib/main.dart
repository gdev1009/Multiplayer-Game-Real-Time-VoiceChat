import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'features/auth/auth_controller.dart';
import 'features/character/character_controller.dart';
import 'features/friends/friend_controller.dart';
import 'features/lobby/lobby_controller.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/prizes/prize_controller.dart';
import 'services/audio_controller.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
import 'services/character_service.dart';
import 'services/device_service.dart';
import 'services/entitlement_service.dart';
import 'services/friend_service.dart';
import 'services/gameplay_service.dart';
import 'services/lobby_service.dart';
import 'services/onboarding_service.dart';
import 'services/prize_service.dart';
import 'services/profile_service.dart';
import 'services/speech_input_service.dart';
import 'services/trial_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  // Load Supabase credentials from the bundled .env file.
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  final client = Supabase.instance.client;

  final deviceService = DeviceService();
  final profileService = ProfileService(client);
  final trialService = TrialService(client);
  final authService = AuthService(
    client: client,
    deviceService: deviceService,
    profileService: profileService,
    trialService: trialService,
  );
  final characterService = CharacterService(client);
  final lobbyService = LobbyService(client);
  final gameplayService = GameplayService(client);
  final friendService = FriendService(client);
  final prizeService = PrizeService(client);
  final billingService = BillingService(client);
  final entitlementService = EntitlementService(
    profileService: profileService,
    billingService: billingService,
  );
  final onboardingService = OnboardingService(profileService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(authService)),
        ChangeNotifierProvider(
          create: (_) => OnboardingController(onboardingService),
        ),
        ChangeNotifierProvider(
          create: (_) => CharacterController(characterService),
        ),
        ChangeNotifierProvider(create: (_) => LobbyController(lobbyService)),
        ChangeNotifierProvider(create: (_) => FriendController(friendService)),
        ChangeNotifierProvider(create: (_) => PrizeController(prizeService)),
        Provider<GameplayService>.value(value: gameplayService),
        Provider<EntitlementService>.value(value: entitlementService),
        Provider<BillingService>.value(value: billingService),
        ChangeNotifierProvider(create: (_) => AudioController()),
        Provider<SpeechInputService>(
          create: (_) => SpeechInputService(),
          dispose: (_, s) => s.dispose(),
        ),
      ],
      child: const MatchWordApp(),
    ),
  );
}
