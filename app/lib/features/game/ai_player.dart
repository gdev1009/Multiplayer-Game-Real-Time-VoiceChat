import '../../models/character.dart';
import '../character/character_catalog.dart';

/// Computer-player behaviour for the seats the host fills with studio players
///.
///
/// The host device is the single authority that drives these seats (see
/// [GameplayController]) and a studio player **never disconnects**. /// tunes them to a **moderate difficulty** so a table feels like real people
/// rather than a perfect machine:
///  * a clue-giver offers a gentle, varied one-word hint (never the word), and
///  * a guesser is *usually* right but sometimes needs a second try or misses,
///    so steals, reveals and varied scores happen naturally.
///
/// All behaviour is **deterministic for a given turn** (seeded by the word plus
/// the exchange count) so the single host driving the seat produces a stable
/// result even if it re-evaluates the same beat after a dropped request.
class AiPlayer {
  const AiPlayer._();

  /// Roughly how often a moderate-skill studio guesser lands the word on a
  /// given attempt. Tuned so AI seats score often enough that a table feels
  /// alive, while still missing enough for steals and reveals.
  static const double _guessAccuracy = 0.9;

  /// A one-word clue for [secretWord]. Uses a hand-picked hint for the words in
  /// the studio bank; falls back to a friendly generic nudge otherwise. The
  /// clue is never the word itself, so a human guesser still has to think. A
  /// bank word offers a few alternatives so repeat games don't feel scripted.
  static String clueFor(String secretWord, {int variant = 0}) {
    final key = secretWord.trim().toLowerCase();
    final options = _hints[key];
    if (options == null || options.isEmpty) return _fallbackFor(key);
    return options[variant.abs() % options.length];
  }

  /// A moderate-skill guess for [secretWord]. About [_guessAccuracy] of the
  /// time (deterministic per turn via [seed]) the studio player says the word;
  /// otherwise it offers a plausible, related-but-wrong guess so the other team
  /// gets a chance to steal — the "moderate difficulty" the spec calls for.
  ///
  /// It is given the [secretWord] only because it fills a seat (by design); the
  /// deliberate misses are what keep it fair rather than unbeatable.
  static String guessFor(String secretWord, {int seed = 0}) {
    final key = secretWord.trim().toLowerCase();
    if (key.isEmpty) return secretWord;
    // A cheap, stable hash of the word + turn seed → a 0..1 roll.
    var h = 2166136261 ^ seed;
    for (final c in key.codeUnits) {
      h = ((h ^ c) * 16777619) & 0x7fffffff;
    }
    final roll = (h % 1000) / 1000.0;
    if (roll < _guessAccuracy) return secretWord; // confident, correct guess
    return _plausibleMiss(key, h); // an honest wrong answer
  }

  /// A believable wrong guess: another everyday word (never the answer), picked
  /// deterministically from [h] so the same turn always yields the same miss.
  static String _plausibleMiss(String key, int h) {
    final pool = _missPool.where((w) => w.toLowerCase() != key).toList();
    if (pool.isEmpty) return 'Hmm';
    return pool[h % pool.length];
  }

  /// A small pool of common, on-theme words used for a studio player's
  /// occasional wrong guess so a miss reads as a real person thinking aloud.
  static const List<String> _missPool = [
    'Kettle', 'Basket', 'Sweater', 'Garden', 'Cookie', 'Muffin', 'Sunset',
    'Puppy', 'Kitten', 'Flower', 'River', 'Cabin', 'Letter', 'Sock', 'Cushion',
  ];

