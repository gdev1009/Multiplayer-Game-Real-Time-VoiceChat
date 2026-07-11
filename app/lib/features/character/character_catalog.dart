import 'package:flutter/material.dart';

/// The character layers, in back-to-front stacking order.
///
/// The assembly engine paints them in this order, so later entries appear on
/// top (e.g. [glasses] over the face, [hat] over the [hair]).
///
/// Milestone 3 uses the artist's real, full-colour PNG art. Every option is a
/// pre-registered 1254×1254 overlay that lines up exactly on the chosen body,
/// so the engine simply stacks the chosen layers — no tinting, no per-part
/// positioning.
enum CharacterLayer { base, hair, outfit, glasses, hat, earrings, accessory }

extension CharacterLayerInfo on CharacterLayer {
  /// Friendly, senior-first heading shown in the wizard.
  String get title => switch (this) {
        CharacterLayer.base => 'Choose a body',
        CharacterLayer.hair => 'Choose hair',
        CharacterLayer.outfit => 'Choose an outfit',
        CharacterLayer.glasses => 'Choose glasses',
        CharacterLayer.hat => 'Choose a hat',
        CharacterLayer.earrings => 'Choose earrings',
        CharacterLayer.accessory => 'Add something to hold',
      };

  /// Whether the player may pick "None" for this layer.
  ///
  /// A body is always required, and everyone should be dressed, so the outfit
  /// is required too. Everything else is optional.
  bool get optional =>
      this != CharacterLayer.base && this != CharacterLayer.outfit;

  /// The asset sub-folder for this layer's PNGs.
  String get folder => switch (this) {
        CharacterLayer.base => 'base',
        CharacterLayer.hair => 'hair',
        CharacterLayer.outfit => 'outfit',
        CharacterLayer.glasses => 'glasses',
        CharacterLayer.hat => 'hat',
        CharacterLayer.earrings => 'earrings',
        CharacterLayer.accessory => 'accessory',
      };

  /// A friendly icon used on section headers and the "None" tile.
  IconData get icon => switch (this) {
        CharacterLayer.base => Icons.face_2_rounded,
        CharacterLayer.hair => Icons.content_cut_rounded,
        CharacterLayer.outfit => Icons.checkroom_rounded,
        CharacterLayer.glasses => Icons.visibility_rounded,
        CharacterLayer.hat => Icons.emoji_nature_rounded,
        CharacterLayer.earrings => Icons.brightness_high_rounded,
        CharacterLayer.accessory => Icons.shopping_bag_rounded,
      };

  /// One-line, senior-friendly helper text shown under the heading.
  String get hint => switch (this) {
        CharacterLayer.base => 'Pick the body that feels like you.',
        CharacterLayer.hair => 'Choose a hairstyle, or skip it.',
        CharacterLayer.outfit => 'Pick something nice to wear.',
        CharacterLayer.glasses => 'Add glasses, or skip this step.',
        CharacterLayer.hat => 'Pop on a hat, or skip it.',
        CharacterLayer.earrings => 'Add earrings, or skip them.',
        CharacterLayer.accessory => 'A bag or a walking aid, or skip it.',
      };
}

/// A single selectable option within a layer.
class LayerOption {
  const LayerOption({
    required this.id,
    required this.label,
    required this.folder,
  });

  /// Stable id stored on the character (also the PNG file name, sans folder).
  final String id;

  /// Friendly label shown under the option.
  final String label;

  /// The asset sub-folder the PNG lives in.
  final String folder;

  /// Full asset path the assembly engine loads.
  ///
  /// Convention: `assets/images/character/<folder>/<id>.png`.
  String get assetPath => 'assets/images/character/$folder/$id.png';
}

/// The catalog of options for every layer.
///
/// Options are **body-aware**: the woman and man have their own hairstyles,
/// outfits, glasses, hats and held items (the earrings are shared). Pass the
/// chosen body id to [forLayer] to get the right set.
class CharacterCatalog {
  CharacterCatalog._();

