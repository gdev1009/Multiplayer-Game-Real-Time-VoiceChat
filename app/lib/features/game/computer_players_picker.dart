import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'computer_play.dart';
import 'computer_play_controller.dart';

/// Easy / Medium / Hard for the computer stand-in players.
///
/// Shown where a game is started. The person who starts the game is the one
/// whose choice the table plays with.
class ComputerPlayersPicker extends StatefulWidget {
  const ComputerPlayersPicker({super.key});

  @override
  State<ComputerPlayersPicker> createState() => _ComputerPlayersPickerState();
}

class _ComputerPlayersPickerState extends State<ComputerPlayersPicker> {
  ComputerPlayLevel _local = ComputerPlayLevel.medium;

  @override
  Widget build(BuildContext context) {
    ComputerPlayController? skill;
    try {
      skill = context.watch<ComputerPlayController>();
    } on ProviderNotFoundException {
      skill = null;
    }
    final level = skill?.level ?? _local;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Computer players',
          style: AppText.title.copyWith(fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final choice in ComputerPlayLevel.values) ...[
              if (choice != ComputerPlayLevel.easy) const SizedBox(width: 8),
              Expanded(
                child: _Choice(
                  label: choice.label,
                  selected: level == choice,
                  onTap: () {
                    if (skill != null) {
                      skill.setLevel(choice);
                    } else {
                      setState(() => _local = choice);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          level.blurb,
          style: AppText.bodyMuted,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.deepPurple : AppColors.surface;
    final fg = selected ? AppColors.onPrimary : AppColors.deepPurple;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.deepPurple,
                width: selected ? 0 : 2,
              ),
            ),
            child: Text(
              label,
              style: AppText.action.copyWith(color: fg, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
