import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/big_text_field.dart';
import '../../../core/widgets/pin_pad.dart';
import '../../../services/auth_failure.dart';
import '../auth_controller.dart';

/// PIN recovery: email (once) → one-time code → new PIN.
///
/// If this device already knows the account email, the email step is skipped.
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key, this.initialEmail});

  /// Prefill / skip email when known (create-account conflict, daily login).
  final String? initialEmail;

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

enum _Step { email, code, newPin }

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  _Step _step = _Step.email;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  String _newPin = '';
  String? _lockedEmail;

  String? _error;
  bool _busy = false;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapEmail());
  }

  Future<void> _bootstrapEmail() async {
    final auth = context.read<AuthController>();
    final fromArg = widget.initialEmail?.trim();
    final remembered = auth.rememberedEmail?.trim();
    final email = (fromArg != null && fromArg.isNotEmpty)
        ? fromArg
        : (remembered != null && remembered.isNotEmpty ? remembered : null);

    if (email != null) {
      _emailController.text = email;
      _lockedEmail = email;
      // Skip the email form — send code to the saved address.
      setState(() {
        _booting = false;
        _busy = true;
        _error = null;
      });
      try {
        await auth.sendRecoveryCode(email: email);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _step = _Step.code;
        });
      } on AuthFailure catch (e) {
        if (!mounted) return;
        setState(() {
          _booting = false;
          _busy = false;
          _step = _Step.email;
          _error = e.message;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _booting = false;
          _busy = false;
          _step = _Step.email;
          _error = 'We could not send the code. Please try again.';
        });
      }
      return;
    }

    if (mounted) setState(() => _booting = false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final err = Validators.email(_emailController.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<AuthController>()
          .sendRecoveryCode(email: _emailController.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lockedEmail = _emailController.text.trim();
        _step = _Step.code;
      });
    } on AuthFailure catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('We could not send the code. Please try again.');
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length < 6) {
      setState(() => _error = 'Please enter the 6-number code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().verifyRecoveryCode(
            email: _emailController.text,
            code: _codeController.text,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.newPin;
      });
    } on AuthFailure catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('That code is not correct or has expired.');
    }
  }

  Future<void> _saveNewPin() async {
    final err = Validators.pin(_newPin);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().setNewPinAndSignIn(pin: _newPin);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('We could not save your new PIN. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const AppPage(
        title: 'Forgot My PIN',
        showBack: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AppPage(
      title: 'Forgot My PIN',
      showBack: true,
      child: switch (_step) {
        _Step.email => _emailStep(),
        _Step.code => _codeStep(),
        _Step.newPin => _newPinStep(),
      },
    );
  }

  Widget _wrap({
    required String heading,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(heading, style: AppText.title),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppText.bodyMuted),
        ],
        const SizedBox(height: AppSpacing.lg),
        ...children,
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: AppText.error, textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Widget _emailStep() {
    return _wrap(
      heading: 'What is your email?',
      subtitle: 'We will send you a one-time code to reset your PIN. '
          'You only need to enter this once on this device.',
      children: [
        BigTextField(
          label: 'Email address',
          controller: _emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: AppSpacing.lg),
        BigButton(
          label: 'Send Code',
          icon: Icons.mail_outline,
          isLoading: _busy,
          onPressed: _busy ? null : _sendCode,
        ),
      ],
    );
  }

  Widget _codeStep() {
    final to = _lockedEmail ?? _emailController.text.trim();
    return _wrap(
      heading: 'Enter your code',
      subtitle: to.isEmpty
          ? 'Check your email and type the 6-number code here.'
          : 'We sent a code to $to. Type the 6-number code here.',
      children: [
        BigTextField(
          label: 'Code',
          controller: _codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _verifyCode(),
        ),
        const SizedBox(height: AppSpacing.lg),
        BigButton(
          label: 'Continue',
          icon: Icons.arrow_forward,
          isLoading: _busy,
          onPressed: _busy ? null : _verifyCode,
        ),
      ],
    );
  }

  Widget _newPinStep() {
    return _wrap(
      heading: 'Choose a new 4-number PIN',
      subtitle: 'Pick 4 numbers you will remember.',
      children: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Center(
            child: PinPad(
              value: _newPin,
              onChanged: (value) {
                setState(() {
                  _error = null;
                  _newPin = value;
                });
                if (value.length == 4) {
                  HapticFeedback.lightImpact();
                  _saveNewPin();
                }
              },
            ),
          ),
      ],
    );
  }
}
