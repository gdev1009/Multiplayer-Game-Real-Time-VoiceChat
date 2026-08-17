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
    final labelStyle = AppText.action.copyWith(color: foreground);
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
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Semantics(
        button: true,
        label: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isPrimary && enabled ? AppColors.brandGradient : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isPrimary && enabled ? AppColors.softShadow : null,
          ),
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: foreground,
              shadowColor: Colors.transparent,
              disabledBackgroundColor:
                  isPrimary ? AppColors.divider : Colors.transparent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isPrimary
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.deepPurple, width: 2.5),
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return isPrimary ? AppColors.divider : Colors.transparent;
                }
                return Colors.transparent;
              }),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

enum BigButtonVariant { primary, secondary }
