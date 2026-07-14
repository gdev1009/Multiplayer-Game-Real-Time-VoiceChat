import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_gate.dart';
import 'features/character/character_creation_screen.dart';
import 'features/friends/friends_screen.dart';
import 'features/lobby/join_by_code_screen.dart';
import 'features/lobby/lobby_room_screen.dart';
import 'features/lobby/upcoming_games_screen.dart';
import 'features/studio/studio_screen.dart';

/// Root widget. Boots the auth controller and shows the [AuthGate].
class MatchWordApp extends StatefulWidget {
  const MatchWordApp({super.key});

  @override
  State<MatchWordApp> createState() => _MatchWordAppState();
}

class _MatchWordAppState extends State<MatchWordApp> {
  @override
  void initState() {
    super.initState();
    // Decide the first screen once the first frame is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Match Word',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
      routes: {
        AppRoutes.upcomingGames: (_) => const UpcomingGamesScreen(),
        AppRoutes.lobbyRoom: (_) => const LobbyRoomScreen(),
        AppRoutes.joinByCode: (_) => const JoinByCodeScreen(),
        AppRoutes.studio: (_) => const StudioScreen(),
        AppRoutes.character: (_) => const CharacterCreationScreen(),
        AppRoutes.friends: (_) => const FriendsScreen(),
      },
    );
  }
}
