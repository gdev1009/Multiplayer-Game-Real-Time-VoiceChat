import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../models/prize.dart';

/// Compact win trophy beside the player name.
///
/// Badge shows win count automatically. Tap opens a simple points popup
/// (wins / ties / games played) — Ronna Aug 2026; Prize Room deferred Tier 2.
class PlayerTrophyBadge extends StatelessWidget {
  const PlayerTrophyBadge({
    super.key,
    required this.room,
    this.loading = false,
  });

  final PrizeRoom room;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final wins = room.winTrophyCount;
    final size = AppResponsive.s(context, 72).clamp(64.0, 84.0);

    return Semantics(
      button: true,
      label: wins == 0
          ? 'Trophy. No wins yet. Tap to see your points.'
          : 'Trophy. $wins ${wins == 1 ? 'win' : 'wins'}. Tap to see your points.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showTrophyPointsPopup(context, room: room),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: AppColors.lavenderSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gold, width: 2),
                    boxShadow: AppColors.tileShadow,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: loading && wins == 0
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Image.asset(
                          PrizeAssets.winCup,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.emoji_events_rounded,
                            size: size * 0.55,
                            color: AppColors.gold,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                _WinCountChip(count: wins),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WinCountChip extends StatelessWidget {
  const _WinCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.deepPurple,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppColors.tileShadow,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: AppText.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Simple dialog: wins, ties, participation (games played).
Future<void> showTrophyPointsPopup(
  BuildContext context, {
  required PrizeRoom room,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xE6000000),
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.gold, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your points',
                      style: AppText.title.copyWith(
                        color: AppColors.deepPurple,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 28),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  'Updated automatically after each game.',
                  style: AppText.caption,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    _PointsRow(
                      label: 'Wins',
                      hint: 'Trophies earned',
                      value: room.gamesWon,
                      highlight: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PointsRow(
                      label: 'Ties',
                      hint: 'Shared finishes',
                      value: room.gamesTied,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PointsRow(
                      label: 'Games played',
                      hint: 'Participation',
                      value: room.gamesPlayed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepPurple,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PointsRow extends StatelessWidget {
  const _PointsRow({
    required this.label,
    required this.hint,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String hint;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: highlight ? AppColors.lavenderSoft : AppColors.warmBeige,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? AppColors.gold : AppColors.divider,
          width: highlight ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(hint, style: AppText.caption),
              ],
            ),
          ),
          Text(
            '$value',
            style: AppText.title.copyWith(
              fontSize: 28,
              color: AppColors.deepPurple,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