  /// The two body choices (this layer is not body-dependent).
  static const List<LayerOption> _bodies = [
    LayerOption(id: 'body-female', label: 'Woman', folder: 'base'),
    LayerOption(id: 'body-male', label: 'Man', folder: 'base'),
  ];

  // ----- Female sets -------------------------------------------------------
  static const List<LayerOption> _hairFemale = [
    LayerOption(id: 'hair-f1', label: 'Style 1', folder: 'hair'),
    LayerOption(id: 'hair-f2', label: 'Style 2', folder: 'hair'),
    LayerOption(id: 'hair-f3', label: 'Style 3', folder: 'hair'),
    LayerOption(id: 'hair-f4', label: 'Style 4', folder: 'hair'),
    LayerOption(id: 'hair-f5', label: 'Style 5', folder: 'hair'),
    LayerOption(id: 'hair-f6', label: 'Style 6', folder: 'hair'),
    LayerOption(id: 'hair-f7', label: 'Style 7', folder: 'hair'),
    LayerOption(id: 'hair-f8', label: 'Style 8', folder: 'hair'),
  ];
  static const List<LayerOption> _outfitFemale = [
    LayerOption(id: 'outfit-f1', label: 'Outfit 1', folder: 'outfit'),
    LayerOption(id: 'outfit-f2', label: 'Outfit 2', folder: 'outfit'),
    LayerOption(id: 'outfit-f3', label: 'Outfit 3', folder: 'outfit'),
    LayerOption(id: 'outfit-f4', label: 'Outfit 4', folder: 'outfit'),
    LayerOption(id: 'outfit-f5', label: 'Outfit 5', folder: 'outfit'),
    LayerOption(id: 'outfit-f6', label: 'Outfit 6', folder: 'outfit'),
    LayerOption(id: 'outfit-f7', label: 'Outfit 7', folder: 'outfit'),
  ];
  static const List<LayerOption> _glassesFemale = [
    LayerOption(id: 'glasses-f-round', label: 'Round', folder: 'glasses'),
    LayerOption(id: 'glasses-f-rect', label: 'Rectangle', folder: 'glasses'),
    LayerOption(id: 'glasses-f-square', label: 'Square', folder: 'glasses'),
    LayerOption(id: 'glasses-f-cateye', label: 'Cat-eye', folder: 'glasses'),
  ];
  static const List<LayerOption> _hatFemale = [
    LayerOption(id: 'hat-f-cap', label: 'Cap', folder: 'hat'),
    LayerOption(id: 'hat-f-knit', label: 'Knit hat', folder: 'hat'),
    LayerOption(id: 'hat-f-brim', label: 'Brim hat', folder: 'hat'),
    LayerOption(id: 'hat-f-sun', label: 'Sun hat', folder: 'hat'),
  ];
  static const List<LayerOption> _accessoryFemale = [
    LayerOption(id: 'acc-f-purse', label: 'Purse', folder: 'accessory'),
    LayerOption(id: 'acc-f-tote', label: 'Tote bag', folder: 'accessory'),
    LayerOption(
      id: 'acc-f-crossbody',
      label: 'Shoulder bag',
      folder: 'accessory',
    ),
    LayerOption(id: 'acc-f-cane', label: 'Walking cane', folder: 'accessory'),
    LayerOption(id: 'acc-f-walker', label: 'Walker', folder: 'accessory'),
  ];

