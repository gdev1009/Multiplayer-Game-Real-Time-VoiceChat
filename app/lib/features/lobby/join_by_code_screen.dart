import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import '../../core/widgets/pin_pad.dart';
import 'lobby_controller.dart';

/// Enter a friend's 4-digit game code to join their room.
class JoinByCodeScreen extends StatefulWidget {
  const JoinByCodeScreen({super.key});

  @override
  State<JoinByCodeScreen> createState() => _JoinByCodeScreenState();
}

class _JoinByCodeScreenState extends State<JoinByCodeScreen> {
  String _code = '';

  Future<void> _submit() async {
    final lobby = context.read<LobbyController>();
    final ok = await lobby.joinByCode(_code);
    if (!mounted) return;
    if (ok) {
      // Replace this screen with the room so Back returns to the hub.
      Navigator.of(context).pushReplacementNamed(AppRoutes.lobbyRoom);
    } else if (lobby.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lobby.error!, style: AppText.body),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      lobby.clearError();
      setState(() => _code = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobby = context.watch<LobbyController>();
    final complete = _code.length == 4;

    return AppPage(
      title: 'Join with a Code',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          const HostGreeting(
            message: 'Type the four numbers your friend shared with you.',
          ),
          const SizedBox(height: AppSpacing.xl),
          _CodeBoxes(code: _code),
          const SizedBox(height: AppSpacing.xl),
          PinPad(
            value: _code,
            onChanged: (v) => setState(() => _code = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          BigButton(
            label: 'Join Game',
            icon: Icons.login_rounded,
            isLoading: lobby.busy,
            onPressed:
                (!complete || lobby.busy) ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Shows the entered digits as four large boxes.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < code.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          width: 60,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: filled ? AppColors.deepPurple : AppColors.lavender,
              width: 2.5,
            ),
          ),
          child: Text(
            filled ? code[i] : '',
            style: AppText.display,
          ),
        );
      }),
    );
  }
}
