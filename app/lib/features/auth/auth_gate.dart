import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_controller.dart';
import 'screens/daily_login_screen.dart';
import 'screens/welcome_screen.dart';
import '../home/home_screen.dart';
import '../../core/theme/app_colors.dart';

/// Routes to the correct screen based on authentication state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthController>().status;

    final Widget child = switch (status) {
      AuthStatus.unknown => const _Splash(),
      AuthStatus.needsAccount => const WelcomeScreen(),
      AuthStatus.locked => const DailyLoginScreen(),
      AuthStatus.signedIn => const HomeScreen(),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(status), child: child),
    );
  }
}


class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

