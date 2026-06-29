import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/pin_pad.dart';
import '../../../services/auth_failure.dart';
import '../auth_controller.dart';
import 'forgot_pin_screen.dart';

/// Returning-player login: greet by name, enter the 4-number PIN.
class DailyLoginScreen extends StatefulWidget {
  const DailyLoginScreen({super.key});

  @override
  State<DailyLoginScreen> createState() => _DailyLoginScreenState();
}

class _DailyLoginScreenState extends State<DailyLoginScreen> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  Future<void> _submit(String name) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<AuthController>()
          .dailyLogin(firstName: name, pin: _pin);
      // AuthGate switches to home on success.
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
        _pin = '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthController>().rememberedName ?? 'friend';

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Icon(Icons.waving_hand_rounded,
              size: 72, color: AppColors.gold),
          const SizedBox(height: AppSpacing.md),
          Text('Welcome back,',
              style: AppText.title, textAlign: TextAlign.center),
          Text(name, style: AppText.display, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          Text('Enter your 4-number PIN',
              style: AppText.body, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Center(
              child: PinPad(
                value: _pin,
                onChanged: (value) {
                  setState(() {
                    _error = null;
                    _pin = value;
                  });
                  if (value.length == 4) {
                    HapticFeedback.lightImpact();
                    _submit(name);
                  }
                },
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: AppText.error, textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppSpacing.lg),
          BigButton(
            label: 'Forgot My PIN',
            variant: BigButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ForgotPinScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
