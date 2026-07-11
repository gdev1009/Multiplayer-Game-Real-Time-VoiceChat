// Milestone 3 — character catalog + model tests (real-art rebuild).
//
// Verifies the body-aware catalog (the woman and man have their own parts),
// the new accessory layers (hat / earrings / held item), and that the
// character model round-trips every field through its map serialization.

import 'package:flutter_test/flutter_test.dart';

import 'package:match_word/features/character/character_catalog.dart';
import 'package:match_word/models/character.dart';

void main() {
  group('catalog layers', () {
    test('body and outfit are required; everything else is optional', () {
      expect(CharacterLayer.base.optional, isFalse);
      expect(CharacterLayer.outfit.optional, isFalse);
      expect(CharacterLayer.hair.optional, isTrue);
      expect(CharacterLayer.glasses.optional, isTrue);
      expect(CharacterLayer.hat.optional, isTrue);
      expect(CharacterLayer.earrings.optional, isTrue);
      expect(CharacterLayer.accessory.optional, isTrue);
    });

    test('base layer offers both body types', () {
      final ids =
          CharacterCatalog.forLayer(CharacterLayer.base).map((o) => o.id);
      expect(ids, containsAll(<String>['body-female', 'body-male']));
    });

    test('parts are body-aware: woman and man have their own sets', () {
      final womanHair = CharacterCatalog.forLayer(
        CharacterLayer.hair,
        baseId: 'body-female',
      );
      final manHair = CharacterCatalog.forLayer(
        CharacterLayer.hair,
        baseId: 'body-male',
      );
      expect(womanHair, isNotEmpty);
      expect(manHair, isNotEmpty);
      expect(womanHair.length, isNot(equals(manHair.length)));
      // Sets are distinct (no shared ids between the two bodies' hair).
      final womanIds = womanHair.map((o) => o.id).toSet();
      final manIds = manHair.map((o) => o.id).toSet();
      expect(womanIds.intersection(manIds), isEmpty);
    });

    test('earrings are shared across both bodies', () {
      final a = CharacterCatalog.forLayer(
        CharacterLayer.earrings,
        baseId: 'body-female',
      );
      final b = CharacterCatalog.forLayer(
        CharacterLayer.earrings,
        baseId: 'body-male',
      );
      expect(a.map((o) => o.id), equals(b.map((o) => o.id)));
    });

    test('accessories cover hats, earrings and held items for each body', () {
      for (final body in <String>['body-female', 'body-male']) {
        expect(
          CharacterCatalog.forLayer(CharacterLayer.hat, baseId: body),
          isNotEmpty,
        );
        expect(
          CharacterCatalog.forLayer(CharacterLayer.accessory, baseId: body),
          isNotEmpty,
        );
      }
    });

    test('find resolves a known id and returns null for unknown', () {
      final womanFirst =
          CharacterCatalog.forLayer(CharacterLayer.hair, baseId: 'body-female')
              .first;
      final found = CharacterCatalog.find(CharacterLayer.hair, womanFirst.id);
      expect(found, isNotNull);
      expect(found!.assetPath, contains('assets/images/character/hair/'));
      expect(CharacterCatalog.find(CharacterLayer.hair, 'nope'), isNull);
    });

    test('defaultOutfitFor returns a body-appropriate outfit', () {
      expect(
        CharacterCatalog.defaultOutfitFor('body-female'),
        startsWith('outfit-f'),
      );
      expect(
        CharacterCatalog.defaultOutfitFor('body-male'),
        startsWith('outfit-m'),
      );
    });
  });

  group('Character serialization', () {
    test('round-trips body, hair, outfit, glasses and accessories', () {
      const character = Character(
        displayName: 'Sunny',
        base: 'body-female',
        hair: 'hair-f2',
        outfit: 'outfit-f3',
        glasses: 'glasses-f-round',
        hat: 'hat-f-brim',
        earrings: 'earring-1',
        accessory: 'acc-f-cane',
      );

      final restored = Character.fromMap(character.toMap('profile-123'));

      expect(restored.displayName, 'Sunny');
      expect(restored.base, 'body-female');
      expect(restored.hair, 'hair-f2');
      expect(restored.outfit, 'outfit-f3');
      expect(restored.glasses, 'glasses-f-round');
      expect(restored.hat, 'hat-f-brim');
      expect(restored.earrings, 'earring-1');
      expect(restored.accessory, 'acc-f-cane');
    });

    test('copyWith can clear an optional layer with an explicit null', () {
      const character = Character(displayName: 'Sunny', hat: 'hat-f-cap');
      final cleared = character.copyWith(hat: null);
      expect(cleared.hat, isNull);
      // Unspecified fields are preserved.
      expect(cleared.displayName, 'Sunny');
    });
  });
}