  /// A deterministic, friendly character for a computer-filled seat, so studio
  /// players appear as real characters on the stage instead of a blank body.
  /// The same [seed] always yields the same look, so a player is consistent.
  static Character lookFor(String seed, String name) {
    var h = 2166136261;
    for (final c in seed.codeUnits) {
      h = (h ^ c) * 16777619 & 0x7fffffff;
    }
    int pick(int n, int salt) => ((h >> (salt % 24)) ^ (h * (salt + 1))) % n;

    // Prefer a body that matches the given name when we recognise it.
    final female = _isFemaleName(name) ?? (pick(2, 1) == 0);
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
      // Skip knit (floats on voluminous hair) and male brim (reads too dressy).
      hat: _studioHat(base, pick),
    );
  }

  /// Known first-name gender hints for studio AI seats (null → use seed).
  static bool? _isFemaleName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    const female = {
      'rosie', 'pearl', 'mabel', 'grace', 'sunny', 'betty', 'doris', 'helen',
      'margaret', 'nancy', 'susan', 'linda', 'barbara', 'patricia', 'jenny',
      'mary', 'anna', 'emma', 'olivia', 'sophia', 'ava', 'mia', 'amelia',
      'rosa',
    };
    const male = {
      'greg', 'walter', 'frank', 'harold', 'arthur', 'edward', 'robert',
      'james', 'john', 'william', 'michael', 'david', 'richard', 'thomas',
      'charles', 'joe', 'bill', 'bob', 'tom', 'sam', 'max', 'leo',
    };
    // Ambiguous nicknames leave gender to the seed.
    if (n == 'buddy' || n == 'pat' || n == 'alex' || n == 'chris') return null;
    if (female.contains(n)) return true;
    if (male.contains(n)) return false;
    if (n.endsWith('ette') || n.endsWith('elle')) return true;
    return null;
  }

  /// Safe hat picks for studio AI seats — cap / sun only.
  static String? _studioHat(String base, int Function(int n, int salt) pick) {
    final male = base == 'body-male';
    final opts = CharacterCatalog.forLayer(CharacterLayer.hat, baseId: base)
        .where((o) {
      if (o.id.contains('knit')) return false;
      if (male && o.id.contains('brim')) return false;
      return true;
    }).toList();
    if (opts.isEmpty) return null;
    // ~35% chance of no hat so heads stay clean.
    if (pick(opts.length + 2, 11) >= opts.length) return null;
    return opts[pick(opts.length, 13)].id;
  }

  static String _fallbackFor(String key) {
    if (key.isEmpty) return 'Hmm';
    // A safe, non-matching nudge derived from the first letter.
    final letter = key[0].toUpperCase();
    return 'Starts$letter';
  }

  /// Two or three gentle one-word clues per bank word so a studio clue-giver
  /// sounds varied across games. Never the word itself.
  static const Map<String, List<String>> _hints = {
    'kitchen': ['Cooking', 'Stove', 'Recipes'],
    'garden': ['Flowers', 'Soil', 'Backyard'],
    'window': ['Glass', 'View', 'Curtains'],
    'blanket': ['Cozy', 'Warm', 'Bed'],
    'teapot': ['Tea', 'Pour', 'Spout'],
    'pillow': ['Sleep', 'Soft', 'Head'],
    'candle': ['Flame', 'Wax', 'Glow'],
    'mirror': ['Reflection', 'Glass', 'Look'],
    'apple': ['Fruit', 'Orchard', 'Crunchy'],
    'butter': ['Toast', 'Spread', 'Yellow'],
    'cookie': ['Sweet', 'Bake', 'Jar'],
    'coffee': ['Morning', 'Mug', 'Beans'],
    'honey': ['Bee', 'Sweet', 'Golden'],
    'lemon': ['Sour', 'Yellow', 'Zest'],
    'pancake': ['Breakfast', 'Syrup', 'Flat'],
    'popcorn': ['Movie', 'Buttery', 'Kernel'],
    'sunshine': ['Bright', 'Warm', 'Sky'],
    'rainbow': ['Colors', 'Rain', 'Arc'],
    'mountain': ['Tall', 'Climb', 'Peak'],
    'river': ['Water', 'Flow', 'Bank'],
    'flower': ['Petals', 'Bloom', 'Vase'],
    'meadow': ['Grass', 'Field', 'Open'],
    'snowman': ['Winter', 'Frosty', 'Carrot'],
    'breeze': ['Wind', 'Gentle', 'Cool'],
    'puppy': ['Dog', 'Playful', 'Paws'],
    'kitten': ['Cat', 'Purr', 'Tiny'],
    'rabbit': ['Hop', 'Ears', 'Carrot'],
    'robin': ['Bird', 'Spring', 'Feathers'],
    'butterfly': ['Wings', 'Flutter', 'Cocoon'],
    'squirrel': ['Nuts', 'Bushy', 'Tree'],
    'penguin': ['Antarctica', 'Waddle', 'Tuxedo'],
    'turtle': ['Slow', 'Shell', 'Pond'],
    'grandma': ['Family', 'Cookies', 'Hugs'],
    'postcard': ['Mail', 'Vacation', 'Stamp'],
    'bicycle': ['Wheels', 'Pedals', 'Ride'],
    'picnic': ['Park', 'Basket', 'Blanket'],
    'quilt': ['Stitches', 'Patches', 'Cozy'],
    'puzzle': ['Pieces', 'Solve', 'Jigsaw'],
    'melody': ['Song', 'Tune', 'Hum'],
    'birthday': ['Cake', 'Candles', 'Party'],
    'clock': ['Time', 'Tick', 'Hands'],
    'kettle': ['Boil', 'Whistle', 'Tea'],
    'slipper': ['Feet', 'Cozy', 'Soft'],
    'umbrella': ['Rain', 'Open', 'Shade'],
    'pumpkin': ['Orange', 'Autumn', 'Pie'],
    'sandwich': ['Lunch', 'Bread', 'Filling'],
    'seashell': ['Beach', 'Ocean', 'Sand'],
    'thunder': ['Storm', 'Loud', 'Boom'],
    'ladybug': ['Spots', 'Red', 'Tiny'],
    'dolphin': ['Ocean', 'Swim', 'Leap'],
    'holiday': ['Vacation', 'Rest', 'Travel'],
  };
}
