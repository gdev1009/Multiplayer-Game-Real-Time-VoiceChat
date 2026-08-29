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
    this.onInteract,
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

  /// Fired on Speak / Type / Send so the host can stop talking (barge-in).
  final VoidCallback? onInteract;

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
    widget.onInteract?.call();
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  Future<void> _speak() async {
    widget.onInteract?.call();
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
          duration: Duration(seconds: 6),
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
                  onTap: widget.onInteract,
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
              style: AppText.bodyMuted.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Compact studio dock — Ronna: clear Type **or** Speak choice.
  /// Narrow phones: mic icon only so the type field stays usable.
  Widget _buildDock(bool enabled) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 380;
        // Keep type large and readable — compress chrome, not letterforms.
        final rowH = narrow ? 52.0 : 58.0;
        final padH = narrow ? 10.0 : 12.0;
        final padV = narrow ? 10.0 : 12.0;
        final titleSize = narrow ? 20.0 : 22.0;
        final fieldSize = narrow ? 22.0 : 24.0;
        final hintSize = narrow ? 20.0 : 22.0;
        final sendW = narrow ? 52.0 : 58.0;
        const gold = Color(0xFFE8B84A);
        const goldOuter = Color(0xFFF1B159);
        const fieldFill = Color(0xFF3A2468);

        return Semantics(
          label: '${widget.label}. Type or speak your word.',
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF24154A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: goldOuter, width: 2),
            ),
            // Inset fill so the gold stroke stays fully closed (child paint
            // cannot cover the border).
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: const Color(0xFF24154A),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          enabled
                              ? 'Type or Speak — your ${widget.label.toLowerCase()}'
                              : widget.label,
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: gold,
                            fontWeight: FontWeight.w900,
                            fontSize: titleSize,
                            height: 1.15,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      SizedBox(height: narrow ? 8 : 10),
                      SizedBox(
                        height: rowH,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DockSpeakButton(
                              enabled: enabled,
                              listening: _listening,
                              iconOnly: narrow,
                              onTap: enabled ? _speak : null,
                            ),
                            SizedBox(width: narrow ? 6 : 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: gold, width: 1.5),
                                ),
                                padding: const EdgeInsets.all(1.5),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12.5),
                                  child: ColoredBox(
                                    color: fieldFill,
                                    child: Row(
                                      children: [
                                        if (!narrow)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 12,
                                              right: 8,
                                            ),
                                            child: Text(
                                              'TYPE',
                                              style: TextStyle(
                                                color: gold.withValues(
                                                  alpha: enabled ? 1 : 0.45,
                                                ),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 18,
                                                height: 1,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ),
                                        if (!narrow)
                                          Container(
                                            width: 1.5,
                                            height: 24,
                                            color: gold.withValues(alpha: 0.45),
                                          ),
                                        Expanded(
                                          child: TextField(
                                            controller: _controller,
                                            enabled: enabled,
                                            textAlign: TextAlign.left,
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            textInputAction:
                                                TextInputAction.send,
                                            onTap: widget.onInteract,
                                            onSubmitted: (_) => _send(),
                                            style: AppText.body.copyWith(
                                              fontSize: fieldSize,
                                              color: Colors.white,
                                              height: 1.0,
                                              fontWeight: FontWeight.w900,
                                            ),
                                            cursorColor: gold,
                                            keyboardAppearance: Brightness.dark,
                                            decoration: InputDecoration(
                                              isCollapsed: true,
                                              filled: true,
                                              fillColor: fieldFill,
                                              hintText:
                                                  enabled ? 'Type here…' : '…',
                                              hintStyle:
                                                  AppText.bodyMuted.copyWith(
                                                fontSize: hintSize,
                                                color: Colors.white70,
                                                height: 1.0,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                horizontal: narrow ? 10 : 12,
                                                vertical: narrow ? 12 : 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: narrow ? 6 : 8),
                            Semantics(
                              button: true,
                              label: 'Send',
                              child: SizedBox(
                                width: sendW,
                                child: FilledButton(
                                  onPressed: enabled ? _send : null,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    side: const BorderSide(
                                      color: gold,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_upward_rounded,
                                    size: narrow ? 26 : 30,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DockSpeakButton extends StatelessWidget {
  const _DockSpeakButton({
    required this.enabled,
    required this.listening,
    required this.onTap,
    this.iconOnly = false,
  });

  final bool enabled;
  final bool listening;
  final VoidCallback? onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? 'Listening' : 'Speak',
      child: Material(
        color: listening
            ? const Color(0xFFE8B84A)
            : AppColors.deepPurple.withValues(alpha: enabled ? 1 : 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE8B84A), width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: iconOnly
              ? SizedBox(
                  width: 48,
                  child: Center(
                    child: Icon(
                      listening
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_rounded,
                      size: 26,
                      color: listening
                          ? const Color(0xFF24154A)
                          : Colors.white,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        listening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_rounded,
                        size: 26,
                        color: listening
                            ? const Color(0xFF24154A)
                            : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        listening ? 'Listening' : 'SPEAK',
                        style: TextStyle(
                          color: listening
                              ? const Color(0xFF24154A)
                              : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1,
                          letterSpacing: 0.5,
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
