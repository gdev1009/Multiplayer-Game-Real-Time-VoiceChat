import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/character.dart';
import 'character_catalog.dart';

/// Premium "Character Studio" preview.
///
/// Presents the player's character as a real clay figure on a soft spotlight
/// stage (matching the Guy Smiley clay art style), rather than flat shapes.
///
/// Rendering order (back to front):
///   1. Spotlight backdrop + gentle vignette.
///   2. Floor shadow ellipse (grounds the figure).
///   3. The clay body, tinted to the chosen skin tone.
///   4. Overlays for outfit / hair / eyes / glasses.
///
/// Every overlay first tries the client's real PNG
/// (`assets/images/character/<layer>/<id>.png`, sized to the full stage). Until
/// that art is delivered it falls back to a hand-crafted, clay-styled vector so
/// the builder looks finished and stays fully usable.
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

  @override
  Widget build(BuildContext context) {
    final stage = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showBackdrop) const _StageBackdrop(),
          _FloorShadow(size: size),
          _ClayBody(character: character, size: size),
          _OutfitLayer(character: character, size: size),
          _NameOnShirtLayer(character: character, size: size),
          _HairLayer(character: character, size: size),
          _EyesLayer(character: character, size: size),
          _GlassesLayer(character: character, size: size),
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
/// player's own figure — so the chooser shows the *actual* hairstyle, eye
/// shape, glasses or outfit instead of identical colour dots.
///
/// It reuses the real [CharacterPreview] assembly (PNG art first, clay-styled
/// vector fallback otherwise) on a minimal figure — the player's chosen body
/// plus only this one option — then zooms to the relevant part of the body.
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

  /// The option id to show (e.g. `hair-curly`).
  final String optionId;

  /// The current draft — used only to inherit the body and chosen colours so
  /// the thumbnail matches what the player will actually see.
  final Character reference;

  /// The rendered square size in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final baseId = reference.base ??
        CharacterCatalog.options[CharacterLayer.base]!.first.id;
    final skin = reference.baseColor ?? CharacterCatalog.skinColors.first.id;

    // A minimal figure: the chosen body plus only this option, so the
    // thumbnail unmistakably reads as this single choice.
    var c = Character(displayName: '', base: baseId, baseColor: skin);
    switch (layer) {
      case CharacterLayer.base:
        c = Character(displayName: '', base: optionId, baseColor: skin);
      case CharacterLayer.hair:
        c = c.copyWith(
          hair: optionId,
          hairColor: reference.hairColor ?? CharacterCatalog.hairColors[1].id,
        );
      case CharacterLayer.eyes:
        c = c.copyWith(
          eyes: optionId,
          eyeColor: reference.eyeColor ?? CharacterCatalog.eyeColors.first.id,
        );
      case CharacterLayer.glasses:
        c = c.copyWith(glasses: optionId);
      case CharacterLayer.outfit:
        c = c.copyWith(outfit: optionId);
    }

    // Where to centre the zoom (as a fraction of the stage height) and how
    // tight, tuned per layer so the relevant part fills the tile.
    final (double focusY, double zoom) = switch (layer) {
      CharacterLayer.outfit => (0.42, 1.55),
      CharacterLayer.base => (0.16, 2.30),
      CharacterLayer.hair => (0.115, 2.55),
      _ => (0.165, 2.75), // eyes / glasses — frame the face
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
      center: Offset(w * 0.5, h * 0.945),
      width: w * 0.52,
      height: h * 0.06,
    );
    final paint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Base clay body (skin-tinted). Falls back to a soft ghost if no base chosen.
// ---------------------------------------------------------------------------

class _ClayBody extends StatelessWidget {
  const _ClayBody({required this.character, required this.size});
  final Character character;
  final double size;

  @override
  Widget build(BuildContext context) {
    final option = CharacterCatalog.find(CharacterLayer.base, character.base);
    if (option == null) {
      return _EmptyFigure(size: size);
    }
    final image = Image.asset(
      option.assetPath(CharacterLayer.base),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _EmptyFigure(size: size),
    );
    // Apply the chosen skin tone (multiply keeps the clay shading).
    final tone =
        CharacterCatalog.findTint(CharacterLayer.base, character.baseColor)
            ?.color;
    if (tone == null) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tone, BlendMode.modulate),
      child: image,
    );
  }
}

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

// ---------------------------------------------------------------------------
// Overlay layers — real PNG first, clay-styled vector fallback otherwise.
// ---------------------------------------------------------------------------

/// Shared helper: render the real PNG for [layer]/[id] filling the stage, or
/// call [fallback] when the asset is missing.
class _AssetOrFallback extends StatelessWidget {
  const _AssetOrFallback({
    required this.layer,
    required this.id,
    required this.tint,
    required this.fallback,
    this.baseId,
  });

  final CharacterLayer layer;
  final String? id;
  final Color? tint;
  final WidgetBuilder fallback;

  /// The chosen body id, so an accessory can load a body-specific render
  /// (`<id>__<baseId>.png`) that lines up precisely with that figure.
  final String? baseId;

