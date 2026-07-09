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
import 'forgot_pin_screen.dart';

/// Step-by-step account creation: name → email → choose PIN → confirm PIN.
/// One decision per screen, large controls, friendly errors.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, this.initialEmail});

  /// Pre-fills the email field (e.g. when arriving from the "please create one"
  /// sign-in prompt), so the player doesn't retype it.
  final String? initialEmail;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

enum _Step { name, email, pin, confirmPin }

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  _Step _step = _Step.name;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _pin = '';
  String _confirmPin = '';

  String? _error;
  bool _busy = false;

  /// True when the chosen email already has an account, so we can offer the
  /// "Forgot my PIN" recovery flow right from the error.
  bool _offerForgotPin = false;

  @override
  void initState() {
    super.initState();
    final email = widget.initialEmail?.trim();
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _goTo(_Step step) => setState(() {
        _error = null;
        _offerForgotPin = false;
        _step = step;
      });

  void _back() {
    switch (_step) {
      case _Step.name:
        Navigator.of(context).maybePop();
      case _Step.email:
        _goTo(_Step.name);
      case _Step.pin:
        setState(() => _pin = '');
        _goTo(_Step.email);
      case _Step.confirmPin:
        setState(() => _confirmPin = '');
        _goTo(_Step.pin);
    }
  }

  void _onNameNext() {
    final err = Validators.firstName(_nameController.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    _goTo(_Step.email);
  }

  void _onEmailNext() {
    final err = Validators.email(_emailController.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    _goTo(_Step.pin);
  }

  void _onPinComplete() {
    final err = Validators.pin(_pin);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    _goTo(_Step.confirmPin);
  }

  Future<void> _onConfirmComplete() async {
    if (_confirmPin != _pin) {
      setState(() {
        _error = 'The two PINs do not match. Let\'s try again.';
        _confirmPin = '';
        _step = _Step.pin;
        _pin = '';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offerForgotPin = false;
    });

    try {
      await context.read<AuthController>().createAccount(
            firstName: _nameController.text,
            email: _emailController.text,
            pin: _pin,
          );
      // Account created and signed in. Remove this pushed flow so the
      // AuthGate's Home screen becomes visible.
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      // If the email is already taken, the answer is to recover the PIN, not
      // to create a second account — so surface the "Forgot my PIN" action.
      final emailTaken = e.message.toLowerCase().contains('already');
      setState(() {
        _busy = false;
        _error = e.message;
        _offerForgotPin = emailTaken;
        _step = emailTaken ? _Step.email : _Step.pin;
        _pin = '';
        _confirmPin = '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  void _openForgotPin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ForgotPinScreen(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Create Account',
      showBack: true,
      onBack: _back,
      child: switch (_step) {
        _Step.name => _nameStep(),
        _Step.email => _emailStep(),
        _Step.pin => _pinStep(),
        _Step.confirmPin => _confirmStep(),
      },
    );
  }

  Widget _stepWrap({required String heading, String? subtitle, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(heading, style: AppText.title),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppText.bodyMuted),
        ],
        const SizedBox(height: AppSpacing.xl),
        ...children,
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: AppText.error, textAlign: TextAlign.center),
        ],
        if (_offerForgotPin) ...[
          const SizedBox(height: AppSpacing.md),
          BigButton(
            label: 'Forgot my PIN',
            icon: Icons.lock_reset,
            variant: BigButtonVariant.secondary,
            onPressed: _openForgotPin,
          ),
        ],
      ],
    );
  }

  Widget _nameStep() {
    return _stepWrap(
      heading: 'What is your first name?',
      subtitle: 'This is the name your friends will see.',
      children: [
        BigTextField(
          label: 'First name',
          controller: _nameController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _onNameNext(),
        ),
        const SizedBox(height: AppSpacing.xl),
        BigButton(label: 'Next', icon: Icons.arrow_forward, onPressed: _onNameNext),
      ],
    );
  }

  Widget _emailStep() {
    return _stepWrap(
      heading: 'What is your email?',
      subtitle:
          'We only use this if you ever forget your PIN. It is never shown '
          'and never used for anything else.',
      children: [
        BigTextField(
          label: 'Email address',
          controller: _emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _onEmailNext(),
        ),
        const SizedBox(height: AppSpacing.xl),
        BigButton(label: 'Next', icon: Icons.arrow_forward, onPressed: _onEmailNext),
      ],
    );
  }

  Widget _pinStep() {
    return _stepWrap(
      heading: 'Choose a 4-number PIN',
      subtitle: 'Pick 4 numbers you will remember, like your bank card.',
      children: [
        PinPad(
          value: _pin,
          onChanged: (value) {
            setState(() {
              _error = null;
              _pin = value;
            });
            if (value.length == 4) {
              HapticFeedback.lightImpact();
              _onPinComplete();
            }
          },
        ),
      ],
    );
  }

  Widget _confirmStep() {
    return _stepWrap(
      heading: 'Type your PIN again',
      subtitle: 'Just to make sure it is correct.',
      children: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          PinPad(
            value: _confirmPin,
            onChanged: (value) {
              setState(() {
                _error = null;
                _confirmPin = value;
              });
              if (value.length == 4) {
                HapticFeedback.lightImpact();
                _onConfirmComplete();
              }
            },
          ),
      ],
    );
  }
}
