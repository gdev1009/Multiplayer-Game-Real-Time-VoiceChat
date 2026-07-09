import 'package:flutter/material.dart';

/// The character layers, in back-to-front stacking order.
///
/// The assembly engine paints them in this order, so later entries appear on
/// top (e.g. [glasses] over [eyes], [outfit] over [base]).
enum CharacterLayer { base, hair, eyes, glasses, outfit }

extension CharacterLayerInfo on CharacterLayer {
  /// Friendly, senior-first heading shown in the wizard.
  String get title => switch (this) {
        CharacterLayer.base => 'Choose a body',
        CharacterLayer.hair => 'Choose hair',
        CharacterLayer.eyes => 'Choose eyes',
        CharacterLayer.glasses => 'Choose glasses',
        CharacterLayer.outfit => 'Choose an outfit',
      };

  /// Whether the player may pick "None" for this layer.
  ///
  /// A face is always required; everything else is optional so the engine must
  /// handle missing layers gracefully.
  bool get optional => this != CharacterLayer.base;

  /// Whether this layer's art is a neutral PNG that the app tints with a
  /// player-chosen colour (skin tone for the body, colour for hair and eyes).
  /// The client supplies one colourless/neutral PNG per style and the engine
  /// applies the colour.
  bool get tintable =>
      this == CharacterLayer.base ||
      this == CharacterLayer.hair ||
      this == CharacterLayer.eyes;

  /// The asset sub-folder for this layer's PNGs.
  String get folder => switch (this) {
        CharacterLayer.base => 'base',
        CharacterLayer.hair => 'hair',
        CharacterLayer.eyes => 'eyes',
        CharacterLayer.glasses => 'glasses',
        CharacterLayer.outfit => 'outfit',
      };

  /// A friendly icon used on section headers and the "None" tile.
  IconData get icon => switch (this) {
        CharacterLayer.base => Icons.face_2_rounded,
        CharacterLayer.hair => Icons.content_cut_rounded,
        CharacterLayer.eyes => Icons.remove_red_eye_rounded,
        CharacterLayer.glasses => Icons.visibility_rounded,
        CharacterLayer.outfit => Icons.checkroom_rounded,
      };

  /// One-line, senior-friendly helper text shown under the heading.
  String get hint => switch (this) {
        CharacterLayer.base => 'Pick a body, then a skin tone.',
        CharacterLayer.hair => 'Choose a style, then a colour.',
        CharacterLayer.eyes => 'Choose a shape, then a colour.',
        CharacterLayer.glasses => 'Add glasses, or skip this step.',
        CharacterLayer.outfit => 'Pick an outfit colour, or skip.',
      };
}

/// A single selectable option within a layer.
class LayerOption {
  const LayerOption({
    required this.id,
    required this.label,
    this.swatch,
    this.asset,
  });

  /// Stable id stored on the character (also the PNG file name, sans folder).
  final String id;

  /// Friendly label shown under the option.
  final String label;

  /// Optional colour used by the fallback renderer when the PNG is absent,
  /// so the builder is fully usable before final art arrives. For the base
  /// layer this doubles as the skin tone applied to the shared clay body.
  final Color? swatch;

  /// Optional explicit asset path. When null the engine uses the convention
  /// `assets/images/character/<folder>/<id>.png`. Used so every skin tone can
  /// share the one real clay body render.
  final String? asset;

  /// Full asset path the assembly engine tries to load.
  ///
  /// Convention: `assets/images/character/<folder>/<id>.png`. Drop the
  /// client's PNGs in with these names and they appear automatically.
  String assetPath(CharacterLayer layer) =>
      asset ?? 'assets/images/character/${layer.folder}/$id.png';

  /// Optional body-specific render tried *before* [assetPath], so an accessory
  /// can be positioned precisely for each body shape.
  ///
  /// Convention: `assets/images/character/<folder>/<id>__<baseId>.png`
  /// (e.g. `hair-short__body-female.png`). Returns null for layers that use an
  /// explicit [asset] (the base body itself).
  String? assetPathForBody(CharacterLayer layer, String baseId) =>
      asset != null
          ? null
          : 'assets/images/character/${layer.folder}/${id}__$baseId.png';
}

/// The catalog of options for every layer.
///
/// This is the single place to register character parts. When Ronna sends the
/// layered PNGs, add an entry here (or reuse these ids as file names) and the
/// wizard + assembly engine pick them up with no other code changes.
class CharacterCatalog {
  CharacterCatalog._();

