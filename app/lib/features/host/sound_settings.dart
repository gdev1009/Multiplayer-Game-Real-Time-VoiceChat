import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../services/audio_controller.dart';

/// A round mute / sound button for the play screen app bar (Milestone 6).
///
/// Shows the current state at a glance (speaker vs. speaker-off) and opens the
/// full [SoundSettingsSheet] on tap so a senior can quieten the game without
/// hunting through menus.
class SoundButton extends StatelessWidget {
  const SoundButton({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioController>();
    return IconButton(
      tooltip: audio.muted ? 'Sound is off' : 'Sound settings',
      iconSize: 30,
      icon: Icon(
        audio.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        color: audio.muted ? AppColors.error : AppColors.deepPurple,
      ),
      onPressed: () => SoundSettingsSheet.show(context),
    );
  }
}

/// A calm bottom sheet with a big mute switch and two large volume sliders.
class SoundSettingsSheet extends StatelessWidget {
  const SoundSettingsSheet({super.key});

  /// Opens the sheet, reusing the ambient [AudioController].
  static Future<void> show(BuildContext context) {
    final audio = context.read<AudioController>();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider<AudioController>.value(
        value: audio,
        child: const SoundSettingsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sound', style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.lavenderSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: SwitchListTile(
              value: !audio.muted,
              onChanged: (on) => audio.setMuted(!on),
              activeThumbColor: AppColors.deepPurple,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              title: Text(
                audio.muted ? 'Sound is off' : 'Sound is on',
                style: AppText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              secondary: Icon(
                audio.muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: audio.muted ? AppColors.error : AppColors.deepPurple,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _VolumeRow(
            icon: Icons.music_note_rounded,
            label: 'Music',
            value: audio.musicVolume,
            enabled: !audio.muted,
            onChanged: audio.setMusicVolume,
          ),
          const SizedBox(height: AppSpacing.md),
          _VolumeRow(
            icon: Icons.campaign_rounded,
            label: 'Host & effects',
            value: audio.sfxVolume,
            enabled: !audio.muted,
            onChanged: audio.setSfxVolume,
          ),
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 30,
            color: enabled ? AppColors.deepPurple : AppColors.textSecondary,),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 128,
          child: Text(label, style: AppText.body),
        ),
        Expanded(
          child: Slider(
            value: value,
            activeColor: AppColors.deepPurple,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
