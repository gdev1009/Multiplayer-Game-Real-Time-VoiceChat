import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../home/opening_screen.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/onboarding_screen.dart';
import 'auth_controller.dart';
import 'screens/daily_login_screen.dart';
import 'screens/welcome_screen.dart';

/// Routes to the correct screen based on authentication + first-launch state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthStatus? _syncedStatus;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final onboarding = context.watch<OnboardingController>();

    if (auth.status != _syncedStatus) {
      _syncedStatus = auth.status;
      if (auth.status == AuthStatus.signedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final o = context.read<OnboardingController>();
          o.syncFromProfile(auth.profile);
          if (!o.shouldShow) {
            // Push the local "seen" flag to the account after sign-in.
            o.complete();
          }
        });
      }
    }

    if (auth.status == AuthStatus.unknown || !onboarding.ready) {
      return const _Splash();
    }

    final Widget child = onboarding.shouldShow
        ? const OnboardingScreen()
        : switch (auth.status) {
            AuthStatus.unknown => const _Splash(),
            AuthStatus.needsAccount => const WelcomeScreen(),
            AuthStatus.locked => const DailyLoginScreen(),
            AuthStatus.signedIn => const OpeningScreen(),
          };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(
          onboarding.shouldShow ? 'onboarding' : auth.status,
        ),
        child: child,
      ),
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

