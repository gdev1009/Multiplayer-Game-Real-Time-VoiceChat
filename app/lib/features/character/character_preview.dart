import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/character.dart';
import 'character_catalog.dart';

/// Premium "Character Studio" preview.
///
/// Presents the player's character as the artist's real, full-colour figure on
/// a soft spotlight stage. Each chosen layer is a pre-registered 1254×1254 PNG
/// that lines up exactly on the body, so the preview simply stacks them in
/// back-to-front order:
///
///   1. Spotlight backdrop + floor shadow.
///   2. Body → outfit → hair → earrings → glasses → hat → held item.
///
/// If any single art file is missing the layer is skipped gracefully (the rest
/// of the figure still renders), and a friendly placeholder shows when no body
/// has been chosen yet.
class CharacterPreview extends StatelessWidget {
  const CharacterPreview({
    super.key,
    required this.character,
    this.size = 260,
    this.showBackdrop = true,
  });

  final Character character;
  final double size;

  /// When false the studio backdrop/border is omitted (for tight inline uses).
  final bool showBackdrop;

  /// The layers to paint, back to front. Earrings sit above hair so they show,
  /// glasses above the face, the hat above the hair, and a held item in front.
  static const List<CharacterLayer> _paintOrder = [
    CharacterLayer.base,
    CharacterLayer.outfit,
    CharacterLayer.hair,
    CharacterLayer.earrings,
    CharacterLayer.glasses,
    CharacterLayer.hat,
    CharacterLayer.accessory,
  ];

  String? _idFor(CharacterLayer layer) => switch (layer) {
        CharacterLayer.base => character.base,
        CharacterLayer.hair => character.hair,
        CharacterLayer.outfit => character.outfit,
        CharacterLayer.glasses => character.glasses,
        CharacterLayer.hat => character.hat,
        CharacterLayer.earrings => character.earrings,
        CharacterLayer.accessory => character.accessory,
      };

  @override
  Widget build(BuildContext context) {
    final layers = <Widget>[];
    for (final layer in _paintOrder) {
      final id = _idFor(layer);
      if (id == null) continue;
      final option = CharacterCatalog.find(layer, id);
      if (option == null) continue;
      layers.add(
        Image.asset(
          option.assetPath,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    final stage = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showBackdrop) const _StageBackdrop(),
          _FloorShadow(size: size),
          if (character.base == null)
            _EmptyFigure(size: size)
          else
            ...layers,
        ],
      ),
    );

    return Semantics(
      label: 'Character preview',
      image: true,
      child: showBackdrop
          ? Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: AppColors.stageGradient,
                borderRadius: BorderRadius.circular(size * 0.11),
                boxShadow: AppColors.softShadow,
                border: Border.all(color: Colors.white, width: 3),
              ),
              clipBehavior: Clip.antiAlias,
              child: stage,
            )
          : stage,
    );
  }
}

/// A small, premium thumbnail that previews a single [layer] option on the
/// player's own figure — so the chooser shows the *actual* hairstyle, hat,
/// glasses, outfit or held item instead of identical colour dots.
///
/// It reuses the real [CharacterPreview] assembly on a minimal figure — the
/// player's chosen body plus only this one option — then zooms to the relevant
/// part of the body.
class CharacterPartThumb extends StatelessWidget {
  const CharacterPartThumb({
    super.key,
    required this.layer,
    required this.optionId,
    required this.reference,
    this.size = 66,
  });

  /// The layer this thumbnail previews.
  final CharacterLayer layer;

  /// The option id to show (e.g. `hair-f2`).
  final String optionId;

  /// The current draft — used only to inherit the body so the thumbnail
  /// matches what the player will actually see.
  final Character reference;

  /// The rendered square size in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final baseId = reference.base ?? CharacterCatalog.defaultBodyId;

    // A minimal figure: the chosen body plus only this option, so the
    // thumbnail unmistakably reads as this single choice. The outfit is kept
    // so the figure is always dressed.
    var c = Character(
      displayName: '',
      base: baseId,
      outfit: CharacterCatalog.defaultOutfitFor(baseId),
    );
    switch (layer) {
      case CharacterLayer.base:
        c = Character(
          displayName: '',
          base: optionId,
          outfit: CharacterCatalog.defaultOutfitFor(optionId),
        );
      case CharacterLayer.hair:
        c = c.copyWith(hair: optionId);
      case CharacterLayer.outfit:
        c = c.copyWith(outfit: optionId);
      case CharacterLayer.glasses:
        c = c.copyWith(glasses: optionId);
      case CharacterLayer.hat:
        c = c.copyWith(hat: optionId);
      case CharacterLayer.earrings:
        c = c.copyWith(earrings: optionId);
      case CharacterLayer.accessory:
        c = c.copyWith(accessory: optionId);
    }

    // Where to centre the zoom (as a fraction of the stage height) and how
    // tight, tuned per layer so the relevant part fills the tile.
    final (double focusY, double zoom) = switch (layer) {
      CharacterLayer.base => (0.29, 1.15),
      CharacterLayer.outfit => (0.44, 1.55),
      CharacterLayer.hair => (0.10, 2.45),
      CharacterLayer.hat => (0.075, 2.45),
      CharacterLayer.accessory => (0.52, 1.20),
      // eyes-level parts — frame the face
      _ => (0.14, 2.70),
    };

    final render = size * zoom;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.30),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.stageGradient),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                width: render,
                height: render,
                left: (size - render) / 2,
                top: size / 2 - focusY * render,
                child: CharacterPreview(
                  character: c,
                  size: render,
                  showBackdrop: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Backdrop + grounding
// ---------------------------------------------------------------------------

class _StageBackdrop extends StatelessWidget {
  const _StageBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.stageGradient),
      child: SizedBox.expand(),
    );
  }
}

class _FloorShadow extends StatelessWidget {
  const _FloorShadow({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _FloorShadowPainter());
  }
}

class _FloorShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.95),
      width: w * 0.5,
      height: h * 0.055,
    );
    final paint = Paint()
      ..color = const Color(0x2E000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Friendly placeholder shown before a body has been chosen.
class _EmptyFigure extends StatelessWidget {
  const _EmptyFigure({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.emoji_people_rounded,
        size: size * 0.5,
        color: AppColors.deepPurple.withValues(alpha: 0.28),
      ),
    );
  }
}
