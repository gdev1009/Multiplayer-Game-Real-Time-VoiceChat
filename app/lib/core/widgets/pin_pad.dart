import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dots(filled: value.length, total: length),
        const SizedBox(height: AppSpacing.xl),
        _padRow(['1', '2', '3']),
        const SizedBox(height: AppSpacing.md),
        _padRow(['4', '5', '6']),
        const SizedBox(height: AppSpacing.md),
        _padRow(['7', '8', '9']),
        const SizedBox(height: AppSpacing.md),
        _padRow(['', '0', '<']),
      ],
    );
  }

  Widget _padRow(List<String> keys) {
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
          if (key != keys.last) const SizedBox(width: AppSpacing.md),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            width: 24,
            height: 24,
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
    if (label.isEmpty) {
      return const SizedBox(width: 84, height: 84);
    }

    final bool isBackspace = label == '<';
    return Semantics(
      button: true,
      label: isBackspace ? 'Delete' : label,
      child: SizedBox(
        width: 84,
        height: 84,
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
                  ? const Icon(Icons.backspace_outlined,
                    size: 30, color: AppColors.deepPurple,)
                  : Text(label, style: AppText.title),
            ),
          ),
        ),
      ),
    );
  }
}
