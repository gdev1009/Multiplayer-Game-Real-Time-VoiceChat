import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_responsive.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Guy Smiley greeting banner — avatar beside a warm speech-bubble message.
class HostGreeting extends StatelessWidget {
  const HostGreeting({
    super.key,
    required this.message,
    this.hostName = 'Guy Smiley',
  });

  /// The line the host "says" to the player.
  final String message;

  /// The host's display name, shown above the message.
  final String hostName;

  @override
  Widget build(BuildContext context) {
    final short = AppResponsive.isShort(context);
    final avatar = AppResponsive.s(context, short ? 48.0 : 56.0)
        .clamp(44.0, 60.0);

    return Semantics(
      label: '$hostName says: $message',
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HostAvatar(size: avatar),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: short ? AppSpacing.sm : 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.lavender,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider, width: 1.5),
                boxShadow: AppColors.tileShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hostName,
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepPurple,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: AppText.body.copyWith(
                      fontSize: short ? 14 : 15,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostAvatar extends StatelessWidget {
  const _HostAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: AppColors.tileShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/host/host-avatar.png',
        fit: BoxFit.cover,
      ),
    );
  }
}
