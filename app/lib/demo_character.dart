// Standalone demo entry for the Milestone 3 character builder.
//
// This mounts the character-creation wizard directly with an in-memory
// service, so the builder can be run and screenshotted WITHOUT Supabase
// sign-in. It is a developer/demo tool only and is never bundled into the
// shipping app (the real entry point remains lib/main.dart).
//
// Run for the web with:
//   flutter run -d web-server -t lib/demo_character.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_text.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/big_button.dart';
import 'features/character/character_controller.dart';
import 'features/character/character_creation_screen.dart';
import 'features/character/character_preview.dart';
import 'models/character.dart';
import 'services/character_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => CharacterController(_InMemoryCharacterService()),
      child: MaterialApp(
        title: 'Match Word — Character Builder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _DemoHome(),
      ),
    ),
  );
}

/// A minimal stand-in for the real Opening screen so the **edit-later** flow is
/// demonstrable without Supabase: it shows the saved character with an
/// Edit button (Create when none exists) exactly like the shipping app.
class _DemoHome extends StatefulWidget {
  const _DemoHome();

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CharacterController>().load();
    });
  }

  Future<void> _openBuilder({required bool edit}) async {
    final characters = context.read<CharacterController>();
    if (edit) {
      characters.startEdit();
    } else {
      characters.startNew();
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CharacterCreationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final characters = context.watch<CharacterController>();
    final saved = characters.saved;

    return Scaffold(
      backgroundColor: AppColors.warmBeige,
      appBar: AppBar(title: const Text('Match Word')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (saved != null)
                  CharacterPreview(character: saved, size: 110)
                else
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: AppColors.stageGradient,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural,
                      size: 54,
                      color: AppColors.deepPurple,
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        saved == null ? 'Make your character' : saved.displayName,
                        style: AppText.title,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        saved == null
                            ? 'Build a fun clay character to play with.'
                            : 'Tap to change your look.',
                        style: AppText.bodyMuted,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      BigButton(
                        label: saved == null ? 'Create' : 'Edit',
                        icon: saved == null ? Icons.add : Icons.edit,
                        variant: BigButtonVariant.secondary,
                        onPressed: () =>
                            _openBuilder(edit: saved != null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A backend-free stand-in for [CharacterService] used only by this demo.
class _InMemoryCharacterService implements CharacterService {
  Character? _stored;

  @override
  Future<Character?> loadCharacter() async => _stored;

  @override
  Future<void> saveCharacter(Character character) async => _stored = character;

  @override
  Future<bool> hasCharacter() async => _stored != null;
}