  @override
  Widget build(BuildContext context) {
    if (id == null) return const SizedBox.shrink();
    final option = CharacterCatalog.find(layer, id);
    if (option == null) return const SizedBox.shrink();

    // Load order, best to last resort:
    //   1. body-specific render  (hair-short__body-female.png)
    //   2. shared render         (hair-short.png)
    //   3. clay-styled vector fallback
    Widget image = Image.asset(
      option.assetPath(layer),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, _, __) => fallback(context),
    );
    final specific = baseId == null
        ? null
        : option.assetPathForBody(layer, baseId!);
    if (specific != null) {
      final shared = image;
      image = Image.asset(
        specific,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, _, __) => shared,
      );
    }
    if (tint == null) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tint!, BlendMode.modulate),
      child: image,
    );
  }
}

class _HairLayer extends StatelessWidget {
  const _HairLayer({required this.character, required this.size});
  final Character character;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color =
        CharacterCatalog.findTint(CharacterLayer.hair, character.hairColor)
                ?.color ??
            const Color(0xFF5A4636);
    return _AssetOrFallback(
      layer: CharacterLayer.hair,
      id: character.hair,
      tint: color,
      baseId: character.base,
      fallback: (_) => CustomPaint(
        size: Size(size, size),
        painter: _HairPainter(
          style: character.hair ?? '',
          color: color,
          a: _BodyAnchors.of(character.base),
        ),
      ),
    );
  }
}

class _EyesLayer extends StatelessWidget {
  const _EyesLayer({required this.character, required this.size});
  final Character character;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color =
        CharacterCatalog.findTint(CharacterLayer.eyes, character.eyeColor)
                ?.color ??
            const Color(0xFF5A3B22);
    return _AssetOrFallback(
      layer: CharacterLayer.eyes,
      id: character.eyes,
      tint: color,
      baseId: character.base,
      fallback: (_) => CustomPaint(
        size: Size(size, size),
        painter: _EyesPainter(
          color: color,
          anchors: _BodyAnchors.of(character.base),
          shape: character.eyes ?? '',
        ),
      ),
    );
  }
}

class _GlassesLayer extends StatelessWidget {
  const _GlassesLayer({required this.character, required this.size});
  final Character character;
  final double size;

  @override
  Widget build(BuildContext context) {
    final option =
        CharacterCatalog.find(CharacterLayer.glasses, character.glasses);
    final color = option?.swatch ?? const Color(0xFF333333);
    return _AssetOrFallback(
      layer: CharacterLayer.glasses,
      id: character.glasses,
      tint: null,
      baseId: character.base,
      fallback: (_) => CustomPaint(
        size: Size(size, size),
        painter: _GlassesPainter(
          color: color,
          anchors: _BodyAnchors.of(character.base),
        ),
      ),
    );
  }
}

class _OutfitLayer extends StatelessWidget {
  const _OutfitLayer({required this.character, required this.size});
  final Character character;
  final double size;

  @override
  Widget build(BuildContext context) {
    final option =
        CharacterCatalog.find(CharacterLayer.outfit, character.outfit);
    final color = option?.swatch ?? AppColors.deepPurple;
    return _AssetOrFallback(
      layer: CharacterLayer.outfit,
      id: character.outfit,
      tint: null,
      baseId: character.base,
      fallback: (_) => CustomPaint(
        size: Size(size, size),
        painter: _OutfitPainter(
          color: color,
          anchors: _BodyAnchors.of(character.base),
          outfitId: character.outfit ?? '',
        ),
      ),
    );
  }
}

