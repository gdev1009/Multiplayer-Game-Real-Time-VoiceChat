import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';

/// Dual clue/guess input for gameplay (Milestone 5).
///
/// Per the spec, players may **speak or type** their word, and a text fallback
/// is *always* available. This widget shows a big, senior-friendly text field
/// with a Send button, plus a large press-to-speak microphone button.
///
/// Speech-to-text itself arrives with the voice-provider work; to keep this
/// milestone self-contained the mic is wired through an optional
/// [onSpeakRequested] callback. When it is null the mic gently guides the
/// player to type instead, so the flow never dead-ends. The recognised text is
/// shown in the field before sending, so what goes to all players is exactly
/// what the player confirms.
class WordInput extends StatefulWidget {
  const WordInput({
    super.key,
    required this.label,
    required this.hint,
    required this.onSubmit,
    this.enabled = true,
    this.onSpeakRequested,
  });

  /// The action label, e.g. "Your clue" or "Your guess".
  final String label;

  /// Placeholder text inside the field.
  final String hint;

  /// Called with the trimmed word when the player sends it.
  final ValueChanged<String> onSubmit;

  /// Whether the input accepts entry right now (it's this player's turn).
  final bool enabled;

  /// Optional press-to-speak handler that returns recognised text (or null if
  /// cancelled / unavailable). When null, the mic prompts the player to type.
  final Future<String?> Function()? onSpeakRequested;

  @override
  State<WordInput> createState() => _WordInputState();
}

class _WordInputState extends State<WordInput> {
  final _controller = TextEditingController();
  bool _listening = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  Future<void> _speak() async {
    final handler = widget.onSpeakRequested;
    if (handler == null) {
      // No speech engine wired yet — guide the player to the text field.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can type your word here any time.',
            style: AppText.body,
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _listening = true);
    try {
      final heard = await handler();
      if (heard != null && heard.trim().isNotEmpty) {
        _controller.text = heard.trim();
      }
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.label, style: AppText.title),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Big press-to-speak mic.
              _MicButton(
                listening: _listening,
                enabled: enabled,
                onTap: enabled ? _speak : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: enabled,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: AppText.body,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: AppText.bodyMuted,
                    filled: true,
                    fillColor: AppColors.warmBeige,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: AppSpacing.buttonHeight,
            child: FilledButton.icon(
              onPressed: enabled ? _send : null,
              icon: const Icon(Icons.send_rounded, size: 26),
              label: const Text('Send', style: AppText.action),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Speak or type — whatever is easiest for you.',
            style: AppText.bodyMuted.copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.enabled,
    required this.onTap,
  });

  final bool listening;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.divider
        : (listening ? AppColors.gold : AppColors.deepPurple);
    return Semantics(
      button: true,
      label: listening ? 'Listening' : 'Press to speak',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: enabled ? AppColors.tileShadow : null,
          ),
          child: Icon(
            listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