  static const Map<CharacterLayer, List<LayerOption>> options = {
    CharacterLayer.base: [
      LayerOption(
        id: 'body-female',
        label: 'Woman',
        swatch: Color(0xFFE7BE9A),
        asset: 'assets/images/character/base/body-female.png',
      ),
      LayerOption(
        id: 'body-male',
        label: 'Man',
        swatch: Color(0xFFE7BE9A),
        asset: 'assets/images/character/base/body-male.png',
      ),
    ],
    CharacterLayer.hair: [
      LayerOption(id: 'hair-spiky', label: 'Spiky', swatch: Color(0xFF8A6A4A)),
      LayerOption(id: 'hair-short', label: 'Short', swatch: Color(0xFF8A6A4A)),
      LayerOption(id: 'hair-curly', label: 'Curly', swatch: Color(0xFF8A6A4A)),
      LayerOption(id: 'hair-bun', label: 'Bun', swatch: Color(0xFF8A6A4A)),
      LayerOption(id: 'hair-long', label: 'Long', swatch: Color(0xFF8A6A4A)),
    ],
    CharacterLayer.eyes: [
      LayerOption(id: 'eyes-round', label: 'Round', swatch: Color(0xFF6B4226)),
      LayerOption(id: 'eyes-almond', label: 'Almond', swatch: Color(0xFF6B4226)),
      LayerOption(id: 'eyes-wide', label: 'Wide', swatch: Color(0xFF6B4226)),
    ],
    CharacterLayer.glasses: [
      LayerOption(id: 'glasses-round', label: 'Round', swatch: Color(0xFF333333)),
      LayerOption(id: 'glasses-square', label: 'Square', swatch: Color(0xFF5B2D8E)),
      LayerOption(id: 'glasses-gold', label: 'Gold', swatch: Color(0xFFD4A431)),
    ],
    CharacterLayer.outfit: [
      LayerOption(
        id: 'outfit-blue',
        label: 'Blue suit',
        swatch: Color(0xFF3F51B5),
      ),
      LayerOption(
        id: 'outfit-rose',
        label: 'Rose dress',
        swatch: Color(0xFFC2185B),
      ),
      LayerOption(
        id: 'outfit-green',
        label: 'Green set',
        swatch: Color(0xFF2E7D32),
      ),
      LayerOption(
        id: 'outfit-purple',
        label: 'Purple set',
        swatch: Color(0xFF5B2D8E),
      ),
      LayerOption(
        id: 'outfit-sunny',
        label: 'Sunny shorts',
        swatch: Color(0xFFF39C12),
      ),
      LayerOption(
        id: 'outfit-teal',
        label: 'Teal hoodie',
        swatch: Color(0xFF00897B),
      ),
    ],
  };

  /// All options for a layer.
  static List<LayerOption> forLayer(CharacterLayer layer) =>
      options[layer] ?? const [];

  /// Finds an option by id within a layer, or null.
  static LayerOption? find(CharacterLayer layer, String? id) {
    if (id == null) return null;
    for (final option in forLayer(layer)) {
      if (option.id == id) return option;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Colour tints for the neutral hair and eyes PNGs.
  //
  // Ronna supplies one colourless PNG per style; the player then picks a colour
  // here and the assembly engine tints the art. Add or reorder entries freely.
  // ---------------------------------------------------------------------------

  static const List<TintOption> hairColors = [
    TintOption(id: 'black', label: 'Black', color: Color(0xFF2E2A26)),
    TintOption(id: 'brown', label: 'Brown', color: Color(0xFF6B4226)),
    TintOption(id: 'auburn', label: 'Auburn', color: Color(0xFF8A3324)),
    TintOption(id: 'blonde', label: 'Blonde', color: Color(0xFFD9B370)),
    TintOption(id: 'grey', label: 'Grey', color: Color(0xFFBFBFBF)),
    TintOption(id: 'white', label: 'White', color: Color(0xFFEDE8E0)),
  ];

  static const List<TintOption> eyeColors = [
    TintOption(id: 'brown', label: 'Brown', color: Color(0xFF6B4226)),
    TintOption(id: 'hazel', label: 'Hazel', color: Color(0xFF8E6B3A)),
    TintOption(id: 'green', label: 'Green', color: Color(0xFF4E8A5B)),
    TintOption(id: 'blue', label: 'Blue', color: Color(0xFF3F6FB0)),
    TintOption(id: 'grey', label: 'Grey', color: Color(0xFF7E8791)),
  ];

  /// Skin tones for the body. These multiply onto the clay render, so the
  /// first (lightest) keeps the art bright and later ones deepen it.
  static const List<TintOption> skinColors = [
    TintOption(id: 'light', label: 'Light', color: Color(0xFFFFF4EA)),
    TintOption(id: 'medium', label: 'Medium', color: Color(0xFFF0D2B4)),
    TintOption(id: 'tan', label: 'Tan', color: Color(0xFFD9AC86)),
    TintOption(id: 'deep', label: 'Deep', color: Color(0xFFB07E58)),
  ];

  /// The colour palette for a tintable layer (empty for non-tintable layers).
  static List<TintOption> tintsFor(CharacterLayer layer) => switch (layer) {
        CharacterLayer.base => skinColors,
        CharacterLayer.hair => hairColors,
        CharacterLayer.eyes => eyeColors,
        _ => const [],
      };

  /// Finds a tint option by id within a layer's palette, or null.
  static TintOption? findTint(CharacterLayer layer, String? id) {
    if (id == null) return null;
    for (final tint in tintsFor(layer)) {
      if (tint.id == id) return tint;
    }
    return null;
  }
}

/// A selectable colour applied to a tintable layer's neutral PNG.
class TintOption {
  const TintOption({
    required this.id,
    required this.label,
    required this.color,
  });

  /// Stable id stored on the character (e.g. `brown`).
  final String id;

  /// Friendly label shown under the colour swatch.
  final String label;

  /// The colour multiplied onto the neutral PNG by the assembly engine.
  final Color color;
}