/// Prints the player's name across the front of the shirt (the "name-on-shirt"
/// deliverable). Only shows when an outfit is worn and a name is set, and reads
/// on any shirt colour thanks to a soft dark outline.
class _NameOnShirtLayer extends StatelessWidget {
  const _NameOnShirtLayer({required this.character, required this.size});
  final Character character;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = character.displayName.trim();
    if (name.isEmpty || character.outfit == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        size: Size(size, size),
        painter: _NameOnShirtPainter(
          name: name,
          anchors: _BodyAnchors.of(character.base),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clay-styled vector painters (fallbacks). All coordinates are fractions of
// the square stage so they scale with [size] and track the clay body.
// ---------------------------------------------------------------------------

/// Face + torso anchor points for each body type, measured directly from the
/// clay art so overlays (eye colour, glasses, outfit) land exactly on the body
/// instead of floating. Fractions of the square stage.
class _BodyAnchors {
  const _BodyAnchors({
    required this.eyeY,
    required this.eyeCX,
    required this.eyeDX,
    required this.irisR,
    required this.templeX,
    required this.browY,
    required this.crownY,
    required this.headCX,
    required this.headHalf,
    required this.hairlineY,
    required this.collarY,
    required this.neckHalf,
    required this.shoulderY,
    required this.shoulderHalf,
    required this.sleeveY,
    required this.sleeveHalf,
    required this.waistY,
    required this.waistHalf,
    required this.hemY,
    required this.hemHalf,
    required this.hipY,
    required this.crotchY,
    required this.inseamHalf,
    required this.thighOuterHalf,
    required this.legCenter,
    required this.kneeY,
    required this.kneeHalf,
    required this.ankleY,
    required this.ankleHalf,
  });

  /// Eye line and iris placement.
  final double eyeY, eyeCX, eyeDX, irisR, templeX, browY;

  /// Head/scalp outline for hair. [crownY] top of the skull, [headCX] centre,
  /// [headHalf] half-width at the widest (ears), [hairlineY] where hair meets
  /// the forehead.
  final double crownY, headCX, headHalf, hairlineY;

  /// Torso outline for a fitted top.
  final double collarY, neckHalf;
  final double shoulderY, shoulderHalf;
  final double sleeveY, sleeveHalf;
  final double waistY, waistHalf;
  final double hemY, hemHalf;

  /// Lower body outline for fitted pants / skirt.
  final double hipY, crotchY, inseamHalf, thighOuterHalf, legCenter;
  final double kneeY, kneeHalf;
  final double ankleY, ankleHalf;

  static _BodyAnchors of(String? baseId) {
    switch (baseId) {
      case 'body-male':
        return const _BodyAnchors(
          eyeY: 0.235,
          eyeCX: 0.488,
          eyeDX: 0.060,
          irisR: 0.0105,
          templeX: 0.325,
          browY: 0.195,
          crownY: 0.044,
          headCX: 0.494,
          headHalf: 0.094,
          hairlineY: 0.098,
          collarY: 0.405,
          neckHalf: 0.055,
          shoulderY: 0.430,
          shoulderHalf: 0.220,
          sleeveY: 0.478,
          sleeveHalf: 0.235,
          waistY: 0.575,
          waistHalf: 0.160,
          hemY: 0.645,
          hemHalf: 0.190,
          hipY: 0.635,
          crotchY: 0.740,
          inseamHalf: 0.015,
          thighOuterHalf: 0.175,
          legCenter: 0.070,
          kneeY: 0.835,
          kneeHalf: 0.056,
          ankleY: 0.930,
          ankleHalf: 0.040,
        );
      case 'body-female':
      default:
        return const _BodyAnchors(
          eyeY: 0.220,
          eyeCX: 0.492,
          eyeDX: 0.060,
          irisR: 0.0100,
          templeX: 0.330,
          browY: 0.178,
          crownY: 0.062,
          headCX: 0.498,
          headHalf: 0.092,
          hairlineY: 0.120,
          collarY: 0.390,
          neckHalf: 0.050,
          shoulderY: 0.418,
          shoulderHalf: 0.200,
          sleeveY: 0.465,
          sleeveHalf: 0.215,
          waistY: 0.555,
          waistHalf: 0.150,
          hemY: 0.630,
          hemHalf: 0.180,
          hipY: 0.620,
          crotchY: 0.720,
          inseamHalf: 0.014,
          thighOuterHalf: 0.165,
          legCenter: 0.065,
          kneeY: 0.820,
          kneeHalf: 0.052,
          ankleY: 0.925,
          ankleHalf: 0.038,
        );
    }
  }
}

/// The lower-body silhouette an outfit uses.
enum _OutfitBottom { longPants, shorts, skirt }

/// A premium, full outfit: a fitted top plus matching bottoms (long pants,
/// shorts, or an A-line skirt for dresses). Calibrated per body via
/// [_BodyAnchors] so it hugs the clay figure instead of floating.
class _OutfitPainter extends CustomPainter {
  _OutfitPainter({
    required this.color,
    required this.anchors,
    required this.outfitId,
  });
  final Color color;
  final _BodyAnchors anchors;
  final String outfitId;

  _OutfitBottom get _bottom => switch (outfitId) {
        'outfit-rose' => _OutfitBottom.skirt,
        'outfit-green' => _OutfitBottom.shorts,
        'outfit-sunny' => _OutfitBottom.shorts,
        _ => _OutfitBottom.longPants,
      };

  Paint _fill(double w, double h, Rect rect, {double lighten = 0.28}) {
    return Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [
          Color.lerp(color, Colors.white, lighten)!,
          color,
          Color.lerp(color, Colors.black, 0.20)!,
        ],
        [0.0, 0.5, 1.0],
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final a = anchors;

    // 1) Bottoms first, so the top overlaps the waistband.
    switch (_bottom) {
      case _OutfitBottom.longPants:
        _drawLegs(canvas, w, h, hemY: a.ankleY, hemHalf: a.ankleHalf);
      case _OutfitBottom.shorts:
        _drawLegs(canvas, w, h, hemY: a.kneeY - 0.01, hemHalf: a.kneeHalf + 0.012);
      case _OutfitBottom.skirt:
        _drawSkirt(canvas, w, h);
    }

    // 2) The fitted top over the torso.
    _drawTop(canvas, w, h);
  }

  void _drawLegs(
    Canvas canvas,
    double w,
    double h, {
    required double hemY,
    required double hemHalf,
  }) {
    final a = anchors;
    final cx = a.eyeCX;
    final legL = cx - a.legCenter;
    final legR = cx + a.legCenter;

    final path = Path()
      // left outer hip down to the left ankle
      ..moveTo(w * (cx - a.thighOuterHalf), h * a.hipY)
      ..cubicTo(
        w * (cx - a.thighOuterHalf), h * (a.crotchY),
        w * (legL - hemHalf), h * (a.kneeY - 0.02),
        w * (legL - hemHalf), h * hemY,
      )
      // across the left hem
      ..lineTo(w * (legL + hemHalf), h * hemY)
      // up the inner left leg to the inseam
      ..cubicTo(
        w * (legL + hemHalf), h * (a.kneeY - 0.02),
        w * (cx - a.inseamHalf), h * (a.crotchY + 0.01),
        w * (cx - a.inseamHalf), h * a.crotchY,
      )
      // inseam V up to the crotch and back down the inner right leg
      ..lineTo(w * cx, h * (a.crotchY - 0.012))
      ..lineTo(w * (cx + a.inseamHalf), h * a.crotchY)
      ..cubicTo(
        w * (cx + a.inseamHalf), h * (a.crotchY + 0.01),
        w * (legR - hemHalf), h * (a.kneeY - 0.02),
        w * (legR - hemHalf), h * hemY,
      )
      // across the right hem
      ..lineTo(w * (legR + hemHalf), h * hemY)
      // up the outer right leg to the right hip
      ..cubicTo(
        w * (legR + hemHalf), h * (a.kneeY - 0.02),
        w * (cx + a.thighOuterHalf), h * a.crotchY,
        w * (cx + a.thighOuterHalf), h * a.hipY,
      )
      // across the waistband
      ..close();

    final rect = Rect.fromLTWH(
      w * (cx - a.thighOuterHalf),
      h * a.hipY,
      w * (a.thighOuterHalf * 2),
      h * (hemY - a.hipY),
    );
    canvas.drawPath(path, _fill(w, h, rect, lighten: 0.20));

    // Waistband highlight.
    final band = Paint()
      ..color = Color.lerp(color, Colors.black, 0.14)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * (cx - a.thighOuterHalf + 0.006), h * (a.hipY + 0.006)),
      Offset(w * (cx + a.thighOuterHalf - 0.006), h * (a.hipY + 0.006)),
      band,
    );
    // Hem cuffs.
    final cuff = Paint()
      ..color = Color.lerp(color, Colors.black, 0.18)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * (legL - hemHalf), h * (hemY - 0.004)),
        Offset(w * (legL + hemHalf), h * (hemY - 0.004)), cuff,);
    canvas.drawLine(Offset(w * (legR - hemHalf), h * (hemY - 0.004)),
        Offset(w * (legR + hemHalf), h * (hemY - 0.004)), cuff,);
  }

  void _drawSkirt(Canvas canvas, double w, double h) {
    final a = anchors;
    final cx = a.eyeCX;
    final hipHalf = a.thighOuterHalf * 0.78;
    final hemHalf = a.thighOuterHalf + 0.055;
    final hemY = a.kneeY - 0.01;

    final path = Path()
      ..moveTo(w * (cx - hipHalf), h * a.hipY)
      // flare out to the left hem
      ..cubicTo(
        w * (cx - hipHalf - 0.02), h * (a.hipY + 0.08),
        w * (cx - hemHalf), h * (hemY - 0.05),
        w * (cx - hemHalf), h * hemY,
      )
      // scalloped hem across
      ..quadraticBezierTo(
          w * (cx - hemHalf * 0.5), h * (hemY + 0.016), w * cx, h * hemY,)
      ..quadraticBezierTo(w * (cx + hemHalf * 0.5), h * (hemY + 0.016),
          w * (cx + hemHalf), h * hemY,)
      // flare up to the right hip
      ..cubicTo(
        w * (cx + hemHalf), h * (hemY - 0.05),
        w * (cx + hipHalf + 0.02), h * (a.hipY + 0.08),
        w * (cx + hipHalf), h * a.hipY,
      )
      ..close();

    final rect = Rect.fromLTWH(w * (cx - hemHalf), h * a.hipY,
        w * (hemHalf * 2), h * (hemY - a.hipY),);
    canvas.drawPath(path, _fill(w, h, rect, lighten: 0.24));

    // Soft vertical pleat shadows for a premium finish.
    final pleat = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.006;
    for (final f in [-0.5, 0.0, 0.5]) {
      canvas.drawLine(
        Offset(w * (cx + f * hipHalf * 0.7), h * (a.hipY + 0.03)),
        Offset(w * (cx + f * hemHalf * 0.9), h * (hemY - 0.006)),
        pleat,
      );
    }
  }

  void _drawTop(Canvas canvas, double w, double h) {
    final a = anchors;
    final cx = a.eyeCX;
    // Dresses use a slightly longer bodice that meets the skirt.
    final hemY = _bottom == _OutfitBottom.skirt ? a.hipY + 0.006 : a.hemY;

    final body = Path()
      ..moveTo(w * (cx - a.neckHalf), h * a.collarY)
      ..cubicTo(
        w * (cx - a.shoulderHalf * 0.7),
        h * (a.collarY + 0.005),
        w * (cx - a.shoulderHalf),
        h * (a.shoulderY - 0.004),
        w * (cx - a.sleeveHalf),
        h * a.sleeveY,
      )
      ..lineTo(w * (cx - a.sleeveHalf + 0.028), h * (a.sleeveY + 0.028))
      ..cubicTo(
        w * (cx - a.shoulderHalf * 0.72),
        h * (a.sleeveY + 0.03),
        w * (cx - a.waistHalf),
        h * (a.waistY - 0.02),
        w * (cx - a.waistHalf),
        h * a.waistY,
      )
      ..cubicTo(
        w * (cx - a.hemHalf),
        h * (a.waistY + 0.02),
        w * (cx - a.hemHalf),
        h * (hemY - 0.01),
        w * (cx - a.hemHalf),
        h * hemY,
      )
      ..quadraticBezierTo(
          w * cx, h * (hemY + 0.014), w * (cx + a.hemHalf), h * hemY,)
      ..cubicTo(
        w * (cx + a.hemHalf),
        h * (hemY - 0.01),
        w * (cx + a.waistHalf),
        h * (a.waistY + 0.02),
        w * (cx + a.waistHalf),
        h * a.waistY,
      )
      ..cubicTo(
        w * (cx + a.waistHalf),
        h * (a.waistY - 0.02),
        w * (cx + a.shoulderHalf * 0.72),
        h * (a.sleeveY + 0.03),
        w * (cx + a.sleeveHalf - 0.028),
        h * (a.sleeveY + 0.028),
      )
      ..lineTo(w * (cx + a.sleeveHalf), h * a.sleeveY)
      ..cubicTo(
        w * (cx + a.shoulderHalf),
        h * (a.shoulderY - 0.004),
        w * (cx + a.shoulderHalf * 0.7),
        h * (a.collarY + 0.005),
        w * (cx + a.neckHalf),
        h * a.collarY,
      )
      ..quadraticBezierTo(w * cx, h * (a.collarY + 0.032),
          w * (cx - a.neckHalf), h * a.collarY,)
      ..close();

    final rect = Rect.fromLTWH(w * (cx - a.hemHalf), h * a.collarY,
        w * (a.hemHalf * 2), h * (hemY - a.collarY),);
    canvas.drawPath(body, _fill(w, h, rect));

    // Clip fabric detail to the top so shading stays on the garment.
    canvas.save();
    canvas.clipPath(body);

    // Soft side shading gives the torso volume instead of a flat cut-out.
    for (final s in [-1.0, 1.0]) {
      final shade = Paint()
        ..color = Color.lerp(color, Colors.black, 0.30)!.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(
        Path()
          ..moveTo(w * (cx + s * a.sleeveHalf), h * a.sleeveY)
          ..quadraticBezierTo(
            w * (cx + s * a.waistHalf), h * (a.waistY - 0.02),
            w * (cx + s * a.hemHalf), h * hemY,
          ),
        shade,
      );
    }

    // Under-arm / shoulder fold shadows curving toward the waist.
    final fold = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.007
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (final s in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * (cx + s * a.shoulderHalf * 0.62), h * (a.sleeveY + 0.02))
          ..quadraticBezierTo(
            w * (cx + s * a.waistHalf * 0.5), h * (a.waistY - 0.05),
            w * (cx + s * a.waistHalf * 0.22), h * (a.waistY),
          ),
        fold,
      );
    }
    // A couple of soft drape folds down the centre front.
    for (final f in [-0.28, 0.30]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * (cx + f * a.waistHalf), h * (a.shoulderY + 0.05))
          ..quadraticBezierTo(
            w * (cx + f * a.waistHalf * 1.3), h * ((a.waistY + hemY) / 2),
            w * (cx + f * a.hemHalf), h * (hemY - 0.02),
          ),
        fold,
      );
    }
    canvas.restore();

    // Sleeve-cap seams for a tailored look.
    final seam = Paint()
      ..color = Color.lerp(color, Colors.black, 0.16)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.006
      ..strokeCap = StrokeCap.round;
    for (final s in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(w * (cx + s * a.shoulderHalf * 0.82), h * (a.shoulderY + 0.004)),
        Offset(w * (cx + s * a.sleeveHalf * 0.9), h * (a.sleeveY + 0.024)),
        seam,
      );
    }

    // Ribbed crew collar.
    final collar = Paint()
      ..color = Color.lerp(color, Colors.white, 0.42)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.010
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * (cx - a.neckHalf - 0.004), h * (a.collarY + 0.002))
        ..quadraticBezierTo(w * cx, h * (a.collarY + 0.04),
            w * (cx + a.neckHalf + 0.004), h * (a.collarY + 0.002),),
      collar,
    );

    // Soft centre highlight.
    final sheen = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * cx, h * (a.shoulderY + 0.06)),
        width: w * a.waistHalf,
        height: h * 0.10,
      ),
      sheen,
    );
  }

  @override
  bool shouldRepaint(covariant _OutfitPainter old) =>
      old.color != color || old.anchors != anchors || old.outfitId != outfitId;
}

