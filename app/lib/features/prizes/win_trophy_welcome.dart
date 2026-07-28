import 'package:flutter/material.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../models/prize.dart';

/// Sign-in / Opening welcome — shows clay win trophies to encourage a return.
class WinTrophyWelcome extends StatelessWidget {
  const WinTrophyWelcome({
    super.key,
    required this.room,
    this.loading = false,
  });

  final PrizeRoom room;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final count = room.winTrophyCount;
    final cups = room.winCups(maxVisible: 5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.prizeRoom),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: [
              _TrophyPreview(cups: cups, count: count, loading: loading),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count > 0 ? 'Your clay trophies' : 'Clay trophies',
                      style: AppText.title.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loading && count == 0
                          ? 'Loading your shelves…'
                          : room.signInTrophyLine,
                      style: AppText.bodyMuted.copyWith(
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to open Prize Room',
                      style: AppText.bodyMuted.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrophyPreview extends StatelessWidget {
  const _TrophyPreview({
    required this.cups,
    required this.count,
    required this.loading,
  });

  final List<PrizeItem> cups;
  final int count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && cups.isEmpty) {
      return const SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    if (cups.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.warmBeige,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(
          Icons.emoji_events_outlined,
          size: 40,
          color: AppColors.gold.withValues(alpha: 0.85),
        ),
      );
    }

    final show = cups.take(3).toList(growable: false);
    return SizedBox(
      width: 88,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < show.length; i++)
            Positioned(
              left: i * 18.0,
              child: Image.asset(
                show[i].assetPath,
                width: 56,
                height: 72,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.emoji_events_rounded,
                  size: 48,
                  color: AppColors.gold.withValues(alpha: 0.85),
                ),
              ),
            ),
          if (count > show.length)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${count - show.length}',
                  style: AppText.body.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
