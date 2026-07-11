/// Match Word — the built-in bank of secret words (Milestone 5).
///
/// Senior-first word choices: common, concrete, everyday nouns that are easy to
/// read and fun to clue. The server keeps the authoritative list (see
/// `supabase/migrations/0007_gameplay.sql`); this mirror lets the app deal a
/// game offline (AI-only / demo) and gives the unit tests a stable source.
library;

import 'dart:math';

/// A small, curated bank of easy, family-friendly words.
class WordBank {
  const WordBank._();

  /// The words, grouped loosely by theme for variety. Kept concrete and
  /// unambiguous so clues stay simple.
  static const List<String> words = [
    // Around the house
    'Kitchen', 'Garden', 'Window', 'Blanket', 'Teapot', 'Pillow', 'Candle',
    'Mirror', 'Clock', 'Kettle', 'Slipper', 'Umbrella',
    // Food & treats
    'Apple', 'Butter', 'Cookie', 'Coffee', 'Honey', 'Lemon', 'Pancake',
    'Popcorn', 'Pumpkin', 'Sandwich',
    // Nature & weather
    'Sunshine', 'Rainbow', 'Mountain', 'River', 'Flower', 'Meadow', 'Snowman',
    'Seashell', 'Thunder', 'Breeze',
    // Animals
    'Puppy', 'Kitten', 'Rabbit', 'Robin', 'Butterfly', 'Squirrel', 'Ladybug',
    'Penguin', 'Dolphin', 'Turtle',
    // People & pastimes
    'Grandma', 'Postcard', 'Bicycle', 'Picnic', 'Garden', 'Quilt', 'Puzzle',
    'Melody', 'Birthday', 'Holiday',
  ];

  /// Returns [count] distinct words in random order. Falls back to sampling with
  /// repeats only if [count] exceeds the bank size.
  static List<String> deal(int count, {Random? random}) {
    final rng = random ?? Random();
    final pool = List<String>.of(words)..shuffle(rng);
    if (count <= pool.length) return pool.take(count).toList();
    // More words requested than we have — top up by cycling the shuffled pool.
    final out = <String>[];
    var i = 0;
    while (out.length < count) {
      out.add(pool[i % pool.length]);
      i++;
    }
    return out;
  }
}
