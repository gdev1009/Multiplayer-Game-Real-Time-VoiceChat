import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/game/ai_player.dart';
import 'package:match_word/features/game/clue_bank.dart';
import 'package:match_word/features/game/word_bank.dart';

/// Ronna (Aug 2026): "when the stand in AI plays, the answers they're giving are
/// not making any sense. And yet often times they tell them they're right. We
/// have to have a word and answer based that is completely sensible."
///
/// The cause was clue data, not scoring: 1,010 of the 1,209 words in the old
/// bank carried a generic category placeholder instead of a clue, so "Person"
/// was the clue for 91 different answers. These tests are the guard rail that
/// keeps a word out of play unless it can be clued.
void main() {
  final words = ClueBank.clues.keys.toList();

  group('every playable word can actually be clued', () {
    test('the bank is big enough for plenty of variety', () {
      // A game deals 16 words (8 per half).
      expect(words.length, greaterThanOrEqualTo(200));
    });

    test('each word has at least three clues', () {
      // One word can need a fresh clue on every exchange.
      for (final word in words) {
        expect(ClueBank.clues[word]!.length, greaterThanOrEqualTo(3),
            reason: '"$word" needs at least three clues');
      }
    });

    test('a clue is a single word and never blank', () {
      for (final word in words) {
        for (final clue in ClueBank.clues[word]!) {
          expect(clue.trim(), isNotEmpty, reason: 'blank clue on "$word"');
          expect(clue.trim(), isNot(contains(' ')),
              reason: '"$clue" on "$word" is not a one-word clue');
        }
      }
    });

    test('a clue never gives its own answer away', () {
      for (final word in words) {
        for (final clue in ClueBank.clues[word]!) {
          final lower = clue.toLowerCase();
          expect(lower, isNot(word), reason: '"$word" is clued with itself');
          expect(lower.contains(word), isFalse,
              reason: '"$clue" contains the answer "$word"');
          expect(word.contains(lower), isFalse,
              reason: '"$clue" is inside the answer "$word"');
        }
      }
    });

    test('a word never repeats a clue', () {
      for (final word in words) {
        final clues = ClueBank.clues[word]!;
        final unique = {for (final c in clues) c.toLowerCase()};
        expect(unique.length, clues.length, reason: '"$word" repeats a clue');
      }
    });

    test('a clue is never itself a playable answer', () {
      // Otherwise the clue looks like a legitimate answer and saying it is a
      // foul, which is exactly the confusion Ronna hit.
      final playable = words.toSet();
      for (final word in words) {
        for (final clue in ClueBank.clues[word]!) {
          expect(playable.contains(clue.toLowerCase()), isFalse,
              reason: '"$clue" (clue for "$word") is also an answer');
        }
      }
    });

    test('no clue is banned by the rules of the game', () {
      for (final word in words) {
        for (final clue in ClueBank.clues[word]!) {
          expect(AiPlayer.clueFor(word), isNotEmpty);
          final lower = clue.toLowerCase();
          expect(lower.startsWith('start'), isFalse, reason: clue);
          expect(lower.startsWith('end'), isFalse, reason: clue);
          expect(lower.contains('letter'), isFalse, reason: clue);
        }
      }
    });
  });

  group('a clue narrows down one answer', () {
    test('no clue is shared by more than three answers', () {
      final owners = <String, List<String>>{};
      for (final word in words) {
        for (final clue in ClueBank.clues[word]!) {
          owners.putIfAbsent(clue.toLowerCase(), () => []).add(word);
        }
      }
      for (final entry in owners.entries) {
        expect(entry.value.length, lessThanOrEqualTo(3),
            reason: '"${entry.key}" could mean any of ${entry.value}');
      }
    });

    test('no two answers share the same set of clues', () {
      final seen = <String, String>{};
      for (final word in words) {
        final key = (ClueBank.clues[word]!.map((c) => c.toLowerCase()).toList()
              ..sort())
            .join('|');
        expect(seen.containsKey(key), isFalse,
            reason: '"$word" and "${seen[key]}" have identical clues');
        seen[key] = word;
      }
    });

    test('the generic category placeholders are gone', () {
      // The exact words that made the old bank unplayable.
      const placeholders = {
        'person', 'someone', 'people', 'place', 'spot', 'area', 'idea',
        'concept', 'thought', 'career', 'profession', 'work', 'thing', 'item',
        'object', 'action', 'doing', 'verb', 'location',
      };
      for (final word in words) {
        for (final clue in ClueBank.clues[word]!) {
          expect(placeholders.contains(clue.toLowerCase()), isFalse,
              reason: '"$clue" on "$word" does not identify anything');
        }
      }
    });
  });

  group('a game only ever deals words it can clue', () {
    test('WordBank deals from the clue bank', () {
      expect(WordBank.words, ClueBank.words);
    });

    test('a full deal is solvable', () {
      for (var game = 0; game < 50; game++) {
        for (final word in WordBank.deal(16)) {
          expect(ClueBank.isPlayable(word), isTrue,
              reason: '"$word" was dealt with no clue to give');
          expect(AiPlayer.clueFor(word).toLowerCase(), isNot(word.toLowerCase()));
        }
      }
    });

    test('a stand-in can clue a word freshly on every exchange', () {
      for (final word in WordBank.words) {
        final given = <String>[];
        for (var exchange = 0; exchange < 3; exchange++) {
          final clue = AiPlayer.clueFor(word, variant: exchange, avoid: given);
          expect(given.map((g) => g.toLowerCase()), isNot(contains(clue.toLowerCase())),
              reason: 'repeated "$clue" on "$word"');
          given.add(clue);
        }
      }
    });

    test('a stand-in only ever offers a curated clue', () {
      // The legacy tables must not leak back in. They are what produced
      // "Garden" clued as "Spot" (145 possible answers) and "Kettle" clued as
      // "Tea", which is itself an answer and so a foul to say.
      final playable = {for (final w in ClueBank.words) w.toLowerCase()};
      for (final word in ClueBank.words) {
        final allowed = {
          for (final c in ClueBank.cluesFor(word)) c.toLowerCase(),
        };
        for (var variant = 0; variant < 12; variant++) {
          final clue = AiPlayer.clueFor(word, variant: variant).toLowerCase();
          expect(allowed, contains(clue),
              reason: '"$word" was clued "$clue", which is not in its bank');
          expect(playable.contains(clue), isFalse,
              reason: '"$clue" is an answer, so clueing with it is a foul');
        }
      }
    });
  });

  group('a stand-in that misses still sounds like it was listening', () {
    test('a wrong guess is another word from the same family', () {
      // Ronna: "the clues and answers didn't make sense when standin's played".
      for (final word in ClueBank.words) {
        final siblings = ClueBank.siblingsOf(word).map((s) => s.toLowerCase());
        expect(siblings, isNotEmpty, reason: '"$word" has no family');
        expect(siblings, isNot(contains(word.toLowerCase())));
      }
    });

    test('a wrong guess is never one of the clues just given', () {
      // Saying the clue back is a foul, so a miss must not be a clue.
      for (final word in ClueBank.words) {
        final clues = ClueBank.cluesFor(word).map((c) => c.toLowerCase()).toSet();
        for (var seed = 0; seed < 40; seed++) {
          final guess = AiPlayer.guessFor(word, seed: seed).toLowerCase();
          expect(clues.contains(guess), isFalse,
              reason: 'guessed the clue "$guess" for "$word"');
        }
      }
    });

    test('a wrong guess is a real word, not a shrug', () {
      for (final word in ClueBank.words) {
        for (var seed = 0; seed < 20; seed++) {
          expect(AiPlayer.guessFor(word, seed: seed), isNot('Hmm'));
        }
      }
    });
  });

  test('the server deals the same bank as the app', () {
    // mw_begin_play holds its own copy of the bank, so an app-only change would
    // silently leave online games dealing unclueable words.
    final sql =
        File('supabase/migrations/0032_clue_safe_word_bank.sql').readAsStringSync();
    final array = RegExp(r'v_bank\s+text\[\]\s*:=\s*array\[(.*?)\];', dotAll: true)
        .firstMatch(sql);
    expect(array, isNotNull, reason: 'could not find the server bank');
    final serverWords = RegExp("'([A-Za-z]+)'")
        .allMatches(array!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();
    expect(serverWords, ClueBank.words.toSet());
  });
}
