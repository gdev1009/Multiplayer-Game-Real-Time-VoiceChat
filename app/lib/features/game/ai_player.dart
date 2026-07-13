import '../../models/character.dart';
import '../character/character_catalog.dart';

/// Computer-player behaviour for the seats the host fills with studio players.
///
/// The host device is the single authority that drives these seats (see
/// [GameplayController]). To keep the game moving and let teams actually score,
/// a computer guesser knows the secret word (it plays for a filled seat, so it
/// is allowed to), and a computer clue-giver offers a gentle one-word hint so a
/// human partner still has a fair chance to guess.
class AiPlayer {
  const AiPlayer._();

  /// A one-word clue for [secretWord]. Uses a hand-picked hint for the words in
  /// the studio bank; falls back to a friendly generic nudge otherwise. The
  /// clue is never the word itself, so a human guesser still has to think.
  static String clueFor(String secretWord) {
    final key = secretWord.trim().toLowerCase();
    return _hints[key] ?? _fallbackFor(key);
  }

  /// A computer guesser plays to win: it guesses the actual word so its team can
  /// score. (It only ever fills a seat, so knowing the word is by design.)
  static String guessFor(String secretWord) => secretWord;

  /// A deterministic, friendly character for a computer-filled seat, so studio
  /// players appear as real characters on the stage instead of a blank body.
  /// The same [seed] always yields the same look, so a player is consistent.
  static Character lookFor(String seed, String name) {
    var h = 2166136261;
    for (final c in seed.codeUnits) {
      h = (h ^ c) * 16777619 & 0x7fffffff;
    }
    int pick(int n, int salt) => ((h >> (salt % 24)) ^ (h * (salt + 1))) % n;

    final female = pick(2, 1) == 0;
    final base = female ? 'body-female' : 'body-male';

    String? idAt(CharacterLayer layer, int salt, {bool allowNone = false}) {
      final opts = CharacterCatalog.forLayer(layer, baseId: base);
      if (opts.isEmpty) return null;
      final span = opts.length + (allowNone ? 1 : 0);
      final i = pick(span, salt);
      if (allowNone && i == opts.length) return null;
      return opts[i].id;
    }

    return Character(
      displayName: name,
      base: base,
      hair: idAt(CharacterLayer.hair, 3),
      outfit: idAt(CharacterLayer.outfit, 5) ??
          CharacterCatalog.defaultOutfitFor(base),
      glasses: idAt(CharacterLayer.glasses, 7, allowNone: true),
      hat: idAt(CharacterLayer.hat, 11, allowNone: true),
    );
  }

  static String _fallbackFor(String key) {
    if (key.isEmpty) return 'Hmm';
    // A safe, non-matching nudge derived from the first letter.
    final letter = key[0].toUpperCase();
    return 'Starts$letter';
  }

  static const Map<String, String> _hints = {
    'kitchen': 'Cooking',
    'garden': 'Flowers',
    'window': 'Glass',
    'blanket': 'Cozy',
    'teapot': 'Tea',
    'pillow': 'Sleep',
    'candle': 'Flame',
    'mirror': 'Reflection',
    'apple': 'Fruit',
    'butter': 'Toast',
    'cookie': 'Sweet',
    'coffee': 'Morning',
    'honey': 'Bee',
    'lemon': 'Sour',
    'pancake': 'Breakfast',
    'popcorn': 'Movie',
    'sunshine': 'Bright',
    'rainbow': 'Colors',
    'mountain': 'Tall',
    'river': 'Water',
    'flower': 'Petals',
    'meadow': 'Grass',
    'snowman': 'Winter',
    'breeze': 'Wind',
    'puppy': 'Dog',
    'kitten': 'Cat',
    'rabbit': 'Hop',
    'robin': 'Bird',
    'butterfly': 'Wings',
    'squirrel': 'Nuts',
    'penguin': 'Antarctica',
    'turtle': 'Slow',
    'grandma': 'Family',
    'postcard': 'Mail',
    'bicycle': 'Wheels',
    'picnic': 'Park',
    'quilt': 'Stitches',
    'puzzle': 'Pieces',
    'melody': 'Song',
    'birthday': 'Cake',
  };
}
