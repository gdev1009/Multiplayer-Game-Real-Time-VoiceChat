import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_gate.dart';

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
    );
  }
}
