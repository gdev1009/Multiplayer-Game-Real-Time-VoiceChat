// Milestone 3 — character tinting logic tests.
//
// Verifies the neutral-PNG + colour-tint design Ronna asked for: hair and eyes
// are tintable, picking a style assigns a default colour, and the character
// model round-trips the colour ids through its map serialization.

import 'package:flutter_test/flutter_test.dart';

import 'package:match_word/features/character/character_catalog.dart';
import 'package:match_word/models/character.dart';

void main() {
  group('tintable layers', () {
    test('base, hair and eyes are tintable; others are not', () {
      expect(CharacterLayer.base.tintable, isTrue);
      expect(CharacterLayer.hair.tintable, isTrue);
      expect(CharacterLayer.eyes.tintable, isTrue);
      expect(CharacterLayer.glasses.tintable, isFalse);
      expect(CharacterLayer.outfit.tintable, isFalse);
    });

    test('each tintable layer exposes a non-empty colour palette', () {
      expect(CharacterCatalog.tintsFor(CharacterLayer.base), isNotEmpty);
      expect(CharacterCatalog.tintsFor(CharacterLayer.hair), isNotEmpty);
      expect(CharacterCatalog.tintsFor(CharacterLayer.eyes), isNotEmpty);
      expect(CharacterCatalog.tintsFor(CharacterLayer.glasses), isEmpty);
    });

    test('base layer offers both body types', () {
      final ids =
          CharacterCatalog.forLayer(CharacterLayer.base).map((o) => o.id);
      expect(ids, containsAll(<String>['body-female', 'body-male']));
    });

    test('findTint resolves a known id and returns null for unknown', () {
      final brown = CharacterCatalog.findTint(CharacterLayer.hair, 'brown');
      expect(brown, isNotNull);
      expect(brown!.label, 'Brown');
      expect(CharacterCatalog.findTint(CharacterLayer.hair, 'nope'), isNull);
    });
  });

  group('Character serialization', () {
    test('round-trips body, skin, hair and eye colours', () {
      const character = Character(
        displayName: 'Sunny',
        base: 'body-male',
        baseColor: 'tan',
        hair: 'hair-spiky',
        hairColor: 'auburn',
        eyes: 'eyes-round',
        eyeColor: 'blue',
      );

      final restored = Character.fromMap(character.toMap('profile-123'));

      expect(restored.displayName, 'Sunny');
      expect(restored.base, 'body-male');
      expect(restored.baseColor, 'tan');
      expect(restored.hair, 'hair-spiky');
      expect(restored.hairColor, 'auburn');
      expect(restored.eyes, 'eyes-round');
      expect(restored.eyeColor, 'blue');
    });

    test('copyWith can clear a colour with an explicit null', () {
      const character = Character(displayName: 'Sunny', hairColor: 'brown');
      final cleared = character.copyWith(hairColor: null);
      expect(cleared.hairColor, isNull);
      // Unspecified fields are preserved.
      expect(cleared.displayName, 'Sunny');
    });
  });
}

