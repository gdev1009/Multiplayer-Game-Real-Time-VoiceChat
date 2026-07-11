import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_text_field.dart';
import '../../models/character.dart';
import 'character_catalog.dart';
import 'character_controller.dart';
import 'character_preview.dart';

/// Step-by-step character builder. One clear choice per screen, with a live
/// preview at the top so the player always sees what they are making.
class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({super.key});

  @override
  State<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  /// The ordered steps: one per layer, then name, then review.
  static final List<_Step> _steps = [
    ...CharacterLayer.values.map(_Step.layer),
    const _Step.name(),
    const _Step.review(),
  ];

  int _index = 0;
  late final TextEditingController _nameController;
  bool _nameTouched = false;

  @override
  void initState() {
    super.initState();
    final controller = context.read<CharacterController>();
    _nameController = TextEditingController(text: controller.draft.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  _Step get _step => _steps[_index];
  bool get _isFirst => _index == 0;
  bool get _isLast => _index == _steps.length - 1;

  void _back() {
    if (_isFirst) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _index--);
    }
  }

  void _next() {
    if (!_isLast) setState(() => _index++);
  }

  Future<void> _save() async {
    final controller = context.read<CharacterController>();
    try {
      await controller.save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your character is saved!')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CharacterController>();

    return AppPage(
      title: 'Character Studio',
      showBack: true,
      onBack: _back,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepProgress(current: _index, total: _steps.length),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: CharacterPreview(character: controller.draft, size: 240),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: _buildStepBody(controller),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildActions(controller),
        ],
      ),
    );
  }

  Widget _buildStepBody(CharacterController controller) {
    return switch (_step.kind) {
      _StepKind.layer => _LayerChooser(
          layer: _step.layer!,
          reference: controller.draft,
          selectedId: controller.selected(_step.layer!),
          onChoose: (id) => controller.chooseOption(_step.layer!, id),
          selectedColorId: controller.selectedColor(_step.layer!),
          onChooseColor: (id) => controller.chooseColor(_step.layer!, id),
        ),
      _StepKind.name => _NameStep(
          controller: _nameController,
          errorText: _nameTouched && _nameController.text.trim().isEmpty
              ? 'Please type a name.'
              : null,
          onChanged: (value) {
            controller.setDisplayName(value);
            if (!_nameTouched) setState(() => _nameTouched = true);
            setState(() {});
          },
        ),
      _StepKind.review => _ReviewStep(name: controller.draft.displayName),
    };
  }

  Widget _buildActions(CharacterController controller) {
    if (_step.kind == _StepKind.review) {
      return BigButton(
        label: 'Save my character',
        icon: Icons.check,
        isLoading: controller.busy,
        onPressed: controller.isComplete ? _save : null,
      );
    }

    final bool canAdvance = switch (_step.kind) {
      _StepKind.layer =>
        !_step.layer!.optional ? controller.selected(_step.layer!) != null : true,
      _StepKind.name => _nameController.text.trim().isNotEmpty,
      _StepKind.review => true,
    };

    return BigButton(
      label: 'Next',
      icon: Icons.arrow_forward,
      onPressed: canAdvance
          ? () {
              if (_step.kind == _StepKind.name && !_nameTouched) {
                setState(() => _nameTouched = true);
              }
              _next();
            }
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Step model
// ---------------------------------------------------------------------------

enum _StepKind { layer, name, review }

class _Step {
  const _Step.layer(this.layer) : kind = _StepKind.layer;
  const _Step.name()
      : kind = _StepKind.name,
        layer = null;
  const _Step.review()
      : kind = _StepKind.review,
        layer = null;

  final _StepKind kind;
  final CharacterLayer? layer;
}

// ---------------------------------------------------------------------------
// Progress indicator
// ---------------------------------------------------------------------------

/// A slim segmented progress bar showing how far through the build the player
/// is. Completed segments fill with the brand gradient.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of $total',
      child: Row(
        children: [
          for (int i = 0; i < total; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 10,
                decoration: BoxDecoration(
                  gradient: i <= current ? AppColors.brandGradient : null,
                  color: i <= current ? null : AppColors.divider,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            if (i != total - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layer chooser
// ---------------------------------------------------------------------------

class _LayerChooser extends StatelessWidget {
  const _LayerChooser({
    required this.layer,
    required this.reference,
    required this.selectedId,
    required this.onChoose,
    required this.selectedColorId,
    required this.onChooseColor,
  });

  final CharacterLayer layer;

  /// The current draft, so each style tile can preview on the player's body.
  final Character reference;
  final String? selectedId;
  final ValueChanged<String?> onChoose;
  final String? selectedColorId;
  final ValueChanged<String?> onChooseColor;

  @override
  Widget build(BuildContext context) {
    final options = CharacterCatalog.forLayer(layer);
    final showColors = layer.tintable && selectedId != null;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: layer.icon, title: layer.title, hint: layer.hint),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              if (layer.optional)
                _OptionTile(
                  label: 'None',
                  color: AppColors.surface,
                  icon: Icons.block_rounded,
                  selected: selectedId == null,
                  onTap: () => onChoose(null),
                ),
              for (final option in options)
                _OptionTile(
                  label: option.label,
                  preview: CharacterPartThumb(
                    layer: layer,
                    optionId: option.id,
                    reference: reference,
                  ),
                  selected: selectedId == option.id,
                  onTap: () => onChoose(option.id),
                ),
            ],
          ),
          if (showColors) ...[
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(
              icon: Icons.palette_rounded,
              title: switch (layer) {
                CharacterLayer.base => 'Skin tone',
                CharacterLayer.hair => 'Hair colour',
                _ => 'Eye colour',
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final tint in CharacterCatalog.tintsFor(layer))
                  _OptionTile(
                    label: tint.label,
                    color: tint.color,
                    selected: selectedColorId == tint.id,
                    onTap: () => onChooseColor(tint.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A friendly section heading with a brand-tinted icon chip and optional hint.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.hint});

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                boxShadow: AppColors.tileShadow,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, style: AppText.title)),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(hint!, style: AppText.bodyMuted),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.preview,
    this.icon,
  });

  final String label;

  /// The swatch colour, used for colour/tint tiles and the "None" tile.
  final Color? color;

  /// A live style thumbnail, used for hair/eyes/glasses/outfit/body tiles so
  /// each option previews its real look instead of an identical dot.
  final Widget? preview;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 100,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected ? AppColors.deepPurple : AppColors.divider,
              width: selected ? 3 : 2,
            ),
            boxShadow: selected ? AppColors.softShadow : AppColors.tileShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              preview != null ? _thumbSwatch() : _colorSwatch(),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected ? AppColors.deepPurple : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A live figure thumbnail with a selection tick in the corner.
  Widget _thumbSwatch() {
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(66 * 0.30),
              border: Border.all(
                color: selected
                    ? AppColors.deepPurple
                    : Colors.white.withValues(alpha: 0.9),
                width: selected ? 2.5 : 2,
              ),
              boxShadow: AppColors.tileShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: preview,
          ),
          if (selected)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.deepPurple,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 15,),
              ),
            ),
        ],
      ),
    );
  }

  /// A rounded colour dot for tint palettes and the "None" tile.
  Widget _colorSwatch() {
    final swatch = color ?? AppColors.lavender;
    final bool isLight = swatch.computeLuminance() > 0.6;
    final Color checkColor = isLight ? AppColors.deepPurple : Colors.white;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1.0,
          colors: [
            Color.lerp(swatch, Colors.white, 0.35)!,
            swatch,
            Color.lerp(swatch, Colors.black, 0.12)!,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: AppColors.tileShadow,
      ),
      child: icon != null && !selected
          ? Icon(icon, color: checkColor, size: 28)
          : selected
              ? Icon(Icons.check_rounded, color: checkColor, size: 32)
              : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Name + review steps
// ---------------------------------------------------------------------------

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.controller,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Name your character', style: AppText.title),
        const SizedBox(height: AppSpacing.md),
        BigTextField(
          label: 'Character name',
          hint: 'For example: Sunny',
          controller: controller,
          autofocus: true,
          errorText: errorText,
          textInputAction: TextInputAction.done,
          onSubmitted: onChanged,
        ),
        // Keep the controller value flowing to the draft as the user types.
        _NameListener(controller: controller, onChanged: onChanged),
      ],
    );
  }
}

/// Tiny helper that forwards every keystroke to [onChanged] without needing a
/// StatefulWidget around the text field.
class _NameListener extends StatefulWidget {
  const _NameListener({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_NameListener> createState() => _NameListenerState();
}

class _NameListenerState extends State<_NameListener> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handle);
  }

  void _handle() => widget.onChanged(widget.controller.text);

  @override
  void dispose() {
    widget.controller.removeListener(_handle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _SectionHeader(
          icon: Icons.celebration_rounded,
          title: 'Looking great!',
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: AppColors.softShadow,
          ),
          child: Text(
            name.trim().isEmpty ? 'Your character' : name.trim(),
            textAlign: TextAlign.center,
            style: AppText.display.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Tap “Save my character” to keep this look. '
          'You can change it any time.',
          textAlign: TextAlign.center,
          style: AppText.bodyMuted,
        ),
      ],
    );
  }
}