  // ----- Male sets ---------------------------------------------------------
  static const List<LayerOption> _hairMale = [
    LayerOption(id: 'hair-m1', label: 'Style 1', folder: 'hair'),
    LayerOption(id: 'hair-m2', label: 'Style 2', folder: 'hair'),
    LayerOption(id: 'hair-m3', label: 'Style 3', folder: 'hair'),
    LayerOption(id: 'hair-m4', label: 'Style 4', folder: 'hair'),
  ];
  static const List<LayerOption> _outfitMale = [
    LayerOption(id: 'outfit-m1', label: 'Outfit 1', folder: 'outfit'),
    LayerOption(id: 'outfit-m2', label: 'Outfit 2', folder: 'outfit'),
    LayerOption(id: 'outfit-m3', label: 'Outfit 3', folder: 'outfit'),
    LayerOption(id: 'outfit-m4', label: 'Outfit 4', folder: 'outfit'),
    LayerOption(id: 'outfit-m5', label: 'Outfit 5', folder: 'outfit'),
    LayerOption(id: 'outfit-m6', label: 'Outfit 6', folder: 'outfit'),
  ];
  static const List<LayerOption> _glassesMale = [
    LayerOption(id: 'glasses-m-round', label: 'Round', folder: 'glasses'),
    LayerOption(id: 'glasses-m-rect', label: 'Rectangle', folder: 'glasses'),
    LayerOption(id: 'glasses-m-square', label: 'Square', folder: 'glasses'),
    LayerOption(id: 'glasses-m-cateye', label: 'Cat-eye', folder: 'glasses'),
  ];
  static const List<LayerOption> _hatMale = [
    LayerOption(id: 'hat-m-cap', label: 'Cap', folder: 'hat'),
    LayerOption(id: 'hat-m-knit', label: 'Knit hat', folder: 'hat'),
    LayerOption(id: 'hat-m-brim', label: 'Brim hat', folder: 'hat'),
  ];
  static const List<LayerOption> _accessoryMale = [
    LayerOption(id: 'acc-m-tote', label: 'Tote bag', folder: 'accessory'),
    LayerOption(
      id: 'acc-m-crossbody',
      label: 'Shoulder bag',
      folder: 'accessory',
    ),
    LayerOption(id: 'acc-m-cane', label: 'Walking cane', folder: 'accessory'),
    LayerOption(id: 'acc-m-walker', label: 'Walker', folder: 'accessory'),
  ];

  // ----- Shared ------------------------------------------------------------
  static const List<LayerOption> _earrings = [
    LayerOption(id: 'earring-1', label: 'Studs', folder: 'earrings'),
    LayerOption(id: 'earring-2', label: 'Drops', folder: 'earrings'),
    LayerOption(id: 'earring-3', label: 'Teardrops', folder: 'earrings'),
    LayerOption(id: 'earring-4', label: 'Diamonds', folder: 'earrings'),
  ];

  /// The default body used when none has been chosen yet.
  static String get defaultBodyId => _bodies.first.id;

  /// Whether [baseId] is the male body (drives which option set to show).
  static bool _isMale(String? baseId) => baseId == 'body-male';

  /// All options for a layer, for the given body.
  static List<LayerOption> forLayer(CharacterLayer layer, {String? baseId}) {
    final male = _isMale(baseId);
    return switch (layer) {
      CharacterLayer.base => _bodies,
      CharacterLayer.hair => male ? _hairMale : _hairFemale,
      CharacterLayer.outfit => male ? _outfitMale : _outfitFemale,
      CharacterLayer.glasses => male ? _glassesMale : _glassesFemale,
      CharacterLayer.hat => male ? _hatMale : _hatFemale,
      CharacterLayer.earrings => _earrings,
      CharacterLayer.accessory => male ? _accessoryMale : _accessoryFemale,
    };
  }

  /// Finds an option by id within a layer (across both bodies), or null.
  static LayerOption? find(CharacterLayer layer, String? id) {
    if (id == null) return null;
    for (final option in [
      ...forLayer(layer, baseId: 'body-female'),
      ...forLayer(layer, baseId: 'body-male'),
    ]) {
      if (option.id == id) return option;
    }
    return null;
  }

  /// The first outfit for a body — used to dress a new character immediately.
  static String defaultOutfitFor(String? baseId) =>
      forLayer(CharacterLayer.outfit, baseId: baseId).first.id;
}

