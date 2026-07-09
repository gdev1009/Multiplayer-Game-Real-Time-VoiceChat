import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/big_text_field.dart';
import '../../../core/widgets/pin_pad.dart';
import '../../../services/auth_failure.dart';
import '../../../services/auth_service.dart';
import '../auth_controller.dart';
import 'create_account_screen.dart';
import 'forgot_pin_screen.dart';

/// "I already have an account" sign-in:
///
///  - Enter email → Next.
///  - If the account is already on this device, greet by name and ask for the
///    PIN.
///  - If it's a fresh device, email a one-time code to verify ownership, then
///    ask for the PIN. Entering the correct PIN restores silent sign-in on
///    this device.
///
/// If the PIN is wrong, the player can tap "Forgot my PIN" to reset it.
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

enum _Step { email, code, pin }

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  _Step _step = _Step.email;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  String _pin = '';
  String _accountName = '';

  String? _error;
  bool _busy = false;

  /// True when the email has no account at all, so we can offer to create one.
  bool _offerCreate = false;

  /// True on a fresh device: the PIN is checked on the server and a one-time
  /// code is required after it. False on the fast local path (no code).
  bool _remote = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final err = Validators.email(_emailController.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _offerCreate = false;
    });
    try {
      final result = await context
          .read<AuthController>()
          .beginEmailSignIn(email: _emailController.text);
      if (!mounted) return;
      switch (result.step) {
        case EmailSignInStep.enterPin:
          // Account already on this device — greet and ask for the PIN. No code.
          setState(() {
            _busy = false;
            _remote = false;
            _accountName = result.name ?? '';
            _step = _Step.pin;
            _pin = '';
          });
        case EmailSignInStep.enterPinRemote:
          // Fresh device — ask for the PIN next; it's verified on the server,
          // and only then do we email a one-time code.
          setState(() {
            _busy = false;
            _remote = true;
            _accountName = '';
            _step = _Step.pin;
            _pin = '';
          });
      }
    } on AuthFailure catch (e) {
      if (!mounted) return;
      _fail(e.message);
    } catch (_) {
      _fail('We could not sign you in. Please try again.');
    }
  }

  Future<void> _submitPin() async {
    setState(() {
      _busy = true;
      _error = null;
      _offerCreate = false;
    });
    try {
      if (_remote) {
        // Fresh device: verify the PIN on the server, then send the code.
        final name = await context
            .read<AuthController>()
            .verifyPinRemoteAndSendCode(
              email: _emailController.text,
              pin: _pin,
            );
        if (!mounted) return;
        setState(() {
          _busy = false;
          _accountName = name;
          _codeController.clear();
          _step = _Step.code;
        });
      } else {
        // Same device: the session is already up, so verify and sign in.
        await context.read<AuthController>().verifyPinSignIn(pin: _pin);
        if (!mounted) return;
        // Signed in — remove this pushed screen so the AuthGate's Opening
        // screen becomes visible.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
        _offerCreate = e.code == 'no_account';
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

  Future<void> _resendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().sendRecoveryCode(
            email: _emailController.text,
          );
      if (!mounted) return;
      setState(() => _busy = false);
    } on AuthFailure catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('We could not send the code. Please try again.');
    }
  }

  Future<void> _submitCode() async {
    if (_codeController.text.trim().length < 6) {
      setState(() => _error = 'Please enter the 6-number code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().completeRemoteSignIn(
            email: _emailController.text,
            code: _codeController.text,
            pin: _pin,
          );
      if (!mounted) return;
      // Signed in — remove this pushed screen so the AuthGate's Opening
      // screen becomes visible.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('That code is not correct or has expired.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  void _openForgotPin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForgotPinScreen()),
    );
  }

  void _openCreateAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CreateAccountScreen(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Sign In',
      showBack: true,
      onBack: () {
        switch (_step) {
          case _Step.code:
            // Back to the PIN entry (fresh-device flow: email -> PIN -> code).
            setState(() {
              _step = _Step.pin;
              _error = null;
              _pin = '';
            });
          case _Step.pin:
            setState(() {
              _step = _Step.email;
              _error = null;
              _offerCreate = false;
              _pin = '';
            });
          case _Step.email:
            Navigator.of(context).maybePop();
        }
      },
      child: switch (_step) {
        _Step.email => _emailStep(),
        _Step.pin => _pinStep(),
        _Step.code => _codeStep(),
      },
    );
  }

  Widget _emailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        const Text('What is your email?', style: AppText.title),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Enter the email you used to sign up, then tap Next.',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: AppSpacing.xl),
        BigTextField(
          label: 'Email address',
          controller: _emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitEmail(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: AppText.error, textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppSpacing.xl),
        BigButton(
          label: 'Next',
          icon: Icons.arrow_forward,
          isLoading: _busy,
          onPressed: _busy ? null : _submitEmail,
        ),
      ],
    );
  }

  Widget _codeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        const Text('One last check', style: AppText.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Your PIN is correct! Because this is a new device, we sent a '
          '6-number code to ${_emailController.text.trim()}. Enter it to '
          'finish signing in.',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: AppSpacing.xl),
        BigTextField(
          label: '6-number code',
          controller: _codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitCode(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: AppText.error, textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppSpacing.xl),
        BigButton(
          label: 'Verify',
          icon: Icons.check_rounded,
          isLoading: _busy,
          onPressed: _busy ? null : _submitCode,
        ),
        const SizedBox(height: AppSpacing.md),
        BigButton(
          label: 'Send the code again',
          variant: BigButtonVariant.secondary,
          onPressed: _busy ? null : _resendCode,
        ),
      ],
    );
  }

  Widget _pinStep() {
    final hasName = _accountName.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Icon(
          hasName ? Icons.waving_hand_rounded : Icons.lock_outline_rounded,
          size: 64,
          color: AppColors.gold,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (hasName) ...[
          const Text(
            'Welcome back,',
            style: AppText.title,
            textAlign: TextAlign.center,
          ),
          Text(
            _accountName,
            style: AppText.display,
            textAlign: TextAlign.center,
          ),
        ] else
          const Text(
            'Enter your PIN',
            style: AppText.title,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Enter your 4-number PIN',
          style: AppText.body,
          textAlign: TextAlign.center,
        ),
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
                  _submitPin();
                }
              },
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: AppText.error, textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (_offerCreate)
          BigButton(
            label: 'Create an Account',
            icon: Icons.person_add_alt_1,
            variant: BigButtonVariant.secondary,
            onPressed: _openCreateAccount,
          )
        else
          BigButton(
            label: 'Forgot My PIN',
            variant: BigButtonVariant.secondary,
            onPressed: _openForgotPin,
          ),
      ],
    );
  }
}
