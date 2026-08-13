import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../models/prize.dart';
import 'prize_controller.dart';

/// Personal Prize Room — clay win trophies (Phase 1) + milestone plaques.
class PrizeRoomScreen extends StatefulWidget {
  const PrizeRoomScreen({super.key});

  @override
  State<PrizeRoomScreen> createState() => _PrizeRoomScreenState();
}

class _PrizeRoomScreenState extends State<PrizeRoomScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PrizeController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrizeController>();
    final room = controller.room;
    final winCups = room.winCups();
    final extraWins = room.winTrophyCount - winCups.length;

    return AppPage(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Prize Room',
            style: AppText.display.copyWith(
              fontSize: AppResponsive.displaySize(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _roomBlurb(room),
            style: AppText.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          _StatsLine(
            won: room.gamesWon,
            tied: room.gamesTied,
            lost: room.gamesLost,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _TournamentTeaser(),
          const SizedBox(height: AppSpacing.lg),
          if (controller.loading && room.items.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (controller.error != null && room.items.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  controller.error!,
                  style: AppText.body,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _ShelfSection(
                    title: room.winTrophyCount <= 1
                        ? 'Trophies'
                        : 'Trophies (${room.winTrophyCount})',
                    items: winCups,
                    emptyHint: 'Win a game to earn your first trophy.',
                    overflowLabel: extraWins > 0 ? '+$extraWins more' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ShelfSection(
                    title: 'Milestone trophies',
                    items: room.milestoneTrophies,
                    emptyHint: 'Keep playing — special trophies unlock along the way.',
                  ),
                  if (PrizeAssets.showNoveltyPrizes) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _ShelfSection(
                      title: 'Prizes',
                      items: room.prizes,
                      emptyHint:
                          'Keep playing — novelty prizes appear as you go.',
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          BigButton(
            label: 'Back',
            icon: Icons.arrow_back_rounded,
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  String _roomBlurb(PrizeRoom room) {
    if (room.winTrophyCount > 0) {
      return room.signInTrophyLine;
    }
    switch (room.roomLevel) {
      case 0:
        return 'Your shelves are waiting for trophies.';
      case 1:
        return 'A lovely start — the shelves are waking up.';
      case 2:
        return 'Looking full and friendly.';
      default:
        return 'What a collection.';
    }
  }
}

/// Wins / ties / losses — Ronna's games-room totals.
class _StatsLine extends StatelessWidget {
  const _StatsLine({
    required this.won,
    required this.tied,
    required this.lost,
  });
  final int won;
  final int tied;
  final int lost;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Stat(value: '$won', label: 'wins'),
        _StatDivider(),
        _Stat(value: '$tied', label: 'ties'),
        _StatDivider(),
        _Stat(value: '$lost', label: 'losses'),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: 1,
        height: 28,
        color: AppColors.divider,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: AppText.title.copyWith(
            fontSize: 26,
            color: AppColors.deepPurple,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppText.caption.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Soft teaser for the annual tournament (Ronna).
class _TournamentTeaser extends StatelessWidget {
  const _TournamentTeaser();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        'Players need at least ${PrizeAssets.yearlyTournamentTrophyQualifier} '
        'trophies to qualify for our yearly tournament. '
        'Stay tuned — top scorers, you’re invited!',
        textAlign: TextAlign.center,
        style: AppText.bodyMuted.copyWith(
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShelfSection extends StatelessWidget {
  const _ShelfSection({
    required this.title,
    required this.items,
    required this.emptyHint,
    this.overflowLabel,
  });

  final String title;
  final List<PrizeItem> items;
  final String emptyHint;
  final String? overflowLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppText.title.copyWith(
            fontSize: 24,
            color: AppColors.deepPurple,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider, width: 1.5),
            boxShadow: AppColors.tileShadow,
          ),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    emptyHint,
                    style: AppText.bodyMuted,
                    textAlign: TextAlign.center,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, box) {
                    const gap = 12.0;
                    final count = items.length.clamp(1, 3);
                    final slotW =
                        ((box.maxWidth - gap * (count - 1)) / count)
                            .clamp(96.0, 160.0);
                    return Column(
                      children: [
                        Wrap(
                          spacing: gap,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final i in items)
                              SizedBox(
                                width: slotW,
                                child: _ShelfSlot(item: i),
                              ),
                          ],
                        ),
                        if (overflowLabel != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            overflowLabel!,
                            style: AppText.caption.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepPurple,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
        ),
        // Soft shelf lip
        Transform.translate(
          offset: const Offset(0, -6),
          child: Container(
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFE8D9C4),
                  const Color(0xFFD4C0A4).withValues(alpha: 0.85),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelfSlot extends StatelessWidget {
  const _ShelfSlot({required this.item});
  final PrizeItem item;

  @override
  Widget build(BuildContext context) {
    final earned = item.earned;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: earned ? 1 : 0.4,
            child: earned
                ? Image.asset(
                    item.assetPath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => _fallbackIcon(),
                  )
                : ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.35, 0.45, 0.10, 0, 28,
                      0.35, 0.45, 0.10, 0, 28,
                      0.35, 0.45, 0.10, 0, 28,
                      0, 0, 0, 0.9, 0,
                    ]),
                    child: Image.asset(
                      item.assetPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => _fallbackIcon(),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          style: AppText.body.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: earned ? AppColors.textPrimary : AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          earned ? 'Earned' : 'Locked',
          style: AppText.caption.copyWith(
            color: earned
                ? AppColors.success
                : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _fallbackIcon() => Icon(
        item.isTrophy
            ? Icons.emoji_events_rounded
            : Icons.card_giftcard_rounded,
        size: 64,
        color: AppColors.gold.withValues(alpha: 0.7),
      );
}
