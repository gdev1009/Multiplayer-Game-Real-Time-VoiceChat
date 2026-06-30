import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'features/auth/auth_controller.dart';
import 'services/auth_service.dart';
import 'services/device_service.dart';
import 'services/profile_service.dart';
import 'services/trial_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthController(authService),
      child: const MatchWordApp(),
    ),
  );
}
