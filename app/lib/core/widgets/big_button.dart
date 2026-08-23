import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_responsive.dart';
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
    final Color foreground =
        isPrimary ? AppColors.onPrimary : AppColors.deepPurple;
    final bool enabled = onPressed != null && !isLoading;
    final height = AppResponsive.buttonHeight(context);
    final labelStyle = AppText.action.copyWith(color: foreground, height: 1.15);
    final iconSize = AppResponsive.isShort(context) ? 22.0 : 24.0;

    final Widget content = isLoading
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
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: labelStyle,
                  ),
                ),
              ),
            ],
          );

    // Grow with the label — a fixed 52px box made two-line titles paint
    // over the next button (Ronna: Home + Subscribe overlap).
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isPrimary && enabled ? AppColors.softShadow : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: isPrimary && enabled ? AppColors.brandGradient : null,
              color: isPrimary && !enabled ? AppColors.divider : null,
            ),
            child: ElevatedButton(
              onPressed: enabled ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: foreground,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                elevation: 0,
                minimumSize: Size(double.infinity, height),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isPrimary
                      ? BorderSide.none
                      : const BorderSide(
                          color: AppColors.deepPurple,
                          width: 2.5,
                        ),
                ),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

enum BigButtonVariant { primary, secondary }
