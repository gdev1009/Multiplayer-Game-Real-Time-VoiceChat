import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/character/character_catalog.dart';
import 'package:match_word/features/character/character_preview.dart';
import 'package:match_word/models/character.dart';

/// Ronna (Aug 2026): "everybody's hair is white. We need to have a choice of
/// hair colour."
///
/// The hair PNGs are neutral light grey (dominant value 224) so they can be
/// tinted, but nothing ever applied a tint or offered the choice.
void main() {
  group('a player can choose their hair colour', () {
    test('the palette covers the range people ask for', () {
      final ids = CharacterCatalog.hairColors.map((c) => c.id).toList();
      expect(ids, containsAll(['black', 'brown', 'blonde', 'grey', 'white']));
      expect(ids.toSet().length, ids.length, reason: 'duplicate colour id');
      expect(CharacterCatalog.hairColors.length, greaterThanOrEqualTo(6));
    });

    test('every colour has a label and an opaque tint', () {
      for (final colour in CharacterCatalog.hairColors) {
        expect(colour.label.trim(), isNotEmpty);
        expect(colour.tint.a, 1.0, reason: '${colour.id} must be opaque');
      }
    });

    test('the swatch shows what the hair will look like', () {
      // Modulate multiplies the art (base value 224) by the tint, so a swatch
      // must be darker than the tint or the picker would lie.
      for (final colour in CharacterCatalog.hairColors) {
        if (colour.id == 'white') continue; // already the untinted art
        expect(colour.swatch.r, lessThanOrEqualTo(colour.tint.r));
        expect(colour.swatch.g, lessThanOrEqualTo(colour.tint.g));
        expect(colour.swatch.b, lessThanOrEqualTo(colour.tint.b));
      }
    });

    test('the colours are actually distinguishable from each other', () {
      final seen = <String>{};
      for (final colour in CharacterCatalog.hairColors) {
        final key = '${colour.swatch.r}|${colour.swatch.g}|${colour.swatch.b}';
        expect(seen.add(key), isTrue, reason: '${colour.label} repeats a shade');
      }
    });
  });

  group('nobody is white-haired by accident', () {
    test('the default is a real hair colour, not the untinted art', () {
      final fallback = CharacterCatalog.hairColor(null);
      expect(fallback.id, CharacterCatalog.defaultHairColorId);
      expect(fallback.id, isNot('white'));
      // The grey art tinted white is what produced the complaint.
      expect(fallback.tint, isNot(const Color(0xFFFFFFFF)));
    });

    test('an unknown or missing id falls back rather than showing grey art', () {
      expect(CharacterCatalog.hairColor('not-a-colour').id,
          CharacterCatalog.defaultHairColorId);
      expect(CharacterCatalog.hairColor('').id,
          CharacterCatalog.defaultHairColorId);
    });

    test('a saved white choice is still honoured', () {
      // Plenty of players genuinely want silver or white hair.
      expect(CharacterCatalog.hairColor('white').id, 'white');
      expect(CharacterCatalog.hairColor('grey').id, 'grey');
    });
  });

  group('the choice survives a round trip', () {
    test('hair colour is saved and loaded with the character', () {
      const c = Character(
        displayName: 'Ronna',
        base: 'body-female',
        hair: 'hair-f2',
        hairColor: 'auburn',
        outfit: 'outfit-f1',
      );
      final map = c.toMap('profile-1');
      expect(map['hair_color'], 'auburn');
      expect(Character.fromMap(map).hairColor, 'auburn');
    });

    test('copyWith can change the colour and can clear it', () {
      const c = Character(displayName: 'A', hairColor: 'black');
      expect(c.copyWith(hairColor: 'red').hairColor, 'red');
      expect(c.copyWith(hairColor: null).hairColor, isNull);
      expect(c.copyWith(displayName: 'B').hairColor, 'black',
          reason: 'an unrelated edit must not drop the colour');
    });

    test('a character saved before this feature still loads', () {
      final old = {
        'display_name': 'Old',
        'base': 'body-male',
        'hair': 'hair-m1',
        'outfit': 'outfit-m1',
      };
      final c = Character.fromMap(old);
      expect(c.hairColor, isNull);
      // ...and paints with the default rather than white.
      expect(CharacterCatalog.hairColor(c.hairColor).id, isNot('white'));
    });
  });

  testWidgets('the preview tints the hair and eyebrows instead of painting grey',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CharacterPreview(
          character: Character(
            displayName: 'Ronna',
            base: 'body-female',
            hair: 'hair-f2',
            hairColor: 'auburn',
            outfit: 'outfit-f1',
          ),
          size: 240,
        ),
      ),
    );

    final tinted = tester.widgetList<ColorFiltered>(find.byType(ColorFiltered));
    expect(tinted.length, greaterThanOrEqualTo(2),
        reason: 'hair and eyebrows must both be tinted');
    final auburn = CharacterCatalog.hairColor('auburn').tint;
    expect(
      tinted.where((w) =>
          w.colorFilter == ColorFilter.mode(auburn, BlendMode.modulate)).length,
      1,
      reason: 'hair uses modulate',
    );
    expect(
      tinted.where((w) =>
          w.colorFilter == ColorFilter.mode(auburn, BlendMode.srcIn)).length,
      1,
      reason: 'brows use srcIn for solid colour',
    );
  });

  test('every hairstyle ships an eyebrow mask companion', () {
    for (final layer in [
      CharacterLayer.hair,
    ]) {
      for (final option in CharacterCatalog.forLayer(layer, baseId: 'body-female')) {
        expect(
          File(option.browMaskPath).existsSync(),
          isTrue,
          reason: '${option.id} is missing ${option.browMaskPath}',
        );
      }
      for (final option in CharacterCatalog.forLayer(layer, baseId: 'body-male')) {
        expect(File(option.browMaskPath).existsSync(), isTrue,
            reason: '${option.id} is missing ${option.browMaskPath}');
      }
    }
    for (final base in ['body-female', 'body-male']) {
      final mask = CharacterCatalog.eyebrowMaskForBase(base);
      expect(mask, isNotNull);
      expect(File(mask!).existsSync(), isTrue, reason: '$base brows mask');
    }
  });
}
