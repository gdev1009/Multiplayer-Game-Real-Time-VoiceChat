import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// The show host greeting banner ("Guy Smiley").
///
/// Shows a friendly host avatar beside a warm, large-text greeting in a
/// speech-bubble style card. The final host artwork and voice arrive in a
/// later milestone; this is the senior-first visual placeholder that the rest
/// of the app reuses wherever the host speaks.
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
    return Semantics(
      label: '$hostName says: $message',
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HostAvatar(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.lavender,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hostName,
                    style: AppText.bodyMuted.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(message, style: AppText.body),
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
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/host/host-avatar.png',
        fit: BoxFit.cover,
      ),
    );
  }
}
