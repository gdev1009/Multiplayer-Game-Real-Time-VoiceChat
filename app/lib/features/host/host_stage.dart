import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// A full-screen disconnect alarm overlay.
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
