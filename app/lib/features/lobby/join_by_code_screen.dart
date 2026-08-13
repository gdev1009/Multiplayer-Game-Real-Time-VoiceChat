import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import '../../core/widgets/pin_pad.dart';
import 'join_preview_screen.dart';
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
    // Peek first so the player can see who's already in the game (and which
    // team they'll land on) before committing to join.
    final preview = await lobby.peekByCode(_code);
    if (!mounted) return;
    if (preview != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => JoinPreviewScreen(preview: preview),
        ),
      );
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
          SizedBox(
            height: AppResponsive.isShort(context)
                ? AppSpacing.sm
                : AppSpacing.md,
          ),
          const HostGreeting(
            message: 'Type the four numbers your friend shared with you.',
          ),
          SizedBox(
            height: AppResponsive.isShort(context)
                ? AppSpacing.md
                : AppSpacing.xl,
          ),
          _CodeBoxes(code: _code),
          SizedBox(
            height: AppResponsive.isShort(context)
                ? AppSpacing.md
                : AppSpacing.xl,
          ),
          PinPad(
            value: _code,
            onChanged: (v) => setState(() => _code = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          BigButton(
            label: 'See the Game',
            icon: Icons.arrow_forward_rounded,
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
    final boxW = AppResponsive.s(context, 60).clamp(48.0, 60.0);
    final boxH = AppResponsive.s(context, 76).clamp(56.0, 76.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < code.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          width: boxW,
          height: boxH,
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
            style: AppText.display.copyWith(
              fontSize: AppResponsive.displaySize(context),
            ),
          ),
        );
      }),
    );
  }
}
