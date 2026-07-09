/// A player's assembled paper-doll character.
///
/// Each layer holds the **id** of a chosen option (see `CharacterCatalog`), or
/// `null` when the player picked "None" for that layer. The assembly engine
/// resolves these ids to PNG asset paths and layers them in order.
class Character {
  const Character({
    required this.displayName,
    this.base,
    this.baseColor,
    this.hair,
    this.hairColor,
    this.eyes,
    this.eyeColor,
    this.glasses,
    this.outfit,
  });

  final String displayName;
  final String? base;

  /// Skin-tone tint id applied to the chosen body (see `CharacterCatalog.skinColors`).
  final String? baseColor;
  final String? hair;

  /// Tint id applied to the neutral hair PNG (see `CharacterCatalog.hairColors`).
  final String? hairColor;
  final String? eyes;

  /// Tint id applied to the neutral eyes PNG (see `CharacterCatalog.eyeColors`).
  final String? eyeColor;
  final String? glasses;
  final String? outfit;

  Character copyWith({
    String? displayName,
    String? base,
    Object? baseColor = _unset,
    Object? hair = _unset,
    Object? hairColor = _unset,
    Object? eyes = _unset,
    Object? eyeColor = _unset,
    Object? glasses = _unset,
    Object? outfit = _unset,
  }) {
    return Character(
      displayName: displayName ?? this.displayName,
      base: base ?? this.base,
      baseColor: baseColor == _unset ? this.baseColor : baseColor as String?,
      hair: hair == _unset ? this.hair : hair as String?,
      hairColor: hairColor == _unset ? this.hairColor : hairColor as String?,
      eyes: eyes == _unset ? this.eyes : eyes as String?,
      eyeColor: eyeColor == _unset ? this.eyeColor : eyeColor as String?,
      glasses: glasses == _unset ? this.glasses : glasses as String?,
      outfit: outfit == _unset ? this.outfit : outfit as String?,
    );
  }

  factory Character.fromMap(Map<String, dynamic> map) {
    return Character(
      displayName: (map['display_name'] as String?) ?? '',
      base: map['base'] as String?,
      baseColor: map['base_color'] as String?,
      hair: map['hair'] as String?,
      hairColor: map['hair_color'] as String?,
      eyes: map['eyes'] as String?,
      eyeColor: map['eye_color'] as String?,
      glasses: map['glasses'] as String?,
      outfit: map['outfit'] as String?,
    );
  }

  Map<String, dynamic> toMap(String profileId) {
    return {
      'profile_id': profileId,
      'display_name': displayName,
      'base': base,
      'base_color': baseColor,
      'hair': hair,
      'hair_color': hairColor,
      'eyes': eyes,
      'eye_color': eyeColor,
      'glasses': glasses,
      'outfit': outfit,
    };
  }
}

/// Sentinel so `copyWith` can distinguish "leave unchanged" from "set to null".
const Object _unset = Object();
