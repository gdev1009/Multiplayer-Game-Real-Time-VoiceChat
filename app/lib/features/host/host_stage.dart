import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// The animated Guy Smiley host figure for the play stage (Milestone 6).
///
/// Idles with a gentle bob so the show feels alive, and gives a brief "excited"
/// bounce + glow whenever the host says something new ([speaking]). Uses the
/// real host artwork with a graceful icon fallback if the asset is missing.
class AnimatedHost extends StatefulWidget {
  const AnimatedHost({
    super.key,
    this.size = 72,
    this.speaking = false,
    this.label = 'Host',
  });

  /// Diameter of the host medallion.
  final double size;

  /// When true the host does an excited bounce + glow (a new line was said).
  final bool speaking;

  /// Caption shown under the host.
  final String label;

  @override
  State<AnimatedHost> createState() => _AnimatedHostState();
}

class _AnimatedHostState extends State<AnimatedHost>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(AnimatedHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speaking && !oldWidget.speaking) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_idle, _pop]),
          builder: (context, child) {
            final bob = math.sin(_idle.value * math.pi) * 3;
            final pop = Curves.elasticOut.transform(_pop.value);
            final scale = 1 + (widget.speaking ? 0.06 : 0.0) + pop * 0.10;
            final glow = widget.speaking || _pop.isAnimating;
            return Transform.translate(
              offset: Offset(0, -bob),
              child: Transform.scale(scale: scale, child: _medallion(glow)),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(widget.label, style: AppText.bodyMuted),
      ],
    );
  }

  Widget _medallion(bool glow) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: glow ? 0.75 : 0.0),
            blurRadius: glow ? 18 : 0,
            spreadRadius: glow ? 2 : 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: Image.asset(
          'assets/images/host/host-avatar.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.emoji_emotions_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
      ),
    );
  }
}

/// A full-screen disconnect alarm overlay (Milestone 6).
///
/// When a player drops, the whole screen flashes red with an ALERT/AWOOGA feel
/// (the sound is fired by the [AudioController]) and the host explains what
/// happened in big, calm text with a single clear button. Designed to be dropped
/// into a [Stack] above the play screen.
class DisconnectAlarm extends StatefulWidget {
  const DisconnectAlarm({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  /// The host's commentary about the disconnect.
  final String message;

  /// Called when the player taps to continue.
  final VoidCallback onDismiss;

  @override
  State<DisconnectAlarm> createState() => _DisconnectAlarmState();
}

class _DisconnectAlarmState extends State<DisconnectAlarm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _flash,
        builder: (context, child) {
          final t = _flash.value;
          return ColoredBox(
            color: Color.lerp(
              AppColors.error.withValues(alpha: 0.55),
              AppColors.error.withValues(alpha: 0.88),
              t,
            )!,
            child: child,
          );
        },
        child: Semantics(
          liveRegion: true,
          label: 'Alert. ${widget.message}',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 88,),
                  const SizedBox(height: 16),
                  Text(
                    'Hold on!',
                    style: AppText.display.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.message,
                    style: AppText.title.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: widget.onDismiss,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 18,),
                      textStyle: AppText.action,
                    ),
                    child: const Text('Keep Playing'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