/// Draws the player's name across the chest of the shirt. Uppercase for a
/// printed-jersey look, scaled to fit the shirt front, with a soft dark
/// outline so it stays legible on light or dark outfits.
class _NameOnShirtPainter extends CustomPainter {
  _NameOnShirtPainter({required this.name, required this.anchors});
  final String name;
  final _BodyAnchors anchors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final a = anchors;
    final cx = a.eyeCX;
    // Upper-chest band, between the collar and the waist.
    final cy = a.shoulderY + (a.waistY - a.shoulderY) * 0.34;
    // Keep the print on the shirt front, clear of the sleeves.
    final maxW = w * a.shoulderHalf * 1.25;

    final text = name.toUpperCase();
    const baseStyle = TextStyle(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
      color: Colors.white,
    );
    final fontSize = h * 0.05;

    final fill = TextPainter(
      text: TextSpan(text: text, style: baseStyle.copyWith(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();

    // Shrink to fit the shirt width; never enlarge past the base size.
    final scale = fill.width > maxW ? maxW / fill.width : 1.0;
    final drawW = fill.width * scale;
    final drawH = fill.height * scale;

    canvas.save();
    canvas.translate(w * cx - drawW / 2, h * cy - drawH / 2);
    canvas.scale(scale);

    // Dark outline backing for legibility on any shirt colour.
    final outline = TextPainter(
      text: TextSpan(
        text: text,
        style: baseStyle.copyWith(
          fontSize: fontSize,
          color: null,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = h * 0.006
            ..color = Colors.black.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    outline.paint(canvas, Offset.zero);
    fill.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NameOnShirtPainter old) =>
      old.name != name || old.anchors != anchors;
}

/// A soft clay-style hairstyle over the scalp, tinted to the hair colour.
/// Body-aware: sits on the measured crown/hairline of the chosen figure and
/// builds volume from layered, shaded strands for a realistic look.
class _HairPainter extends CustomPainter {
  _HairPainter({
    required this.style,
    required this.color,
    required this.a,
  });
  final String style;
  final Color color;
  final _BodyAnchors a;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final light = Color.lerp(color, Colors.white, 0.34)!;
    final mid = Color.lerp(color, Colors.white, 0.06)!;
    final dark = Color.lerp(color, Colors.black, 0.30)!;
    final deep = Color.lerp(color, Colors.black, 0.48)!;

    final cx = a.headCX; // head centre
    final crown = a.crownY; // top of the skull
    final half = a.headHalf; // half-width at the ears
    final line = a.hairlineY; // where hair meets the forehead

    // How far the hair falls past the ears, and any extra length panels.
    double sideY; // side hair bottom (fraction of height)
    switch (style) {
      case 'hair-bun':
        sideY = line + 0.010;
      case 'hair-long':
        sideY = line + 0.070;
      case 'hair-curly':
        sideY = line + 0.045;
      case 'hair-short':
      default:
        sideY = line + 0.006;
    }

    final topY = crown - 0.010; // hair rises just above the crown
    final outerHalf = half + 0.010; // slight puff past the head silhouette

    // ---- Long trailing panels (drawn first, behind the head mass) ----
    //
    // The two locks hang *outside* the face silhouette — from the temples down
    // past the shoulders — so long hair frames the face instead of covering it.
    // The inner edge never crosses the head half-width (where the ears are), so
    // the eyes and cheeks stay clear.
    if (style == 'hair-long') {
      final panel = Paint()
        ..shader = ui.Gradient.linear(
          Offset(w * cx, h * crown),
          Offset(w * cx, h * (line + 0.320)),
          [mid, color, dark],
          [0.0, 0.55, 1.0],
        );
      final topY = crown + 0.050; // starts at the temple, just below the crown
      final botY = line + 0.315; // falls to the upper chest
      for (final s in [-1.0, 1.0]) {
        final innerTop = cx + s * (half - 0.004); // hugs the head edge (sideburn)
        final outer = cx + s * (half + 0.052); // bulges out beside the head
        final botX = cx + s * (half + 0.016); // tapers back in at the tip
        final path = Path()
          ..moveTo(w * innerTop, h * topY)
          // outer edge: bulge out past the ear, then sweep down to the tip
          ..cubicTo(
            w * outer, h * (crown + 0.130),
            w * outer, h * (line + 0.170),
            w * botX, h * botY,
          )
          // rounded tip, then back up the inner edge (kept at the head edge)
          ..quadraticBezierTo(
            w * (cx + s * (half + 0.004)), h * (botY + 0.006),
            w * (cx + s * (half - 0.010)), h * (line + 0.190),
          )
          ..cubicTo(
            w * (cx + s * (half - 0.006)), h * (line + 0.090),
            w * (cx + s * (half - 0.002)), h * (crown + 0.120),
            w * innerTop, h * topY,
          )
          ..close();
        canvas.drawPath(path, panel);
      }
    }

    // ---- Main hair mass: cap the crown, frame down the sides ----
    final mass = Path()
      // left temple / side bottom
      ..moveTo(w * (cx - outerHalf), h * sideY)
      // up the left side and over the crown
      ..cubicTo(
        w * (cx - outerHalf - 0.006), h * (crown + 0.020),
        w * (cx - half * 0.72), h * topY,
        w * cx, h * (topY - 0.004),
      )
      // down the right side to the right temple
      ..cubicTo(
        w * (cx + half * 0.72), h * topY,
        w * (cx + outerHalf + 0.006), h * (crown + 0.020),
        w * (cx + outerHalf), h * sideY,
      )
      // inner right edge climbing back up to the hairline
      ..cubicTo(
        w * (cx + half * 0.90), h * (sideY - 0.012),
        w * (cx + half * 0.86), h * (line + 0.004),
        w * (cx + half * 0.66), h * line,
      )
      // forehead hairline with a soft central dip (widow's peak)
      ..cubicTo(
        w * (cx + half * 0.30), h * (line - 0.006),
        w * (cx + 0.028), h * (line + 0.012),
        w * cx, h * (line + 0.014),
      )
      ..cubicTo(
        w * (cx - 0.028), h * (line + 0.012),
        w * (cx - half * 0.30), h * (line - 0.006),
        w * (cx - half * 0.66), h * line,
      )
      // inner left edge back down to the temple
      ..cubicTo(
        w * (cx - half * 0.86), h * (line + 0.004),
        w * (cx - half * 0.90), h * (sideY - 0.012),
        w * (cx - outerHalf), h * sideY,
      )
      ..close();

    final massPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * cx, h * topY),
        Offset(w * cx, h * (sideY + 0.01)),
        [light, color, dark],
        [0.0, 0.5, 1.0],
      );
    canvas.drawPath(mass, massPaint);

    // Clip strand detail to the hair mass so nothing spills onto the face.
    canvas.save();
    canvas.clipPath(mass);

    // ---- Strand texture: fan of thin tapered locks from the crown ----
    final crownPt = Offset(w * cx, h * (crown + 0.002));
    final strandCount = style == 'hair-curly' ? 10 : 14;
    for (var i = 0; i < strandCount; i++) {
      final t = i / (strandCount - 1); // 0..1 left→right
      final ex = cx - outerHalf + t * (2 * outerHalf);
      final ey = sideY - 0.004 * (1 - (2 * t - 1).abs());
      final shade = i.isEven ? dark : deep;
      final strand = Paint()
        ..color = shade.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.006
        ..strokeCap = StrokeCap.round;
      // bow the strand outward from the parting for a combed look
      final bow = (t - 0.5) * 0.06;
      final path = Path()
        ..moveTo(crownPt.dx, crownPt.dy)
        ..quadraticBezierTo(
          w * (ex - bow), h * ((crown + ey) / 2),
          w * ex, h * ey,
        );
      canvas.drawPath(path, strand);
    }

    // Bright parting highlights for the clay sheen.
    for (final off in [-0.012, 0.010]) {
      final hl = Paint()
        ..color = light.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.004
        ..strokeCap = StrokeCap.round;
      final ex = cx + off * 6;
      final path = Path()
        ..moveTo(w * (cx + off), h * (crown + 0.006))
        ..quadraticBezierTo(
          w * (ex + off), h * ((crown + line) / 2),
          w * ex, h * (line + 0.002),
        );
      canvas.drawPath(path, hl);
    }

    // ---- Curly texture: overlapping shaded coils ----
    if (style == 'hair-curly') {
      for (var row = 0; row < 3; row++) {
        final ry = crown + 0.006 + row * 0.026;
        final n = 5 - (row == 1 ? 0 : 1);
        for (var i = 0; i < n; i++) {
          final fx = cx + (i - (n - 1) / 2) * (half * 0.42);
          final r = w * (0.020 - row * 0.002);
          canvas.drawCircle(
            Offset(w * fx, h * ry),
            r,
            Paint()..color = deep.withValues(alpha: 0.30),
          );
          canvas.drawCircle(
            Offset(w * (fx - 0.004), h * (ry - 0.004)),
            r * 0.5,
            Paint()..color = light.withValues(alpha: 0.30),
          );
        }
      }
    }

    canvas.restore();

    // ---- Bun: a coiled knot above the crown ----
    if (style == 'hair-bun') {
      final bc = Offset(w * cx, h * (crown - 0.028));
      final r = w * 0.040;
      canvas.drawCircle(
        bc,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            bc.translate(-r * 0.3, -r * 0.3),
            r * 1.3,
            [light, color, dark],
            [0.0, 0.55, 1.0],
          ),
      );
      // wrap coils
      final coil = Paint()
        ..color = deep.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.004;
      for (final ang in [-0.6, 0.0, 0.6]) {
        canvas.drawArc(
          Rect.fromCircle(center: bc, radius: r * 0.7),
          ang - 0.7,
          1.4,
          false,
          coil,
        );
      }
    }

    // ---- Soft top gloss band ----
    final gloss = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * (cx - 0.02), h * (crown + 0.014)),
        width: w * 0.070,
        height: h * 0.024,
      ),
      gloss,
    );
  }

  @override
  bool shouldRepaint(covariant _HairPainter old) =>
      old.color != color || old.style != style || old.a != a;
}

