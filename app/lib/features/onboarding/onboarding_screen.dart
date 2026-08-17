import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../models/prize.dart';
import 'onboarding_controller.dart';
import 'onboarding_copy.dart';

class _Page {
  const _Page({
    required this.title,
    required this.body,
    required this.icon,
    this.showTrophy = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool showTrophy;
}

/// Skippable first-launch screens. Copy lives in [OnboardingCopy] for Ronna.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    _Page(
      title: OnboardingCopy.welcomeTitle,
      body: OnboardingCopy.welcomeBody,
      icon: Icons.waving_hand_rounded,
    ),
    _Page(
      title: OnboardingCopy.playTitle,
      body: OnboardingCopy.playBody,
      icon: Icons.sports_esports_rounded,
    ),
    _Page(
      title: OnboardingCopy.trophiesTitle,
      body: OnboardingCopy.trophiesBody,
      icon: Icons.emoji_events_rounded,
      showTrophy: true,
    ),
    _Page(
      title: OnboardingCopy.tournamentsTitle,
      body: OnboardingCopy.tournamentsBody,
      icon: Icons.military_tech_rounded,
    ),
    _Page(
      title: OnboardingCopy.friendsTitle,
      body: OnboardingCopy.friendsBody,
      icon: Icons.groups_rounded,
    ),
  ];

  int _index = 0;

  bool get _isLast => _index >= _pages.length - 1;

  Future<void> _finish() async {
    await context.read<OnboardingController>().complete();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = AppResponsive.s(context, 88).clamp(64.0, 96.0);
    final p = _pages[_index];

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.deepPurple,
                minimumSize: const Size(64, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                OnboardingCopy.skip,
                style: AppText.body.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SizedBox(
            height: AppResponsive.isShort(context)
                ? AppSpacing.sm
                : AppSpacing.lg,
          ),
          if (p.showTrophy)
            Center(child: _TrophyDemo(size: iconSize))
          else
            Center(
              child: Container(
                width: iconSize + 24,
                height: iconSize + 24,
                decoration: BoxDecoration(
                  color: AppColors.lavenderSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.divider,
                    width: 2,
                  ),
                ),
                child: Icon(
                  p.icon,
                  size: iconSize * 0.55,
                  color: AppColors.gold,
                ),
              ),
            ),
          SizedBox(
            height: AppResponsive.isShort(context)
                ? AppSpacing.md
                : AppSpacing.xl,
          ),
          Text(
            p.title,
            style: AppText.display.copyWith(
              fontSize: AppResponsive.displaySize(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            p.body,
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '${_index + 1} ${OnboardingCopy.pageOf} ${_pages.length}',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pages.length; i++)
                Container(
                  width: i == _index ? 18 : 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.deepPurple
                        : AppColors.divider,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          BigButton(
            label: _isLast ? OnboardingCopy.letsPlay : OnboardingCopy.next,
            icon: _isLast
                ? Icons.play_arrow_rounded
                : Icons.arrow_forward_rounded,
            onPressed: _next,
          ),
          SizedBox(
            height: AppResponsive.isShort(context)
                ? AppSpacing.sm
                : AppSpacing.md,
          ),
        ],
      ),
    );
  }
}

class _TrophyDemo extends StatelessWidget {
  const _TrophyDemo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    // Small corner badge — never a full-width purple bar (Ronna feedback).
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lavenderSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold, width: 2),
                boxShadow: AppColors.tileShadow,
              ),
              child: Image.asset(
                PrizeAssets.winCup,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.emoji_events_rounded,
                  size: size * 0.5,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.deepPurple,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                '3',
                style: AppText.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
