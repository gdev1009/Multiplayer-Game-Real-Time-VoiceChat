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

  /// Friendly first-name pool for studio seats (client demos + offline fill).
  static const fillNamePool = [
    'Sunny', 'Rosie', 'Buddy', 'Pearl', 'Gus', 'Mabel', 'Otis', 'Ada',
    'Walter', 'Rosa', 'Frank', 'Helen', 'Betty', 'Joe', 'Doris', 'Sam',
    'Nancy', 'Bill', 'Grace', 'Tom', 'Linda', 'Arthur', 'Margaret', 'Max',
  ];

  /// Deterministic unique names for empty seats in one game (mirrors SQL fill).
  static List<String> fillNamesForGame(
    String gameId, {
    required int count,
    Iterable<String> taken = const [],
  }) {
    final used = {
      for (final n in taken) n.trim().toLowerCase(),
    }..removeWhere((n) => n.isEmpty);
    final ranked = [...fillNamePool]..sort(
        (a, b) => _stableHash('$gameId:$a').compareTo(_stableHash('$gameId:$b')),
      );
    final out = <String>[];
    for (final name in ranked) {
      if (out.length >= count) break;
      final key = name.toLowerCase();
      if (used.contains(key)) continue;
      used.add(key);
      out.add(name);
    }
    var i = 1;
    while (out.length < count) {
      final fallback = 'Player$i';
      i++;
      if (used.contains(fallback.toLowerCase())) continue;
      used.add(fallback.toLowerCase());
      out.add(fallback);
    }
    return out;
  }

  static int _stableHash(String s) {
    var h = 2166136261;
    for (final c in s.codeUnits) {
      h = (h ^ c) * 16777619 & 0x7fffffff;
    }
    return h;
  }

  /// A deterministic, friendly character for a computer-filled seat, so studio
  /// players appear as real characters on the stage instead of a blank body.
  /// The same [seed] always yields the same look, so a player is consistent.
  static Character lookFor(String seed, String name) {
    return _lookFor(
      seed,
      name,
      usedHair: const {},
      usedGlasses: const {},
      usedHat: const {},
      usedOutfit: const {},
    );
  }

  /// Distinct looks for every AI seat in one match (video23: Rosie & Pearl
  /// shared the same hat + glasses). Hair, glasses, hat, and outfit stay unique
  /// across the roster while remaining stable for [salt].
  static Map<String, Character> looksForSeats(
    String salt,
    Iterable<({String role, String name})> seats,
  ) {
    final usedHair = <String>{};
    final usedGlasses = <String>{};
    final usedHat = <String>{};
    final usedOutfit = <String>{};
    final out = <String, Character>{};
    var i = 0;
    for (final seat in seats) {
      final c = _lookFor(
        '$salt:${seat.role}:${seat.name}:$i',
        seat.name,
        usedHair: usedHair,
        usedGlasses: usedGlasses,
        usedHat: usedHat,
        usedOutfit: usedOutfit,
      );
      if (c.hair != null) usedHair.add(c.hair!);
      usedGlasses.add(c.glasses ?? '__none__');
      usedHat.add(c.hat ?? '__none__');
      if (c.outfit != null) usedOutfit.add(c.outfit!);
      out[seat.role] = c;
      i++;
    }
    return out;
  }

  static Character _lookFor(
    String seed,
    String name, {
    required Set<String> usedHair,
    required Set<String> usedGlasses,
    required Set<String> usedHat,
    required Set<String> usedOutfit,
  }) {
    var h = 2166136261;
    for (final c in seed.codeUnits) {
      h = (h ^ c) * 16777619 & 0x7fffffff;
    }
    int pick(int n, int salt) =>
        n <= 0 ? 0 : ((h >> (salt % 24)) ^ (h * (salt + 1))) % n;

    final female = _isFemaleName(name) ?? (pick(2, 1) == 0);
    final base = female ? 'body-female' : 'body-male';

    String? pickAvoid(
      CharacterLayer layer,
      int salt, {
      required Set<String> used,
      bool allowNone = false,
      bool noneCounts = true,
      bool Function(String id)? keep,
    }) {
      var opts = CharacterCatalog.forLayer(layer, baseId: base)
          .where((o) => keep == null || keep(o.id))
          .toList();
      if (opts.isEmpty) return null;
      // Prefer unused ids; fall back to full list if exhausted.
      final fresh = opts.where((o) => !used.contains(o.id)).toList();
      if (fresh.isNotEmpty) opts = fresh;
      final noneOk = allowNone &&
          (!noneCounts || !used.contains('__none__'));
      final span = opts.length + (noneOk ? 1 : 0);
      final i = pick(span, salt);
      if (noneOk && i == opts.length) return null;
      return opts[i % opts.length].id;
    }

    final hair = pickAvoid(CharacterLayer.hair, 3, used: usedHair);
    final outfit = pickAvoid(CharacterLayer.outfit, 5, used: usedOutfit) ??
        CharacterCatalog.defaultOutfitFor(base);
    final glasses = pickAvoid(
      CharacterLayer.glasses,
      7,
      used: usedGlasses,
      allowNone: true,
    );
    final hat = pickAvoid(
      CharacterLayer.hat,
      13,
      used: usedHat,
      allowNone: true,
      keep: (id) {
        if (id.contains('knit')) return false;
        if (base == 'body-male' && id.contains('brim')) return false;
        return true;
      },
    );

    return Character(
      displayName: name,
      base: base,
      hair: hair,
      outfit: outfit,
      glasses: glasses,
      hat: hat,
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
