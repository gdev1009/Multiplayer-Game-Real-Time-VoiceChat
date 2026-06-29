import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// A large, high-contrast primary button that meets the senior-first
/// tap-target and text-size requirements. One clear action per button.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = BigButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final BigButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = variant == BigButtonVariant.primary;
    final Color background =
        isPrimary ? AppColors.deepPurple : Colors.transparent;
    final Color foreground =
        isPrimary ? AppColors.onPrimary : AppColors.deepPurple;
    final bool enabled = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: Semantics(
        button: true,
        label: label,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor:
                isPrimary ? AppColors.divider : Colors.transparent,
            elevation: isPrimary ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: isPrimary
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.deepPurple, width: 3),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 28, color: foreground),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppText.action.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

enum BigButtonVariant { primary, secondary }
