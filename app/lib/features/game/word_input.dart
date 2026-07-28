import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';

/// Dual clue/guess input for gameplay.
///
/// Per the spec, players may **speak or type** their word, and a text fallback
/// is *always* available. This widget shows a big, senior-friendly text field
/// with a Send button, plus a large press-to-speak microphone button.
///
/// When [onSpeakRequested] is provided (device speech recognition), Speak
/// fills the field with the heard word so the player can confirm before Send.
/// When it is null, Speak gently guides them to type instead.
class WordInput extends StatefulWidget {
  const WordInput({
    super.key,
    required this.label,
    required this.hint,
    required this.onSubmit,
    this.enabled = true,
    this.onSpeakRequested,
    this.compact = false,
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

  /// Tight padding for the live studio play screen (more room for the stage).
  final bool compact;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Speak isn’t available here — type your word, then tap Send.',
            style: AppText.body,
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _listening = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Listening… say your one word clearly.',
            style: AppText.body,
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
    try {
      final heard = await handler();
      if (!mounted) return;
      if (heard != null && heard.trim().isNotEmpty) {
        _controller.text = heard.trim();
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Got “${heard.trim()}” — tap Send when it looks right.',
              style: AppText.body,
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn’t catch that — tap Speak again, or type your word.',
              style: AppText.body,
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    if (widget.compact) {
      return _buildDock(enabled);
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.label, style: AppText.title),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.onSpeakRequested != null) ...[
                _MicButton(
                  listening: _listening,
                  enabled: enabled,
                  onTap: enabled ? _speak : null,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
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
          if (widget.onSpeakRequested != null) ...[
            const SizedBox(height: 4),
            Text(
              'Speak or type — whatever is easiest for you.',
              style: AppText.bodyMuted.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Compact studio dock: Speak + type field + Send (spec: choose either).
  Widget _buildDock(bool enabled) {
    return Semantics(
      label: '${widget.label}. Speak or type.',
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF24154A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFF1B159).withValues(alpha: 0.65),
              width: 1.0,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Speak — large chip so seniors see Speak vs Type clearly.
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
                  child: _DockSpeakButton(
                    enabled: enabled,
                    listening: _listening,
                    onTap: enabled ? _speak : null,
                  ),
                ),
                Expanded(
                  child: SizedBox.expand(
                    child: Align(
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _controller,
                        enabled: enabled,
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: AppText.body.copyWith(
                          fontSize: 28,
                          color: Colors.white,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                        ),
                        cursorColor: const Color(0xFFE8B84A),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          hintText: enabled
                              ? 'Type ${widget.label.toLowerCase()}'
                              : widget.label,
                          hintStyle: AppText.bodyMuted.copyWith(
                            fontSize: 20,
                            color: Colors.white70,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                  child: Semantics(
                    button: true,
                    label: 'Send',
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: FilledButton(
                        onPressed: enabled ? _send : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          side: const BorderSide(
                            color: Color(0xFFE8B84A),
                            width: 1.0,
                          ),
                          shape: const CircleBorder(),
                        ),
                        child:
                            const Icon(Icons.arrow_upward_rounded, size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockSpeakButton extends StatelessWidget {
  const _DockSpeakButton({
    required this.enabled,
    required this.listening,
    required this.onTap,
  });

  final bool enabled;
  final bool listening;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? 'Listening' : 'Speak',
      child: Material(
        color: listening
            ? const Color(0xFFE8B84A)
            : AppColors.deepPurple.withValues(alpha: enabled ? 1 : 0.45),
        shape: const StadiumBorder(
          side: BorderSide(color: Color(0xFFE8B84A), width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  size: 22,
                  color: listening ? const Color(0xFF24154A) : Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  listening ? 'Listening' : 'Speak',
                  style: TextStyle(
                    color: listening ? const Color(0xFF24154A) : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
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