/// Small coloured irises placed on the clay face for the chosen eye colour.
class _EyesPainter extends CustomPainter {
  _EyesPainter({
    required this.color,
    required this.anchors,
    required this.shape,
  });
  final Color color;
  final _BodyAnchors anchors;
  final String shape;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final a = anchors;

    // A freshly drawn pair of eyes that covers the clay art, so the chosen
    // shape and colour are unmistakably the player's. Dimensions vary by style.
    final (double eyeHalfW, double eyeHalfH, double lidDrop) = switch (shape) {
      'eyes-almond' => (0.0250, 0.0130, 0.30),
      'eyes-wide' => (0.0245, 0.0160, 0.16),
      _ /* eyes-round */ => (0.0230, 0.0160, 0.10),
    };
    // Space the eyes on the body's real eye-line (measured into eyeDX), so they
    // sit over the clay eyes instead of bunched up in the middle.
    final spacing = a.eyeDX;

    // Iris height a little under the eye opening, so white shows around it and
    // the eye reads as an eye (not a dark disc / sunglasses).
    final irisR = h * (eyeHalfH * 0.82);

    for (final dir in [-1.0, 1.0]) {
      final c = Offset(w * (a.eyeCX + dir * spacing), h * a.eyeY);
      final ew = w * eyeHalfW;
      final eh = h * eyeHalfH;
      final eyeRect = Rect.fromCenter(
        center: c,
        width: ew * 2,
        height: eh * 2,
      );

      // Sclera (eye white) with a subtle top shadow for depth.
      final white = Paint()
        ..shader = ui.Gradient.linear(
          eyeRect.topCenter,
          eyeRect.bottomCenter,
          [const Color(0xFFE9EDF2), Colors.white],
          [0.0, 0.6],
        );
      final scleraPath = _eyeShapePath(eyeRect, shape);
      canvas.drawPath(scleraPath, white);

      // Clip the iris/pupil to the eye white so they sit inside the lids.
      canvas.save();
      canvas.clipPath(scleraPath);

      final ir = irisR;
      final iris = Paint()
        ..shader = ui.Gradient.radial(
          c,
          ir,
          [
            Color.lerp(color, Colors.white, 0.30)!,
            color,
            Color.lerp(color, Colors.black, 0.32)!,
          ],
          [0.0, 0.60, 1.0],
        );
      canvas.drawCircle(c, ir, iris);
      canvas.drawCircle(c, ir * 0.38, Paint()..color = const Color(0xFF120C06));
      // Iris limbal ring for a crisp, premium look.
      canvas.drawCircle(
        c,
        ir,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.0012
          ..color = Colors.black.withValues(alpha: 0.20),
      );
      // Catch-light.
      canvas.drawCircle(
        Offset(c.dx - ir * 0.34, c.dy - ir * 0.36),
        ir * 0.24,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.restore();

      // Upper eyelid line + soft lash for expression.
      final lid = Paint()
        ..color = const Color(0xFF2A1B12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.004
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - ew, c.dy - eh * (1 - lidDrop))
          ..quadraticBezierTo(
            c.dx,
            c.dy - eh * 1.25,
            c.dx + ew,
            c.dy - eh * (1 - lidDrop),
          ),
        lid,
      );

      // Thin frame around the eye to seat it on the face.
      canvas.drawPath(
        scleraPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.0018
          ..color = Colors.black.withValues(alpha: 0.16),
      );
    }
  }

  /// Builds the eye-white outline for the given style.
  Path _eyeShapePath(Rect r, String shape) {
    final cx = r.center.dx;
    final cy = r.center.dy;
    final hw = r.width / 2;
    final hh = r.height / 2;
    switch (shape) {
      case 'eyes-almond':
        // Tapered corners, like an almond.
        return Path()
          ..moveTo(cx - hw, cy)
          ..quadraticBezierTo(cx - hw * 0.4, cy - hh * 1.15, cx, cy - hh * 0.9)
          ..quadraticBezierTo(cx + hw * 0.4, cy - hh * 0.7, cx + hw, cy)
          ..quadraticBezierTo(cx + hw * 0.4, cy + hh * 0.95, cx, cy + hh * 0.9)
          ..quadraticBezierTo(cx - hw * 0.4, cy + hh * 0.95, cx - hw, cy)
          ..close();
      case 'eyes-wide':
        // Big and open, gently rounded rectangle.
        return Path()
          ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(hh)));
      default: // eyes-round
        return Path()..addOval(r);
    }
  }

  @override
  bool shouldRepaint(covariant _EyesPainter old) =>
      old.color != color || old.anchors != anchors || old.shape != shape;
}

