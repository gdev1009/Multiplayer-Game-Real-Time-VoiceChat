import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/character.dart';
import 'character_catalog.dart';
import 'character_poses.dart';

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
/// When [pose] is set, the neutral base body is swapped for the matching
/// posed PNG (generated from the same artist body by
/// `tools/generate_idle_poses.py`) so idle expressions/gestures can play while
/// the rest of the layers stay registered.
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
    this.pose,
    this.mouthOpen = 0,
  });

  final Character character;
  final double size;

  /// When false the studio backdrop/border is omitted (for tight inline uses).
  final bool showBackdrop;

  /// Optional named idle pose — swaps only the base body layer.
  final CharacterPose? pose;

  /// Lipsync amplitude 0..1 — overlays a mouth sprite on the face.
  final double mouthOpen;

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
    final wearingHat =
        character.hat != null && character.hat!.trim().isNotEmpty;
    final talkPose = CharacterPose.talkFromAmplitude(mouthOpen);
    final effectivePose = talkPose ?? pose;

    for (final layer in _paintOrder) {
      // Hats aren't authored to sit over voluminous hair — skip hair when
      // hatted so crown/brim don't float above a second hair dome.
      if (layer == CharacterLayer.hair && wearingHat) continue;

      if (layer == CharacterLayer.base && effectivePose != null) {
        final posePath = poseAssetPath(character.base, effectivePose);
        if (posePath != null) {
          layers.add(
            Image.asset(
              posePath,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) {
                final id = character.base;
                if (id == null) return const SizedBox.shrink();
                final option = CharacterCatalog.find(CharacterLayer.base, id);
                if (option == null) return const SizedBox.shrink();
                return Image.asset(
                  option.assetPath,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                );
              },
            ),
          );
          continue;
        }
      }
      final id = _idFor(layer);
      if (id == null) continue;
      final option = CharacterCatalog.find(layer, id);
      if (option == null) continue;
      Widget image = Image.asset(
        option.assetPath,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
      // Pull hats down onto the crown so they don't float above the skull.
      if (layer == CharacterLayer.hat) {
        image = Transform.translate(
          offset: Offset(0, size * 0.012),
          child: image,
        );
      }
      layers.add(image);
    }

    // Soft skin bridge under the chin so outfit collars never flash a hole
    // (the grey diamond neck artifact on the studio bust).
    if (character.base != null) {
      final bridge = CustomPaint(
        size: Size(size, size),
        painter: _NeckBridgePainter(
          female: character.base == 'body-female',
        ),
      );
      // Insert after base (index 0 or 1 if backdrop shadow…) — layers start
      // with base as first character layer; put bridge right after first layer.
      if (layers.isNotEmpty) {
        layers.insert(1, bridge);
      }
    }

    final stage = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showBackdrop) const _StageBackdrop(),
          if (showBackdrop) _FloorShadow(size: size),
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

/// Soft skin oval under the chin so open collars never show a hole / diamond.
class _NeckBridgePainter extends CustomPainter {
  _NeckBridgePainter({required this.female});
  final bool female;

  @override
  void paint(Canvas canvas, Size size) {
    final skin = female
        ? const Color(0xFFF6C49A)
        : const Color(0xFFF9C28B);
    final w = size.width;
    final h = size.height;
    // Chin ~ y 360/1254 ≈ 0.287; shoulders ~ 0.375 — fill that band.
    final rect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.325),
      width: w * 0.18,
      height: h * 0.085,
    );
    final paint = Paint()
      ..color = skin
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.012);
    canvas.drawOval(rect, paint);
    // Slightly denser core so thin collar gaps stay filled.
    canvas.drawOval(
      rect.deflate(w * 0.02),
      Paint()..color = skin.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _NeckBridgePainter oldDelegate) =>
      oldDelegate.female != female;
}

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
