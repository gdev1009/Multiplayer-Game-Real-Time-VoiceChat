import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_responsive.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// A large, senior-friendly 4-digit PIN entry control with its own on-screen
/// number pad. Familiar to anyone who uses a bank card.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.length = 4,
  });

  /// The current PIN digits entered so far.
  final String value;

  /// Called whenever the value changes (digit added or removed).
  final ValueChanged<String> onChanged;

  final int length;

  void _addDigit(String digit) {
    if (value.length >= length) return;
    onChanged(value + digit);
  }

  void _removeDigit() {
    if (value.isEmpty) return;
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final gap = AppResponsive.isShort(context)
        ? AppResponsive.s(context, AppSpacing.sm)
        : AppSpacing.md;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dots(filled: value.length, total: length),
        SizedBox(
          height: AppResponsive.isShort(context)
              ? AppSpacing.md
              : AppSpacing.xl,
        ),
        _padRow(context, ['1', '2', '3'], gap),
        SizedBox(height: gap),
        _padRow(context, ['4', '5', '6'], gap),
        SizedBox(height: gap),
        _padRow(context, ['7', '8', '9'], gap),
        SizedBox(height: gap),
        _padRow(context, ['', '0', '<'], gap),
      ],
    );
  }

  Widget _padRow(BuildContext context, List<String> keys, double gap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final key in keys) ...[
          _PadKey(
            label: key,
            onTap: switch (key) {
              '' => null,
              '<' => _removeDigit,
              _ => () => _addDigit(key),
            },
          ),
          if (key != keys.last) SizedBox(width: gap),
        ],
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final dot = AppResponsive.s(context, 24);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++)
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: AppResponsive.s(context, AppSpacing.sm),
            ),
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? AppColors.deepPurple : Colors.transparent,
              border: Border.all(color: AppColors.deepPurple, width: 3),
            ),
          ),
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Keep >= 48 tap target; shrink a bit on narrow/short phones so the pad
    // fits above the keyboard / next button without scrolling off.
    final keySize = AppResponsive.s(context, 84).clamp(56.0, 84.0);
    if (label.isEmpty) {
      return SizedBox(width: keySize, height: keySize);
    }

    final bool isBackspace = label == '<';
    return Semantics(
      button: true,
      label: isBackspace ? 'Delete' : label,
      child: SizedBox(
        width: keySize,
        height: keySize,
        child: Material(
          color: AppColors.surface,
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.divider, width: 2),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: isBackspace
                  ? Icon(
                      Icons.backspace_outlined,
                      size: keySize * 0.36,
                      color: AppColors.deepPurple,
                    )
                  : Text(
                      label,
                      style: AppText.title.copyWith(
                        fontSize: keySize * 0.36,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
