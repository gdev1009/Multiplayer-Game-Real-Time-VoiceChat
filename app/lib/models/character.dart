/// A player's assembled paper-doll character.
///
/// Each layer holds the **id** of a chosen option (see `CharacterCatalog`), or
/// `null` when the player picked "None" for that layer. The assembly engine
/// resolves these ids to PNG asset paths and layers them in order.
///
/// Uses the artist's full-colour art, so there are no colour
/// tints — the chosen art is exactly what is shown.
class Character {
  const Character({
    required this.displayName,
    this.base,
    this.hair,
    this.outfit,
    this.glasses,
    this.hat,
    this.earrings,
    this.accessory,
  });

  final String displayName;

  /// The body id (`body-female` / `body-male`).
  final String? base;
  final String? hair;
  final String? outfit;
  final String? glasses;

  /// Headwear (a hat or cap).
  final String? hat;
  final String? earrings;

  /// A held item — a bag, a walking cane or a walker.
  final String? accessory;

  Character copyWith({
    String? displayName,
    String? base,
    Object? hair = _unset,
    Object? outfit = _unset,
    Object? glasses = _unset,
    Object? hat = _unset,
    Object? earrings = _unset,
    Object? accessory = _unset,
  }) {
    return Character(
      displayName: displayName ?? this.displayName,
      base: base ?? this.base,
      hair: hair == _unset ? this.hair : hair as String?,
      outfit: outfit == _unset ? this.outfit : outfit as String?,
      glasses: glasses == _unset ? this.glasses : glasses as String?,
      hat: hat == _unset ? this.hat : hat as String?,
      earrings: earrings == _unset ? this.earrings : earrings as String?,
      accessory: accessory == _unset ? this.accessory : accessory as String?,
    );
  }

  factory Character.fromMap(Map<String, dynamic> map) {
    return Character(
      displayName: (map['display_name'] as String?) ?? '',
      base: map['base'] as String?,
      hair: map['hair'] as String?,
      outfit: map['outfit'] as String?,
      glasses: map['glasses'] as String?,
      hat: map['hat'] as String?,
      earrings: map['earrings'] as String?,
      accessory: map['accessory'] as String?,
    );
  }

  Map<String, dynamic> toMap(String profileId) {
    return {
      'profile_id': profileId,
      'display_name': displayName,
      'base': base,
      'hair': hair,
      'outfit': outfit,
      'glasses': glasses,
      'hat': hat,
      'earrings': earrings,
      'accessory': accessory,
    };
  }
}

/// Sentinel so `copyWith` can distinguish "leave unchanged" from "set to null".
const Object _unset = Object();