/// Clean glasses frames resting over the eyes.
class _GlassesPainter extends CustomPainter {
  _GlassesPainter({required this.color, required this.anchors});
  final Color color;
  final _BodyAnchors anchors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final a = anchors;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final lensFill = Paint()..color = Colors.white.withValues(alpha: 0.16);

    final leftC = Offset(w * (a.eyeCX - a.eyeDX), h * a.eyeY);
    final rightC = Offset(w * (a.eyeCX + a.eyeDX), h * a.eyeY);
    final rx = w * 0.026;
    final ry = h * 0.021;
    final radius = Radius.circular(w * 0.008);
    final left = RRect.fromRectAndRadius(
      Rect.fromCenter(center: leftC, width: rx * 2, height: ry * 2),
      radius,
    );
    final right = RRect.fromRectAndRadius(
      Rect.fromCenter(center: rightC, width: rx * 2, height: ry * 2),
      radius,
    );

    canvas.drawRRect(left, lensFill);
    canvas.drawRRect(right, lensFill);
    canvas.drawRRect(left, stroke);
    canvas.drawRRect(right, stroke);
    // Bridge across the nose.
    canvas.drawLine(
      Offset(leftC.dx + rx, h * (a.eyeY - 0.002)),
      Offset(rightC.dx - rx, h * (a.eyeY - 0.002)),
      stroke,
    );
    // Temple arms out to the head edge.
    canvas.drawLine(
      Offset(leftC.dx - rx, h * (a.eyeY - 0.002)),
      Offset(w * a.templeX, h * (a.eyeY - 0.006)),
      stroke,
    );
    canvas.drawLine(
      Offset(rightC.dx + rx, h * (a.eyeY - 0.002)),
      Offset(w * (2 * a.eyeCX - a.templeX), h * (a.eyeY - 0.006)),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassesPainter old) => old.color != color;
}
